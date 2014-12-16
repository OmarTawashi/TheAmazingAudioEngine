//
//  VEAEforGames.m
//  TheGameSample
//
//  Created by Leo on 2014-12-08.
//  Copyright (c) 2014 visionsencoded.com, All rights reserved.
//

#import "VEAEforGames.h"
#import <QuartzCore/QuartzCore.h>


//@interface MyAEAudioController : AEAudioController
//- (AudioUnit)getGroupMixerAudioUnit:(AEChannelGroupRef)channelGroup;
//@end
//@implementation MyAEAudioController
//- (AudioUnit)getGroupMixerAudioUnit:(AEChannelGroupRef)channelGroup {
//    return channelGroup->mixerAudioUnit;
//}
//@end



#pragma mark - STATIC VARIABLES (used internally to this file)

static AEAudioController *_audCtrlr = nil;
static AEChannelGroupRef _channelGroup = NULL;



#pragma mark - HIDDEN (INTERNAL USE) FUNCTIONS

AudioStreamBasicDescription _audCreateModifiedCopyOfASBD(AudioStreamBasicDescription asbd, float sampleRate, int numChannels) {
    // Create a mono audio description
    asbd.mSampleRate = sampleRate; // I like to use 22050.0 for games
    AEAudioStreamBasicDescriptionSetChannelsPerFrame(&asbd, numChannels); // e.g. 1 for mono
    return asbd;
}


// USE: provide only playback rate or cents and set the opposite one to <=0 to disable.  playbackRate takes precidence if both are provided.
AEAudioUnitFilter* _audAUVarispeedFilter(AEAudioController *audioController, AudioUnit audioUnitToFilter, float playbackRate, int playbackCents) {
    // Make an AudioUnit based filter and use the NewTimePitch audio unit to change pitch AND rate at the same time!
    AudioComponentDescription component = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                          kAudioUnitType_FormatConverter,
                                                                          kAudioUnitSubType_Varispeed);
    NSError *err;
    AEAudioUnitFilter *filter = [[AEAudioUnitFilter alloc] initWithComponentDescription:component
                                                                        audioController:audioController
                                                                                  error:&err];
    if(filter) {
        if(playbackRate) {
            // Set the pitch via PlaybackRate
            playbackRate = MAX(0.25, MIN(4.0, playbackRate)); // clamp cents to 0.25 -> 4.0 as defined in AudioUnitParameters.h
            audCheckStatus(AudioUnitSetParameter(filter.audioUnit,               // inUnit : AudioUnit
                                                 kVarispeedParam_PlaybackRate,   // inID: AudioUnitParameterID
                                                 kAudioUnitScope_Global,         // inScope: AudioUnitScope
                                                 0,                              // inElement: AudioUnitElement
                                                 playbackRate,                   // inValue: AudioUnitParameterValue
                                                 0),                             // inBufferOffsetInFrames: UInt32
                           "AudioUnitSetParameter[kVarispeedParam_PlaybackRate] failed");
        } else {
            // Set the pitch via cents
            playbackCents = MAX(-2400, MIN(2400, playbackCents)); // clamp cents to +/-2400 as defined in AudioUnitParameters.h
            audCheckStatus(AudioUnitSetParameter(filter.audioUnit,               // inUnit : AudioUnit
                                                 kVarispeedParam_PlaybackCents,  // inID: AudioUnitParameterID
                                                 kAudioUnitScope_Global,         // inScope: AudioUnitScope
                                                 0,                              // inElement: AudioUnitElement
                                                 playbackCents,                  // inValue: AudioUnitParameterValue
                                                 0),                             // inBufferOffsetInFrames: UInt32
                           "AudioUnitSetParameter[kVarispeedParam_PlaybackRate] failed");
        }
        
        return filter;
    } else {
        NSLog(@"%s - Failed to create the AEAudioUnitFilter.  Error message:  '%@'", __PRETTY_FUNCTION__, [err localizedDescription]);
        return nil;
    }
}



#pragma mark - UTILITY FUNCTIONS

