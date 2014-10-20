//
//  SPEvent_Internal.h
//  Sparrow
//
//  Created by Daniel Sperl on 03.05.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPEvent.h>

@interface SPEvent ()

@property (nonatomic, weak) SPEventDispatcher *target;
@property (nonatomic, weak) SPEventDispatcher *currentTarget;
@property (nonatomic, strong) id data;
@property (nonatomic, readonly) BOOL stopsPropagation;
@property (nonatomic, readonly) BOOL stopsImmediatePropagation;

@end

