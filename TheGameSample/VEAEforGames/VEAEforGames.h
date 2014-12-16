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
#import "AEGameSoundChannel.h"
#import "AEBlockTimer.h"



#pragma mark - Typedefs

//typedef AEAudioUnitChannel SamplerChannel; // This channel must have a "AUSampler" as its .audioUnit parameter - this is not strictly enforced in code, but should be adhered to in use (hence the typedef - just to remind us - I recommend in your own code use the SamplerChannel type instead of AEAudioUnitChannel for objects that came from this "for games" library).


typedef AEAUAudioFilePlayerChannel AmbienceChannel; // This channel must have a "AUAudioFilePlayer" as its .audioUnit parameter - same idea as the "SamplerChannel" typedef


@protocol HasAnAudioUnitProperty <NSObject>
@required
@property AudioUnit audioUnit;
@end
@interface AEAudioUnitFilter() <HasAnAudioUnitProperty> @end
@interface AEAudioUnitChannel() <HasAnAudioUnitProperty> @end
@interface AEAUAudioFilePlayerChannel() <HasAnAudioUnitProperty> @end
@interface AEGameSoundChannel() <HasAnAudioUnitProperty> @end
@interface AEAudioController() <HasAnAudioUnitProperty> @end


#pragma mark - *** THE GLOBAL AUDIO UTILITY FUNCTIONS ***

/** Returns true on "OK", else prints the supplied message to the console along with some other details, and returns false. */
BOOL audCheckStatus(OSStatus status, const char *errMessage);


/** Print out all available AudioUnit parameters to the console. */
void audPrintAudioUnitParametersInScope(AudioUnit audioUnit, int audioUnitScope);
void audPrintAudioUnitParameters(AudioUnit audioUnit); // <-- kAudioUnitScope_Global


/** Get the AudioComponentDescription from an AudioUnit instance */
AudioComponentDescription audGetComponentDescription(AudioUnit audioUnit);

/** Attempts to create and return an AEAudioUnitChannel that has a sampler AudioUnit loaded with the supplied URL. */
AEGameSoundChannel* audGetAUSamplerChannel(AEAudioController *audCtrlr, NSURL *audioFileUrl, BOOL isLooping, int cents);


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


AEGameSoundChannel* audLoadEffect(NSString *fullPathToFile, float pitch, float pan, BOOL isLooping);


void audPlayEffect(AEGameSoundChannel *samplerChannel, float volume);


/** Fade in/out the volume between the range of 0.0 and 1.0 */
void audRampEffectVolume(AEGameSoundChannel *samplerChannel, float fromVolume, float toVolume, float duration);


/** Ramp the pitch up/down between the range of 0.0 (down two octaves) and 2.0 (up two octaves), where 1.0 == at pitch */
void audRampEffectPitch(AEGameSoundChannel *samplerChannel, float fromPitch, float toPitch, float duration);


/** Pan the audio from one side to the other (stereo) between the range of -1.0 (fully left) to 1.0 (fully right). */
void audRampEffectPan(AEGameSoundChannel *samplerChannel, float fromPan, float toPan, float duration);


AmbienceChannel* audLoadAmbience(NSString *fullPathToFile, float pitch, float pan, float fadeInDuration);


void audModulate(id<HasAnAudioUnitProperty> channel,
                 AudioUnitParameterID		inID,
                 AudioUnitScope				inScope,
                 AudioUnitElement			inElement,
                 AudioUnitParameterValue	startValue,
                 AudioUnitParameterValue	endValue,
                 UInt32						inBufferOffsetInFrames,
                 Float32                    duration);







































