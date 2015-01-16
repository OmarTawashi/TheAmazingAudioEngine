//
//  AEAUAudioFilePlayerChannel.m
//  TheAmazingAudioEngine
//
//  This file is based on "AEAudioUnitChannel.m" which was created by Michael
//  Tyson on 01/02/2013.
//
//  This file was created by Leo Thiessen on 10/12/2014.
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "AEAUAudioFilePlayerChannel.h"

#define checkResult(result,operation) (_checkResult((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _checkResult(OSStatus result, const char *operation, const char* file, int line) {
    if ( result != noErr ) {
        int fourCC = CFSwapInt32HostToBig(result);
        NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&fourCC);
        return NO;
    }
    return YES;
}

@interface AEAUAudioFilePlayerChannel () {
    AEAudioController *_audioController;
    AudioComponentDescription _componentDescription;
    AUNode _node;
    AudioUnit _audioUnit;
//    AUNode _converterNode;    // We use the AUAudioFilePlayer units built in conversion capability instead
//    AudioUnit _converterUnit;
    AUGraph _audioGraph;
    AudioFileID _fileId;
    UInt32 _mFramesToPlay;
    UInt32 _numLoopsCompleted;
    NSTimeInterval _currentTime;
    Float64 _outSampleRate;
    BOOL _outputIsSilence;
}
@end

@implementation AEAUAudioFilePlayerChannel

@synthesize url=_fileURL;
@synthesize currentTime=_currentTime;
@synthesize duration=_duration;
@synthesize loop=_loop;
@synthesize completionBlock  = _completionBlock;
@synthesize startLoopBlock   = _startLoopBlock;
@synthesize removeUponFinish = _removeUponFinish;
@synthesize outputIsSilence = _outputIsSilence;

- (id)initWithFileURL:(NSURL*)fileURL
      audioController:(AEAudioController*)audioController
           shouldLoop:(BOOL)shouldLoop
                error:(NSError**)error {
    return [self initWithFileURL:fileURL audioController:audioController preInitializeBlock:NULL shouldLoop:shouldLoop error:error];
}

- (id)initWithFileURL:(NSURL*)fileURL
      audioController:(AEAudioController*)audioController
   preInitializeBlock:(void(^)(AudioUnit audioUnit))block
           shouldLoop:(BOOL)shouldLoop
                error:(NSError**)error {
    
    if(!(fileURL)) return nil;
    
    if ( !(self = [super init]) ) return nil;
    
    // Create the node, and the audio unit
    _audioController = audioController;
    _componentDescription = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Generator, kAudioUnitSubType_AudioFilePlayer);
    _audioGraph = _audioController.audioGraph;
    _fileURL = fileURL;
    _loop = shouldLoop;
    _numLoopsCompleted = 0;
    _outputIsSilence = YES;
    
    if ( ![self setup:block error:error] ) {
        return nil;
    }
    
    self.volume = 1.0;
    self.pan = 0.0;
    self.channelIsMuted = NO;
    self.channelIsPlaying = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRecreateGraph:) name:AEAudioControllerDidRecreateGraphNotification object:_audioController];
    
    return self;
}

