//
//  SPDisplayLink.h
//  Sparrow
//
//  Created by Robert Carone on 2/5/14.
//  Copyright 2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import "SPMacros.h"

typedef NS_ENUM(uint, SPDisplayLinkMode)
{
    SPDisplayLinkModeLink,
    SPDisplayLinkModeTimer
};

typedef void (^SPDisplayLinkBlock)(double frameTime);

/** Class representing a timer bound to the display vsync depending on it's mode. **/

@interface SPDisplayLink : NSObject

/// ------------------
/// @name Initializers
/// ------------------

/// Initializes a display link which will run the block on the specified queue. _Designated Initializer_
- (instancetype)initWithQueue:(dispatch_queue_t)queue block:(SPDisplayLinkBlock)block;

/// Initializes a display link which will run the block on the main queue.
- (instancetype)initWithBlock:(SPDisplayLinkBlock)block;

/// Factory method.
+ (instancetype)displayLinkWithQueue:(dispatch_queue_t)queue block:(SPDisplayLinkBlock)block;

/// Factory method.
+ (instancetype)displayLinkWithBlock:(SPDisplayLinkBlock)block;

/// ----------------
/// @name Properties
/// ----------------

/// When YES the display link is prevented from firing. (default: YES)
@property (nonatomic, assign) BOOL paused;

/// Determines whether or not the display link calls it's execution block asynchronously. (default: NO)
@property (nonatomic, assign) BOOL asynchronous;

/// The current mode this display link uses. (default: SPDisplayLinkModeLink)
@property (nonatomic, assign) SPDisplayLinkMode mode;

/// Defines how many display frames must pass between each time the display link fires. (default: 1)
@property (nonatomic, assign) int frameInterval;

/// The maximum amount of frames that will be queued before skipping frames. (default: 3)
@property (nonatomic, assign) int maxQueuedFrameCount;

@end
