//
//  VEAEUtils.h
//
//  Created by Leo on 2014-12-17.
//  Copyright (c) 2014 The Amazing Audio Engine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TheAmazingAudioEngine.h"

#ifndef __VEAEUtils_h__
#define __VEAEUtils_h__
/*
 This library provides MIDI related functions so that the same code doesn't need to be repeated in various places 
 throughout your own projects (e.g. MIDI pitch bend messages code, etc.).
 If a DEBUG macro is defined and set to true, then these functions will log error to the console.
 */



#pragma mark - Static Inline C Functions

/*! Convert OpenAL float pitch in the range of 0.0 to 2.0 to cents in the range of +/-2400. */
static inline float audPitchToCents(float pitch) { return 2400.0 * (MAX(0.0, MIN(2.0, pitch)) - 1.0); }

/*! Convert AudioUnit cents in the range of -2400 to 2400 to OpenAL float pitch in the range of 0.0 to 2.0. */
static inline float audCentsToPitch(float cents) { return (MAX(-2400.0, MIN(2400.0, cents)) / 2400.0) + 1.0; }



#pragma mark - C Functions

/*!
 @abstract Print out all available AudioUnit parameters in the kAudioUnitScope_Global to the console. 
 @param audioUnit the audioUnit for which to print out the parameters.
 */
void audPrintAUParameters(AudioUnit audioUnit); // <-- kAudioUnitScope_Global

/*!
 @abstract Print out all available AudioUnit parameters to the console.
 @param audioUnit the audioUnit for which to print out the parameters.
 @param audioUnitScope the scope which to print paramters for, e.g. kAudioUnitScope_Global
 */
void audPrintAUParametersInScope(AudioUnit audioUnit,
                                 int audioUnitScope);

/*!
 @abstract Get the AudioComponentDescription from an AudioUnit instance
 @param audioUnit the audioUnit for which to print out the parameters.
 */
AudioComponentDescription audGetComponentDescription(AudioUnit audioUnit);

/*!
 @abstract Get a new instance of AUVarispeed configured and ready for use as a TAAE channel filter.
 @param audioController the AEAudioController object that will be using this filter.
 @param audioUnitToFilter the audioUnit which the filter will be applied to.
 @param cents the pitch to set the AUVarispeed.  Range is +/-2400.
 */
AEAudioUnitFilter* audCreateAUVarispeedFilter(AEAudioController *audioController,
                                              AudioUnit audioUnitToFilter,
                                              int16_t cents);

/*!
 @abstract Get a new instance of AUNewTimePitch configured and ready for use as a TAAE channel filter.
 @param audioController the AEAudioController object that will be using this filter.
 @param audioUnitToFilter the audioUnit which the filter will be applied to.
 @param rate the speed at which the audio should play back at.  Range is 1/32 up to 32.0
 @param cents the pitch to set the AUVarispeed.  Range is +/-2400.
 */
AEAudioUnitFilter* audCreateAUNewTimePitchFilter(AEAudioController *audioController,
                                                 AudioUnit audioUnitToFilter,
                                                 float rate,
                                                 int16_t cents);























#endif // __VEAEUtils_h__
