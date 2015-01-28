//
//  VEAEAbstractChannel.m
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

#import "VEAEAbstractChannel.h"



BOOL _needToGetTInfo = YES;
double _hTime2nsFactor = 1.0; // we'll get the actual value of this when this class is loaded the first time



@implementation VEAEAbstractChannel


@synthesize url=_url,
            audioDescription=_asbd,
            audioUnit=_au,
            audioGraphNode=_auNode,
            channelIsPlaying=_channelIsPlaying,
            channelIsMuted=_channelIsMuted,
            isLooping=_isLooping;



#pragma mark - Initialization

+ (void)load {
    
    // One time static initialization
    if(_needToGetTInfo) {
        kern_return_t kerror;
        mach_timebase_info_data_t tinfo;
        kerror = mach_timebase_info(&tinfo);
        if(kerror == KERN_SUCCESS) {
            _hTime2nsFactor = 1.0 / ((double)tinfo.numer / (double)tinfo.denom);
            _needToGetTInfo = NO;
        }
    }
}


- (instancetype)init {
    if((self=[super init])) {
        _dspGain = 1.0f; // 100% volume
        _dspPan = 1.0f;  // center
        _outputIsSilence = YES; // nothing is happenning yet
        _channelIsMuted = NO;
        _channelIsPlaying = NO; // don't play automatically when added
        _isLooping = NO; // default is not to loop
        memset(&_modGain, 0, sizeof(_aud_modulate_param_t)); // set initial values to 0
        memset(&_modPan, 0, sizeof(_aud_modulate_param_t));  // set initial values to 0
        
        // TODO IN A SUB-CLASS: need to actually create and init the Audio Unit to be used and do related setup.
    }
    return self;
}



#pragma mark - Declared Properties

- (BOOL)outputIsSilence {
    return (_outputIsSilence || (_dspGain < FLT_EPSILON));
}


- (float)dspGain {
    return _dspGain;
}


- (void)setDspGain:(float)dspGain {
    _audStopModulation(&_modGain, _audCtrlr);
    _dspGain = dspGain < 0 ? 0 : dspGain;
    if(_modGainCompletionBlock) {
        _modGainCompletionBlock(self);
        _modGainCompletionBlock = NULL;
    }
}


- (float)dspPan {
    return _dspPan;
}


- (void)setDspPan:(float)dspPan {
    _audStopModulation(&_modPan, _audCtrlr);
    _dspPan = dspPan < 0 ? 0 : (dspPan > 2 ? 2 : dspPan);
    if(_modPanCompletionBlock) {
        _modPanCompletionBlock(self);
        _modPanCompletionBlock = NULL;
    }
}


- (void)dspGainTo:(float)gain duration:(float)seconds completion:(ve_completion_block_t)completion {
    
    // Stop any active modulation by setting it's value
    [self stopModulatingDspGain]; // this ensures any existing completion block is called as required
    
    // Setup for modulation to the new value
    if(completion) {
        _modGainCompletionBlock = [completion copy];
    }
    _modGain.startValue = _dspGain; // current
    _modGain.endValue = gain < 0 ? 0 : gain;
    _modGain.valueDiff = _modGain.endValue - _modGain.startValue;
    if(seconds > 0.05f && _modGain.valueDiff > FLT_EPSILON) {
        if(completion) {
            _modGainCompletionBlock = [completion copy];
        }
        // The "host time" supposedy stops when the machine stops or sleeps, which in our case is good, as our
        // modulation should wait then too
        _modGain.hostStartTime = mach_absolute_time();
        _modGain.hostDuration = _audHostTicksFromSeconds(seconds);
        _modGain.hostEndTime = _modGain.hostStartTime + _modGain.hostDuration; // set future time to be finished by
        
        // Start modulating
        _modGain.active = YES;
    } else {
        [self setDspGain:_modGain.endValue]; // instant, also calls the completion block
    }
}


