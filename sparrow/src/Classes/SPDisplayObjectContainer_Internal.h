//
//  SPDisplayObjectContainer_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 9/23/13.
//
//

#import "SPDisplayObjectContainer.h"

@interface SPDisplayObjectContainer (Internal)

- (void)getChildEventListeners:(SPDisplayObject*)object eventType:(NSString*)type listeners:(NSMutableArray*)listeners;

@end
