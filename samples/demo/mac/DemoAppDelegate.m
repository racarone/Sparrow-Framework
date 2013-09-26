//
//  AppDelegate.m
//  Demo
//
//  Created by Robert Carone on 9/25/13.
//  Copyright (c) 2013 Gamua. All rights reserved.
//

#import "DemoAppDelegate.h"
#import "Sparrow.h"

// --- c functions ---

void onUncaughtException(NSException* exception)
{
	NSLog(@"uncaught exception: %@", exception.description);
}

// ---

@implementation DemoAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSSetUncaughtExceptionHandler(&onUncaughtException);

}

@end
