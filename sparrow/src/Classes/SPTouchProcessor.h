//
//  SPTouchProcessor.h
//  Sparrow
//
//  Created by Daniel Sperl on 03.05.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>

@class SPDisplayObjectContainer;
@class SPStage;
@class SPTouch;

/** ------------------------------------------------------------------------------------------------

 The SPTouchProcesser processes raw touch information and dispatches it on display objects.

 _This is an internal class. You do not have to use it manually._

 ------------------------------------------------------------------------------------------------- */

@interface SPTouchProcessor : NSObject

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a touch processor with a certain root object.
- (instancetype)initWithStage:(SPStage *)stage;

/// -------------
/// @name Methods
/// -------------

/// Analyzes the current touch queue and processes the list of current touches, emptying
/// the queue while doing so. This method is called by Sparrow once per frame.
- (void)advanceTime:(double)seconds;

/// Enqueues a new touch.
- (void)enqueueTouch:(SPTouch *)touch;

/// ----------------
/// @name Properties
/// ----------------

/// The root display container to check for touched targets.
@property (nonatomic, weak) SPStage *stage;

/// The base object that will be used for hit testing. Per default, this reference points
/// to the stage; however, you can limit touch processing to certain parts of your game
/// by assigning a different object.
@property (nonatomic, strong) SPDisplayObject *root;

/// The time period (in seconds) in which two touches must occur to be recognized as
/// a multitap gesture.
@property (nonatomic, assign) double multitapTime;

/// The distance (in points) describing how close two touches must be to each other to
/// be recognized as a multitap gesture.
@property (nonatomic, assign) float multitapDistance;

/// Returns the number of fingers or touch points that are currently on the stage.
@property (nonatomic, readonly) int numCurrentTouches;

@end
