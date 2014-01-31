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

#import <Sparrow/SPBlendMode.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPQuadBatch.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPRenderSupport.h>
#import <Sparrow/SPSprite.h>
#import <Sparrow/SPStage.h>

// --- class implementation ------------------------------------------------------------------------

@implementation SPSprite
{
    NSMutableArray *_flattenedContents;
    BOOL _flattenRequested;
    SPRectangle *_clipRect;
}

#pragma mark Initialization

- (void)dealloc
{
    [_flattenedContents release];
    [super dealloc];
}

+ (instancetype)sprite
{
    return [[[self alloc] init] autorelease];
}

#pragma mark Methods

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

- (SPRectangle *)clipRectInSpace:(SPDisplayObject *)targetSpace
{
    if (!_clipRect)
        return nil;

    float minX =  FLT_MAX;
    float maxX = -FLT_MAX;
    float minY =  FLT_MAX;
    float maxY = -FLT_MAX;

    float clipLeft = _clipRect.left;
    float clipRight = _clipRect.right;
    float clipTop = _clipRect.top;
    float clipBottom = _clipRect.bottom;

    SPMatrix *transform = [self transformationMatrixToSpace:targetSpace];

    float x;
    float y;

    for (int i=0; i<4; ++i)
    {
        switch (i)
        {
            case 0: x = clipLeft;  y = clipTop;    break;
            case 1: x = clipLeft;  y = clipBottom; break;
            case 2: x = clipRight; y = clipTop;    break;
            case 3: x = clipRight; y = clipBottom; break;
        }

        SPPoint *transformedPoint = [transform transformPointWithX:x y:y];
        if (minX > transformedPoint.x) minX = transformedPoint.x;
        if (maxX < transformedPoint.x) maxX = transformedPoint.x;
        if (minY > transformedPoint.y) minY = transformedPoint.y;
        if (maxY < transformedPoint.y) maxY = transformedPoint.y;
    }

    return [SPRectangle rectangleWithX:minX y:minY width:maxX-minX height:maxY-minY];
}

#pragma mark SPDisplayObject

- (void)render:(SPRenderSupport *)support
{
    if (_clipRect)
    {
        SPRectangle *stageClipRect = [support pushClipRect:[self clipRectInSpace:self.stage]];
        if (!stageClipRect || stageClipRect.isEmpty)
        {
            // empty clipping bounds - no need to render children
            [support popClipRect];
            return;
        }
    }

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

    if (_clipRect)
        [support popClipRect];
}

- (SPRectangle *)boundsInSpace:(SPDisplayObject *)targetSpace
{
    SPRectangle *bounds = [super boundsInSpace:targetSpace];

    // if we have a scissor rect, intersect it with our bounds
    if (_clipRect)
        bounds = [bounds intersectionWithRectangle:[self clipRectInSpace:targetSpace]];

    return bounds;
}

- (SPDisplayObject *)hitTestPoint:(SPPoint *)localPoint
{
    if (_clipRect && ![_clipRect containsPoint:localPoint])
        return nil;
    else
        return [super hitTestPoint:localPoint];
}

@end
