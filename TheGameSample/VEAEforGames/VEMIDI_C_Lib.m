//
//  VEMIDI_C_Lib.m
//  TheGameSample
//
//  Created by Leo on 2014-12-17.
//  Copyright (c) 2014 The Amazing Audio Engine. All rights reserved.
//

#import "VEMIDI_C_Lib.m"

BOOL midiCheckStatus(OSStatus status, const char *errMessage) {
    if(status==noErr) {
        return YES; // is OK
    } else {
        //        #if defined(DEBUG) && DEBUG
        char errorString[20];
        // See if it appears to be 4-char-code
        *(UInt32*)(errorString + 1) = CFSwapInt32HostToBig(status);
        if(isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
            errorString[0] = errorString[5] = '\''; // wrap with single quotes
            errorString[6] = '\0';                  // NULL terminator
        } else {
            sprintf(errorString,"%d",(int)status);   // Format is an integer
        }
        fprintf(stderr, "Error: %s (%s)\n", errMessage, errorString);
        //        #endif
        return NO; // not OK
    }
}