//
//  VEAEAUSampler.h
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
#import "AUMIDIDefs.h"

/*!
 * Audio Unit Channel
 *
 *  This class allows you to add the AUSampler audio unit as a channel.
 *  Provide a URL that points to the audio file you wish to use as a sample, 
 *  and the sampler audio unit will be initialised, ready for use.
 *
 */
@interface VEAEAUSampler : NSObject <AEAudioPlayable> {
    AEAudioController *_audioController;
    AudioComponentDescription _componentDescription;
    AUNode _node;
    AudioUnit _audioUnit; // moved to .h file so we can directly access this in subclasses for performance
//    AUNode _converterNode;    // We use the AUAudioFilePlayer units built in conversion capability instead
//    AudioUnit _converterUnit;
    AUGraph _audioGraph;
    BOOL _outputIsSilence;
    NSDictionary *_aupreset;
}

/*!
 * Create a new Audio Unit channel
 *
 * @param aupresetFileURL An URL to the local .aupreset resource you wish to load.
 * @param audioController The audio controller
 * @param error On output, if not NULL, will point to an error if a problem occurred
 * @return The initialised channel
 */
- (instancetype)initWithFileURL:(NSURL*)aupresetFileURL
                audioController:(AEAudioController*)audioController
                          error:(NSError**)error;

/*!
 * Create a new Audio Unit channel
 *
 * @param aupresetFileURL An URL to the local .aupreset resource you wish to load.
 * @param audioController The audio controller
 * @param preInitializeBlock A block to run before the audio unit is initialized.  Can be NULL.
 *              This can be used to set some properties that needs to be set before the unit is initialized.
 * @param error On output, if not NULL, will point to an error if a problem occurred
 * @return The initialised channel
 */
- (instancetype)initWithFileURL:(NSURL*)aupresetFileURL
                audioController:(AEAudioController*)audioController
             preInitializeBlock:(void(^)(AudioUnit audioUnit))block
                          error:(NSError**)error;

/*!
 * Create a new Audio Unit channel
 *
 * @param aupresetDictionary A dicationary, typically loaded from a .aupreset file (but loading it yourself
 *              enables you to modify it programmatically before it is loaded into the Audio Unit)
 * @param audioController The audio controller
 * @param preInitializeBlock A block to run before the audio unit is initialized.  Can be NULL.
 *              This can be used to set some properties that needs to be set before the unit is initialized.
 * @param error On output, if not NULL, will point to an error if a problem occurred
 * @return The initialised channel
 */
- (id)initWithDictionary:(NSDictionary*)aupresetDictionary
         audioController:(AEAudioController*)audioController
      preInitializeBlock:(void(^)(AudioUnit audioUnit))block
                   error:(NSError**)error;

/*!
 * The original .aupreset as an NSDictionary object
 */
@property (nonatomic, strong, readonly) NSDictionary *aupreset;

/*!
 * Wether the last render cycle output silence or not.  This can be useful if you wish 
 * stop the sound - if it has no audio, just stop it, or optionally fade out first.
 */
@property (nonatomic, readonly) BOOL outputIsSilence;

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
 * The AUSampler audio unit
 */
@property (nonatomic, readonly) AudioUnit audioUnit;

/*!
 * The audio graph node
 */
@property (nonatomic, readonly) AUNode audioGraphNode;


/*! @method startNote:withVelocity
 @abstract sends a MIDI Note On event to the instrument
 @param note the note number (key) to play. Range: 0 -> 127
 @param velocity specifies the volume with which the note is played. Range: 0 -> 127
 */
- (void)startNote:(uint8_t)note withVelocity:(uint8_t)velocity;

/*! @method stopNote
 @abstract sends a MIDI Note Off event to the instrument
 @param note the note number (key) to stop Range: 0 -> 127
 */
- (void)stopNote:(uint8_t)note;

/*! @method sendController:withValue
 @abstract send a MIDI controller event to the instrument.
 @param controller a standard MIDI controller number. Range: 0 -> 127
 @param  value value for the controller. Range: 0 -> 127
 */
- (void)sendController:(uint8_t)controller withValue:(uint8_t)value;

/*! @method sendPitchBend
 @abstract sends MIDI Pitch Bend event to the instrument.
 @param pitchbend value of the pitchbend Range: 0 -> 16383
 */
- (void)sendPitchBend:(uint16_t)pitchbend;

/*! Stop all notes. */
- (void)allNotesOff;

/*! Stop all sound. */
- (void)allSoundOff;

/*! Reset all controllers. */
- (void)resetAllControllers;

/*! Stop all MIDI notes, stop all sound output and reset all controller values. */
- (void)panic;

/*! Declared here so sublasses can call it via [super didRecreateGraph:], don't call this manually. */
- (void)didRecreateGraph:(NSNotification*)notification;

@end

#ifdef __cplusplus
}
#endif