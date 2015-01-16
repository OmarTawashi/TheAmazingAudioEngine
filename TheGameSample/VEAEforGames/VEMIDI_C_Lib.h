//
//  VEMIDI_C_Lib.h
//  TheGameSample
//
//  Created by Leo on 2014-12-17.
//  Copyright (c) 2014 The Amazing Audio Engine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>



//#ifndef __VEMIDI_C_Lib_h__
//#define __VEMIDI_C_Lib_h__

BOOL midiCheckStatus(OSStatus status, const char *errMessage);

//static inline void midiNoteOn(uint8_t note, uint8_t velocity) {
//    midiCheckStatus(MusicDeviceMIDIEvent(_audioUnit, kMidiMessage_NoteOn, note, velocity, 0), "Error sending MIDI start note event.");
//}

//- (void)midiNoteOff:(uint8_t)note {
//    checkResult(MusicDeviceMIDIEvent(_audioUnit, kMidiMessage_NoteOff, note, 0, 0), "Error sending MIDI stop note event.");
//}
//
//- (void)midiSendController:(uint8_t)controller withValue:(uint8_t)value {
//    // See: http://tuxguitar.sourcearchive.com/documentation/1.2/org__herac__tuxguitar__player__impl__midiport__coreaudio__MidiReceiverJNI_8cpp-source.html
//    checkResult(MusicDeviceMIDIEvent(_audioUnit, kMidiMessage_ControlChange, controller, value, 0), "Error sending MIDI control change controller event.");
//}
//
//- (void)sendPitchBend:(uint16_t)bendValue {
//    //    checkResult(MusicDeviceMIDIEvent(_audioUnit, kMidiMessage_PitchBend, 0, pitchbend, 0), "Error sending MIDI pitch bend event.");
//    
//    // See: http://stackoverflow.com/q/15468558
//    bendValue = MAX(0, MIN(16383, bendValue));
//    UInt32 bendMSB = (bendValue >> 7) & 0x7F; // coarse pitch
//    UInt32 bendLSB = bendValue & 0x7F;        // fine pitch
//    NSLog(@"MSB=%d, LSB=%d", (unsigned int)bendMSB, (unsigned int)bendLSB);
//    checkResult(MusicDeviceMIDIEvent(_audioUnit, kMidiMessage_PitchBend << 4 | 0, bendLSB, bendMSB, 0), "Error sending MIDI pitch bend event.");
//}





//#endif // __VEMIDI_C_Lib_h__
