//
//  VEAEforGames.h
//  TheGameSample
//
//  Created by Leo on 2014-12-08.
//  Copyright (c) 2014 visionsencoded.com, All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TheAmazingAudioEngine.h"
#import "AUMIDIDefs.h"
#import "AEAUAudioFilePlayerChannel.h"


#pragma mark - Typedefs

typedef AEAudioUnitChannel SamplerChannel; // This channel must have a "AUSampler" as its .audioUnit parameter - this is not strictly enforced in code, but should be adhered to in use (hence the typedef - just to remind us - I recommend in your own code use the SamplerChannel type instead of AEAudioUnitChannel for objects that came from this "for games" library).


typedef AEAUAudioFilePlayerChannel AmbienceChannel; // This channel must have a "AUAudioFilePlayer" as its .audioUnit parameter - same idea as the "SamplerChannel" typedef


#pragma mark - *** THE GLOBAL AUDIO UTILITY FUNCTIONS ***

/** Returns true on "OK", else prints the supplied message to the console along with some other details, and returns false. */
BOOL audCheckStatus(OSStatus status, const char *errMessage);


/** Print out all available AudioUnit parameters to the console. */
void audPrintAudioUnitParametersInScope(AudioUnit audioUnit, int audioUnitScope);
void audPrintAudioUnitParameters(AudioUnit audioUnit); // <-- kAudioUnitScope_Global


/** Attempts to create and return an AEAudioUnitChannel that has a sampler AudioUnit loaded with the supplied URL. */
SamplerChannel* audGetAUSamplerChannel(AEAudioController *audCtrlr, NSURL *audioFileUrl, BOOL isLooping, int cents);


/** Send a MIDI control change event (e.g. gain is CC#7 and pan is CC#10). */
void audMidiControlChange(AudioUnit audioUnit, int ccNumber, int valueBetween0and127);


/** Send a MIDI pitch bend event.  Our default is: a value of 64 is "at pitch"; 127 is 2octaves up, and 0 is 2 octaves down. */
void audMidiPitchBend(AudioUnit audioUnit, short valueBetween0and127);


/** Get a new instance of AUVarispeed configured and ready for use as a TAAE channel filter.  Rate can be 0.25 to 4.0 */
AEAudioUnitFilter* audAUVarispeedFilter(AEAudioController *audioController, AudioUnit audioUnitToFilter, float playbackRate);


/** Get a new instance of AUVarispeed configured and ready for use as a TAAE channel filter.  Range is +/-2400 cents. */
AEAudioUnitFilter* audAUVarispeedFilterCents(AEAudioController *audioController, AudioUnit audioUnitToFilter, int cents);


/** Get a new instance of AUNewTimePitch configured and ready for use as a TAAE channel filter. */
AEAudioUnitFilter* audAUNewTimePitchFilter(AEAudioController *audioController, AudioUnit audioUnitToFilter, float rate, int cents);



#pragma mark - *** THE GLOBAL AUDIO "GAME ENGINE" FUNCTIONS ***

/** Init the audio engine; you may optionally provide your own audioController, else one will be created. */
AEAudioController* audInit( AEAudioController *audioControllerOrNil );


/** Returns the AEAudioController object the game engine is using, if the engine is initialized. */
AEAudioController* audController();


SamplerChannel* audLoadEffect(NSString *fullPathToFile, float pitch, float pan, BOOL isLooping);


void audPlayEffect(SamplerChannel *samplerChannel, float volume);


AmbienceChannel* audLoadAmbience(NSString *fullPathToFile, float pitch, float pan, float fadeInDuration);







































