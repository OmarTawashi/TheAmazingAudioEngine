//
//  VEAEUtils.m
//  TheAmazingAudioEngine
//
//  Created by Leo on 2015-01-21.
//  Copyright (c) 2015 A Tasty Pixel. All rights reserved.
//

#import "VEAEUtils.h"


// These constants are for certain audio units as defined in AudioUnitParameters.h
static int16_t const _kAUMinCents = -2400;
static int16_t const _kAUMaxCents = -2400;
static float const _kAUMinRate = 1.0f / 32.0f;
static float const _kAUMaxRate = 32.0f;


// Log available AudioUnit parameters in the kAudioUnitScope_Global to the console.
void audLogAUParameters(AudioUnit au) {
    audLogAUParametersInScope(au, kAudioUnitScope_Global);
}


// Log available AudioUnit parameters in the specified scope to the console.
void audLogAUParametersInScope(AudioUnit au,
                               int auScope) { //e.g. kAudioUnitScope_Global
#if VEAE_IS_DEBUG
    if(!(au)) {
        VEAELog(@"Function was called with NULL.");
        return;
    }
    printf("\n%s\n\nOUTPUT:", __PRETTY_FUNCTION__);

    // Get # of parameters in this unit
    UInt32 parameterListSize = 0;
    if(!audCheck(AudioUnitGetPropertyInfo(au,
                                          kAudioUnitProperty_ParameterList,
                                          auScope,
                                          0,
                                          &parameterListSize,
                                          NULL),
                 "AudioUnitGetPropertyInfo(kAudioUnitProperty_ParameterList)")) {
        printf("\n\nOUTPUT ENDED.\n\n");
        return;
    }

    // Get IDs for the parameters:
    AudioUnitParameterID *parameterIDs = malloc(parameterListSize);
    if(!audCheck(AudioUnitGetProperty(au,
                                      kAudioUnitProperty_ParameterList,
                                      auScope,
                                      0,
                                      parameterIDs,
                                      &parameterListSize),
                 "AudioUnitGetProperty(kAudioUnitProperty_ParameterList)")) {
        printf("\n\nOUTPUT ENDED.\n\n");
        return;
    }

    // Iterate through total # of parameters available
    AudioUnitParameterInfo p;
    UInt32 parameterInfoSize = sizeof(AudioUnitParameterInfo);
    UInt32 parametersCount = parameterListSize / sizeof(AudioUnitParameterID);
    for(UInt32 pIndex = 0; pIndex < parametersCount; pIndex++){
        if(audCheck(AudioUnitGetProperty(au,
                                         kAudioUnitProperty_ParameterInfo,
                                         auScope,
                                         parameterIDs[pIndex],
                                         &p,
                                         &parameterInfoSize), "AudioUnitGetProperty(AudioUnitParameterID)")) {
            
            // SUCCESS
            
            // Convert flags into plain english - maybe better/more concise way to do this but this works
            NSMutableString *flags = [NSMutableString stringWithString:@""];
            if(p.flags & kAudioUnitParameterFlag_CFNameRelease)
                [flags appendString:@"\n        CFNameRelease"];
            if(p.flags & kAudioUnitParameterFlag_PlotHistory)
                [flags appendString:@"\n        PlotHistory"];
            if(p.flags & kAudioUnitParameterFlag_MeterReadOnly)
                [flags appendString:@"\n        MeterReadOnly"];
            if(p.flags & kAudioUnitParameterFlag_DisplayMask)
                [flags appendString:@"\n        DisplayMask"];
            if(p.flags & kAudioUnitParameterFlag_DisplaySquareRoot)
                [flags appendString:@"\n        DisplaySquareRoot"];
            if(p.flags & kAudioUnitParameterFlag_DisplaySquared)
                [flags appendString:@"\n        DisplaySquared"];
            if(p.flags & kAudioUnitParameterFlag_DisplayCubed)
                [flags appendString:@"\n        DisplayCubed"];
            if(p.flags & kAudioUnitParameterFlag_DisplayCubeRoot)
                [flags appendString:@"\n        DisplayCubeRoot"];
            if(p.flags & kAudioUnitParameterFlag_DisplayExponential)
                [flags appendString:@"\n        DisplayExponential"];
            if(p.flags & kAudioUnitParameterFlag_HasClump)
                [flags appendString:@"\n        HasClump"];
            if(p.flags & kAudioUnitParameterFlag_ValuesHaveStrings)
                [flags appendString:@"\n        ValuesHaveStrings"];
            if(p.flags & kAudioUnitParameterFlag_DisplayLogarithmic)
                [flags appendString:@"\n        DisplayLogarithmic"];
            if(p.flags & kAudioUnitParameterFlag_IsHighResolution)
                [flags appendString:@"\n        IsHighResolution"];
            if(p.flags & kAudioUnitParameterFlag_NonRealTime)
                [flags appendString:@"\n        NonRealTime"];
            if(p.flags & kAudioUnitParameterFlag_CanRamp)
                [flags appendString:@"\n        CanRamp"]; // <- AudioUnitScheduleParameters capable
            if(p.flags & kAudioUnitParameterFlag_ExpertMode)
                [flags appendString:@"\n        ExpertMode"];
            if(p.flags & kAudioUnitParameterFlag_HasCFNameString)
                [flags appendString:@"\n        HasCFNameString"];
            if(p.flags & kAudioUnitParameterFlag_IsGlobalMeta)
                [flags appendString:@"\n        IsGlobalMeta"];
            if(p.flags & kAudioUnitParameterFlag_IsElementMeta)
                [flags appendString:@"\n        IsElementMeta"];
            if(p.flags & kAudioUnitParameterFlag_IsReadable)
                [flags appendString:@"\n        IsReadable"];
            if(p.flags & kAudioUnitParameterFlag_IsWritable)
                [flags appendString:@"\n        IsWritable"];
            
            // Log the results to the console
            printf("\n    clumpID:%i, cfNameString:%s, unit:%i, minValue:%.2f, maxValue:%.2f, defaultValue:%.2f, "
                   "flags:%i:'%s'",
                   (uint32_t)p.clumpID,
                   [(__bridge NSString*)p.cfNameString UTF8String],
                   (uint32_t)p.unit, p.minValue,
                   p.maxValue,
                   p.defaultValue,
                   (uint32_t)p.flags,   // flags as a value
                   [flags UTF8String]); // flags as text
            
        } else {
            
            // FAILED
            
            printf("\nProblem: could not get AU property with parameterID: %i", parameterIDs[pIndex]);
            
        }
    } // for parametersCount
    
    // All done.
    printf("\n\nOUTPUT ENDED.\n\n");
#endif
}


