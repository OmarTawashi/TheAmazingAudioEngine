//
//  VEAETrack.m
//  VEAudioEngine Module for TheAmazingAudioEngine
//
//  Created by Leo Thiessen on 2015-01-21.
//  Copyright (c) 2015 Visions Encoded. All rights reserved.
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


- (instancetype)initWithFileURL:(NSURL*)fileURL
                audioController:(AEAudioController*)audioController
                     shouldLoop:(BOOL)shouldLoop
                          error:(NSError**)error {
    
    if(!(fileURL)) return nil;
    
    if( !(self=[super init]) ) return nil;
    
    // Init iVars
    _superclassRenderCallback = [super renderCallback];
    _url = [fileURL copy];
    _audCtrlr = audioController;
    memset(&_audioTimeStamp, 0, sizeof(AudioTimeStamp)); // zero out the memory location for this struct
    _audioTimeStampSize = sizeof(AudioTimeStamp);
    
//    // Create the node, and the audio unit
//    _auVolume = 1.0; // default
//    memset(&_modulateVolume, 0, sizeof(_modulateVolume)); // zero out memory location, booleans will be false
//    _isTimingReceiver = NO; // currently are not a timing receiver
//    _audioController = audioController;
//    _componentDescription = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Generator, kAudioUnitSubType_AudioFilePlayer);
//    _audioGraph = _audioController.audioGraph;
//    _fileURL = fileURL;
//    _loop = shouldLoop;
//    _numLoopsCompleted = 0;
//    _outputIsSilence = YES;
//    
//    if ( ![self setup:block error:error] ) {
//        return nil;
//    }
//    
//    self.volume = 1.0;
//    self.pan = 0.0;
//    self.channelIsMuted = NO;
//    self.channelIsPlaying = YES;
//    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRecreateGraph:) name:AEAudioControllerDidRecreateGraphNotification object:_audioController];
    
    return self;
}


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


static OSStatus _renderCallback2(__unsafe_unretained VEAETrack         *THIS,
                                 __unsafe_unretained AEAudioController *audioController,
                                 const AudioTimeStamp                  *time,
                                 UInt32                                 frameCount,
                                 AudioBufferList                       *audio) {
    
    // Do the main audio processing
    THIS->_superclassRenderCallback(THIS, audioController, time, frameCount, audio);
    
    // Get our current time data
    if(noErr==AudioUnitGetProperty(THIS->_au,
                                   kAudioUnitProperty_CurrentPlayTime,
                                   kAudioUnitScope_Global,
                                   0,
                                   &THIS->_audioTimeStamp,
                                   &THIS->_audioTimeStampSize)) {
        UInt32 currLoopCount = floor(THIS->_audioTimeStamp.mSampleTime / THIS->_mFramesToPlay);
        THIS->_currentTime = (THIS->_audioTimeStamp.mSampleTime - ((float)currLoopCount * THIS->_mFramesToPlay)) / THIS->_outSampleRate;
        
        // Check for callbacks to be done
        if(THIS->_completionBlock) {
            if(THIS->_isLooping) {
                // If we are on a new loop number, trigger completion callback
                if(currLoopCount > THIS->_numLoopsCompleted) {
                    THIS->_numLoopsCompleted++;
                    AEAudioControllerSendAsynchronousMessageToMainThread(audioController, _notifyCompletion, &THIS, sizeof(VEAETrack*));
                }
            } else {
                // If we're in the last renderCallback of a non-looping channel, trigger the completion callback
                UInt32 remainderPlusFramesThisRender = ((UInt32)THIS->_audioTimeStamp.mSampleTime % THIS->_mFramesToPlay) + frameCount;
                if(remainderPlusFramesThisRender >= THIS->_mFramesToPlay) {
                    AEAudioControllerSendAsynchronousMessageToMainThread(audioController, _notifyCompletion, &THIS, sizeof(VEAETrack*));
                }
            }
        }
    }

    return noErr;
}


- (AEAudioControllerRenderCallback)renderCallback {
    return _renderCallback2;
}


@end
