//
//  SPResizeEvent.m
//  Sparrow
//
//  Created by Daniel Sperl on 01.10.2012.
//  Copyright 2012 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPResizeEvent.h>

NSString *const SPEventTypeResize = @"SPEventTypeResize";

@implementation SPResizeEvent
{
    float _width;
    float _height;
    double _animationTime;
}

#pragma mark Initialization

- (instancetype)initWithType:(NSString *)type width:(float)width height:(float)height 
     animationTime:(double)time
{
    if ((self = [super initWithType:type bubbles:NO]))
    {
        _width = width;
        _height = height;
        _animationTime = time;
    }
    return self;
}

- (instancetype)initWithType:(NSString *)type width:(float)width height:(float)height
{
    return [self initWithType:type width:width height:height animationTime:0.0];
}

- (instancetype)initWithType:(NSString *)type bubbles:(BOOL)bubbles
{
    return [self initWithType:type width:320 height:480 animationTime:0.5];
}

#pragma mark Properties

- (BOOL)isPortrait
{
    return _height > _width;
}

@end