- (BOOL)setup:(void(^)(AudioUnit audioUnit))block error:(NSError**)error {
	OSStatus result;
    if ( !checkResult(result=AUGraphAddNode(_audioGraph, &_componentDescription, &_node), "AUGraphAddNode") ||
         !checkResult(result=AUGraphNodeInfo(_audioGraph, _node, NULL, &_audioUnit), "AUGraphNodeInfo") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result userInfo:@{NSLocalizedDescriptionKey: @"Couldn't initialise audio unit"}];
        return NO;
    }
    
    UInt32 maxFPS = 4096;
    checkResult(result=AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, sizeof(maxFPS)), "kAudioUnitProperty_MaximumFramesPerSlice");

    // Try to set the output audio description
    AudioStreamBasicDescription outASBD = _audioController.audioDescription;
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outASBD, sizeof(AudioStreamBasicDescription));
    
    checkResult(AUGraphUpdate(_audioGraph, NULL), "AUGraphUpdate");

    if(block) block(_audioUnit);

    checkResult(AudioUnitInitialize(_audioUnit), "AudioUnitInitialize");
    
    // Open the input audio file
    _fileId = NULL;
    checkResult(AudioFileOpenURL((__bridge CFURLRef)_fileURL,
                                 kAudioFileReadPermission,
                                 0,
                                 &_fileId),
                "AudioFileOpenURL[kAudioFileReadPermission] failed");
    
    // Get the audio data format from the file
    AudioStreamBasicDescription fileASBD;
    UInt32 propSize = sizeof(fileASBD);
    checkResult(AudioFileGetProperty(_fileId,
                                     kAudioFilePropertyDataFormat,
                                     &propSize,
                                     &fileASBD),
                "AudioFileGetProperty[kAudioFilePropertyDataFormat] failed");
    
    // Get number of packets in the audio file
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    checkResult(AudioFileGetProperty(_fileId,
                                     kAudioFilePropertyAudioDataPacketCount,
                                     &propsize,
                                     &nPackets),
                "AudioFileGetProperty[kAudioFilePropertyAudioDataPacketCount] failed");
    
    // Provide a list of AudioFileIDs to play by setting the unit’s kAudioUnitProperty_ScheduledFileIDs property.
    // This probably *adds to* rather than "sets" the property
    checkResult(AudioUnitSetProperty(_audioUnit,
                                     kAudioUnitProperty_ScheduledFileIDs,
                                     kAudioUnitScope_Global,
                                     0,
                                     &_fileId,
                                     sizeof(_fileId)),
                "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIDs] failed");
    
    // Tell the file player AU to play the entire file
    // This probably *adds to* rather than "sets" the property, see http://lists.apple.com/archives/coreaudio-api/2012/Jun/msg00022.html
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL;
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = _fileId;
    rgn.mLoopCount = _loop ? UINT32_MAX : 0;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = (UInt32)(nPackets * fileASBD.mFramesPerPacket);
    _mFramesToPlay = rgn.mFramesToPlay * (outASBD.mSampleRate / fileASBD.mSampleRate); // BUGS? This is used for detecting if callback blocks need to be triggered from inside the render function - someone please check my math here
    checkResult(AudioUnitSetProperty(_audioUnit,
                                     kAudioUnitProperty_ScheduledFileRegion,
                                     kAudioUnitScope_Global,
                                     0,
                                     &rgn,
                                     sizeof(rgn)),
                "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion] failed");
    
    // Prime the player by setting the kAudioUnitProperty_ScheduledFilePrime property.
    UInt32 primeFrames = 0;	// use default
    checkResult(AudioUnitSetProperty(_audioUnit,
                                     kAudioUnitProperty_ScheduledFilePrime,
                                     kAudioUnitScope_Global,
                                     0,
                                     &primeFrames,
                                     sizeof(primeFrames)),
                "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFilePrime] failed");
    
    // Provide a start time with the kAudioUnitProperty_ScheduleStartTimeStamp property.
    // Tell the file player AU when to start playing (-1 sample time // means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    checkResult(AudioUnitSetProperty(_audioUnit,
                                     kAudioUnitProperty_ScheduleStartTimeStamp,
                                     kAudioUnitScope_Global,
                                     0,
                                     &startTime,
                                     sizeof(startTime)),
                "AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]");
    
    
    // Calculating file playback duration in seconds
//    _lengthInSeconds = (nPackets * outASBD.mFramesPerPacket) / outASBD.mSampleRate;
    // ... must calculate differently for compressed files, as per: http://forum.theamazingaudioengine.com/discussion/comment/388/#Comment_388
    AudioFilePacketTableInfo pktinfo;
    propsize = sizeof(pktinfo);
    if(AudioFileGetProperty(_fileId, kAudioFilePropertyPacketTableInfo, &propsize, &pktinfo) != noErr) {
        propsize = 0;
    }
    double audioSampleFramesCount = (propsize) ? pktinfo.mNumberValidFrames : (nPackets * fileASBD.mFramesPerPacket);
    _outSampleRate = outASBD.mSampleRate;
    _duration = audioSampleFramesCount / _outSampleRate;

    return YES;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AEAudioControllerDidRecreateGraphNotification object:_audioController];
    
    if ( _node ) {
        checkResult(AUGraphRemoveNode(_audioGraph, _node), "AUGraphRemoveNode");
    }

    checkResult(AUGraphUpdate(_audioGraph, NULL), "AUGraphUpdate");
    
    checkResult(AudioFileClose(_fileId), "AudioFileClose");
}

