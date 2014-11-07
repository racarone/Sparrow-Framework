//
//  SPTouchProcessor.m
//  Sparrow
//
//  Created by Daniel Sperl on 03.05.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPDisplayObjectContainer.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPStage.h>
#import <Sparrow/SPTouch.h>
#import <Sparrow/SPTouchEvent.h>
#import <Sparrow/SPTouchProcessor.h>
#import <Sparrow/SPTouch_Internal.h>

#import <UIKit/UIKit.h>

#define MULTITAP_TIME 0.3f
#define MULTITAP_DIST 25.0f

// --- helper class  -------------------------------------------------------------------------------

@interface SPHoverData : SPPoolObject

@property (nonatomic, assign) SPTouch *touch;
@property (nonatomic, assign) SPDisplayObject *target;

@end

@implementation SPHoverData
{
    SPTouch *__weak _touch;
    SPDisplayObject *__weak _target;
}

- (instancetype)initWithTouch:(SPTouch *)touch
{
    if (self = [super init])
    {
        _touch = touch;
        _target = touch.target;
    }

    return self;
}

+ (instancetype)dataWithTouch:(SPTouch *)touch
{
    return [[[self alloc] initWithTouch:touch] autorelease];
}

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPTouchProcessor
{
    SPStage *__weak _stage;
    SPDisplayObject *_root;

    NSMutableOrderedSet *_currentTouches;
    NSMutableOrderedSet *_updatedTouches;
    NSMutableArray *_hoveringTouches;
    NSMutableArray *_queuedTouches;
    NSMutableArray *_lastTaps;

    double _lastTouchTimestamp;
    double _elapsedTime;
    double _multitapTime;
    float _multitapDistance;
}

#pragma mark Initialization

- (instancetype)initWithStage:(SPStage *)stage
{
    if ((self = [super init]))
    {
        _root = _stage = [stage retain];
        _multitapTime = MULTITAP_TIME;
        _multitapDistance = MULTITAP_DIST;
        _currentTouches = [[NSMutableOrderedSet alloc] init];
        _updatedTouches = [[NSMutableOrderedSet alloc] init];
        _hoveringTouches = [[NSMutableArray alloc] init];
        _queuedTouches = [[NSMutableArray alloc] init];
        _lastTaps = [[NSMutableArray alloc] init];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelCurrentTouches:)
			name:UIApplicationWillResignActiveNotification object:nil];
    }

    return self;
}

- (instancetype)init
{
    return [self initWithStage:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_currentTouches release];
    [_updatedTouches release];
    [_queuedTouches release];
    [_hoveringTouches release];
    [_lastTaps release];
    [_root release];

    [super dealloc];
}

#pragma mark Methods

- (void)advanceTime:(double)seconds
{
    _elapsedTime += seconds;

    if (_lastTaps.count)
    {
        NSMutableArray *remainingTaps = [NSMutableArray array];

        for (SPTouch *touch in _lastTaps)
            if (_elapsedTime - touch.timestamp <= _multitapTime)
                [remainingTaps addObject:touch];

        SP_RELEASE_AND_RETAIN(_lastTaps, remainingTaps);
    }

    if (_queuedTouches.count)
    {
        for (SPTouch *touch in _currentTouches)
            if (touch.phase == SPTouchPhaseBegan || touch.phase == SPTouchPhaseMoved)
                touch.phase = SPTouchPhaseStationary;

        for (SPTouch *touch in _queuedTouches)
            [_updatedTouches addObject:[self createOrUpdateTouch:touch]];

        [self processTouches:_updatedTouches];
        [_updatedTouches removeAllObjects];

        NSMutableOrderedSet *remainingTouches = [NSMutableOrderedSet orderedSet];
        for (SPTouch *touch in _currentTouches)
            if (touch.phase != SPTouchPhaseEnded && touch.phase != SPTouchPhaseCancelled)
                [remainingTouches addObject:touch];

        SP_RELEASE_AND_RETAIN(_currentTouches, remainingTouches);
        [_queuedTouches removeAllObjects];
    }
}

- (void)enqueueTouch:(SPTouch *)touch
{
    [_queuedTouches addObject:touch];
}

#pragma mark Properties

