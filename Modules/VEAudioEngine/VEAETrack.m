//
//  VEAETrack.m
//  VEAudioEngine Module for TheAmazingAudioEngine
//
//  Created by Leo Thiessen on 2015-01-21.
//
//  Copyright (C) 2015 Visions Encoded.
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


#import "VEAETrack.h"



@implementation VEAETrack {
    AEAudioControllerRenderCallback _superclassRenderCallback;
    AudioTimeStamp _audioTimeStamp;
    UInt32 _audioTimeStampSize;
    AudioFileID _fileId;
    UInt32 _mFramesToPlay;
    UInt32 _numLoopsCompleted;
    Float64 _outSampleRate;
    NSTimeInterval _duration;
    NSTimeInterval _currentTime;
    ve_completion_block_t _completionBlock;
}


@synthesize duration=_duration,
            currentTime=_currentTime,
            completionBlock=_completionBlock;



#pragma mark - Initialize

- (instancetype)initWithFileURL:(NSURL*)fileURL
                audioController:(AEAudioController*)audioController
                     shouldLoop:(BOOL)shouldLoop
                          error:(NSError**)error {
    
    if(!(fileURL)) {
        if(error) *error = veNSError(@"fileURL was not provided.");
        return nil;
    }
    
    if(!(self=[super init])) {
        if(error) *error = veNSError(@"The superclass could not be initalized.");
        return nil;
    }
    
    
    // Init iVars
    _superclassRenderCallback = [super renderCallback];
    _url = [fileURL copy];
    _audCtrlr = audioController;
    _isLooping = shouldLoop;
    memset(&_audioTimeStamp, 0, sizeof(AudioTimeStamp)); // zero out the memory location for this struct
    _audioTimeStampSize = sizeof(AudioTimeStamp);
    
    // Setup an AUAudioFilePlayer for playback
    if(![self _setup:error]) {
        return nil;
    }
    
    // Set our default behaviour to automatically start playback when this channel is added to the _audCtrlr
    self.channelIsMuted = NO;
    self.channelIsPlaying = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_didRecreateGraph:)
                                                 name:AEAudioControllerDidRecreateGraphNotification
                                               object:_audCtrlr];
    
    return self;
}


/// This is simply an internal helper method for the _setup: method
- (void)_setupDidFail:(OSStatus)result error:(NSError**)error msg:(NSString*)localizedDescription {
    if(error) *error = audNSError(result, @"Couldn't set the output kAudioUnitProperty_StreamFormat");
    audCheck(AUGraphRemoveNode(_audCtrlr.audioGraph, _auNode), "AUGraphRemoveNode() - failed attempted cleanup.");
    _auNode = 0;
    _au = NULL;
}