BOOL audCheckStatus(OSStatus status, const char *errMessage) {
    if(status==noErr) {
        return YES; // is OK
    } else {
        #if defined(DEBUG) && DEBUG
        char errorString[20];
        // See if it appears to be 4-char-code
        *(UInt32*)(errorString + 1) = CFSwapInt32HostToBig(status);
        if(isprint(errorString[1])
           && isprint(errorString[2])
           && isprint(errorString[3])
           && isprint(errorString[4])) {
            errorString[0] = errorString[5] = '\''; // wrap with single quotes
            errorString[6] = '\0';                  // NULL terminator
        } else {
            sprintf(errorString,"%d",(int)status);   // Format is an integer
        }
        fprintf(stderr, "Error: %s (%s)\n", errMessage, errorString);
        #endif
        return NO; // not OK
    }
}


void audPrintAudioUnitParametersInScope(AudioUnit audioUnit, int audioUnitScope) { //e.g. kAudioUnitScope_Global
    NSLog(@"%s output:", __PRETTY_FUNCTION__);
    if(audioUnit) {
        //  Get number of parameters in this unit (size in bytes really):
        UInt32 parameterListSize = 0;
        audCheckStatus(AudioUnitGetPropertyInfo(audioUnit, kAudioUnitProperty_ParameterList, audioUnitScope, 0, &parameterListSize, NULL), "Couldn't get the audio unit property info.");
        
        //  Get ids for the parameters:
        AudioUnitParameterID *parameterIDs = malloc(parameterListSize);
        AudioUnitGetProperty(audioUnit, kAudioUnitProperty_ParameterList, audioUnitScope, 0, parameterIDs, &parameterListSize);
        
        AudioUnitParameterInfo p;
        UInt32 parameterInfoSize = sizeof(AudioUnitParameterInfo);
        UInt32 parametersCount = parameterListSize / sizeof(AudioUnitParameterID);
        for(UInt32 pIndex = 0; pIndex < parametersCount; pIndex++){
            AudioUnitGetProperty(audioUnit, kAudioUnitProperty_ParameterInfo, audioUnitScope, parameterIDs[pIndex], &p, &parameterInfoSize);
            // do whatever you want with each parameter...
            NSString *flags = @"";
            if(p.flags & kAudioUnitParameterFlag_CFNameRelease) flags = [flags stringByAppendingString:@"\n        CFNameRelease"];
            if(p.flags & kAudioUnitParameterFlag_PlotHistory) flags = [flags stringByAppendingString:@"\n        PlotHistory"];
            if(p.flags & kAudioUnitParameterFlag_MeterReadOnly) flags = [flags stringByAppendingString:@"\n        MeterReadOnly"];
            if(p.flags & kAudioUnitParameterFlag_DisplayMask) flags = [flags stringByAppendingString:@"\n        DisplayMask"];
            if(p.flags & kAudioUnitParameterFlag_DisplaySquareRoot) flags = [flags stringByAppendingString:@"\n        DisplaySquareRoot"];
            if(p.flags & kAudioUnitParameterFlag_DisplaySquared) flags = [flags stringByAppendingString:@"\n        DisplaySquared"];
            if(p.flags & kAudioUnitParameterFlag_DisplayCubed) flags = [flags stringByAppendingString:@"\n        DisplayCubed"];
            if(p.flags & kAudioUnitParameterFlag_DisplayCubeRoot) flags = [flags stringByAppendingString:@"\n        DisplayCubeRoot"];
            if(p.flags & kAudioUnitParameterFlag_DisplayExponential) flags = [flags stringByAppendingString:@"\n        DisplayExponential"];
            if(p.flags & kAudioUnitParameterFlag_HasClump) flags = [flags stringByAppendingString:@"\n        HasClump"];
            if(p.flags & kAudioUnitParameterFlag_ValuesHaveStrings) flags = [flags stringByAppendingString:@"\n        ValuesHaveStrings"];
            if(p.flags & kAudioUnitParameterFlag_DisplayLogarithmic) flags = [flags stringByAppendingString:@"\n        DisplayLogarithmic"];
            if(p.flags & kAudioUnitParameterFlag_IsHighResolution) flags = [flags stringByAppendingString:@"\n        IsHighResolution"];
            if(p.flags & kAudioUnitParameterFlag_NonRealTime) flags = [flags stringByAppendingString:@"\n        NonRealTime"];
            if(p.flags & kAudioUnitParameterFlag_CanRamp) flags = [flags stringByAppendingString:@"\n        CanRamp"]; // if this, then could use AudioUnitScheduleParameters !!!
            if(p.flags & kAudioUnitParameterFlag_ExpertMode) flags = [flags stringByAppendingString:@"\n        ExpertMode"];
            if(p.flags & kAudioUnitParameterFlag_HasCFNameString) flags = [flags stringByAppendingString:@"\n        HasCFNameString"];
            if(p.flags & kAudioUnitParameterFlag_IsGlobalMeta) flags = [flags stringByAppendingString:@"\n        IsGlobalMeta"];
            if(p.flags & kAudioUnitParameterFlag_IsElementMeta) flags = [flags stringByAppendingString:@"\n        IsElementMeta"];
            if(p.flags & kAudioUnitParameterFlag_IsReadable) flags = [flags stringByAppendingString:@"\n        IsReadable"];
            if(p.flags & kAudioUnitParameterFlag_IsWritable) flags = [flags stringByAppendingString:@"\n        IsWritable"];
            
            NSLog(@"    clumpID:%i, cfNameString:%@, unit:%i, minValue:%.2f, maxValue:%.2f, defaultValue:%.2f, flags:%i:'%@'",
                  (unsigned int)p.clumpID,
                  p.cfNameString,
                  (unsigned int)p.unit, p.minValue,
                  p.maxValue,
                  p.defaultValue,
                  (unsigned int)p.flags,flags);
        }
    } else {
        NSLog(@"%s(nil) - ERROR: function was called with nil.", __PRETTY_FUNCTION__);
    }
    
    NSLog(@"%s output ended.", __PRETTY_FUNCTION__);
}


