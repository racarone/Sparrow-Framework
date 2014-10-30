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
#import <Sparrow/SPMacros.h>

/** A wrapper class for a CADisplayLink or CVDisplayLink object. */

@interface SPDisplayLink : NSObject

/// ------------------
/// @name Initializers
/// ------------------

/// Initializes a display link which will execute the block on the specified queue each frame.
- (instancetype)initWithQueue:(dispatch_queue_t)queue block:(SPCallbackBlock)block;

/// Initializes a display link which will execute the block on the main queue each frame.
- (instancetype)initWithBlock:(SPCallbackBlock)block;

/// ----------------
/// @name Properties
/// ----------------

/// When YES the display link is prevented from firing. (default: YES)
@property (nonatomic, assign) BOOL paused;

/// Determines whether or not the display link calls it's execution block asynchronously. (default: NO)
@property (nonatomic, assign) BOOL asynchronous;

/// Defines how many display frames must pass between each time the display link fires. (default: 1)
@property (nonatomic, assign) int frameInterval;

/// The maximum amount of frames that will be queued before skipping frames. (default: 3)
@property (nonatomic, assign) int maxQueuedFrameCount;

/// The time value associated with the last frame that was displayed.
@property (nonatomic, readonly) double timestamp;

/// The time interval between screen refresh updates.
@property (nonatomic, readonly) double duration;

/// Returns the average frame time calculated over 4 frames.
@property (nonatomic, readonly) float averageFrameTime;

@end
