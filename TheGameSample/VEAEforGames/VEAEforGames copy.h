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


typedef AEAudioUnitChannel SamplerChannel; // This channel must have a "AUSampler" as its .audioUnit parameter - this is not strictly enforced in code, but should be adhered to in use (hence the typedef - just to remind us - I recommend in your own code use the SamplerChannel type instead of AEAudioUnitChannel for objects that came from this "for games" library).

typedef AEAudioUnitChannel AmbientChannel; // This channel must have a "AUAudioFilePlayer" as its .audioUnit parameter - same idea as the "SamplerChannel" typedef


#pragma mark - *** THE GLOBAL AUDIO UTILITY FUNCTIONS ***

/**
 * Returns true on "OK" and false on "Error".
 * USAGE: VECheckErr(FuncThatReturnsOSStatus(params), "Some human comprehensible message for stderr.");
 */
BOOL audCheckStatus(OSStatus status, const char *errMessage);


/** 
 * Print out all available AudioUnit parameters to the console. 
 */
void audNSLogAudioUnitParameters(AudioUnit audioUnit);


/**
 * Attempts to create and return an AEAudioUnitChannel that has a sampler AudioUnit with the specified audio file being used as the sample.
 */
SamplerChannel* audGetAUSamplerChannel(AEAudioController *audCtrlr, NSURL *audioFileUrl, BOOL isLooping, int cents);


/**
 * Send a MIDI control change event (e.g. gain is CC#7 and pan is CC#10).
 */
void audMidiControlChange(AudioUnit audioUnit, int ccNumber, int valueBetween0and127);


/**
 *  Send a MIDI pitch bend event.  A pitch value of 64 is "at pitch"; 127 is 2octaves up, and 0 is 2 octaves down.
 */
void audMidiPitchBend(AudioUnit audioUnit, short valueBetween0and127);



#pragma mark - *** THE GLOBAL AUDIO "GAME ENGINE" FUNCTIONS ***

/** Init the audio engine; you may optionally provide your own audioController, else one will be created.  Note if you are providing your own audioController: for Mac OS X / iOS cross platform compatibility `AEAudioController.nonInterleavedFloatStereoAudioDescription()` works, others may not.
 */
AEAudioController* audInit( AEAudioController *audioControllerOrNil );


/** Returns the AEAudioController object the game engine is using, if the engine is initialized.
 */
AEAudioController* audController();

/*
/// Returns the global effects volume scale - see comments on `audSetEffectsVolumeScale(...)`
func audVolumeScale() -> Float {
    return _engine._effectsVolumeScale
}


// Sets the global effects volume scaling, which is a number between 0.0 and 1.0 by which all effects volumes are "scaled", e.g. a sound effect played at volume 1.0 will actually be played back at 1.0 * effectsVolumeScale.  This only applies to "effects" - not to long background music tracks.
func audSetVolumeScale( volumeScale : Float) {
    _engine._effectsVolumeScale = volumeScale
}
*/


/// Load the sound effect without playing it, so there will be minimal delay on the first playback and the channel can be reused via the audPlay(...) function(s)
SamplerChannel* audPreload(NSString *fullPathToFile,
                           float pitch,
                           float pan,
                           BOOL isLooping);


/*
/// Unload the sound effect to free up RAM
func audUnload( relFilePath : String ) {
    
}
*/

/** Play an audio effect; typically these should be short, mono sound files: 22050khz, mono IMA4 caf is recommended.
 
 @param filePath full path to the audio file
 @param volume value of 0.0 to 1.0 representing how loud to play - this value is combined with the "volume scale" to get a final volume level.
 @param pitch a value between 0.0 and 2.0 where 1.0 is unaltered, 0.0 is two octaves lower and 2.0 is two octaves higher.
 @param pan a value between -1.0 and 1.0 where -1.0 is fully left and 1.0 is fuly right
 @param isLooping whether the sound should loop indefinitly or only play back once
 */
//AEAudioUnitChannel* __attribute__((overloadable)) audPlay(NSString *relFilePath,
//                                                          float volume,
//                                                          float pitch,
//                                                          float pan,
//                                                          BOOL isLooping);
/** Play an audio effect; typically these should be short, mono sound files: 22050khz, mono IMA4 caf is recommended.
 */
void audPlay(SamplerChannel *samplerChannel, double volume);



//void audSetVolume(SamplerChannel *samplerChannel, float volume);



/*
/// This will stop all instances of this sound file; to stop only specific instances, you need call the function by the same name but passing it the player object that was returned by the `audPlay()` function.
func audStop( relFilePath : String) {
    
}


func audStop( sndObj : AnyObject? ) {
    if let snd = sndObj? as? NSObject {
        // do something
    }
}


// Stops all the sound effects, including looping sound effects.  Does not stop the long sound tracks (e.g. bg music or narration).
func audStopAllEffects();


/// Stop all "one shot" type sound effects while allowing the looping ones to continue (e.g. some ambient wind noise that should continue to loop)
func audStopAllNonLoopingEffects();
*/