//
//  Game.swift
//  Scaffold
//
//  Ported from Media.h/m in non-Swift project
//

import Foundation

class Game : SPSprite {
    
    var _contents: SPSprite!

    override init() {
        super.init()
        setup()
    }
    
    deinit {
        // release any resources here
        Media.releaseAtlas()
        Media.releaseSound()
    }
    
    func setup() {
        // This is where the code of your game will start.
        // In this sample, we add just a few simple elements to get a feeling about how it's done.
        
        SPAudioEngine.start()  // starts up the sound engine
        
        // The Application contains a very handy "Media" class which loads your texture atlas
        // and all available sound files automatically. Extend this class as you need it --
        // that way, you will be able to access your textures and sounds throughout your
        // application, without duplicating any resources.
        
        Media.initAtlas()      // loads your texture atlas -> see Media.h/Media.m
        Media.initSound()      // loads all your sounds    -> see Media.h/Media.m
        
        // Create some placeholder content: a background image, the Sparrow logo, and a text field.
        // The positions are updated when the device is rotated. To make that easy, we put all objects
        // in one sprite (_contents): it will simply be rotated to be upright when the device rotates.
        
        _contents = SPSprite()
        self.addChild(_contents)
        
        let background = SPImage(contentsOfFile: "background.jpg")
        _contents.addChild(background)

        let text = "To find out how to create your own game out of this scaffold, " +
                   "have a look at the 'First Steps' section of the Sparrow website!"
        
        let textField = SPTextField(width: 280, height: 80, text: text)
        textField.x = (background.width - textField.width) / 2
        textField.y = (background.height / 2) - 135
        _contents.addChild(textField)
        
        let image = SPImage(texture: Media.atlasTexture("sparrow"))
        image.pivotX = Float(Int(image.width  / 2))
        image.pivotY = Float(Int(image.height / 2))
        image.x = background.width  / 2
        image.y = background.height / 2 + 40
        _contents.addChild(image)
        
        self.updateLocations()
        
        // play a sound when the image is touched
        image.addEventListener("onImageTouched:", atObject: self, forType: SPEventTypeTouch)
        
        // and animate it a little
        Sparrow.juggler().tweenWithTarget(image, time: 1.5, properties: [
                "transition"  : SPTransitionEaseInOut,
                "repeatCount" : 1,
                "reverse"     : true,
                "y"           : image.y + 30,
                "rotation"    : 0.1
            ]);
        
        // The controller autorotates the game to all supported device orientations.
        // Choose the orienations you want to support in the Xcode Target Settings ("Summary"-tab).
        // To update the game content accordingly, listen to the "RESIZE" event; it is dispatched
        // to all game elements (just like an ENTER_FRAME event).
        //
        // To force the game to start up in landscape, add the key "Initial Interface Orientation"
        // to the "App-Info.plist" file and choose any landscape orientation.

        self.addEventListener("onResize:", atObject: self, forType: SPEventTypeResize)
        
        // Per default, this project compiles as a universal application. To change that, enter the
        // project info screen, and in the "Build"-tab, find the setting "Targeted device family".
        //
        // Now choose:
        //   * iPhone      -> iPhone only App
        //   * iPad        -> iPad only App
        //   * iPhone/iPad -> Universal App
        //
        // Sparrow's minimum deployment target is iOS 5.
    }
    
    func updateLocations() {
        let gameWidth  = Sparrow.stage().width
        let gameHeight = Sparrow.stage().height

        _contents.x = Float(Int((gameWidth  - _contents.width ) / 2))
        _contents.y = Float(Int((gameHeight - _contents.height) / 2))
    }
    
    func onImageTouched(event: SPTouchEvent) {
        let touches = event.touchesWithTarget(self, andPhase: SPTouchPhase.Ended)
        if touches.anyObject() != nil {
            Media.playSound("sound.caf")
        }
    }
    
    func onResize(event: SPResizeEvent) {
        NSLog("new size: %.0fx%.0f (%@)", event.width, event.height,
              event.isPortrait ? "portrait" : "landscape")
        self.updateLocations()
    }
}