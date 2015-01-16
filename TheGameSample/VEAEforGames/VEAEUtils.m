//
//  VEAEUtils.m
//
//  Created by Leo on 2014-12-17.
//  Copyright (c) 2014 The Amazing Audio Engine. All rights reserved.
//

#import "VEAEUtils.h"

#define checkResult(result,operation) (_checkResult((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _checkResult(OSStatus result,
                                const char *operation,
                                const char* file,
                                int line) {
    if ( result != noErr ) {
        #if defined(DEBUG) && DEBUG
            int fourCC = CFSwapInt32HostToBig(result);
            NSLog(@"%s:%d: %s result %d %08X %4.4s\n",
                  file,
                  line,
                  operation,
                  (int)result,
                  (int)result,
                  (char*)&fourCC);
        #endif
        return NO;
    }
    return YES;
}


void audPrintAUParameters(AudioUnit audioUnit) {
    audPrintAUParametersInScope(audioUnit, kAudioUnitScope_Global);
}


void audPrintAUParametersInScope(AudioUnit audioUnit,
                                 int audioUnitScope) { //e.g. kAudioUnitScope_Global
    if(!(audioUnit)) {
        NSLog(@"\n\n%s(nil, %i) - ERROR: function was called with nil.\n ", __FUNCTION__, audioUnitScope);
        return;
    }
    NSLog(@"\n\n%s output:", __PRETTY_FUNCTION__);
    
    // Get # of parameters in this unit
    UInt32 parameterListSize = 0;
    if(!checkResult(AudioUnitGetPropertyInfo(audioUnit,
                                         kAudioUnitProperty_ParameterList,
                                         audioUnitScope,
                                         0,
                                         &parameterListSize,
                                         NULL),
                    "AudioUnitGetPropertyInfo(kAudioUnitProperty_ParameterList)")) {
        NSLog(@"%s output ended.\n ", __PRETTY_FUNCTION__);
        return;
    }
    
    // Get IDs for the parameters:
    AudioUnitParameterID *parameterIDs = malloc(parameterListSize);
    if(!checkResult(AudioUnitGetProperty(audioUnit,
                                         kAudioUnitProperty_ParameterList,
                                         audioUnitScope,
                                         0,
                                         parameterIDs,
                                         &parameterListSize),
                    "AudioUnitGetProperty(kAudioUnitProperty_ParameterList)")) {
        NSLog(@"%s output ended.\n ", __PRETTY_FUNCTION__);
        return;
    }
    
    // Iterate through total # of parameters available
    AudioUnitParameterInfo p;
    UInt32 parameterInfoSize = sizeof(AudioUnitParameterInfo);
    UInt32 parametersCount = parameterListSize / sizeof(AudioUnitParameterID);
    for(UInt32 pIndex = 0; pIndex < parametersCount; pIndex++){
        if(!checkResult(AudioUnitGetProperty(audioUnit,
                                         kAudioUnitProperty_ParameterInfo,
                                         audioUnitScope,
                                         parameterIDs[pIndex],
                                         &p,
                                         &parameterInfoSize), "AudioUnitGetProperty(AudioUnitParameterID)")) {
            NSLog(@"%s output ended.\n ", __PRETTY_FUNCTION__);
            return;
        }
        
        // Convert flags into plain english - maybe better/more concise way to do this but this works
        NSString *flags = @"";
        if(p.flags & kAudioUnitParameterFlag_CFNameRelease)
            flags = [flags stringByAppendingString:@"\n        CFNameRelease"];
        if(p.flags & kAudioUnitParameterFlag_PlotHistory)
            flags = [flags stringByAppendingString:@"\n        PlotHistory"];
        if(p.flags & kAudioUnitParameterFlag_MeterReadOnly)
            flags = [flags stringByAppendingString:@"\n        MeterReadOnly"];
        if(p.flags & kAudioUnitParameterFlag_DisplayMask)
            flags = [flags stringByAppendingString:@"\n        DisplayMask"];
        if(p.flags & kAudioUnitParameterFlag_DisplaySquareRoot)
            flags = [flags stringByAppendingString:@"\n        DisplaySquareRoot"];
        if(p.flags & kAudioUnitParameterFlag_DisplaySquared)
            flags = [flags stringByAppendingString:@"\n        DisplaySquared"];
        if(p.flags & kAudioUnitParameterFlag_DisplayCubed)
            flags = [flags stringByAppendingString:@"\n        DisplayCubed"];
        if(p.flags & kAudioUnitParameterFlag_DisplayCubeRoot)
            flags = [flags stringByAppendingString:@"\n        DisplayCubeRoot"];
        if(p.flags & kAudioUnitParameterFlag_DisplayExponential)
            flags = [flags stringByAppendingString:@"\n        DisplayExponential"];
        if(p.flags & kAudioUnitParameterFlag_HasClump)
            flags = [flags stringByAppendingString:@"\n        HasClump"];
        if(p.flags & kAudioUnitParameterFlag_ValuesHaveStrings)
            flags = [flags stringByAppendingString:@"\n        ValuesHaveStrings"];
        if(p.flags & kAudioUnitParameterFlag_DisplayLogarithmic)
            flags = [flags stringByAppendingString:@"\n        DisplayLogarithmic"];
        if(p.flags & kAudioUnitParameterFlag_IsHighResolution)
            flags = [flags stringByAppendingString:@"\n        IsHighResolution"];
        if(p.flags & kAudioUnitParameterFlag_NonRealTime)
            flags = [flags stringByAppendingString:@"\n        NonRealTime"];
        if(p.flags & kAudioUnitParameterFlag_CanRamp)
            flags = [flags stringByAppendingString:@"\n        CanRamp"]; // <- AudioUnitScheduleParameters capable
        if(p.flags & kAudioUnitParameterFlag_ExpertMode)
            flags = [flags stringByAppendingString:@"\n        ExpertMode"];
        if(p.flags & kAudioUnitParameterFlag_HasCFNameString)
            flags = [flags stringByAppendingString:@"\n        HasCFNameString"];
        if(p.flags & kAudioUnitParameterFlag_IsGlobalMeta)
            flags = [flags stringByAppendingString:@"\n        IsGlobalMeta"];
        if(p.flags & kAudioUnitParameterFlag_IsElementMeta)
            flags = [flags stringByAppendingString:@"\n        IsElementMeta"];
        if(p.flags & kAudioUnitParameterFlag_IsReadable)
            flags = [flags stringByAppendingString:@"\n        IsReadable"];
        if(p.flags & kAudioUnitParameterFlag_IsWritable)
            flags = [flags stringByAppendingString:@"\n        IsWritable"];
        
        // Log the results to the console
        NSLog(@"    clumpID:%i, cfNameString:%@, unit:%i, minValue:%.2f, maxValue:%.2f, defaultValue:%.2f, "
              "flags:%i:'%@'",
              (uint32_t)p.clumpID,
              p.cfNameString,
              (uint32_t)p.unit, p.minValue,
              p.maxValue,
              p.defaultValue,
              (uint32_t)p.flags, // flags as a value
              flags);            // flags as text
    }
    NSLog(@"%s output ended.\n ", __PRETTY_FUNCTION__);
}


