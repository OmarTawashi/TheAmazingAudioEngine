//
//  VEAETrack.h
//  VEAudioEngine Module for TheAmazingAudioEngine
//
//  Created by Leo Thiessen on 2015-01-21.
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

#import "VEAEAbstractChannel.h"
EXTERN_C_BEGIN



@interface VEAETrack : VEAEAbstractChannel


/// Create a new audio track channel using the kAudioUnitSubType_AudioFilePlayer audio unit.
/// @param fileURL An URL pointing to the local file resource you wish to load.
/// @param audioController The audio controller
/// @param shouldLoop Whether to loop the audio file or not.
/// @param error Optional - if provided and a problem occurs, this will point to an error object
- (instancetype)initWithFileURL:(NSURL*)fileURL
                audioController:(AEAudioController*)audioController
                     shouldLoop:(BOOL)shouldLoop
                          error:(NSError**)error;



/// Length of audio, in seconds.
@property (nonatomic, readonly) NSTimeInterval duration;

/// Current playback position, in seconds.
@property (nonatomic, readonly) NSTimeInterval currentTime;

/// A block to be called when playback finishes; will be called repeatedly in case of a looping file.
@property (nonatomic, copy) ve_completion_block_t completionBlock;


@end



EXTERN_C_END