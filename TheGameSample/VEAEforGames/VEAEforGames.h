//
//  VEAEforGames.h
//  VE TAAE Game Engine
//
//  Created by Leo on 2014-12-08.
//  Copyright (c) 2014 http://visionsencoded.com, All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TheAmazingAudioEngine.h"
#import "VEAEUtils.h"
#import "VEAEGameTrack.h"
#import "VEAEGameSound.h"




/*! 
 @abstract Init the audio engine; you may optionally provide your own audioController, else one will be created.
 */
AEAudioController* audInit( AEAudioController *audioControllerOrNil );

/*! 
 @abstract Returns the AEAudioController object the game engine is using, if the engine is initialized.
 */
AEAudioController* audController();

/*!
 @abstract Returns a game sound ready to be played.
 @param url the full file-URL to the local sound file
 @param pitch the pitch in the range of 0.0->2.0, where 1.0 is at pitch, 0. is two octaves down, 2.0 is two octaves up
 @param isLooping whether this sound should loop - if looping the sound can only play back one instance; for a non-looping sound you can call "play" on the sound object repeatedly for multiple playbacks of the same sound (e.g. a machine gun fire burst).  If the sound is looping and play is called repeatedly, the sound starts again from the beginning.  You can call the "allSoundOff" method to stop a looping sound without unloading it.
 */
VEAEGameSound* audLoadEffect(NSURL *url, float pitch, BOOL isLooping);

//void audPlayEffect(VEAEGameSound *sound);
//void audPlayEffectV(VEAEGameSound *samplerChannel);
//void audPlayEffectVP(VEAEGameSound *samplerChannel);

//AmbienceChannel* audLoadAmbience(NSString *fullPathToFile, float pitch, float pan, float fadeInDuration);







































