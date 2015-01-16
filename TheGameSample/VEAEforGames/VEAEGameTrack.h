//
//  VEAEGameTrack.h
//  TheAmazingAudioEngine
//
//  This file is based on "AEAudioUnitChannel.h" which was created by Michael
//  Tyson on 01/02/2013.
//
//  This file was created by Leo Thiessen on 10/12/2014.
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

#ifdef __cplusplus
extern "C" {
#endif

#import <Foundation/Foundation.h>
#import "TheAmazingAudioEngine.h"

/*!
 * Audio Unit Channel
 *
 *  This class allows you to add the AUAudioFilePlayer audio unit as a channel. 
 *  Provide a URL that points to the audio file you wish to play, and the
 *  corresponding audio player unit will be initialised, ready for use.
 *
 */
@interface VEAEGameTrack : NSObject <AEAudioPlayable>

/*!
 * Create a new Audio Unit channel
 *
 * @param fileURL An URL pointing to the local file resource you wish to load.
 * @param audioController The audio controller
 * @param error On output, if not NULL, will point to an error if a problem occurred
 * @param shouldLoop Whether to loop the audio file or not.
 * @return The initialised channel
 */
- (instancetype)initWithFileURL:(NSURL*)fileURL
                audioController:(AEAudioController*)audioController
                     shouldLoop:(BOOL)shouldLoop
                          error:(NSError**)error;

/*!
 * Create a new Audio Unit channel
 *
 * @param fileURL An URL pointing to the local file resource you wish to load.
 * @param audioController The audio controller
 * @param preInitializeBlock A block to run before the audio unit is initialized.  Can be NULL.
 *              This can be used to set some properties that needs to be set before the unit is initialized.
 * @param shouldLoop Whether to loop the audio file or not.
 * @param error On output, if not NULL, will point to an error if a problem occurred
 * @return The initialised channel
 */
- (instancetype)initWithFileURL:(NSURL*)fileURL
                audioController:(AEAudioController*)audioController
             preInitializeBlock:(void(^)(AudioUnit audioUnit))block
                     shouldLoop:(BOOL)shouldLoop
                          error:(NSError**)error;


/*! 
 * Original media URL
 */
@property (nonatomic, strong, readonly) NSURL *url;

/*!
 * Length of audio, in seconds
 */
@property (nonatomic, readonly) NSTimeInterval duration;

/*!
 * Current playback position, in seconds
 */
@property (nonatomic, readonly) NSTimeInterval currentTime; // TODO: some guru to make this "assign"-able, see See: http://lists.apple.com/archives/coreaudio-api/2005/Dec/msg00010.html

/*!
 * Wether the last render cycle output silence or not.  This property is NOT KVO compliant.
 */
@property (nonatomic, readonly) BOOL outputIsSilence;

/*!
 * Whether to loop this track
 */
@property (nonatomic, readwrite) BOOL loop;

/*!
 * Track volume
 *
 * Range: 0.0 to 1.0
 */
@property (nonatomic, assign) float volume;

/*!
 * Track pan
 *
 * Range: -1.0 (left) to 1.0 (right)
 */
@property (nonatomic, assign) float pan;

/*
 * Whether channel is currently playing
 *
 * If this is NO, then the track will be silenced and no further render callbacks
 * will be performed until set to YES again.
 */
@property (nonatomic, assign) BOOL channelIsPlaying;

/*
 * Whether channel is muted
 *
 * If YES, track will be silenced, but render callbacks will continue to be performed.
 */
@property (nonatomic, assign) BOOL channelIsMuted;

/*!
 * The AUAudioFilePlayer audio unit
 */
@property (nonatomic, readonly) AudioUnit audioUnit;

/*!
 * The audio graph node
 */
@property (nonatomic, readonly) AUNode audioGraphNode;

/*!
 * Whether the track automatically removes itself from the audio controller after playback completes.
 */
@property (nonatomic, readwrite) BOOL removeUponFinish;

/*!
 * A block to be called when playback finishes; will be called repeatedly in case of a looping file.
 */
@property (nonatomic, copy) void(^completionBlock)();

/*!
 * A block to be called when the loop restarts in loop mode.
 */
@property (nonatomic, copy) void(^startLoopBlock)();

@end

#ifdef __cplusplus
}
#endif