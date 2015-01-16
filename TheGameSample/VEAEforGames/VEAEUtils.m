//
//  VEMIDI_C_Lib.m
//  TheGameSample
//
//  Created by Leo on 2014-12-17.
//  Copyright (c) 2014 The Amazing Audio Engine. All rights reserved.
//

#import "VEMIDI_C_Lib.h"

#define checkResult(result,operation) (_checkResult((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _checkResult(OSStatus result, const char *operation, const char* file, int line) {
    if ( result != noErr ) {
        #if defined(DEBUG) && DEBUG
            int fourCC = CFSwapInt32HostToBig(result);
            NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&fourCC);
        #endif
        return NO;
    }
    return YES;
}

void midiNoteOn(AudioUnit instrumentAU, uint8_t note, uint8_t velocity) {
    checkResult(MusicDeviceMIDIEvent(instrumentAU,
                                     kMidiMessage_NoteOn,
                                     note,
                                     velocity,
                                     0),
                "Sending MIDI start note event.");
}

void midiNoteOff(AudioUnit instrumentAU, uint8_t note) {
    checkResult(MusicDeviceMIDIEvent(instrumentAU,
                                     kMidiMessage_NoteOff,
                                     note,
                                     0,
                                     0),
                "Sending MIDI stop note event.");
}

void midiSendController(AudioUnit instrumentAU, uint8_t controller, uint8_t value) {
    // See: http://tuxguitar.sourcearchive.com/documentation/1.2/org__herac__tuxguitar__player__impl__midiport__coreaudio__MidiReceiverJNI_8cpp-source.html
    checkResult(MusicDeviceMIDIEvent(instrumentAU,
                                     kMidiMessage_ControlChange,
                                     controller,
                                     value,
                                     0),
                "Sending MIDI control change controller event.");
}

void midiSendPitchBend(AudioUnit instrumentAU, uint16_t bendValue) {
//    midiCheckStatus(MusicDeviceMIDIEvent(instrumentAU, kMidiMessage_PitchBend, 0, bendValue, 0),
//                    "Sending MIDI pitch bend event.");
    
    // See: http://stackoverflow.com/q/15468558
    bendValue = MAX(0, MIN(16383, bendValue));
    UInt32 bendMSB = (bendValue >> 7) & 0x7F; // coarse pitch
    UInt32 bendLSB = bendValue & 0x7F;        // fine pitch
//    NSLog(@"MSB=%d, LSB=%d", (unsigned int)bendMSB, (unsigned int)bendLSB);
    checkResult(MusicDeviceMIDIEvent(instrumentAU,
                                     kMidiMessage_PitchBend << 4 | 0,
                                     bendLSB,
                                     bendMSB,
                                     0),
                "Sending MIDI pitch bend event.");
}


void midiAllNotesOff(AudioUnit instrumentAU) {
    checkResult(MusicDeviceMIDIEvent(instrumentAU,
                                     kMidiMessage_ControlChange,
                                     kMidiController_AllNotesOff,
                                     0,
                                     0),
                "Sending MIDI control change AllNotesOff event.");
    
}

void midiAllSoundOff(AudioUnit instrumentAU) {
    checkResult(MusicDeviceMIDIEvent(instrumentAU,
                                     kMidiMessage_ControlChange,
                                     kMidiController_AllSoundOff,
                                     0,
                                     0),
                "Sending MIDI control change AllSoundOff event.");
    
}

void midiResetAllControllers(AudioUnit instrumentAU) {
    checkResult(MusicDeviceMIDIEvent(instrumentAU,
                                     kMidiMessage_ControlChange,
                                     kMidiController_ResetAllControllers,
                                     0,
                                     0),
                "Sending MIDI control change ResetAllControllers event.");
}











