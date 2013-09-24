//
//  SPStage_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 9/23/13.
//
//

#import "SPStage.h"

@interface SPStage (Internal)

- (void)addEnterFrameListener:(SPDisplayObject*)listener;
- (void)removeEnterFrameListener:(SPDisplayObject*)listener;

@end