void audPrintAudioUnitParameters(AudioUnit audioUnit) {
    audPrintAudioUnitParametersInScope(audioUnit, kAudioUnitScope_Global);
}



AudioComponentDescription audGetComponentDescription(AudioUnit audioUnit) {
    AudioComponentDescription component = {0};
    audCheckStatus(AudioComponentGetDescription(AudioComponentInstanceGetComponent(audioUnit), &component), "AudioComponentGetDescription(AudioComponentInstanceGetComponent(...)) failed");
    return component;
}


AEGameSoundChannel* audGetAUSamplerChannel(AEAudioController *audCtrlr, NSURL *audioFileUrl, BOOL isLooping, int cents) {
    
    NSError *error;
    AEGameSoundChannel *channel = [[AEGameSoundChannel alloc] initWithFileURL:audioFileUrl audioController:_audCtrlr shouldLoop:isLooping cents:cents error:&error];
    if(channel) {
        return channel;
    } else {
        // Report error
        printf("Can't get AEGameSoundChannel object");
        return nil;
    }
}


void audMidiControlChange(AudioUnit audioUnit, int ccNumber, int value) {
    // See: http://tuxguitar.sourcearchive.com/documentation/1.2/org__herac__tuxguitar__player__impl__midiport__coreaudio__MidiReceiverJNI_8cpp-source.html
    audCheckStatus(MusicDeviceMIDIEvent(audioUnit, kMidiMessage_ControlChange, ccNumber, value, 0), "Error sending MIDI control change event.");
}


void audMidiPitchBend(AudioUnit audioUnit, short value) {
    audCheckStatus(MusicDeviceMIDIEvent(audioUnit, kMidiMessage_PitchWheel, 0, value, 0), "Error sending MIDI pitch bend event.");
}


AEAudioUnitFilter* audAUVarispeedFilter(AEAudioController *audioController, AudioUnit audioUnitToFilter, float playbackRate) {
    return _audAUVarispeedFilter(audioController, audioUnitToFilter, playbackRate, 0);
}


AEAudioUnitFilter* audAUVarispeedFilterCents(AEAudioController *audioController, AudioUnit audioUnitToFilter, int cents) {
    return _audAUVarispeedFilter(audioController, audioUnitToFilter, 0, cents);
}


