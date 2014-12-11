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
static float _effectsVolumeScale = 1.0;



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


void audNSLogAudioUnitParameters(AudioUnit audioUnit) {
    if(audioUnit) {
        //  Get number of parameters in this unit (size in bytes really):
        UInt32 parameterListSize = 0;
        AudioUnitGetPropertyInfo(audioUnit, kAudioUnitProperty_ParameterList, kAudioUnitScope_Global, 0, &parameterListSize, NULL);
        
        //  Get ids for the parameters:
        AudioUnitParameterID *parameterIDs = malloc(parameterListSize);
        AudioUnitGetProperty(audioUnit, kAudioUnitProperty_ParameterList, kAudioUnitScope_Global, 0, parameterIDs, &parameterListSize);
        
        AudioUnitParameterInfo p;
        UInt32 parameterInfoSize = sizeof(AudioUnitParameterInfo);
        UInt32 parametersCount = parameterListSize / sizeof(AudioUnitParameterID);
        for(UInt32 pIndex = 0; pIndex < parametersCount; pIndex++){
            AudioUnitGetProperty(audioUnit, kAudioUnitProperty_ParameterInfo, kAudioUnitScope_Global, parameterIDs[pIndex], &p, &parameterInfoSize);
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


SamplerChannel* audGetAUSamplerChannel(AEAudioController *audCtrlr, NSURL *audioFileUrl, BOOL isLooping, int cents) {
    AudioComponentDescription component = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                          kAudioUnitType_MusicDevice,
                                                                          kAudioUnitSubType_Sampler);
    NSError *error = NULL;
    SamplerChannel *channel = [[AEAudioUnitChannel alloc]
                                   initWithComponentDescription:component
                                   audioController:audCtrlr
                                   preInitializeBlock:^(AudioUnit samplerUnit) {
                                       
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
    
    if ( !channel ) {
        // Report error
        printf("Can't get instrument SamplerChannel object");
        return nil;
    }
    
    return channel;
}

void audMidiControlChange(AudioUnit audioUnit, int ccNumber, int value) {
    // See: http://tuxguitar.sourcearchive.com/documentation/1.2/org__herac__tuxguitar__player__impl__midiport__coreaudio__MidiReceiverJNI_8cpp-source.html
    audCheckStatus(MusicDeviceMIDIEvent(audioUnit, kMidiMessage_ControlChange, ccNumber, value, 0), "Error sending MIDI control change event.");
}

void audMidiPitchBend(AudioUnit audioUnit, short value) {
    audCheckStatus(MusicDeviceMIDIEvent(audioUnit, kMidiMessage_PitchWheel, 0, value, 0), "Error sending MIDI pitch bend event.");
}




#pragma mark - "GAME ENGINE" FUNCTIONS


AEAudioController* audInit(AEAudioController *audioControllerOrNil) {
    if(_audCtrlr == nil) {
        
        // Ensure we have an AEAudioController
        _audCtrlr = audioControllerOrNil;
        if(_audCtrlr == nil) {
            // Init audio controller
//            AudioStreamBasicDescription asbd = [AEAudioController nonInterleaved16BitStereoAudioDescription]; // this does not work on Mac
            AudioStreamBasicDescription asbd = [AEAudioController nonInterleavedFloatStereoAudioDescription]; // this works on both Mac & iOS
            asbd.mSampleRate = 22050.0; // I like to use 22050.0 for games
            
            _audCtrlr = [[AEAudioController alloc] initWithAudioDescription:asbd];
            NSError *err;
            if([_audCtrlr start:&err] == NO) {
                NSLog(@"ERROR: Couldn't start the AEAudioController.  Error.debugDescription: %@", [err localizedDescription]);
                [_audCtrlr stop];
                _audCtrlr = nil;
                return nil;
            }
        }
        
//        // Create a mono audio description
//        AudioStreamBasicDescription asbd = _audCtrlr.audioDescription;
//        asbd.mSampleRate = 22050.0; // I like to use 22050.0 for games
//        AEAudioStreamBasicDescriptionSetChannelsPerFrame(&asbd, 1); // mono
    }
    return _audCtrlr;
}


AEAudioController* audController() {
    return _audCtrlr;
}










SamplerChannel* audPreload( NSString *fullPathToFile,
                               float pitch,
                               float pan,
                               BOOL isLooping) {
    if(_audCtrlr==nil) {
        audInit(nil);
    }
    if(_audCtrlr) {
        int cents = 0;//((int)(MAX(0.0,MIN(2.0, pitch)) * 2400.0)) - 2400; // range +/-2400
//        NSLog(@"pitch -> cents == %.2f -> %i", pitch, cents);
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





/// Play an audio effect; typically these should be short, mono sound files: 22050khz, mono IMA4 caf is recommended.
///
/// :param: relFilePath the audio file
/// :param: volume value of 0.0 to 1.0 representing how loud to play - this value is combined with the "volume scale" to get a final volume level.
/// :param: pitch a value between 0.0 and 2.0 where 1.0 is unaltered, 0.0 is two octaves lower and 2.0 is two octaves higher.
/// :param: pan a value between -1.0 and 1.0 where -1.0 is fully left and 1.0 is fuly right
/// :param: isLooping whether the sound should loop indefinitly or only play back once
void audPlay(SamplerChannel *samplerChannel, double volume) {
    
    static UInt32 midiNoteNum = 0;
    UInt32 onVelocity = 127 * (MAX(0, MIN(1.0, volume)) * _effectsVolumeScale);
    MusicDeviceMIDIEvent(samplerChannel.audioUnit, kMidiMessage_NoteOn, midiNoteNum, onVelocity, 0);
    
    // In case of repeated plays on same AUSampler, change the MIDI note # so the prev. playing instance doesn't stop
    midiNoteNum++;
    if(midiNoteNum>127) {
        midiNoteNum = 0;
    }
}
//SamplerChannel* __attribute__((overloadable)) audPlay(NSString *relFilePath,
//                                                          float volume,
//                                                          float pitch,
//                                                          float pan) {
//    return audPlay(relFilePath, volume, pitch, pan, NO);
//}
//SamplerChannel* __attribute__((overloadable)) audPlay(NSString *relFilePath,
//                                                          float volume,
//                                                          float pitch) {
//    return audPlay(relFilePath, volume, pitch, 0.0, NO);
//}
//SamplerChannel* __attribute__((overloadable)) audPlay(NSString *relFilePath,
//                                                          float volume) {
//    return audPlay(relFilePath, volume, 1.0, 0.0, NO);
//}
//SamplerChannel* audPlay(NSString *filePath, double volume) {
//    NSLog(@"%s(%@)", __PRETTY_FUNCTION__, filePath);
//    return _audPlay(filePath, volume);
//}


//void audSetVolume(SamplerChannel *channel, float volume) {
//}
//
//
///// This will stop all instances of this sound file; to stop only specific instances, you need call the function by the same name but passing it the player object that was returned by the `audPlay()` function.
//void __attribute__((overloadable)) audStop(NSString *relFilePath) {
//    
//}
//
//
//void __attribute__((overloadable)) audStop(SamplerChannel *channel) {
//    if(channel) {
//        // stop playback
//    }
//}
//
//
//// Stops all the sound effects, including looping sound effects.  Does not stop the long sound tracks (e.g. bg music or narration).
//void audStopAllEffects() {
//    
//}
//
//
///// Stop all "one shot" type sound effects while allowing the looping ones to continue (e.g. some ambient wind noise that should continue to loop)
//void audStopAllNonLoopingEffects() {
//    
//}



// Returns the global effects volume scale - see comments on `audSetEffectsVolumeScale(...)`
float audVolumeScale() {
    return _effectsVolumeScale;
}


// Sets the global effects volume scaling, which is a number between 0.0 and 1.0 by which all effects volumes are "scaled", e.g. a sound effect played at volume 1.0 will actually be played back at 1.0 * effectsVolumeScale.  This only applies to "effects" - not to long background music tracks.
void audSetVolumeScale(float volumeScale) {
    _effectsVolumeScale = MAX(0.0, MIN(1.0, volumeScale));
}


//// Unload the sound effect to free up RAM
//void audUnload(NSString *relFilePath) {
//    
//}

