// Get the AudioComponentDescription from an AudioUnit instance.
AudioComponentDescription audGetAUComponentDescription(AudioUnit au) {
    AudioComponentDescription component = {0};
    audCheck(AudioComponentGetDescription(AudioComponentInstanceGetComponent(au), &component),
             "AudioComponentGetDescription(AudioComponentInstanceGetComponent(au))");
    return component;
}


// Create a new TAAE channel filter configured with an AUVarispeed Audio Unit, ready to be added and used.
AEAudioUnitFilter* audNewAUVarispeedFilter(AEAudioController *audioController,
                                           int16_t cents) {
    // Make an AudioUnit based filter and use the NewTimePitch audio unit to change pitch AND rate at the same time!
    AudioComponentDescription component = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                          kAudioUnitType_FormatConverter,
                                                                          kAudioUnitSubType_Varispeed);
    NSError *err;
    AEAudioUnitFilter *filter = [[AEAudioUnitFilter alloc] initWithComponentDescription:component
                                                                        audioController:audioController
                                                                                  error:&err];
    if(filter) {
        // Set the pitch via cents
        audCheck(AudioUnitSetParameter(filter.audioUnit,                            // inUnit : AudioUnit
                                       kVarispeedParam_PlaybackCents,               // inID: AudioUnitParameterID
                                       kAudioUnitScope_Global,                      // inScope: AudioUnitScope
                                       0,                                           // inElement: AudioUnitElement
                                       CLAMP(cents, _kAUMinCents, _kAUMaxCents),    // inValue: AudioUnitParameterValue
                                       0),                                          // inBufferOffsetInFrames: UInt32
                 "AudioUnitSetParameter(kVarispeedParam_PlaybackCents)");
        return filter;
    } else {
        VEAELog(@"%@", [err localizedDescription]);
        return nil;
    }
}


// Create a new TAAE channel filter configured with an AUNewTimePitch Audio Unit, ready to be added and used.
AEAudioUnitFilter* audNewAUNewTimePitchFilter(AEAudioController *audioController,
                                              float rate,
                                              int16_t cents) {
    // Make an AudioUnit based filter and use the NewTimePitch audio unit to change pitch AND rate at the same time!
    AudioComponentDescription component = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                          kAudioUnitType_FormatConverter,
                                                                          kAudioUnitSubType_NewTimePitch);
    
    NSError *err;
    AEAudioUnitFilter *filter = [[AEAudioUnitFilter alloc] initWithComponentDescription:component
                                                                        audioController:audioController
                                                                                  error:&err];
    
    if(filter) {
        
        // Rate
        audCheck(AudioUnitSetParameter(filter.audioUnit,                        // inUnit : AudioUnit
                                       kNewTimePitchParam_Rate,                 // inID: AudioUnitParameterID
                                       kAudioUnitScope_Global,                  // inScope: AudioUnitScope
                                       0,                                       // inElement: AudioUnitElement
                                       CLAMP(rate, _kAUMinRate, _kAUMaxRate),   // inValue: AudioUnitParameterValue
                                       0),                                      // inBufferOffsetInFrames: UInt32
                 "AudioUnitSetParameter[kNewTimePitchParam_Rate] failed");
        
        // Pitch
        audCheck(AudioUnitSetParameter(filter.audioUnit,                            // inUnit : AudioUnit
                                       kNewTimePitchParam_Pitch,                    // inID: AudioUnitParameterID
                                       kAudioUnitScope_Global,                      // inScope: AudioUnitScope
                                       0,                                           // inElement: AudioUnitElement
                                       CLAMP(cents, _kAUMinCents, _kAUMaxCents),    // inValue: AudioUnitParameterValue
                                       0),                                          // inBufferOffsetInFrames: UInt32
                 "AudioUnitSetParameter[kNewTimePitchParam_Pitch] failed");
        
        return filter;
    } else {
        VEAELog(@"%@",[err localizedDescription]);
        return nil;
    }
}