AEAudioUnitFilter* audAUNewTimePitchFilter(AEAudioController *audioController, AudioUnit audioUnitToFilter, float rate, int cents) {
    // Make an AudioUnit based filter and use the NewTimePitch audio unit to change pitch AND rate at the same time!
    AudioComponentDescription component = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                          kAudioUnitType_FormatConverter,
                                                                          kAudioUnitSubType_NewTimePitch);
    
    NSError *err;
    AEAudioUnitFilter *filter = [[AEAudioUnitFilter alloc] initWithComponentDescription:component
                                                                        audioController:audioController
                                                                                  error:&err];
    
    if(filter) {
        
        // Set the rate
        rate = MAX(1.0/32.0, MIN(32.0, rate)); // clamp rate to "1/32 -> 32.0, 1.0" as defined in AudioUnitParameters.h
        audCheckStatus(AudioUnitSetParameter(filter.audioUnit,           // inUnit : AudioUnit
                                             kNewTimePitchParam_Rate,    // inID: AudioUnitParameterID
                                             kAudioUnitScope_Global,     // inScope: AudioUnitScope
                                             0,                          // inElement: AudioUnitElement
                                             rate,                       // inValue: AudioUnitParameterValue
                                             0),                         // inBufferOffsetInFrames: UInt32
                       "AudioUnitSetParameter[kNewTimePitchParam_Rate] failed");
        
        // Set the pitch
        cents = MAX(-2400, MIN(2400, cents)); // clamp cents to +/-2400 as defined in AudioUnitParameters.h
        audCheckStatus(AudioUnitSetParameter(filter.audioUnit,           // inUnit : AudioUnit
                                             kNewTimePitchParam_Pitch,   // inID: AudioUnitParameterID
                                             kAudioUnitScope_Global,     // inScope: AudioUnitScope
                                             0,                          // inElement: AudioUnitElement
                                             cents,                      // inValue: AudioUnitParameterValue
                                             0),                         // inBufferOffsetInFrames: UInt32
                       "AudioUnitSetParameter[kNewTimePitchParam_Pitch] failed");
        
        return filter;
    } else {
        NSLog(@"%s - Failed to create the AEAudioUnitFilter.  Error message:  '%@'", __PRETTY_FUNCTION__, [err localizedDescription]);
        return nil;
    }
}



#pragma mark - "GAME ENGINE" INIT

AEAudioController* audInit(AEAudioController *audioControllerOrNil) {
    if(_audCtrlr == nil) {
        
        // Ensure we have an AEAudioController
        _audCtrlr = audioControllerOrNil;
        if(_audCtrlr == nil) {
            // Init audio controller
//            AudioStreamBasicDescription asbd = [AEAudioController nonInterleaved16BitStereoAudioDescription]; // this does not work on Mac
            AudioStreamBasicDescription asbd = [AEAudioController nonInterleavedFloatStereoAudioDescription]; // this works on both Mac & iOS
            _audCtrlr = [[AEAudioController alloc] initWithAudioDescription:_audCreateModifiedCopyOfASBD(asbd, 22050.0, asbd.mChannelsPerFrame)];
            NSError *err;
            if([_audCtrlr start:&err] == NO) {
                NSLog(@"ERROR: Couldn't start the AEAudioController.  Error.debugDescription: %@", [err localizedDescription]);
                [_audCtrlr stop];
                _audCtrlr = nil;
                return nil;
            }
        }
        
    }
    
    // Create our channel group
    if(_channelGroup==NULL) {
        _channelGroup = [_audCtrlr createChannelGroup];
        
    }
    
    return _audCtrlr;
}


AEAudioController* audController() {
    return _audCtrlr;
}



#pragma mark - "GAME ENGINE" GAME USE

AEGameSoundChannel* audLoadEffect(NSString *fullPathToFile, float pitch, float pan, BOOL isLooping) {
    if(_audCtrlr==nil) {
        audInit(nil);
    }
    if(_audCtrlr) {
        int cents = ((int)(MAX(0.0,MIN(2.0, pitch)) * 2400.0)) - 2400; // range +/-2400
        NSURL *url = [NSURL fileURLWithPath:fullPathToFile];
        AEGameSoundChannel *channel = audGetAUSamplerChannel(_audCtrlr, url, isLooping, cents);
        if(channel) {
            ///TODO: create channel group for all effects?
            channel.auPan = pan;
            [_audCtrlr addChannels:@[channel] toChannelGroup:_channelGroup];
            return channel;
        } else {
            return nil; // ERROR: couldn't create the channel
        }
    } else {
        return nil; // ERROR: not initialized
    }
}


