//
//  AppDelegate.swift
//  Scaffold
//
//  Ported from Media.h/m in non-Swift project
//

import Foundation
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var _viewController: SPViewController!
    var _window: UIWindow!
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: NSDictionary?) -> Bool {

        _window = UIWindow(frame: UIScreen.mainScreen().bounds)
        _viewController = SPViewController()

        _viewController.showStats = true;
        _viewController.startWithRoot(Game.self, supportHighResolutions: true, doubleOnPad: true)
        
        _window.rootViewController = _viewController
        _window.makeKeyAndVisible()
        
        return true;
    }
}