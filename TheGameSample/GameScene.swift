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
    
    var _audCtrlr : AEAudioController = audInit(nil)
//    var _bgMusic  : AEAudioUnitFilePlayer! // looping doesn't work
    var _bgMusic  : AEAudioFilePlayer! // takes more memory... keep your background sound files short, and perhaps use lower bitrate (e.g. 22050)
//    var _snd1     : AEAudioFilePlayer!
//    var _snd2     : AEAudioFilePlayer!
    
//    var _snd1PanIncr : Float = 0.066
//    var _snd2PanIncr : Float = -0.033
    
    var _samplerChannel : SamplerChannel!
    var _samplerVolume = Float(1.0)
    var _samplerPitch  = Float(0.0)
    var _samplerPitchIncr = Float(0.1)
    var _samplerPan    = Float(1.0)
    var _samplerPanIncr = Float(-0.05)
    
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
        
        // Preload audio
        _samplerChannel = audLoadEffect(NSBundle.mainBundle().pathForResource("effect1", ofType: "caf"), 1.0, 0.0, false)
        
        // TEST
        audLoadAmbience(NSBundle.mainBundle().pathForResource("HiQualityMix96.7", ofType: "wav"), 1.0, 0.0, 0)
        
        // on iOS let's let the user know to use headphones to be able to hear the panning effects
//        #if os(iOS)
//            runAction(SKAction.sequence([SKAction.waitForDuration(0.65), SKAction.runBlock({
//                let alertView = UIAlertView(title: "Tip of the Day", message: "To hear the panning effect, use headphones!\n\nThe pitch and rate are being set randomly but only on one sound effect (the organ); see the source code for more information.", delegate: nil, cancelButtonTitle: "OK")
//                alertView.show()
//            })]))
//        #endif
    }
    
    
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        
//        if _samplerVolume > 0.0 && _samplerChannel != nil {
//            
//            // Volume
//            _samplerVolume -= 0.01
//            audMidiControlChange(_samplerChannel.audioUnit, 7, max(0,Int32(127 * _samplerVolume)))
//            
//            // Pan
//            _samplerPan = max(0.0,min(1.0, _samplerPan + _samplerPanIncr))
//            if _samplerPan <= 0 || _samplerPan >= 1.0 {
//                _samplerPanIncr *= -1.0
//            }
//            audMidiControlChange(_samplerChannel.audioUnit, 10, max(0,Int32(127 * _samplerPan)))
//            
//            // Pitch
//            _samplerPitch = max(0.0,min(1.0, _samplerPitch + _samplerPitchIncr))
//            if _samplerPitch <= 0.0 || _samplerPitch >= 1.0 {
//                _samplerPitchIncr *= -1.0
//            }
//            audMidiPitchBend(_samplerChannel.audioUnit, max(1, Int16(126 * _samplerPitch)))
//            
//            
//            if _samplerVolume <= 0 {
//                // Hacked reset for TESTING
//                let chnl = _samplerChannel
//                _samplerChannel = nil
//                _samplerVolume = 1.0
//                runAction(SKAction.sequence([SKAction.waitForDuration(0.1),SKAction.runBlock({self._audCtrlr.removeChannels([chnl])})]))
//            }
//        }
        
        
        // Just playing around a bit: this tests out panning the effects independently of each other (useful for game sound effects)
//        if _snd1 != nil {
//            _snd1.pan += _snd1PanIncr
//            if _snd1.pan > 0.99 || _snd1.pan < -0.99 { _snd1PanIncr *= -1.0 }
//            
//            _snd2.pan += _snd2PanIncr
//            if _snd2.pan > 0.99 || _snd2.pan < -0.99 { _snd2PanIncr *= -1.0 }
//        }
    }
    
    
    func _doBtnBoing(btn : SKLabelNode) {
        btn.removeAllActions()
        btn.setScale(1.0)
        SKAction.scaleXTo(0.8, y: 0.6, duration: 0.75)
        btn.runAction(SKAction.sequence([SKAction.scaleXTo(0.9, y: 0.6, duration: 0.075),SKAction.scaleTo(1.0, duration: 0.15)]))
    }
    
    
    func _doStartBgMusic() {
        if _bgMusic == nil {
            // There is an unsupported "AEAudioUnitFilePlayer.h" you can use, but looping doesn't seem to loop and the loop completion callback gets called at what seems to be the wrong time.  So, for no I've converted this function to use a regular file player.  This unfortunately loads everything into memory, so keep these tracks short even if using a compressed format - it still takes the same memory as an uncompressed format.
            var err : NSErrorPointer = nil
            _bgMusic = AEAudioFilePlayer.audioFilePlayerWithURL(NSBundle.mainBundle().URLForResource("bg_music", withExtension: "wav"), audioController: _audCtrlr, error: err) as AEAudioFilePlayer
            if _bgMusic == nil {
                println("Could not load bgMusic !")
                return
            }
            _bgMusic.loop = true
            _bgMusic.volume = 0.65
            _audCtrlr.addChannels([_bgMusic])
            
            println("bgMusic playing: \(_bgMusic.channelIsPlaying)")
        } else {
            _audCtrlr.removeChannels([_bgMusic])
            _bgMusic = nil
        }
    }
    
    
//    func playSound( filename : String ) {
//        audPlay(NSBundle.mainBundle().pathForResource(filename, ofType: "caf"))
//    }
    
    
    /// EVENTS
    func uiEventStart(p : CGPoint) {
        
        if btnBgSnd.containsPoint(p) {
            if btnBgSnd.yScale > 0.99 && btnBgSnd.yScale < 1.01 { // prevents fast repeated taps
                _doBtnBoing(btnBgSnd)
//                runAction(SKAction.runBlock(_doStartBgMusic))
                runAction(SKAction.runBlock({
                    self._samplerChannel = nil
                    self._samplerVolume = 1.0
                    self._samplerPitch = 0.0
                    self._audCtrlr.removeChannels(self._audCtrlr.channels())
                }))
            }
        } else if btnEffects.containsPoint(p) {
//            if btnEffects.yScale > 0.99 && btnEffects.yScale < 1.01 { // prevents fast repeated taps
                _doBtnBoing(btnEffects)
//                let filename = "effect1"//randomFloat() > 0.5 ? "effect1" : "effect2"
//                _samplerChannel = audPlay(NSBundle.mainBundle().pathForResource(filename, ofType: "caf"))
                runAction(SKAction.runBlock({ audPlayEffect(self._samplerChannel, 1.0) }))
                
                // The let a= works around Swift bug with a C func that returns something.
//                runAction(SKAction.runBlock({ let a=audPlay(NSBundle.mainBundle().pathForResource(filename, ofType: "caf"))?; }))
//            }
        } else {
            
            // Just some sample code from original Xcode generated project:
//            let sprite = SKSpriteNode(imageNamed:"Spaceship")
//            
//            sprite.xScale = 0.5
//            sprite.yScale = 0.5
//            sprite.position = p
//            
//            let action = SKAction.rotateByAngle(CGFloat(M_PI) * (randomFloat() > 0.5 ? 1.0 : -1.0) , duration:0.5 + 0.5 * Double(arc4random_uniform(5)))
//            
//            sprite.runAction(SKAction.repeatActionForever(action))
//            
//            addChild(sprite)
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