AudioComponentDescription audGetComponentDescription(AudioUnit audioUnit) {
    AudioComponentDescription component = {0};
    checkResult(AudioComponentGetDescription(AudioComponentInstanceGetComponent(audioUnit), &component), "AudioComponentGetDescription(AudioComponentInstanceGetComponent(audioUnit))");
    return component;
}


AEAudioUnitFilter* audCreateAUVarispeedFilter(AEAudioController *audioController,
                                              AudioUnit audioUnitToFilter,
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
            cents = MAX(-2400, MIN(2400, cents)); // clamp cents to +/-2400 as defined in AudioUnitParameters.h
            checkResult(AudioUnitSetParameter(filter.audioUnit,               // inUnit : AudioUnit
                                              kVarispeedParam_PlaybackCents,  // inID: AudioUnitParameterID
                                              kAudioUnitScope_Global,         // inScope: AudioUnitScope
                                              0,                              // inElement: AudioUnitElement
                                              cents,                          // inValue: AudioUnitParameterValue
                                              0),                             // inBufferOffsetInFrames: UInt32
                        "AudioUnitSetParameter(kVarispeedParam_PlaybackRate)");
        return filter;
    } else {
        NSLog(@"%s - Failed to create the AEAudioUnitFilter.  Error message:  '%@'",
              __PRETTY_FUNCTION__,
              [err localizedDescription]);
        return nil;
    }
}


AEAudioUnitFilter* audCreateAUNewTimePitchFilter(AEAudioController *audioController,
                                                 AudioUnit audioUnitToFilter,
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
        rate = MAX(1.0/32.0, MIN(32.0, rate)); // clamp rate to "1/32 -> 32.0, 1.0" as defined in AudioUnitParameters.h
        checkResult(AudioUnitSetParameter(filter.audioUnit,           // inUnit : AudioUnit
                                          kNewTimePitchParam_Rate,    // inID: AudioUnitParameterID
                                          kAudioUnitScope_Global,     // inScope: AudioUnitScope
                                          0,                          // inElement: AudioUnitElement
                                          rate,                       // inValue: AudioUnitParameterValue
                                          0),                         // inBufferOffsetInFrames: UInt32
                    "AudioUnitSetParameter[kNewTimePitchParam_Rate] failed");
        
        // Pitch
        cents = MAX(-2400, MIN(2400, cents)); // clamp cents to +/-2400 as defined in AudioUnitParameters.h
        checkResult(AudioUnitSetParameter(filter.audioUnit,           // inUnit : AudioUnit
                                          kNewTimePitchParam_Pitch,   // inID: AudioUnitParameterID
                                          kAudioUnitScope_Global,     // inScope: AudioUnitScope
                                          0,                          // inElement: AudioUnitElement
                                          cents,                      // inValue: AudioUnitParameterValue
                                          0),                         // inBufferOffsetInFrames: UInt32
                    "AudioUnitSetParameter[kNewTimePitchParam_Pitch] failed");
        
        return filter;
    } else {
        NSLog(@"%s - Failed to create the AEAudioUnitFilter.  Error message:  '%@'",
              __PRETTY_FUNCTION__,
              [err localizedDescription]);
        return nil;
    }
}