void audPlayEffect(AEGameSoundChannel *samplerChannel, float volume) {
//    NSLog(@"%s - %@, %.2f", __PRETTY_FUNCTION__, samplerChannel, volume);
//    int scopes[8] = {
//        kAudioUnitScope_Global		,
//        kAudioUnitScope_Input		,
//        kAudioUnitScope_Output		,
//        kAudioUnitScope_Group		,
//        kAudioUnitScope_Part		,
//        kAudioUnitScope_Note		,
//        kAudioUnitScope_Layer		,
//        kAudioUnitScope_LayerItem
//    };
//    kAUSamplerParam_Gain
//    for(int i=0; i<8; ++i)
//        audPrintAudioUnitParametersInScope(samplerChannel.audioUnit, scopes[i]);//AudioUnitScheduleParameters
//    audPrintAudioUnitParametersInScope([_audCtrlr getGroupMixerAudioUnit:_channelGroup], kAudioUnitScope_Output);
    
//    kAudioUnitProperty_MeteringMode
//    kAudioUnitRenderAction_OutputIsSilence
//    kAudioUnitRenderAction_OutputIsSilence
    
    //HACK: test to see if gain is "meter" as per property info dump
//    float incrBy = 0.05; // delay
//    __block float curVal = 0.05;
//    float endAt = 2.0;
//    ae_timer_block_t block = ^{
//        if( (samplerChannel!=nil) && (incrBy > 0.0 && curVal <= endAt) ) {
////            audCheckStatus(AudioUnitSetParameter(samplerChannel.audioUnit,
////                                                 kAUSamplerParam_Gain,
////                                                 kAudioUnitScope_Global,
////                                                 0,
////                                                 curVal,
////                                                 0), // N/A
////                           "AudioUnitSetParameter[inID] failed");
//            AudioUnitParameterValue outVal = 0;
//            audCheckStatus(AudioUnitGetParameter(samplerChannel.audioUnit, kAUSamplerParam_Gain, kAudioUnitScope_Global, 0, &outVal), "read param failed!");
//            printf("outVal == %.3f\n",outVal);
//            curVal += incrBy;
//            return NO; // keep iterating
//        } else {
//            return YES; // we're finished
//        }
//    };
    
    // Send the block to the timer
//    [AEBlockTimer scheduleBlock:block inTimeInterval:0.05];
    
    
    
    
    static UInt32 midiNoteNum = 0;
    UInt32 onVelocity = 127 * (MAX(0, MIN(1.0, volume)));
//    NSLog(@"    ...going to play %@, noteOn, %i, %i", samplerChannel.audioUnit, (int)midiNoteNum, (int)onVelocity);
    MusicDeviceMIDIEvent(samplerChannel.audioUnit, kMidiMessage_NoteOn, midiNoteNum, onVelocity, 0);
    
    // In case of repeated plays on same AUSampler, change the MIDI note # so the prev. playing instance doesn't stop
    midiNoteNum++;
    if(midiNoteNum>127) {
        midiNoteNum = 0;
    }
}


/** Fade in/out the volume between the range of 0.0 and 1.0 */
void audRampEffectVolume(AEGameSoundChannel *samplerChannel, float fromVolume, float toVolume, float duration) {
    NSLog(@"%s from: %.3f  to: %.3f", __PRETTY_FUNCTION__, 127 * MAX(0.0, MIN(1.0, fromVolume)), 127 * MAX(0.0, MIN(1.0, toVolume)));
    audModulate(samplerChannel,
                kAUGroupParameterID_Volume,
                kAudioUnitScope_Group,
                0,    // bus
                127 * MAX(0.0, MIN(1.0, fromVolume)),
                127 * MAX(0.0, MIN(1.0, toVolume)),
                0,    // start frame
                MAX(0.001, duration)); // duration
}