/// Setup an AUAudioFilePlayer Audio Unit for playback
- (BOOL)_setup:(NSError**)error {
    AUGraph graph = _audCtrlr.audioGraph;
    AudioComponentDescription compDesc = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                         kAudioUnitType_Generator,
                                                                         kAudioUnitSubType_AudioFilePlayer);
    OSStatus result;
    if(!audCheck(result=AUGraphAddNode(graph, &compDesc, &_auNode), "AUGraphAddNode")) {
        if(error) *error = audNSError(result, @"Failed to do AUGraphAddNode()");
        _auNode = 0;
        return NO;
    }
    if(!audCheck(result=AUGraphNodeInfo(graph, _auNode, NULL, &_au), "AUGraphNodeInfo")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed in AUGraphNodeInfo()"];
        return NO;
    }
    
    UInt32 maxFPS = 4096;
    audCheck(result=AudioUnitSetProperty(_au,
                                         kAudioUnitProperty_MaximumFramesPerSlice,
                                         kAudioUnitScope_Global,
                                         0,
                                         &maxFPS,
                                         sizeof(maxFPS)),
             "kAudioUnitProperty_MaximumFramesPerSlice");
    
    // Try to set the output audio description
    AudioStreamBasicDescription outASBD = _audCtrlr.audioDescription;
    if(!audCheck(result=AudioUnitSetProperty(_au,
                                             kAudioUnitProperty_StreamFormat,
                                             kAudioUnitScope_Output,
                                             0,
                                             &outASBD,
                                             sizeof(AudioStreamBasicDescription)),
                 "AudioUnitSetProperty[kAudioUnitProperty_StreamFormat]")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Couldn't set the output kAudioUnitProperty_StreamFormat"];
        return NO;
    }
    
    if(!audCheck(result=AUGraphUpdate(graph, NULL), "AUGraphUpdate")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed to do AUGraphUpdate()"];
        return NO;
    }
    
    if(!audCheck(result=AudioUnitInitialize(_au), "AudioUnitInitialize")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed to do AudioUnitInitialize()"];
        return NO;
    }
    
    // Open the input audio file
    _fileId = NULL;
    if(!audCheck(result=AudioFileOpenURL((__bridge CFURLRef)_url,
                                         kAudioFileReadPermission,
                                         0,
                                         &_fileId),
                 "AudioFileOpenURL[kAudioFileReadPermission] failed")) {
        [self _setupDidFail:result
                      error:error
                        msg:[NSString stringWithFormat:@"Failed to do AudioFileOpenURL('%@')", _url]];
        return NO;
    }
    
    // Get the audio data format from the file
    AudioStreamBasicDescription fileASBD;
    UInt32 propSize = sizeof(fileASBD);
    if(!audCheck(result=AudioFileGetProperty(_fileId,
                                             kAudioFilePropertyDataFormat,
                                             &propSize,
                                             &fileASBD),
                 "AudioFileGetProperty[kAudioFilePropertyDataFormat] failed")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed to do AudioFileGetProperty(kAudioFilePropertyDataFormat)"];
        return NO;
    }
    
    // Get number of packets in the audio file
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    if(!audCheck(result=AudioFileGetProperty(_fileId,
                                             kAudioFilePropertyAudioDataPacketCount,
                                             &propsize,
                                             &nPackets),
                 "AudioFileGetProperty[kAudioFilePropertyAudioDataPacketCount] failed")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed to do AudioFileGetProperty(kAudioFilePropertyAudioDataPacketCount)"];
        return NO;
    }
    
    // Provide a list of AudioFileIDs to play by setting the unit’s kAudioUnitProperty_ScheduledFileIDs property.
    // This probably *adds to* rather than "sets" the property
    if(!audCheck(result=AudioUnitSetProperty(_au,
                                             kAudioUnitProperty_ScheduledFileIDs,
                                             kAudioUnitScope_Global,
                                             0,
                                             &_fileId,
                                             sizeof(_fileId)),
                 "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIDs] failed")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed to do AudioUnitSetProperty(kAudioUnitProperty_ScheduledFileIDs)"];
        return NO;
    }
    
    // Tell the file player AU to play the entire file
    // This probably *adds to* rather than "sets" the property, see
    // http://lists.apple.com/archives/coreaudio-api/2012/Jun/msg00022.html
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL; // using this "completion" callback results in a too-early callback
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = _fileId;
    rgn.mLoopCount = _isLooping ? UINT32_MAX : 0;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = (UInt32)(nPackets * fileASBD.mFramesPerPacket);
    _mFramesToPlay = rgn.mFramesToPlay * (outASBD.mSampleRate / fileASBD.mSampleRate); // Used to trigger callbacks
    if(!audCheck(result=AudioUnitSetProperty(_au,
                                             kAudioUnitProperty_ScheduledFileRegion,
                                             kAudioUnitScope_Global,
                                             0,
                                             &rgn,
                                             sizeof(rgn)),
                 "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion] failed")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed to do AudioUnitSetProperty(kAudioUnitProperty_ScheduledFileRegion)"];
        return NO;
    }
    
    // Prime the player by setting the kAudioUnitProperty_ScheduledFilePrime property.
    UInt32 primeFrames = 0;	// use default
    if(!audCheck(result=AudioUnitSetProperty(_au,
                                             kAudioUnitProperty_ScheduledFilePrime,
                                             kAudioUnitScope_Global,
                                             0,
                                             &primeFrames,
                                             sizeof(primeFrames)),
                 "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFilePrime] failed")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed to do AudioUnitSetProperty(kAudioUnitProperty_ScheduledFileRegion)"];
        return NO;
    }
    
    // Provide a start time with the kAudioUnitProperty_ScheduleStartTimeStamp property.
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1; // -1 means start playing next render cycle
    if(!audCheck(result=AudioUnitSetProperty(_au,
                                             kAudioUnitProperty_ScheduleStartTimeStamp,
                                             kAudioUnitScope_Global,
                                             0,
                                             &startTime,
                                             sizeof(startTime)),
                 "AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]")) {
        [self _setupDidFail:result
                      error:error
                        msg:@"Failed to do AudioUnitSetProperty(kAudioUnitProperty_ScheduleStartTimeStamp)"];
        return NO;
    }
    
    // Calculating file playback duration in seconds:
    //    _lengthInSeconds = (nPackets * outASBD.mFramesPerPacket) / outASBD.mSampleRate;
    // Must calculate differently for compressed files, as per:
    // http://forum.theamazingaudioengine.com/discussion/comment/388/#Comment_388
    double audioSampleFramesCount = nPackets * fileASBD.mFramesPerPacket; // could be inaccurate for compressed format
    AudioFilePacketTableInfo pktinfo;
    propsize = sizeof(pktinfo);
    if(noErr==AudioFileGetProperty(_fileId, kAudioFilePropertyPacketTableInfo, &propsize, &pktinfo)) {
        audioSampleFramesCount = pktinfo.mNumberValidFrames; // should be accurate for compressed audio format too
    }
    _outSampleRate = outASBD.mSampleRate;
    _duration = audioSampleFramesCount / _outSampleRate;
    
    return YES;
}