- (void)dspPanTo:(float)pan duration:(float)seconds completion:(ve_completion_block_t)completion {
    
    // Stop any active modulation by setting it's value
    [self stopModulationDspPan]; // this ensures any existing completion block is called as required
    
    // Setup for modulation to the new value
    if(completion) {
        _modPanCompletionBlock = [completion copy];
    }
    _modPan.startValue = _dspPan; // current
    _modPan.endValue = pan < 0 ? 0 : (pan > 2 ? 2 : pan);
    _modPan.valueDiff = _modPan.endValue - _modPan.startValue;
    if(seconds > 0.05f && _modPan.valueDiff > FLT_EPSILON) {
        if(completion) {
            _modPanCompletionBlock = [completion copy];
        }
        // The "host time" supposedy stops when the machine stops or sleeps, which in our case is good, as our
        // modulation should wait then too
        _modPan.hostStartTime = mach_absolute_time();
        _modPan.hostDuration = _audHostTicksFromSeconds(seconds);
        _modPan.hostEndTime = _modPan.hostStartTime + _modPan.hostDuration; // set future time to be finished by
        
        // Start modulating
        _modPan.active = YES;
    } else {
        [self setDspPan:_modPan.endValue]; // instant, also calls the completion block
    }
}


- (void)stopModulatingDspGain {
    [self setDspGain:_dspGain];
}


- (void)stopModulationDspPan {
    [self setDspPan:_dspPan];
}


- (BOOL)isModulating {
    return (_modGain.active || _modPan.active);
}


- (void)removeSelf:(float)fadeOutDuration {
    fadeOutDuration = fadeOutDuration<0 ? 0 : fadeOutDuration;
    AEAudioController __weak *weakAudCtrlr = _audCtrlr;
    [self dspGainTo:0 duration:fadeOutDuration completion:^(VEAEAbstractChannel *THIS){
        [weakAudCtrlr removeChannels:@[THIS]];
    }];
}



#pragma mark - Render Callback & Related Internal Notifications

static void _notifyModGainStopped(AEAudioController *audioController, void *userInfo, int length) {
    VEAEAbstractChannel *THIS = (__bridge VEAEAbstractChannel*)*(void**)userInfo;
    [THIS setDspGain:THIS->_dspGain];
}


static void _notifyModPanStopped(AEAudioController *audioController, void *userInfo, int length) {
    VEAEAbstractChannel *THIS = (__bridge VEAEAbstractChannel*)*(void**)userInfo;
    [THIS setDspPan:THIS->_dspPan];
}


static OSStatus _renderCallback(__unsafe_unretained VEAEAbstractChannel *THIS,
                                __unsafe_unretained AEAudioController   *audioController,
                                const AudioTimeStamp                    *time,
                                UInt32                                   frameCount,
                                AudioBufferList                         *audio) {
    
    // Render the audio
    AudioUnitRenderActionFlags flags = 0;
    if(audCheck(AudioUnitRender(THIS->_au, &flags, time, 0, frameCount, audio), "AudioUnitRender")) {
        
        // Modulate Gain
        if(THIS->_modGain.active) {
            if(time->mHostTime >= THIS->_modGain.hostEndTime) {
                THIS->_modGain.active = NO;
                THIS->_dspGain = THIS->_modGain.endValue; // set to exact end value
                AEAudioControllerSendAsynchronousMessageToMainThread(THIS->_audCtrlr,
                                                                     _notifyModGainStopped,
                                                                     &THIS,
                                                                     sizeof(&THIS));
            } else {
                float percComplete = ((float)(time->mHostTime - THIS->_modGain.hostStartTime))
                                     / THIS->_modGain.hostDuration;
                THIS->_dspGain = THIS->_modGain.startValue + (percComplete * THIS->_modGain.valueDiff);
            }
        }
        
        // Apply post-render gain filter (volume/amplification)
        audDSP_gain(audio, frameCount, THIS->_dspGain);
        
        // Modulate Pan
        if(THIS->_modPan.active) {
            if(time->mHostTime >= THIS->_modPan.hostEndTime) {
                THIS->_modPan.active = NO;
                THIS->_dspPan = THIS->_modPan.endValue; // set to exact end value
                AEAudioControllerSendAsynchronousMessageToMainThread(THIS->_audCtrlr,
                                                                     _notifyModPanStopped,
                                                                     &THIS,
                                                                     sizeof(&THIS));
            } else {
                float percCmplt = ((float)(time->mHostTime - THIS->_modPan.hostStartTime)) / THIS->_modPan.hostDuration;
                THIS->_dspPan = THIS->_modPan.startValue + (percCmplt * THIS->_modPan.valueDiff);
            }
        }
        
        // Apply post-render pan filter
        audDSP_pan(audio, frameCount, THIS->_dspPan);
        
    }
    
    // Update outputIsSilence status
    THIS->_outputIsSilence = (flags & kAudioUnitRenderAction_OutputIsSilence);
    
    return noErr;
}


-(AEAudioControllerRenderCallback)renderCallback {
    return _renderCallback;
}



@end
