//
//  SPEventDispatcher_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 9/23/13.
//
//

#import "SPEventDispatcher.h"

@class SPEventListener;

@interface SPEventDispatcher (Internal)

- (void)addEventListener:(SPEventListener*)listener forType:(NSString*)eventType;
- (void)removeEventListenersForType:(NSString*)eventType withTarget:(id)object andSelector:(SEL)selector orBlock:(SPEventBlock)block;

@end
