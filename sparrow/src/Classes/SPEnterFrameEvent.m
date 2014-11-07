//
//  SPEnterFrameEvent.m
//  Sparrow
//
//  Created by Daniel Sperl on 30.04.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPEnterFrameEvent.h"

NSString *const SPEventTypeEnterFrame = @"SPEventTypeEnterFrame";

@implementation SPEnterFrameEvent
{
    double _passedTime;
}

#pragma mark Initialization

- (instancetype)initWithType:(NSString *)type bubbles:(BOOL)bubbles passedTime:(double)seconds 
{
    if ((self = [super initWithType:type bubbles:bubbles]))
    {
        _passedTime = seconds;
    }
    return self;    
}

- (instancetype)initWithType:(NSString *)type passedTime:(double)seconds
{
    return [self initWithType:type bubbles:NO passedTime:seconds];
}

- (instancetype)initWithType:(NSString *)type bubbles:(BOOL)bubbles
{
    return [self initWithType:type bubbles:bubbles passedTime:0.0f];
}

+ (instancetype)eventWithType:(NSString *)type passedTime:(double)seconds
{
    return [[[self alloc] initWithType:type passedTime:seconds] autorelease];
}

@end
