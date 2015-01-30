//
//  VEAudioEngine.h
//  VEAudioEngine Module for TheAmazingAudioEngine
//
//  Created by Leo Thiessen on 2015-01-29.
//
//  Copyright (C) 2015 Visions Encoded.
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import <Foundation/Foundation.h>
#import "TheAmazingAudioEngine.h"
#import "VEAETrack.h"


/*!
 @abstract Init the audio engine; you may optionally provide your own audioController, else one will be created.
 */
AEAudioController* audInit( AEAudioController *audioControllerOrNil );

/*!
 @abstract Returns the AEAudioController object the game engine is using, if the engine is initialized.
 */
AEAudioController* audController();

/*!
 @abstract Returns a game sound ready to be played like [sound play:1.0]
 */
//VEAEGameSound* audLoadSound(NSString *relFilePath, BOOL isLooping, int cents);

/*!
 @abstract Do a very short fade out (if required), then stop, then remove this sound channel from the audio controller.
 */
//void audUnloadSound(VEAEGameSound *sound, float fadeOutDuration);

/*!
 @abstract Stop all playing instances of this particular sound object from playing, but otherwise leave it in its 
 current state so it can be used for further playback.
 */
//void audStopSound(VEAEGameSound *sound);

/*!
 @abstract Returns a game audio track ready to be played like [track play:1.0]
 */
VEAETrack* audNewTrack(NSString *relFilePath, BOOL isLooping);









