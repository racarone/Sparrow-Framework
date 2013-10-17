//
//  SPStage_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 10/7/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPStage.h"

@interface SPStage (Internal)

- (void)advanceTime:(double)passedTime;
- (void)addEnterFrameListener:(SPDisplayObject *)listener;
- (void)removeEnterFrameListener:(SPDisplayObject *)listener;

@end