#pragma mark - Memory Management

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AEAudioControllerDidRecreateGraphNotification
                                                  object:_audCtrlr];
    if(_auNode) {
        audCheck(AUGraphRemoveNode(_audCtrlr.audioGraph, _auNode), "AUGraphRemoveNode");
    }
    audCheck(AUGraphUpdate(_audCtrlr.audioGraph, NULL), "AUGraphUpdate");
    audCheck(AudioFileClose(_fileId), "AudioFileClose");
}



#pragma mark - Realtime Audio Thread Functions

static void _notifyCompletion(AEAudioController *audioController, void *userInfo, int length) {
    VEAETrack *THIS = (__bridge VEAETrack*)*(void**)userInfo;
    if(THIS->_completionBlock) {
        THIS->_completionBlock(THIS);
        if(!THIS->_isLooping) {
            [THIS setChannelIsPlaying:NO]; // in case of KVO send a message
            THIS->_completionBlock = NULL;
        }
    }
}


static OSStatus _renderCallback(__unsafe_unretained VEAETrack         *THIS,
                                __unsafe_unretained AEAudioController *audioController,
                                const AudioTimeStamp                  *time,
                                UInt32                                 frameCount,
                                AudioBufferList                       *audio) {
    
    // Do the main audio processing in the super-class which also handles gain and pan filtering and modulation for us
    THIS->_superclassRenderCallback(THIS, audioController, time, frameCount, audio);
    
    // Get our current time data
    if(noErr==AudioUnitGetProperty(THIS->_au,
                                   kAudioUnitProperty_CurrentPlayTime,
                                   kAudioUnitScope_Global,
                                   0,
                                   &THIS->_audioTimeStamp,
                                   &THIS->_audioTimeStampSize)) {
        float loop = floor(THIS->_audioTimeStamp.mSampleTime / THIS->_mFramesToPlay);
        THIS->_currentTime = (THIS->_audioTimeStamp.mSampleTime - (loop * THIS->_mFramesToPlay)) / THIS->_outSampleRate;
        
        // Check for callbacks to be done
        if(THIS->_completionBlock) {
            if(THIS->_isLooping) {
                // If we are on a new loop number, trigger completion callback
                if((UInt32)loop > THIS->_numLoopsCompleted) {
                    THIS->_numLoopsCompleted++;
                    AEAudioControllerSendAsynchronousMessageToMainThread(audioController,
                                                                         _notifyCompletion,
                                                                         &THIS,
                                                                         sizeof(VEAETrack*));
                }
            } else {
                // If we're in the last renderCallback of a non-looping channel, trigger the completion callback
                UInt32 completedFrmes = ((UInt32)THIS->_audioTimeStamp.mSampleTime % THIS->_mFramesToPlay) + frameCount;
                if(completedFrmes >= THIS->_mFramesToPlay) {
                    AEAudioControllerSendAsynchronousMessageToMainThread(audioController,
                                                                         _notifyCompletion,
                                                                         &THIS,
                                                                         sizeof(VEAETrack*));
                }
            }
        }
    }
    
    return noErr;
}


- (AEAudioControllerRenderCallback)renderCallback {
    return _renderCallback;
}



#pragma mark - NSNotifications

- (void)_didRecreateGraph:(NSNotification*)notification {
    _auNode = 0;
    _au = NULL;
    [self _setup:NULL]; // attempt to re-setup with a new AUAudioFilePlayer Audio Unit for playback
}


@end