-(AudioUnit)audioUnit {
    return _audioUnit;
}

-(AUNode)audioGraphNode {
    return _node;
}

static void notifyPlaybackStopped(AEAudioController *audioController, void *userInfo, int length) {
    AEAUAudioFilePlayerChannel *THIS = (__bridge AEAUAudioFilePlayerChannel*)*(void**)userInfo;
    THIS->_channelIsPlaying = NO;
    THIS->_outputIsSilence = YES;
    
    if ( THIS->_removeUponFinish ) {
        [audioController removeChannels:@[THIS]];
    }
    
    if ( THIS->_completionBlock ) {
        THIS->_completionBlock();
        THIS->_completionBlock = NULL;
    }
}

static void notifyStartLoopBlock(AEAudioController *audioController, void *userInfo, int length) {
    AEAUAudioFilePlayerChannel *THIS = (__bridge AEAUAudioFilePlayerChannel*)*(void**)userInfo;
    THIS->_channelIsPlaying = YES;
    
    if ( THIS->_startLoopBlock ) {
        THIS->_startLoopBlock();
    }
}

static OSStatus renderCallback(__unsafe_unretained AEAUAudioFilePlayerChannel *THIS,
                               __unsafe_unretained AEAudioController *audioController,
                               const AudioTimeStamp     *time,
                               UInt32                    frames,
                               AudioBufferList          *audio) {
    
    AudioUnitRenderActionFlags flags = 0;
    checkResult(AudioUnitRender(THIS->_audioUnit, &flags, time, 0, frames, audio), "AudioUnitRender");
    
    // Update outputIsSilence status
    THIS->_outputIsSilence = (flags & kAudioUnitRenderAction_OutputIsSilence);
    
    // Get our current time data
    AudioTimeStamp ts;
    UInt32 size = sizeof(ts);
    AudioUnitGetProperty(THIS->_audioUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, &ts, &size);
    
    // Check for callbacks to be done
    if(THIS->_loop) {
        
        // Looping callback
        UInt32 currentNumLoops = floor(ts.mSampleTime / THIS->_mFramesToPlay);
        
        // Update current time relative to the start of the file (instead of overall playback time)
        THIS->_currentTime = (ts.mSampleTime - ((float)currentNumLoops * THIS->_mFramesToPlay)) / THIS->_outSampleRate;
        
        // If we are on a new loop number, trigger the startLoop callback
        if(currentNumLoops > THIS->_numLoopsCompleted) {
            THIS->_numLoopsCompleted++;
            AEAudioControllerSendAsynchronousMessageToMainThread(audioController, notifyStartLoopBlock, &THIS, sizeof(AEAUAudioFilePlayerChannel*));
        }
    } else {
        
        // Update current time
        THIS->_currentTime = ts.mSampleTime / THIS->_outSampleRate;
        
        // If we're in the last renderCallback, trigger the completion callback
        UInt32 remainderPlusFramesThisRender = ((UInt32)ts.mSampleTime % THIS->_mFramesToPlay) + frames;
        if(remainderPlusFramesThisRender >= THIS->_mFramesToPlay) {
            AEAudioControllerSendAsynchronousMessageToMainThread(audioController, notifyPlaybackStopped, &THIS, sizeof(AEAUAudioFilePlayerChannel*));
        }
    }
    
    return noErr;
}

-(AEAudioControllerRenderCallback)renderCallback {
    return renderCallback;
}

- (void)didRecreateGraph:(NSNotification*)notification {
    _node = 0;
    _audioUnit = NULL;
    _audioGraph = _audioController.audioGraph;
    [self setup:nil error:NULL];
}

@end
