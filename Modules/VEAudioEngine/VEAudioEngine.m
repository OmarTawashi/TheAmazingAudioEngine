//
//  VEAudioEngine.m
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

#import "VEAudioEngine.h"



#pragma mark - STATIC VARIABLES (used internally to this file)

static AEAudioController *_audCtrlr = nil;
static AEChannelGroupRef _channelGroupSounds = NULL;
static AEChannelGroupRef _channelGroupTracks = NULL;



#pragma mark - "GAME ENGINE" INIT

AEAudioController* audInit(AEAudioController *audioControllerOrNil) {
    
    // Setup the AEAudioController
    if(_audCtrlr == nil) {
        // Ensure we have an AEAudioController
        _audCtrlr = audioControllerOrNil;
        if(_audCtrlr == nil) {
            // Init audio controller
            // NOTE: the nonInterleaved16BitStereoAudioDescription does not work on Mac, "...Float" does:
            AudioStreamBasicDescription asbd = [AEAudioController nonInterleavedFloatStereoAudioDescription];
            asbd.mSampleRate = 22050.0; // I like to use 22050.0 for games
            AEAudioStreamBasicDescriptionSetChannelsPerFrame(&asbd, 2); // e.g. 1 for mono
            _audCtrlr = [[AEAudioController alloc] initWithAudioDescription:asbd];
            NSError *err;
            if([_audCtrlr start:&err] == NO) {
                VEAELog(@"ERROR: Attempting to initialize the AEAudioController failed with message: %@",
                        [err localizedDescription]);
                [_audCtrlr stop];
                _audCtrlr = nil;
                return nil;
            }
        }
    }
    
    // Create our sounds channel group (so we can apply reverb to all sounds, collectively)
    if(_channelGroupSounds==NULL) {
        _channelGroupSounds = [_audCtrlr createChannelGroup];
    }
    
    // Create our tracks channel group
    if(_channelGroupTracks==NULL) {
        _channelGroupTracks = [_audCtrlr createChannelGroup];
    }
    
    return _audCtrlr;
}


AEAudioController* audController() {
    return _audCtrlr;
}



#pragma mark - AUDIO "TRACKS" (e.g. longer bg music type audio, streamed from disk)

VEAETrack* audNewTrack(NSString *relFilePath, BOOL isLooping) {
    if(_audCtrlr) {
        NSString *path = [relFilePath stringByDeletingLastPathComponent];
        NSString *file = [[relFilePath lastPathComponent] stringByDeletingPathExtension];
        NSString *ext  = [relFilePath pathExtension];
        NSURL *url = [[NSBundle mainBundle] URLForResource:file withExtension:ext subdirectory:path];
        NSError *error;
        VEAETrack *track = [[VEAETrack alloc] initWithFileURL:url
                                              audioController:_audCtrlr
                                                   shouldLoop:isLooping
                                                        error:&error];
        if(track) {
            track.channelIsPlaying = NO;
            [_audCtrlr addChannels:@[track] toChannelGroup:_channelGroupTracks];
            return track;
        } else {
            VEAELog(@"ERROR: creating VEAETrack failed with message: %@",
                    [error localizedDescription]);
            return nil;
        }
    } else {
        VEAELog(@"ERROR: Audio engine not set/initialized - please call "
                @"audInit(AEAudioController *audioControllerOrNil) first.");
        return nil;
    }
}



//VEAEGameSound* audLoadSound(NSString *relFilePath, BOOL isLooping, int cents) {
//    if(_audCtrlr) {
//        NSString *path = [relFilePath stringByDeletingLastPathComponent];
//        NSString *file = [[relFilePath lastPathComponent] stringByDeletingPathExtension];
//        NSString *ext  = [relFilePath pathExtension];
//        NSURL *url = [[NSBundle mainBundle] URLForResource:file withExtension:ext subdirectory:path];
//        VEAEGameSound *sound = [[VEAEGameSound alloc] initWithFileURL:url audioController:_audCtrlr shouldLoop:isLooping cents:cents error:nil];
//        [_audCtrlr addChannels:@[sound] toChannelGroup:_channelGroupSounds];
//        return sound;
//    } else {
//#if defined(DEBUG) && DEBUG
//        NSLog(@"%s:%i:%s() - Audio engine not initialized.", strrchr(__FILE__, '/')+1, __LINE__, __FUNCTION__);
//#endif
//        return nil;
//    }
//}
//
//void audUnloadSound(VEAEGameSound *sound, float fadeOutDuration) {
//    [sound removeSelf:0.1]; // very short default fade out.
//}


//void audPlayEffect(VEAEGameSound *sound) {
//    [sound play:1.0];
////    [sound setChannelIsMuted:NO];
////    [sound setChannelIsPlaying:YES];
//}























