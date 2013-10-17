//
//  SPSprite.m
//  Sparrow
//
//  Created by Daniel Sperl on 21.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPSprite.h"
#import "SPQuadBatch.h"
#import "SPRenderSupport.h"
#import "SPBlendMode.h"
#import "SPMacros.h"

@implementation SPSprite
{
    NSMutableArray *_flattenedContents;
    BOOL _flattenRequested;
}

- (void)dealloc
{
    [_flattenedContents release];
    [super dealloc];
}

- (void)flatten
{
    _flattenRequested = YES;
    [self broadcastEventWithType:SPEventTypeFlatten];
}

- (void)unflatten
{
    _flattenRequested = NO;
    SP_RELEASE_AND_NIL(_flattenedContents);
}

- (BOOL)isFlattened
{
    return _flattenedContents || _flattenRequested;
}

- (void)render:(SPRenderSupport *)support
{
    if (_flattenRequested)
    {
        _flattenedContents = [[SPQuadBatch compileObject:self intoArray:[_flattenedContents autorelease]] retain];
        _flattenRequested = NO;
    }
    
    if (_flattenedContents)
    {
        [support finishQuadBatch];
        [support addDrawCalls:(int)_flattenedContents.count];
        
        SPMatrix *mvpMatrix = support.mvpMatrix;
        float alpha = support.alpha;
        uint supportBlendMode = support.blendMode;
        
        for (SPQuadBatch *quadBatch in _flattenedContents)
        {
            uint blendMode = quadBatch.blendMode;
            if (blendMode == SPBlendModeAuto) blendMode = supportBlendMode;
            
            [quadBatch renderWithMvpMatrix:mvpMatrix alpha:alpha blendMode:blendMode];
        }
    }
    else [super render:support];
}

+ (instancetype)sprite
{
    return [[[self alloc] init] autorelease];
}

@end
