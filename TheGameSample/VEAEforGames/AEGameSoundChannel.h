//
//  AEGameSoundChannel.h
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
#import "AEAUSamplerChannel.h"
#import <mach/mach_time.h> // for our timing/param modulation functions
    
/*!
 * Audio Unit Channel
 *
 *  This class allows you to add the AUSampler audio unit as a channel.
 *  Provide a URL that points to the audio file you wish to use as a sample,
 *  and the sampler audio unit will be initialised, ready for use.
 *
 */
@interface AEGameSoundChannel : AEAUSamplerChannel <AEAudioTimingReceiver>

/*!
 * Create a new Audio Unit channel
 *
 * @param fileURL An URL pointing to the local file resource you wish to load.
 * @param audioController The audio controller
 * @param error On output, if not NULL, will point to an error if a problem occurred
 * @param shouldLoop Whether to loop the sample or not.
 * @param cents - the "tuning" in the range of +/- 2400 cents (100cents = 1 semitone) that this sample
 *              should be initialized at
 * @return The initialised channel
 */
- (id)initWithFileURL:(NSURL*)fileURL
      audioController:(AEAudioController*)audioController
           shouldLoop:(BOOL)shouldLoop
                cents:(int)cents
                error:(NSError**)error;

/*!
 * Create a new Audio Unit channel
 *
 * @param fileURL An URL pointing to the local file resource you wish to load.
 * @param audioController The audio controller
 * @param preInitializeBlock A block to run before the audio unit is initialized.  Can be NULL.
 *              This can be used to set some properties that needs to be set before the unit is initialized.
 * @param shouldLoop Whether to loop the sample or not.
 * @param cents - the "tuning" in the range of +/- 2400 cents (100cents = 1 semitone) that this sample 
 *              should be initialized at
 * @param error On output, if not NULL, will point to an error if a problem occurred
 * @return The initialised channel
 */
- (id)initWithFileURL:(NSURL*)fileURL
      audioController:(AEAudioController*)audioController
   preInitializeBlock:(void(^)(AudioUnit audioUnit))block
           shouldLoop:(BOOL)shouldLoop
                cents:(int)cents
                error:(NSError**)error;


/*!
 * Original audio file URL
 */
@property (nonatomic, strong, readonly) NSURL *url;

/*!
 * Whether the sample loops
 */
@property (nonatomic, readonly) BOOL loop;

/*!
 * AudioUnit volume. Setting this value will stop any modulation.
 *
 * Range: 0.0 to 1.0
 */
@property (nonatomic, readwrite) float auVolume;

/*!
 * AudioUnit pan. Setting this value will stop any modulation.
 *
 * Range: -1.0 (left) to 1.0 (right)
 */
@property (nonatomic, readwrite) float auPan;

/*!
 * AudioUnit pitch - this is the state of the "pitch bend" (not the au "tuning"). 
 * Setting this value will stop any modulation.
 *
 * Range: 0.0 (two octaves lower) to 2.0 (two octaves higher)
 *        e.g. 0.5 is one octave lower and 1.5 is one octave higher
 */
@property (nonatomic, readwrite) float auPitchBend;

/*!
 * Modulate the AudioUnit pan to the new setting; note that this is not the
 * same as the channel or track pan, rather this is a direct modulation
 * of the AUSampler audio unit pan parameter.  To stop modulation, set the
 * auPan property on this object.  This channel must be playing before this
 * is called.
 */
- (void)auPanTo:(float)auPanTo duration:(float)duration;
- (void)auPitchBendTo:(float)auPitchBendTo duration:(float)duration;
- (void)auVolumeTo:(float)auVolumeTo duration:(float)duration;

@end
    
#ifdef __cplusplus
}
#endif