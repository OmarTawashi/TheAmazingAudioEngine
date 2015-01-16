//
//  VEMIDI_C_Lib.h
//  TheGameSample
//
//  Created by Leo on 2014-12-17.
//  Copyright (c) 2014 The Amazing Audio Engine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AUMIDIDefs.h"


/*
 This library provides MIDI related functions so that the same code doesn't need to be repeated in various places 
 throughout your own projects (e.g. MIDI pitch bend messages code, etc.).
 If a DEBUG macro is defined and set to true, then these functions will log error to the console.
 */
#ifndef __VEMIDI_C_Lib_h__
#define __VEMIDI_C_Lib_h__

/*!
 @abstract sends a MIDI Note On event to the instrument
 @param note the note number (key) to play. Range: 0 -> 127
 @param velocity specifies the volume with which the note is played. Range: 0 -> 127
 */
void midiNoteOn(AudioUnit instrumentAU, uint8_t note, uint8_t velocity);

/*!
 @abstract sends a MIDI Note Off event to the instrument
 @param note the note number (key) to stop Range: 0 -> 127
 */
void midiNoteOff(AudioUnit instrumentAU, uint8_t note);

/*!
 @abstract send a MIDI controller event to the instrument.
 @param controller a standard MIDI controller number. Range: 0 -> 127
 @param  value value for the controller. Range: 0 -> 127
 */
void midiSendController(AudioUnit instrumentAU, uint8_t controller, uint8_t value);

/*!
 @abstract sends MIDI Pitch Bend event to the instrument.
 @param pitchbend value of the pitchbend Range: 0 -> 16383
 */
void midiSendPitchBend(AudioUnit instrumentAU, uint16_t bendValue);

/*!
 @abstract sends MIDI all notes off event to the instrument.
 */
void midiAllNotesOff(AudioUnit instrumentAU);

/*!
 @abstract sends MIDI all sound off event to the instrument; the instrument must support this for it to work.
 */
void midiAllSoundOff(AudioUnit instrumentAU);

/*!
 @abstract sends MIDI event to the instrument to reset all controllers to their default "positions" (values).
 */
void midiResetAllControllers(AudioUnit instrumentAU);






#endif // __VEMIDI_C_Lib_h__
