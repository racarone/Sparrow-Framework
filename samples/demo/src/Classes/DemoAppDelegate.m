//
//  DemoAppDelegate.m
//  Demo
//
//  Created by Daniel Sperl on 25.07.09.
//  Copyright 2011 Gamua. All rights reserved.
//

#import "DemoAppDelegate.h"
#import "Game.h"
#import "Sparrow.h"

#import "SPNSExtensions.h"

// --- c functions ---

void onUncaughtException(NSException *exception) 
{
	NSLog(@"uncaught exception: %@", exception.description);
}

// ---

@implementation DemoAppDelegate
{
    UIWindow *_window;
    SPViewController *_viewController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
{
    NSSetUncaughtExceptionHandler(&onUncaughtException);
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    _window = [[UIWindow alloc] initWithFrame:screenBounds];
    
    [SPAudioEngine start];
    
    _viewController = [[SPViewController alloc] init];
    _viewController.multitouchEnabled = YES;
    _viewController.preferredFramesPerSecond = 60;
    [_viewController startWithRoot:[Game class] supportHighResolutions:YES doubleOnPad:YES];
    
    [_window setRootViewController:_viewController];
    [_window makeKeyAndVisible];
    
    // What follows is a very simply approach to support the iPad:
    // we just center the stage on the screen!
    //
    // (Beware: to support autorotation, this would need a little more work.)
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        _viewController.view.frame = CGRectMake(64, 32, 640, 960);
        _viewController.stage.width = 320;
        _viewController.stage.height = 480;
    }
    
    return YES;
}

@end
