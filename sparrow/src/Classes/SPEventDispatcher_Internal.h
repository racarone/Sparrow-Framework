//
//  SPEventDispatcher_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 10/7/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPEventDispatcher.h"

@class SPEventListener;

@interface SPEventDispatcher (Internal)

- (void)addEventListener:(SPEventListener *)listener forType:(NSString *)eventType;
- (void)removeEventListenersForType:(NSString *)eventType withTarget:(id)object andSelector:(SEL)selector orBlock:(SPEventBlock)block;

@end