/** Ramp the pitch up/down between the range of 0.0 (down two octaves) and 2.0 (up two octaves), where 1.0 == at pitch */
void audRampEffectPitch(AEGameSoundChannel *samplerChannel, float fromPitch, float toPitch, float duration) {
    NSLog(@"%s from: %.3f  to: %.3f", __PRETTY_FUNCTION__, 127 * MAX(0.0, MIN(1.0, fromPitch * 0.5)), 127 * MAX(0.0, MIN(1.0, toPitch * 0.5)));
    audModulate(samplerChannel,
                kAUGroupParameterID_PitchBend,  // in our aupreset we've set pitch bend to the full range of +/-2 octaves
                kAudioUnitScope_Group,
                0,    // bus
                127 * MAX(0.0, MIN(1.0, fromPitch * 0.5)),
                127 * MAX(0.0, MIN(1.0, toPitch * 0.5)),
                0,    // start frame
                MAX(0.001, duration)); // duration
}


/** Pan the audio from one side to the other (stereo) between the range of -1.0 (fully left) to 1.0 (fully right). */
void audRampEffectPan(AEGameSoundChannel *samplerChannel, float fromPan, float toPan, float duration) {
    NSLog(@"%s from: %.3f  to: %.3f", __PRETTY_FUNCTION__, 127 * MAX(0.0, MIN(1.0, ((fromPan + 1.0) * 0.5))), 127 * MAX(0.0, MIN(1.0, ((toPan + 1.0) * 0.5))));
    audModulate(samplerChannel,
                kAUGroupParameterID_Pan,
                kAudioUnitScope_Group,
                0,    // bus
                127 * MAX(0.0, MIN(1.0, ((fromPan + 1.0) * 0.5))),
                127 * MAX(0.0, MIN(1.0, ((toPan + 1.0) * 0.5))),
                0,    // start frame
                MAX(0.001, duration)); // duration
}


AmbienceChannel* audLoadAmbience(NSString *fullPathToFile, float pitch, float pan, float fadeInDuration) {
    // kAudioUnitParameterFlag_CanRamp
    if(_audCtrlr==nil) {
        audInit(nil);
    }
    static bool seeded = NO;
    if(!seeded) {
        srand48(time(0));
        seeded = YES;
    }
    if(_audCtrlr) {
//        NSLog(@"%s - going to attempt loading AEAUAudioFilePlayerChannel...", __PRETTY_FUNCTION__);
        AEAUAudioFilePlayerChannel *channel = [[AEAUAudioFilePlayerChannel alloc] initWithFileURL:[NSURL fileURLWithPath:fullPathToFile]
                                                                                  audioController:_audCtrlr
                                                                                       shouldLoop:YES
                                                                                            error:nil];
        
        if( channel ) {
            __block unsigned int numCalls = 0;
            channel.startLoopBlock = ^{ printf("\n%i:channel.startLoopBlock()",++numCalls); };
            channel.channelIsPlaying = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSLog(@"going to ramp channel audiounit volume down to 0.0");
                audModulate(channel, kAudioUnitParameterUnit_LinearGain, kAudioUnitScope_Global, 0, 1.0, 0.0, 0, 1.0);
            });
            [_audCtrlr addChannels:@[channel] toChannelGroup:_channelGroup];
            
            
            // Add a filter
//            float randRate = 1.0;//0.75 + 0.5 * drand48();
//            int randCent = arc4random_uniform(2400) - 1200;
//            NSLog(@"...will play back at randRate: %.2f, and randCent: %i", randRate, randCent);
//            AEAudioUnitFilter *newFilter = audAUNewTimePitchFilter(_audCtrlr, channel.audioUnit, randRate, randCent);
//            if(newFilter) {
//                [_audCtrlr addFilter:newFilter toChannel:channel];
//            }
            
            // Add varispeed fiolter
//            float randRate = 0.75 + 0.5 * drand48();
//            int randCent = 0;//arc4random_uniform(2400) - 1200;
//            NSLog(@"...will play back at randCent: %i", randCent);
//            AEAudioUnitFilter *newFilter = audAUVarispeedFilterCents(_audCtrlr, channel.audioUnit, randCent);
//            if(newFilter) {
//                [_audCtrlr addFilter:newFilter toChannel:channel];
//            }
            
            
            
//            // Add, then modulate a varispeed filter
//            __block float start_value = -1200;
//            AEAudioUnitFilter *newFilter = audAUVarispeedFilterCents(_audCtrlr, channel.audioUnit, start_value); // start at pitch, then we'll modulate!
//            if(newFilter) {
//                [_audCtrlr addFilter:newFilter toChannel:channel];
//                __block float end_value = 1200;
//                float duration_in_seconds = 3.5;
//                audModulate(newFilter,
//                            kVarispeedParam_PlaybackCents,
//                            kAudioUnitScope_Global,
//                            0,
//                            start_value,
//                            end_value,
//                            0,
//                            duration_in_seconds);
//                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration_in_seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                    audModulate(newFilter,
//                                kVarispeedParam_PlaybackCents,
//                                kAudioUnitScope_Global,
//                                0,
//                                end_value,
//                                start_value,
//                                0,
//                                duration_in_seconds);
//                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration_in_seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                        audModulate(newFilter,
//                                    kVarispeedParam_PlaybackCents,
//                                    kAudioUnitScope_Global,
//                                    0,
//                                    start_value,
//                                    0,
//                                    0,
//                                    duration_in_seconds);
//                    });
//                });
//            }
            
            
            channel.channelIsPlaying = YES;
            
            return channel;
        } else {
            // Report error
            printf("Can't get AmbienceChannel object");
            return nil;
        }
    } else {
        return nil; // ERROR: not initialized
    }
}


