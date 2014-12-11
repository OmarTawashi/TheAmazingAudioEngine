//
//  VEAEforGames.m
//  TheGameSample
//
//  Created by Leo on 2014-12-08.
//  Copyright (c) 2014 visionsencoded.com, All rights reserved.
//

#import "VEAEforGames.h"



#pragma mark - STATIC VARIABLES (used internally to this file)

static AEAudioController *_audCtrlr = nil;



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
    NSLog(@"%s - here 1", __PRETTY_FUNCTION__);
    if(audioUnit) {
        NSLog(@"%s - here 2", __PRETTY_FUNCTION__);
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
            NSLog(@"    clumpID:%i, cfNameString:%@, unit:%i, minValue:%.2f, maxValue:%.2f, defaultValue:%.2f, flags:%i",
                  (unsigned int)p.clumpID,
                  p.cfNameString,
                  (unsigned int)p.unit, p.minValue,
                  p.maxValue,
                  p.defaultValue,
                  (unsigned int)p.flags);
        }
    } else {
        NSLog(@"%s(nil) - ERROR: function was called with nil.", __PRETTY_FUNCTION__);
    }
}


void audPrintAudioUnitParameters(AudioUnit audioUnit) {
    audPrintAudioUnitParametersInScope(audioUnit, kAudioUnitScope_Global);
}


SamplerChannel* audGetAUSamplerChannel(AEAudioController *audCtrlr, NSURL *audioFileUrl, BOOL isLooping, int cents) {
    AudioComponentDescription component = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                          kAudioUnitType_MusicDevice,
                                                                          kAudioUnitSubType_Sampler);
    NSError *error = NULL;
    SamplerChannel *channel = [[AEAudioUnitChannel alloc]
                                   initWithComponentDescription:component
                                   audioController:audCtrlr
                                   preInitializeBlock:^(AudioUnit samplerUnit) {
                                       
//                                       audPrintAudioUnitParameters(samplerUnit);
                                       
                                       // Load a .aupreset file
                                       NSURL *url = [[NSBundle mainBundle] URLForResource:@"VolumePanPitch" withExtension:@"aupreset"];
                                       NSMutableDictionary *aupreset = [NSMutableDictionary dictionaryWithContentsOfURL:url];
                                       [[aupreset objectForKey:@"file-references"] setValue:[audioFileUrl path] forKey:@"Sample:268435457"];
                                       
                                       // Is looping?
                                       NSDictionary *zone = [[[aupreset objectForKey:@"Instrument"] objectForKey:@"Layers"][0] objectForKey:@"Zones"][0];
                                       if(isLooping) {
                                           [zone setValue:@YES forKey:@"loop enabled"];
                                       }
                                       
                                       // Changed pitch?
                                       if(cents!=0) {
                                           float f    = ((float)cents) / 100.0;
                                           int course = (int)f;
                                           int fine   = (int)((f - ((float)course)) * 100.0);
                                           [zone setValue:[NSNumber numberWithInt:course] forKey:@"coarse tune"];
                                           [zone setValue:[NSNumber numberWithInt:fine] forKey:@"fine tune"];
                                       }
                                       
                                       // Convert the data object into a property list
                                       CFPropertyListRef presetPropertyList = (__bridge CFPropertyListRef)(aupreset);
                                       
                                       // Set the class info property for the Sampler unit using the property list as the value.
                                       audCheckStatus(AudioUnitSetProperty(samplerUnit,
                                                                           kAudioUnitProperty_ClassInfo,
                                                                           kAudioUnitScope_Global,
                                                                           0,
                                                                           &presetPropertyList,
                                                                           sizeof(CFPropertyListRef)
                                                                           ),"Unable to set aupreset on the AUSampler Audio Unit");
                                   }
                                   error:&error];
    
    if ( channel ) {
        return channel;
    } else {
        // Report error
        printf("Can't get instrument SamplerChannel object");
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
    return _audCtrlr;
}


AEAudioController* audController() {
    return _audCtrlr;
}



#pragma mark - "GAME ENGINE" GAME USE

SamplerChannel* audLoadEffect(NSString *fullPathToFile, float pitch, float pan, BOOL isLooping) {
    if(_audCtrlr==nil) {
        audInit(nil);
    }
    if(_audCtrlr) {
        int cents = ((int)(MAX(0.0,MIN(2.0, pitch)) * 2400.0)) - 2400; // range +/-2400
        BOOL isLooping = NO;
        NSURL *url = [NSURL fileURLWithPath:fullPathToFile];
        SamplerChannel *channel = audGetAUSamplerChannel(_audCtrlr, url, isLooping, cents);
        if(channel) {
            ///TODO: create channel group for all effects?
            [_audCtrlr addChannels:@[channel]];
            return channel;
        } else {
            return nil; // ERROR: couldn't create the channel
        }
    } else {
        return nil; // ERROR: not initialized
    }
}


void audPlayEffect(SamplerChannel *samplerChannel, float volume) {
    NSLog(@"%s - %@, %.2f", __PRETTY_FUNCTION__, samplerChannel, volume);
    static UInt32 midiNoteNum = 0;
    UInt32 onVelocity = 127 * (MAX(0, MIN(1.0, volume)));
    NSLog(@"    ...going to play %@, noteOn, %i, %i", samplerChannel.audioUnit, (int)midiNoteNum, (int)onVelocity);
    MusicDeviceMIDIEvent(samplerChannel.audioUnit, kMidiMessage_NoteOn, midiNoteNum, onVelocity, 0);
    
    // In case of repeated plays on same AUSampler, change the MIDI note # so the prev. playing instance doesn't stop
    midiNoteNum++;
    if(midiNoteNum>127) {
        midiNoteNum = 0;
    }
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
        NSLog(@"%s - going to attempt loading AEAUAudioFilePlayerChannel...", __PRETTY_FUNCTION__);
        AEAUAudioFilePlayerChannel *channel = [[AEAUAudioFilePlayerChannel alloc] initWithFileURL:[NSURL fileURLWithPath:fullPathToFile]
                                                                                  audioController:_audCtrlr
                                                                                       shouldLoop:YES
                                                                                            error:nil];
        
        if( channel ) {
            __block unsigned int numCalls = 0;
            channel.startLoopBlock = ^{ printf("\n%i:channel.startLoopBlock()",++numCalls); };
            channel.channelIsPlaying = NO;
            [_audCtrlr addChannels:@[channel]];
            
            // Add a filter
            float randRate = 1.0;//0.75 + 0.5 * drand48();
            int randCent = arc4random_uniform(2400) - 1200;
            NSLog(@"...will play back at randRate: %.2f, and randCent: %i", randRate, randCent);
            AEAudioUnitFilter *newFilter = audAUNewTimePitchFilter(_audCtrlr, channel.audioUnit, randRate, randCent);
            if(newFilter) {
                [_audCtrlr addFilter:newFilter toChannel:channel];
            }
            
            // Add varispeed fiolter
//            float randRate = 0.75 + 0.5 * drand48();
//            int randCent = arc4random_uniform(2400) - 1200;
//            NSLog(@"...will play back at randCent: %i", randCent);
//            AEAudioUnitFilter *newFilter = audAUVarispeedFilterCents(_audCtrlr, channel.audioUnit, randCent);
//            if(newFilter) {
//                [_audCtrlr addFilter:newFilter toChannel:channel];
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



































