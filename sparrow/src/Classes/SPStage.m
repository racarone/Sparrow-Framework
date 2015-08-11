//
//  SPStage.m
//  Sparrow
//
//  Created by Daniel Sperl on 15.03.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPContext.h"
#import "SPEnterFrameEvent.h"
#import "SPDisplayObject_Internal.h"
#import "SPDisplayObjectContainer_Internal.h"
#import "SPPoint.h"
#import "SPMacros.h"
#import "SPMatrix3D.h"
#import "SPRenderSupport.h"
#import "SPStage.h"
#import "SPVector3D.h"

#import <UIKit/UIKit.h>

// --- class implementation ------------------------------------------------------------------------

@implementation SPStage
{
    float _width;
    float _height;
    uint _color;
    float _fieldOfView;
    SPPoint *_projectionOffset;
    NSMutableArray<SPDisplayObject*> *_enterFrameListeners;
}

@synthesize width  = _width;
@synthesize height = _height;

#pragma mark Initialization

- (instancetype)initWithWidth:(float)width height:(float)height
{    
    if ((self = [super init]))
    {
        _width = width;
        _height = height;
        _fieldOfView = 1.0f;
        _projectionOffset = [[SPPoint alloc] init];
        _enterFrameListeners = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)init
{
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    return [self initWithWidth:screenSize.width height:screenSize.height];
}

- (void)dealloc
{
    [_projectionOffset release];
    [_enterFrameListeners release];
    [super dealloc];
}

#pragma mark Methods

- (SPVector3D *)cameraPositionInSpace:(SPDisplayObject *)targetSpace
{
    return [[self transformationMatrix3DToSpace:targetSpace] transformVectorWithX:_width  / 2.0f + _projectionOffset.x
                                                                                y:_height / 2.0f + _projectionOffset.y
                                                                                z:-self.focalLength];
}

- (UIImage *)drawToImage
{
    return [self drawToImage:YES];
}

- (UIImage *)drawToImage:(BOOL)transparent
{
    SPRenderSupport *support = [SPRenderSupport new];
    
    support.renderTarget = nil;
    [support setProjectionMatrixWithX:0 y:0 width:_width height:_height
                           stageWidth:_width stageHeight:_height cameraPos:self.cameraPosition];
    
    if (transparent) [support clear];
    else             [support clearWithColor:_color alpha:1];
    
    [self render:support];
    [support finishQuadBatch];
    [support release];
    
    UIImage *image = [Sparrow.context drawToImage];
    //[Sparrow.context present]; // required on some platforms to avoid flickering
    return image;
}

#pragma mark SPDisplayObject

- (void)render:(SPRenderSupport *)support
{
    [SPRenderSupport clearWithColor:_color alpha:1.0f];
    [support setProjectionMatrixWithX:0 y:0 width:_width height:_height
                           stageWidth:_width stageHeight:_height
                            cameraPos:self.cameraPosition];

    [super render:support];
}

- (SPDisplayObject *)hitTestPoint:(SPPoint *)localPoint
{
    if (!self.visible || !self.touchable)
        return nil;
    
    // locations outside of the stage area shouldn't be accepted
    if (localPoint.x < 0.0f || localPoint.x > _width ||
        localPoint.y < 0.0f || localPoint.y > _height)
        return nil;
    
    // if nothing else is hit, the stage returns itself as target
    SPDisplayObject *target = [super hitTestPoint:localPoint];
    if (!target) target = self;
    
    return target;
}

#pragma mark SPDisplayObjectContainer (Internal)

- (void)appendDescendantEventListenersOfObject:(SPDisplayObject *)object withEventType:(NSString *)type
                                       toArray:(NSMutableArray<SPDisplayObject*> *)listeners
{
    if (object == self && [type isEqualToString:SPEventTypeEnterFrame])
        [listeners addObjectsFromArray:_enterFrameListeners];
    else
        [super appendDescendantEventListenersOfObject:object withEventType:type toArray:listeners];
}

#pragma mark Properties

- (float)focalLength
{
    return _width / (2.0f * tanf(_fieldOfView / 2.0f));
}

- (void)setFocalLength:(float)focalLength
{
    _fieldOfView = 2.0f * atanf(_width / (2.0f * focalLength));
}

- (void)setProjectionOffset:(SPPoint *)projectionOffset
{
    [_projectionOffset setX:projectionOffset.x y:projectionOffset.y];
}

- (SPVector3D *)cameraPosition
{
    return [self cameraPositionInSpace:nil];
}

- (void)setX:(float)value
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot set x-coordinate of stage"];
}

- (void)setY:(float)value
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot set y-coordinate of stage"];
}

- (void)setPivotX:(float)value
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot set pivot coordinates of stage"];
}

- (void)setPivotY:(float)value
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot set pivot coordinates of stage"];
}

- (void)setScaleX:(float)value
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot scale stage"];
}

- (void)setScaleY:(float)value
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot scale stage"];
}

- (void)setSkewX:(float)skewX
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot skew stage"];
}

- (void)setSkewY:(float)skewY
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot skew stage"];
}

- (void)setRotation:(float)value
{
    [NSException raise:SPExceptionInvalidOperation format:@"cannot rotate stage"];
}

@end

// -------------------------------------------------------------------------------------------------

@implementation SPStage (Internal)

- (void)advanceTime:(double)passedTime
{
    SPEnterFrameEvent* enterFrameEvent = [[SPEnterFrameEvent alloc] initWithType:SPEventTypeEnterFrame passedTime:passedTime];
    [self broadcastEvent:enterFrameEvent];
    [enterFrameEvent release];
}

- (void)addEnterFrameListener:(SPDisplayObject *)listener
{
    [_enterFrameListeners addObject:listener];
}

- (void)removeEnterFrameListener:(SPDisplayObject *)listener
{
    NSUInteger index = [_enterFrameListeners indexOfObject:listener];
    if (index != NSNotFound) [_enterFrameListeners removeObjectAtIndex:index];
}

@end
