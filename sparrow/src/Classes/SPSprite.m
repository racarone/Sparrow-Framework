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

#import "SPBlendMode.h"
#import "SPQuadBatch.h"
#import "SPRenderSupport.h"
#import "SPSprite.h"
#import "SPStage.h"

@implementation SPSprite
{
    NSMutableArray*     _flattenedContents;
    BOOL                _flattenRequested;
}

- (void)dealloc
{
    SP_RELEASE_AND_NIL(_flattenedContents);
    SP_RELEASE_AND_NIL(_clipRect);

    [super dealloc];
}

- (void)flatten
{
    _flattenRequested = YES;
    [self broadcastEventWithType:kSPEventTypeFlatten];
}

- (void)unflatten
{
    _flattenRequested = NO;
    _flattenedContents = nil;
}

- (SPRectangle*)clipRectInSpace:(SPDisplayObject*)targetSpace
{
    if (!_clipRect)
        return nil;

    float minX =  FLT_MAX;
    float maxX = -FLT_MAX;
    float minY =  FLT_MAX;
    float maxY = -FLT_MAX;

    SPMatrix* transMatrix = [self transformationMatrixToSpace:targetSpace];

    float x, y;

    for (int i=0; i<4; ++i)
    {
        switch (i) {
            case 0: x = _clipRect.left;  y = _clipRect.top;    break;
            case 1: x = _clipRect.left;  y = _clipRect.bottom; break;
            case 2: x = _clipRect.right; y = _clipRect.top;    break;
            case 3: x = _clipRect.right; y = _clipRect.bottom; break;
        }

        SPPoint* transformedPoint = [transMatrix transformPointWithX:x y:y];
        if (minX > transformedPoint.x) minX = transformedPoint.x;
        if (maxX < transformedPoint.x) maxX = transformedPoint.x;
        if (minY > transformedPoint.y) minY = transformedPoint.y;
        if (maxY < transformedPoint.y) maxY = transformedPoint.y;
    }

    return [SPRectangle rectangleWithX:minX y:minY width:maxX-minX height:maxY-minY];
}

- (BOOL)isFlattened
{
    return _flattenedContents || _flattenRequested;
}

- (SPRectangle*)boundsInSpace:(SPDisplayObject*)targetSpace
{
    SPRectangle* bounds = [super boundsInSpace:targetSpace];

    // if we have a scissor rect, intersect it with our bounds
    if (_clipRect)
        bounds = [bounds intersectionWithRectangle:[self clipRectInSpace:targetSpace]];

    return bounds;
}

- (SPDisplayObject*)hitTestPoint:(SPPoint*)localPoint
{
    if (_clipRect && ![_clipRect containsPoint:localPoint])
        return nil;
    else
        return [super hitTestPoint:localPoint];
}

- (void)render:(SPRenderSupport*)support
{
    if (_clipRect)
    {
        SPRectangle* stageClipRect = [support pushClipRect:[self clipRectInSpace:self.stage]];
        if (!stageClipRect || stageClipRect.isEmpty)
        {
            // empty clipping bounds - no need to render children.
            [support popClipRect];
            return;
        }
    }

    if (_flattenRequested)
    {
        _flattenedContents = [SPQuadBatch compileObject:self intoArray:_flattenedContents];
        _flattenRequested = NO;
    }
    
    if (_flattenedContents)
    {
        [support finishQuadBatch];
        [support addDrawCalls:(int)_flattenedContents.count];
        
        SPMatrix* mvpMatrix = support.mvpMatrix;
        float alpha = support.alpha;
        uint supportBlendMode = support.blendMode;
        
        for (SPQuadBatch* quadBatch in _flattenedContents)
        {
            uint blendMode = quadBatch.blendMode;
            if (blendMode == SP_BLEND_MODE_AUTO) blendMode = supportBlendMode;
            
            [quadBatch renderWithMvpMatrix:mvpMatrix alpha:alpha blendMode:blendMode];
        }
    }
    else [super render:support];

    if (_clipRect)
        [support popClipRect];
}

+ (instancetype)sprite
{
    return [[[self alloc] init] autorelease];
}

@end