- (int)numCurrentTouches
{
    return (int)_currentTouches.count;
}

#pragma mark Process Touches

- (void)processTouches:(NSMutableOrderedSet *)touches
{
    // the same touch event will be dispatched to all targets
    SPTouchEvent *touchEvent = [[SPTouchEvent alloc]
                                initWithType:SPEventTypeTouch touches:_currentTouches.set];

    // hit test our updated touches
    for (SPTouch *touch in touches)
    {
        // hovering touches need special handling (see below)
        if (touch.phase == SPTouchPhaseHover && touch.target)
            [_hoveringTouches addObject:[SPHoverData dataWithTouch:touch]];

        if (touch.phase == SPTouchPhaseHover || touch.phase == SPTouchPhaseBegan)
        {
            SPPoint *touchPosition = [SPPoint pointWithX:touch.globalX y:touch.globalY];
            touch.target = [_root hitTestPoint:touchPosition];
        }
    }

    // if the target of a hovering touch changed, we dispatch the event to the previous
    // target to notify it that it's no longer being hovered over.
    for (SPHoverData *hoverData in _hoveringTouches)
        if (hoverData.target != hoverData.touch.target)
            [hoverData.target dispatchEvent:touchEvent];

    [_hoveringTouches removeAllObjects];

    // dispatch events for the rest of our updated touches
    for (SPTouch *touch in touches)
        [touch.target dispatchEvent:touchEvent];

    [touchEvent release];
}

- (void)cancelCurrentTouches:(NSNotification *)notification
{
    double now = CACurrentMediaTime();

    // remove touches that have already ended / were already canceled
    [_currentTouches filterUsingPredicate:
     [NSPredicate predicateWithBlock:^BOOL(SPTouch *touch, NSDictionary *bindings)
      {
          return touch.phase != SPTouchPhaseEnded && touch.phase != SPTouchPhaseCancelled;
      }]];

    for (SPTouch *touch in _currentTouches)
    {
        touch.phase = SPTouchPhaseCancelled;
        touch.timestamp = now;
    }

    for (SPTouch *touch in _currentTouches)
    {
        SPTouchEvent *touchEvent = [[SPTouchEvent alloc] initWithType:SPEventTypeTouch
                                                              touches:_currentTouches.set];
        [touch.target dispatchEvent:touchEvent];
        [touchEvent release];
    }

    [_currentTouches removeAllObjects];
}

#pragma mark Update Touches

- (SPTouch *)createOrUpdateTouch:(SPTouch *)touch
{
    SPTouch *currentTouch = [self currentTouchWithID:touch.touchID];
    if (!currentTouch)
    {
        currentTouch = [SPTouch touchWithID:touch.touchID];
        [_currentTouches addObject:currentTouch];
    }

    currentTouch.globalX = touch.globalX;
    currentTouch.globalY = touch.globalY;
    currentTouch.previousGlobalX = touch.previousGlobalX;
    currentTouch.previousGlobalY = touch.previousGlobalY;
    currentTouch.phase = touch.phase;
    currentTouch.timestamp = _elapsedTime;

    if (currentTouch.phase == SPTouchPhaseBegan)
        [self updateTapCount:currentTouch];

    return currentTouch;
}

- (void)updateTapCount:(SPTouch *)touch
{
    SPTouch *nearbyTap = nil;
    float minSqDist = SP_SQUARE(_multitapDistance);

    for (SPTouch *tap in _lastTaps)
    {
        float sqDist = powf(tap.globalX - tap.globalY,   2) +
                       powf(tap.globalX - touch.globalY, 2);

        if (sqDist <= minSqDist)
            nearbyTap = tap;
    }

    if (nearbyTap)
    {
        touch.tapCount = nearbyTap.tapCount + 1;
        [_lastTaps removeObject:nearbyTap];
    }
    else
    {
        touch.tapCount = 1;
    }

    [_lastTaps addObject:[[touch copy] autorelease]];
}

#pragma mark Current Touches

- (SPTouch *)currentTouchWithID:(size_t)touchID
{
    for (SPTouch *touch in _currentTouches)
        if (touch.touchID == touchID)
            return touch;
    
    return nil;
}

@end
