//
//  SPJuggler.h
//  Sparrow
//
//  Created by Daniel Sperl on 09.05.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import "SPAnimatable.h"
#import "SPMacros.h"

/** ------------------------------------------------------------------------------------------------

 The SPJuggler takes objects that implement SPAnimatable (e.g. `SPTween`s) and executes them.
 
 A juggler is a simple object. It does no more than saving a list of objects implementing 
 `SPAnimatable` and advancing their time if it is told to do so (by calling its own `advanceTime:`
 method). Furthermore, an object can request to be removed from the juggler by dispatching an
 `SPEventTypeRemoveFromJuggler` event.
 
 There is a default juggler that you can access from anywhere with the following code:
 
	SPJuggler *juggler = Sparrow.juggler;
 
 You can, however, create juggler objects yourself, too. That way, you can group your game 
 into logical components that handle their animations independently.
 
 A cool feature of the juggler is to delay method calls. Say you want to remove an object from its
 parent 2 seconds from now. Call:

	[[juggler delayInvocationAtTarget:object byTime:2.0] removeFromParent];
 
 This line of code will execute the following method 2 seconds in the future:

 	[object removeFromParent];
 
 Alternatively, you can use the block-based verson of the method:

	[juggler delayInvocationByTime:2.0 block:^{ [object removeFromParent]; };

------------------------------------------------------------------------------------------------- */

@interface SPJuggler : NSObject <SPAnimatable>

/// ------------------
/// @name Initializers
/// ------------------

/// Factory method.
+ (instancetype)juggler;

/// -------------
/// @name Methods
/// -------------

/// Adds an object to the juggler.
- (void)addObject:(id<SPAnimatable>)object;

/// Removes an object from the juggler.
- (void)removeObject:(id<SPAnimatable>)object;

/// Removes all objects at once.
- (void)removeAllObjects;

/// Removes all objects with a `target` property referencing a certain object (e.g. tweens or
/// delayed invocations).
- (void)removeObjectsWithTarget:(id)object;

/// Determines if an object has been added to the juggler.
- (BOOL)containsObject:(id<SPAnimatable>)object;

/// Delays the execution of a certain method. Returns a proxy object on which to call the method
/// instead. Execution will be delayed until `time` has passed.
- (id)delayInvocationAtTarget:(id)target byTime:(double)time;

/// Delays the execution of a block by a certain time in seconds.
- (id)delayInvocationByTime:(double)time block:(SPCallbackBlock)block;

/// ----------------
/// @name Properties
/// ----------------

/// The total life time of the juggler.
@property (nonatomic, readonly) double elapsedTime;

/// The speed factor adjusts how fast a juggler's animatables run.
/// For example, a speed factor of 2.0 means the juggler runs twice as fast.
@property (nonatomic, assign) double speed;

@end