void audModulate(id<HasAnAudioUnitProperty> strongRefToChannel,
                 AudioUnitParameterID		inID,
                 AudioUnitScope				inScope,
                 AudioUnitElement			inElement,
                 AudioUnitParameterValue	startValue,
                 AudioUnitParameterValue	endValue,
                 UInt32						inBufferOffsetInFrames,
                 Float32                    duration) {
    
    __typeof__(strongRefToChannel) __weak channel = strongRefToChannel;
    if(channel != nil && channel.audioUnit != NULL) {
        
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
        static const AudioUnitParameterValue fps = 20.0; // Higher for Mac - more CPU available
#else
        static const AudioUnitParameterValue fps = 10.0; // For gaming quality, this seems good & saves a fair bit of CPU, e.g. on iPhone 6 cpu dropped 10-15% when lowered from 25fps to 10fps.
#endif
        static const AudioUnitParameterValue delay = 1.0 / fps;
        __block AudioUnitParameterValue curVal = startValue;
        __block AudioUnitParameterValue incrBy = (endValue - startValue) / (duration / delay); // presumably this is greater than epsilon
        __block AudioUnitParameterValue endAt  = endValue + (FLT_EPSILON * (incrBy ? 1.0 : -1.0));  // want to make sure endValue is fully reached
//        NSLog(@"curVal/endAt/incrBy/delay == %.2f/%.2f/%.3f/%.2f", curVal, endAt, incrBy, delay);
        
        
        
        
        
        
        
        
        
        
        
        // NOTES: I tested using MIDI cc events for this instead of direct parameter modulation - the CPU is perhaps marginally lower (eye-balling it), however the performance is worse as soon as more than one parameter is modulated at the same time.
        
        // Immediately set starting value so we don't get an artifact on multiple runs/starts of the same effect
        audCheckStatus(AudioUnitSetParameter(channel.audioUnit,
                                             inID,
                                             inScope,
                                             inElement,
                                             curVal,
                                             inBufferOffsetInFrames),
                       "AudioUnitSetParameter[inID] failed");
        curVal += incrBy;
        
        // then setup a block to "modulate" through the range over time increments
        ae_timer_block_t block = ^{
            if( (channel!=nil) && ((incrBy > 0.0 && curVal <= endAt) || (incrBy < 0.0 && curVal >= endAt))) {
                audCheckStatus(AudioUnitSetParameter(channel.audioUnit,
                                                     inID,
                                                     inScope,
                                                     inElement,
                                                     curVal,
                                                     inBufferOffsetInFrames),
                               "AudioUnitSetParameter[inID] failed");
                curVal += incrBy;
                return NO; // keep iterating
            } else {
                return YES; // we're finished
            }
        };
        
        // Send the block to the timer
        [AEBlockTimer scheduleBlock:block inTimeInterval:delay];
    } // END if(inUnit)...
}



































