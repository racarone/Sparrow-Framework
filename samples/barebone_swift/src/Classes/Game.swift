//
//  Game.swift
//

import Foundation

class Game : SPSprite {

    override init() {
        super.init()

        // This is where the code of your game will start;
        // in this sample, we add just a simple quad to see if it works.

        var quad = SPQuad(width: 100, height: 100, color: SPColorRed)
        quad.x = 50
        quad.y = 50
        addChild(quad)

        // Per default, this project compiles as an universal application. To change that, enter the
        // project info screen, and in the "General"-tab, find the setting "Deployment Info".
        //
        // Now choose the right setting in the "Devices" dropdown:
        //
        //   * iPhone      -> iPhone only App
        //   * iPad        -> iPad only App
        //   * iPhone/iPad -> Universal App
        //
        // The "Deployment target" setting must be at least "iOS 5.0" for Sparrow 2.
        // Always use the latest available version as the base SDK.
    }

}