//
//  GameScene.swift
//  TheGameSample
//
//  Created by Leo on 2014-12-04.
//  Copyright (c) 2014 The Amazing Audio Engine. All rights reserved.
//

import SpriteKit



// Utility functions - you would probably want to organize this better!

/// Returns a float between 0.0 and 1.0
func randomFloat() -> Float {
    return Float(arc4random()) /  Float(UInt32.max)
}



/// This controlls the SpriteKit SKScene for both the Mac and iOS targets!
class GameScene: SKScene {
    
    var _audCtrlr : AEAudioController!
//    var _bgMusic  : AEAudioUnitFilePlayer! // looping doesn't work
    var _bgMusic  : AEAudioFilePlayer! // takes more memory... keep your background sound files short, and perhaps use lower bitrate (e.g. 22050)
    var _snd1     : AEAudioFilePlayer!
    var _snd2     : AEAudioFilePlayer!
    
    var _snd1PanIncr : Float = 0.066
    var _snd2PanIncr : Float = -0.033
    
    var btnBgSnd, btnEffects : SKLabelNode!
    
    
    override func didMoveToView(view: SKView) {
        
        backgroundColor = SKColor.blackColor()
        
        let fontSize : CGFloat = 24
        
        // "Button" #1 - a label, but tap/click-able
        btnBgSnd = SKLabelNode(fontNamed:"Chalkduster")
        btnBgSnd.text = "Play background music track!";
        btnBgSnd.fontSize = fontSize;
        btnBgSnd.position = CGPoint(x:CGRectGetMidX(frame), y:CGRectGetMidY(frame) + 64);
        addChild(btnBgSnd)
        
        // "Button" #2 - a label, but tap/click-able
        btnEffects = SKLabelNode(fontNamed:"Chalkduster")
        btnEffects.text = "Play 2 stereo panning sound effects!";
        btnEffects.fontSize = fontSize;
        btnEffects.position = CGPoint(x:CGRectGetMidX(frame), y:CGRectGetMidY(frame) - 64);
        addChild(btnEffects)
        
        // Init audio controller
//        #if os(iOS)
//            var audioDesc = AEAudioController.nonInterleaved16BitStereoAudioDescription() // this does not work on Mac
//        #else
            var audioDesc = AEAudioController.nonInterleavedFloatStereoAudioDescription() // this works on both Mac & iOS
//        #endif
        audioDesc.mSampleRate = 22050.0 // I like to use 22050.0 for games
        
        if let audCtrlr = AEAudioController(audioDescription: audioDesc, inputEnabled: false) {
            _audCtrlr = audCtrlr
        } else {
            fatalError("ERROR: Couldn't instantiate an AEAudioController.")
        }
        
        // Start the audio controller
        var err : NSErrorPointer = nil
        if _audCtrlr.start(err) != true {
            fatalError("ERROR: Couldn't start the AEAudioController.  Error.debugDescription: \(err.debugDescription)")
        }
        
        // on iOS let's let the user know to use headphones to be able to hear the panning effects
        #if os(iOS)
            runAction(SKAction.sequence([SKAction.waitForDuration(0.65), SKAction.runBlock({
                let alertView = UIAlertView(title: "Tip of the Day", message: "To hear the panning effect, use headphones!\n\nThe pitch and rate are being set randomly but only on one sound effect (the organ); see the source code for more information.", delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
            })]))
        #endif
    }
    
    
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        
        // Just playing around a bit: this test out panning effects indepentent of each other (useful for game sound effects)
        if _snd1 != nil {
            _snd1.pan += _snd1PanIncr
            if _snd1.pan > 0.99 || _snd1.pan < -0.99 { _snd1PanIncr *= -1.0 }
            
            _snd2.pan += _snd2PanIncr
            if _snd2.pan > 0.99 || _snd2.pan < -0.99 { _snd2PanIncr *= -1.0 }
        }
    }
    
    
    func _doBtnBoing(btn : SKLabelNode) {
        btn.removeAllActions()
        btn.setScale(1.0)
        SKAction.scaleXTo(0.8, y: 0.6, duration: 0.75)
        btn.runAction(SKAction.sequence([SKAction.scaleXTo(0.9, y: 0.6, duration: 0.075),SKAction.scaleTo(1.0, duration: 0.15)]))
    }
    
    
    func _doStartBgMusic() {
        if _bgMusic == nil {
            // Let's try to play a long bg music track!
            if let player = AEAudioUnitFilePlayer(audioUnitFilePlayerWithAudioController: _audCtrlr, error:nil) {
                
                // This code works, except it doesn't loop:
//                _bgMusic = player
//                _bgMusic.loadAudioFileFromUrl(NSBundle.mainBundle().URLForResource("bg_music", withExtension: "caf")) // stereo 44.1hz wav
//                _bgMusic.volume = 0.75
//                _bgMusic.removeUponFinish = false
//                _bgMusic.loop = true // ...but looping not working! See next comments:
//                _bgMusic.completionBlock = { println("completionBlock") } // this prints at the wrong time!
//                _bgMusic.startLoopBlock  = { println("startLoopBlock") } // this never seems to get called
//                _audCtrlr.addChannels([_bgMusic])
//                _bgMusic.play()
                
                // Just use a regular file player (loads everything into memory)
                var err : NSErrorPointer = nil
                _bgMusic = AEAudioFilePlayer.audioFilePlayerWithURL(NSBundle.mainBundle().URLForResource("bg_music", withExtension: "wav"), audioController: _audCtrlr, error: err) as AEAudioFilePlayer
                if _bgMusic == nil {
                    _doResetEffectSounds()
                    println("Could not load snd1 !")
                    return
                }
                _bgMusic.loop = true
                _bgMusic.volume = 0.65
                _audCtrlr.addChannels([_bgMusic])
                
                println("bgMusic playing: \(_bgMusic.channelIsPlaying)")
            }
        } else {
            _audCtrlr.removeChannels([_bgMusic])
            _bgMusic = nil
        }
    }
    
    
    // This function shows you how you can change the speed of the sound, which changes pitch too
    func _doAddNewVarispeedFilter(snd : AEAudioFilePlayer) { // you could add a "rate" parameter
        // Make an AudioUnit based filter and use the Varispeed audio unit to change pitch
        if let pitchFilter = AEAudioUnitFilter(componentDescription: AEAudioComponentDescriptionMake(
            OSType(kAudioUnitManufacturer_Apple),
            OSType(kAudioUnitType_FormatConverter),
            OSType(kAudioUnitSubType_Varispeed)),
            audioController: _audCtrlr, error:nil) {
                let status = AudioUnitSetParameter(
                    pitchFilter.audioUnit,                // inUnit : AudioUnit
                    OSType(kVarispeedParam_PlaybackRate), // inID: AudioUnitParameterID
                    OSType(kAudioUnitScope_Global),       // inScope: AudioUnitScope
                    0,                                    // inElement: AudioUnitElement
                    1.25,                                 // inValue: AudioUnitParameterValue
                    0);                                   // inBufferOffsetInFrames: UInt32
                if status == noErr {
                    _audCtrlr.addFilter(pitchFilter, toChannel: snd)
                }
        } // END if pitchFilter (Varispeed based)
    }
    
    
    // This function shows how you can change both pitch and rate independently
    func _doAddNewTimePitchFilter(snd : AEAudioFilePlayer) { // you could add 2 parameters, one for rate and one for pitch
        
        // Make an AudioUnit based filter and use the NewTimePitch audio unit to change pitch AND rate at the same time!
        if let pitchFilter = AEAudioUnitFilter(componentDescription: AEAudioComponentDescriptionMake(
            OSType(kAudioUnitManufacturer_Apple),
            OSType(kAudioUnitType_FormatConverter),
            OSType(kAudioUnitSubType_NewTimePitch)),
            audioController: _audCtrlr, error:nil) {
                
                // Random time-stretch
                var f = AudioUnitParameterValue(randomFloat()) * 0.3 // a value between 0 and 0.3
                if randomFloat() > 0.5 {
                    f *= -1.0
                }
                var status = AudioUnitSetParameter(
                    pitchFilter.audioUnit,              // inUnit : AudioUnit
                    OSType(kNewTimePitchParam_Rate),    // inID: AudioUnitParameterID
                    OSType(kAudioUnitScope_Global),     // inScope: AudioUnitScope
                    0,                                  // inElement: AudioUnitElement
                    1.0 + f,                            // inValue: AudioUnitParameterValue
                    0);                                 // inBufferOffsetInFrames: UInt32
                
                if status == noErr {
                    
                    // Random pitch
                    let i = AudioUnitParameterValue(100 + arc4random_uniform(1100)) // we could do anything from 0 to 2400
                    let randomPitch = i * AudioUnitParameterValue((randomFloat() > 0.5 ? 1 : -1))
                    status = AudioUnitSetParameter(
                        pitchFilter.audioUnit,              // inUnit : AudioUnit
                        OSType(kNewTimePitchParam_Pitch),   // inID: AudioUnitParameterID
                        OSType(kAudioUnitScope_Global),     // inScope: AudioUnitScope
                        0,                                  // inElement: AudioUnitElement
                        randomPitch,                        // inValue: AudioUnitParameterValue, +/-2400
                        0);                                 // inBufferOffsetInFrames: UInt32
                    if status == noErr {
                        _audCtrlr.addFilter(pitchFilter, toChannel: snd)
                    }
                }
        } // END if pitchFilter (NewTimePitch based)
    }
    
    
    func _doResetEffectSounds() {
        _audCtrlr.removeChannels([_snd1, _snd2])
        _snd1 = nil
        _snd2 = nil
        _snd1PanIncr = abs(_snd1PanIncr)
        _snd2PanIncr = -abs(_snd2PanIncr)
    }
    
    
    func _doStartSndEffects() {
        if _snd1 == nil {
            var err : NSErrorPointer = nil
            
            // Load sound 1
            _snd1 = AEAudioFilePlayer.audioFilePlayerWithURL(NSBundle.mainBundle().URLForResource("effect1", withExtension: "caf"), audioController: _audCtrlr, error: err) as AEAudioFilePlayer
            if _snd1 == nil {
                _doResetEffectSounds()
                println("Could not load snd1 !")
                return
            }
            _snd1.pan = -1.0
            _snd1.loop = true
            
            // Load sound 2
            _snd2 = AEAudioFilePlayer.audioFilePlayerWithURL(NSBundle.mainBundle().URLForResource("effect2", withExtension: "caf"), audioController: _audCtrlr, error: err) as AEAudioFilePlayer
            if _snd2 == nil {
                _doResetEffectSounds()
                println("Could not load snd2 !")
                return
            }
            _snd2.pan = 1.0
            _snd2.loop = true
            
            // Start the sounds playing back
            _audCtrlr.addChannels([_snd1, _snd2])
            
            // Just for fun...
            _doAddNewTimePitchFilter(_snd1) // organ "one shot" sound
            
        } else {
            // Stop playback of the looping sound effects and reset for next button press
            _doResetEffectSounds()
        }
    }
    
    
    /// EVENTS
    func uiEventStart(p : CGPoint) {
        
        if btnBgSnd.containsPoint(p) {
            if btnBgSnd.yScale > 0.99 && btnBgSnd.yScale < 1.01 { // prevents fast repeated taps
                _doBtnBoing(btnBgSnd)
                runAction(SKAction.runBlock(_doStartBgMusic))
            }
        } else if btnEffects.containsPoint(p) {
            if btnEffects.yScale > 0.99 && btnEffects.yScale < 1.01 { // prevents fast repeated taps
                _doBtnBoing(btnEffects)
                runAction(SKAction.runBlock(_doStartSndEffects))
            }
        } else {
            
            // Just some sample code from original Xcode generated project:
            let sprite = SKSpriteNode(imageNamed:"Spaceship")
            
            sprite.xScale = 0.5
            sprite.yScale = 0.5
            sprite.position = p
            
            let action = SKAction.rotateByAngle(CGFloat(M_PI) * (randomFloat() > 0.5 ? 1.0 : -1.0) , duration:0.5 + 0.5 * Double(arc4random_uniform(5)))
            
            sprite.runAction(SKAction.repeatActionForever(action))
            
            addChild(sprite)
        }
    }
    
    
#if os(iOS)
    // iPad/iPod touch/iPhone
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        /* Called when a touch begins */
        
        for touch: AnyObject in touches {
            uiEventStart(touch.locationInNode(self))
        }
    }
    
#else
    // Mac OS X
    
    override func mouseDown(theEvent: NSEvent) {
        uiEventStart(theEvent.locationInNode(self))
    }
    
#endif
} // END CLASS
