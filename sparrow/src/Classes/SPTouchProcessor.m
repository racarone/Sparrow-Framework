//
//  SPTouchProcessor.m
//  Sparrow
//
//  Created by Daniel Sperl on 03.05.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPTouchProcessor.h"
#import "SPMacros.h"
#import "SPTouchEvent.h"
#import "SPTouch.h"
#import "SPTouch_Internal.h"
#import "SPPoint.h"
#import "SPMatrix.h"
#import "SPDisplayObjectContainer.h"

#import <UIKit/UIKit.h>

#define MULTITAP_TIME 0.25f
#define MULTITAP_DIST 25

@implementation SPTouchProcessor
{
    SPDisplayObjectContainer *__weak _root;
    NSMutableSet *_currentTouches;
}

- (instancetype)initWithRoot:(SPDisplayObjectContainer *)root
{
    if ((self = [super init]))
    {
        _root = root;
        _currentTouches = [[NSMutableSet alloc] initWithCapacity:2];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelCurrentTouches:)
                                              name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}

- (instancetype)init
{    
    return [self initWithRoot:nil];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_currentTouches release];
    [super dealloc];
}

- (void)processTouches:(NSSet *)touches
{
    NSMutableSet *processedTouches = [[NSMutableSet alloc] init];
    
    // process new touches
    for (SPTouch *touch in touches)
    {
        SPTouch *currentTouch = nil;
        
        for (SPTouch *existingTouch in _currentTouches)
        {
            if (existingTouch.phase == SPTouchPhaseEnded || existingTouch.phase == SPTouchPhaseCancelled)
                continue;
            
            if (existingTouch.nativeTouch == touch.nativeTouch)
            {
                // existing touch; update values
                existingTouch.timestamp = touch.timestamp;
                existingTouch.previousGlobalX = touch.previousGlobalX;
                existingTouch.previousGlobalY = touch.previousGlobalY;
                existingTouch.globalX = touch.globalX;
                existingTouch.globalY = touch.globalY;
                existingTouch.phase = touch.phase;
                existingTouch.tapCount = touch.tapCount;
                
                if (!existingTouch.target.stage)
                {
                    // target could have been removed from stage -> find new target in that case
                    SPPoint *touchPosition = [SPPoint pointWithX:touch.globalX y:touch.globalY];
                    existingTouch.target = [_root hitTestPoint:touchPosition];       
                }
                
                currentTouch = existingTouch;
                break;
            }
        }
        
        if (!currentTouch) // new touch
        {
            SPPoint *touchPosition = [SPPoint pointWithX:touch.globalX y:touch.globalY];
            touch.target = [_root hitTestPoint:touchPosition];
            currentTouch = touch;
        }
        
        [processedTouches addObject:currentTouch];
    }
    
    // dispatch events         
    for (SPTouch *touch in processedTouches)
    {       
        SPTouchEvent *touchEvent = [[SPTouchEvent alloc] initWithType:SPEventTypeTouch 
                                                              touches:processedTouches];
        [touch.target dispatchEvent:touchEvent];
        [touchEvent release];
    }

    SP_RELEASE_AND_RETAIN(_currentTouches, processedTouches);
    [processedTouches release];
}

- (void)cancelCurrentTouches:(NSNotification *)notification
{
    double now = CACurrentMediaTime();
    
    for (SPTouch *touch in _currentTouches)
    {
        touch.phase = SPTouchPhaseCancelled;
        touch.timestamp = now;
    }

    for (SPTouch *touch in _currentTouches)
    {
        SPTouchEvent *touchEvent = [[SPTouchEvent alloc] initWithType:SPEventTypeTouch
                                                              touches:_currentTouches];
        [touch.target dispatchEvent:touchEvent];
        [touchEvent release];
    }

    [_currentTouches removeAllObjects];
}

@end
