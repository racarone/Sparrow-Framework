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

#import "SPDisplayObjectContainer.h"
#import "SPMacros.h"
#import "SPMatrix.h"
#import "SPPoint.h"
#import "SPTouch.h"
#import "SPTouch_Internal.h"
#import "SPTouchEvent.h"
#import "SPTouchProcessor.h"

#ifdef SP_TARGET_IPHONE
    #import <UIKit/UIKit.h>
#else
    #import <Cocoa/Cocoa.h>
    #define UIApplicationWillResignActiveNotification NSApplicationWillResignActiveNotification
#endif

@implementation SPTouchProcessor
{
    SPDisplayObjectContainer*   _root;
    NSMutableSet*               _currentTouches;
}

@synthesize root = _root;

- (instancetype)initWithRoot:(SPDisplayObjectContainer*)root
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
    SP_RELEASE_AND_NIL(_currentTouches);
    [super dealloc];
}

- (void)processTouches:(NSSet*)touches
{
    NSMutableSet* processedTouches = [NSMutableSet set];
    
    // process new touches
    for (SPTouch* touch in touches)
    {
        SPTouch* currentTouch = nil;
        
        for (SPTouch* existingTouch in _currentTouches)
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
                    SPPoint* touchPosition = [SPPoint pointWithX:touch.globalX y:touch.globalY];
                    existingTouch.target = [_root hitTestPoint:touchPosition];       
                }
                
                currentTouch = existingTouch;
                break;
            }
        }
        
        if (!currentTouch) // new touch
        {
            SPPoint* touchPosition = [SPPoint pointWithX:touch.globalX y:touch.globalY];
            touch.target = [_root hitTestPoint:touchPosition];
            currentTouch = touch;
        }
        
        [processedTouches addObject:currentTouch];
    }
    
    // dispatch events         
    for (SPTouch* touch in processedTouches)
    {       
        SPTouchEvent* touchEvent = [[[SPTouchEvent alloc] initWithType:kSPEventTypeTouch touches:processedTouches] autorelease];
        [touch.target dispatchEvent:touchEvent];
    }

    [_currentTouches release];
    _currentTouches = [processedTouches retain];
}

- (void)cancelCurrentTouches:(NSNotification*)notification
{
    double now = CACurrentMediaTime();

    for (SPTouch* touch in _currentTouches)
    {
        touch.phase = SPTouchPhaseCancelled;
        touch.timestamp = now;
    }

    for (SPTouch* touch in _currentTouches)
        [touch.target dispatchEvent:[SPTouchEvent eventWithType:kSPEventTypeTouch touches:_currentTouches]];

    [_currentTouches removeAllObjects];
}

@end
