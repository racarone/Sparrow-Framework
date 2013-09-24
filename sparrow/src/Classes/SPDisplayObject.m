//
//  SPDisplayObject.m
//  Sparrow
//
//  Created by Daniel Sperl on 15.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPBlendMode.h"
#import "SPDisplayObject_Internal.h"
#import "SPDisplayObjectContainer.h"
#import "SPEventDispatcher_Internal.h"
#import "SPEnterFrameEvent.h"
#import "SPMacros.h"
#import "SPMatrix_Internal.h"
#import "SPStage_Internal.h"
#import "SPTouchEvent.h"

// --- class implementation ------------------------------------------------------------------------

@implementation SPDisplayObject
{
    float                               _x;
    float                               _y;
    float                               _pivotX;
    float                               _pivotY;
    float                               _scaleX;
    float                               _scaleY;
    float                               _skewX;
    float                               _skewY;
    float                               _rotation;
    float                               _alpha;
    uint                                _blendMode;
    BOOL                                _visible;
    BOOL                                _touchable;
    BOOL                                _orientationChanged;

    SPDisplayObjectContainer* __weak    _parent;
    SPMatrix*                           _transformationMatrix;
    double                              _lastTouchTimestamp;
    NSString*                           _name;
}

@synthesize x           = _x;
@synthesize y           = _y;
@synthesize pivotX      = _pivotX;
@synthesize pivotY      = _pivotY;
@synthesize scaleX      = _scaleX;
@synthesize scaleY      = _scaleY;
@synthesize skewX       = _skewX;
@synthesize skewY       = _skewY;
@synthesize rotation    = _rotation;
@synthesize parent      = _parent;
@synthesize alpha       = _alpha;
@synthesize visible     = _visible;
@synthesize touchable   = _touchable;
@synthesize name        = _name;
@synthesize blendMode   = _blendMode;

- (instancetype)init
{    
    #ifdef DEBUG    
    if ([self isMemberOfClass:[SPDisplayObject class]]) 
    {
        [NSException raise:SP_EXC_ABSTRACT_CLASS 
                    format:@"Attempting to initialize abstract class SPDisplayObject."];        
        return nil;
    }    
    #endif
    
    if ((self = [super init]))
    {
        _alpha = 1.0f;
        _scaleX = 1.0f;
        _scaleY = 1.0f;
        _visible = YES;
        _touchable = YES;
        _transformationMatrix = [[SPMatrix alloc] init];
        _orientationChanged = YES;
        _blendMode = SP_BLEND_MODE_AUTO;
    }
    return self;
}

- (void) dealloc
{
    SP_RELEASE_AND_NIL(_name);
    SP_RELEASE_AND_NIL(_transformationMatrix);

    [super dealloc];
}

#pragma mark methods

- (void)render:(SPRenderSupport*)support
{
    // override in subclass
}

- (void)removeFromParent
{
    [_parent removeChild:self];
}

- (void)alignPivotWithHAlign:(SPHAlign)hAlign vAlign:(SPVAlign)vAlign
{
    SPRectangle* bounds = [self boundsInSpace:self];
    _orientationChanged = true;

    switch (hAlign) {
        case SPHAlignLeft:      _pivotX = bounds.x;                         break;
        case SPHAlignCenter:    _pivotX = bounds.x + bounds.width / 2.0;    break;
        case SPHAlignRight:     _pivotX = bounds.x + bounds.width;          break;
        default:                [NSException raise:SP_EXC_INVALID_OPERATION format:@"Invalid horizontal alignment."];
    }

    switch (vAlign) {
        case SPVAlignTop:       _pivotY = bounds.y;                         break;
        case SPVAlignCenter:    _pivotY = bounds.y + bounds.height / 2.0;   break;
        case SPVAlignBottom:    _pivotY = bounds.y + bounds.height;         break;
        default:                [NSException raise:SP_EXC_INVALID_OPERATION format:@"Invalid vertical alignment."];
    }
}

- (SPMatrix*)transformationMatrixToSpace:(SPDisplayObject*)targetSpace
{
    SPMatrix* resultMatrix = SPMatrixCreate();

    if (targetSpace == self)
    {
        return resultMatrix;
    }
    else if (targetSpace == _parent || (!targetSpace && !_parent))
    {
        SPMatrixCopyFrom(resultMatrix, self.transformationMatrix);
        return resultMatrix;
    }
    else if (!targetSpace || targetSpace == self.base)
    {
        // targetSpace 'nil' represents the target coordinate of the base object.
        // -> move up from self to base
        SPDisplayObject* currentObject = self;
        while (currentObject != targetSpace)
        {
            SPMatrixAppendMatrix(resultMatrix, currentObject.transformationMatrix);
            currentObject = currentObject->_parent;
        }
        return resultMatrix;
    }
    else if (targetSpace->_parent == self)
    {
        SPMatrixCopyFrom(resultMatrix, targetSpace.transformationMatrix);
        SPMatrixInvert(resultMatrix);
        return resultMatrix;
    }
    
    // 1.: Find a common parent of self and the target coordinate space.
    //
    // This method is used very often during touch testing, so we optimized the code. 
    // Instead of using an NSSet or NSArray (which would make the code much cleaner), we 
    // use a C array here to save the ancestors.
    
    static SPDisplayObject* ancestors[SP_MAX_DISPLAY_TREE_DEPTH];
    
    int count = 0;
    SPDisplayObject* commonParent = nil;
    SPDisplayObject* currentObject = self;
    while (currentObject && count < SP_MAX_DISPLAY_TREE_DEPTH)
    {
        ancestors[count++] = currentObject;
        currentObject = currentObject->_parent;
    }

    currentObject = targetSpace;    
    while (currentObject && !commonParent)
    {        
        for (int i=0; i<count; ++i)
        {
            if (currentObject == ancestors[i])
            {
                commonParent = ancestors[i];
                break;                
            }            
        }
        currentObject = currentObject->_parent;
    }
    
    if (!commonParent)
        [NSException raise:SP_EXC_NOT_RELATED format:@"Object not connected to target"];
    
    // 2.: Move up from self to common parent
    currentObject = self;    
    while (currentObject != commonParent)
    {
        SPMatrixAppendMatrix(resultMatrix, currentObject.transformationMatrix);
        currentObject = currentObject->_parent;
    }

    if (commonParent == targetSpace)
        return resultMatrix;

    // 3.: Now move up from target until we reach the common parent
    SPMatrix* targetMatrix = SPMatrixCreate();
    currentObject = targetSpace;
    while (currentObject && currentObject != commonParent)
    {
        SPMatrixAppendMatrix(targetMatrix, currentObject.transformationMatrix);
        currentObject = currentObject->_parent;
    }    
    
    // 4.: Combine the two matrices
    SPMatrixInvert(targetMatrix);
    SPMatrixAppendMatrix(resultMatrix, targetMatrix);
    
    return resultMatrix;
}

- (SPRectangle*)boundsInSpace:(SPDisplayObject*)targetSpace
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD 
                format:@"Method 'boundsInSpace:' needs to be implemented in subclasses"];
    return nil;
}

- (SPPoint*)localToGlobal:(SPPoint*)localPoint
{
    SPMatrix* matrix = [self transformationMatrixToSpace:self.base];
    return SPMatrixTransformPoint(matrix, localPoint);
}

- (SPPoint*)globalToLocal:(SPPoint*)globalPoint
{
    SPMatrix* matrix = [self transformationMatrixToSpace:self.base];
    SPMatrixInvert(matrix);
    return SPMatrixTransformPoint(matrix, globalPoint);
}

- (SPDisplayObject*)hitTestPoint:(SPPoint*)localPoint
{
    // invisible or untouchable objects cause the test to fail
    if (!_visible || !_touchable) return nil;

    // otherwise, check bounding box
    if ([[self boundsInSpace:self] containsPoint:localPoint]) return self;
    else return nil;
}

- (void)broadcastEvent:(SPEvent*)event
{
    if (event.bubbles)
        [NSException raise:SP_EXC_INVALID_OPERATION
                    format:@"Broadcast of bubbling events is prohibited"];

    [self dispatchEvent:event];
}

- (void)broadcastEventWithType:(NSString*)type
{
    [self dispatchEventWithType:type];
}

- (void)dispatchEvent:(SPEvent*)event
{
    // on one given moment, there is only one set of touches -- thus, 
    // we process only one touch event with a certain timestamp
    if ([event isKindOfClass:[SPTouchEvent class]])
    {
        SPTouchEvent* touchEvent = (SPTouchEvent*)event;
        if (touchEvent.timestamp == _lastTouchTimestamp) return;        
        else _lastTouchTimestamp = touchEvent.timestamp;
    }

    [super dispatchEvent:event];
}

#pragma mark overrides

// enter frame event optimization

// To avoid looping through the complete display tree each frame to find out who's
// listening to ENTER_FRAME events, we manage a list of them manually in the Stage class.

- (void)addEnterFrameListenerToStage
{
    [[[Sparrow currentController] stage] addEnterFrameListener:self];
}

- (void)removeEnterFrameListenerFromStage
{
    [[[Sparrow currentController] stage] removeEnterFrameListener:self];
}

- (void)addEventListener:(id)listener forType:(NSString*)eventType
{
    if ([eventType isEqualToString:kSPEventTypeEnterFrame] && ![self hasEventListenerForType:kSPEventTypeEnterFrame])
    {
        [self addEventListener:@selector(addEnterFrameListenerToStage) atObject:self forType:kSPEventTypeAddedToStage];
        [self addEventListener:@selector(removeEnterFrameListenerFromStage) atObject:self forType:kSPEventTypeRemovedFromStage];
        if (self.stage) [self addEnterFrameListenerToStage];
    }

    [super addEventListener:listener forType:eventType];
}

- (void)removeEventListenersForType:(NSString*)eventType withTarget:(id)object andSelector:(SEL)selector orBlock:(SPEventBlock)block
{
    [super removeEventListenersForType:eventType withTarget:object andSelector:selector orBlock:block];

    if ([eventType isEqualToString:kSPEventTypeEnterFrame] && ![self hasEventListenerForType:kSPEventTypeEnterFrame])
    {
        [self removeEventListener:@selector(addEnterFrameListenerToStage) atObject:self forType:kSPEventTypeAddedToStage];
        [self removeEventListener:@selector(removeEnterFrameListenerFromStage) atObject:self forType:kSPEventTypeRemovedFromStage];
        [self removeEnterFrameListenerFromStage];
    }
}

#pragma mark properties

- (void)setX:(float)value
{
    if (value != _x)
    {
        _x = value;
        _orientationChanged = YES;
    }
}

- (void)setY:(float)value
{
    if (value != _y)
    {
        _y = value;
        _orientationChanged = YES;
    }
}

- (void)setScaleX:(float)value
{
    if (value != _scaleX)
    {
        _scaleX = value;
        _orientationChanged = YES;
    }
}

- (void)setScaleY:(float)value
{
    if (value != _scaleY)
    {
        _scaleY = value;
        _orientationChanged = YES;
    }
}

- (void)setSkewX:(float)value
{
    if (value != _skewX)
    {
        _skewX = value;
        _orientationChanged = YES;
    }
}

- (void)setSkewY:(float)value
{
    if (value != _skewY)
    {
        _skewY = value;
        _orientationChanged = YES;
    }
}

- (void)setPivotX:(float)value
{
    if (value != _pivotX)
    {
        _pivotX = value;
        _orientationChanged = YES;
    }
}

- (void)setPivotY:(float)value
{
    if (value != _pivotY)
    {
        _pivotY = value;
        _orientationChanged = YES;
    }
}

- (void)setRotation:(float)value
{
    // move to equivalent value in range [0 deg, 360 deg] without a loop
    value = fmod(value, TWO_PI);
    
    // move to [-180 deg, +180 deg]
    if (value < -PI) value += TWO_PI;
    if (value >  PI) value -= TWO_PI;
    
    _rotation = value;
    _orientationChanged = YES;
}

- (void)setAlpha:(float)value
{
    _alpha = SP_CLAMP(value, 0.0f, 1.0f);
}

- (float)width
{
    return [self boundsInSpace:_parent].width;
}

- (void)setWidth:(float)value
{
    // this method calls 'self.scaleX' instead of changing _scaleX directly.
    // that way, subclasses reacting on size changes need to override only the scaleX method.

    self.scaleX = 1.0f;
    float actualWidth = self.width;
    if (actualWidth != 0.0f) self.scaleX = value / actualWidth;
}

- (float)height
{
    return [self boundsInSpace:_parent].height;
}

- (void)setHeight:(float)value
{
    self.scaleY = 1.0f;
    float actualHeight = self.height;
    if (actualHeight != 0.0f) self.scaleY = value / actualHeight;
}

- (SPRectangle*)bounds
{
    return [self boundsInSpace:_parent];
}

- (SPDisplayObject*)base
{
    SPDisplayObject* currentObject = self;
    while (currentObject->_parent) currentObject = currentObject->_parent;
    return currentObject;
}

- (SPDisplayObject*)root
{
    Class stageClass = [SPStage class];
    SPDisplayObject* currentObject = self;
    while (currentObject->_parent)
    {
        if ([currentObject->_parent isMemberOfClass:stageClass]) return currentObject;
        else currentObject = currentObject->_parent;
    }
    return nil;
}

- (SPStage*)stage
{
    SPDisplayObject* base = self.base;
    if ([base isKindOfClass:[SPStage class]]) return (SPStage*)base;
    else return nil;
}

- (SPMatrix*)transformationMatrix
{
    if (_orientationChanged)
    {
        _orientationChanged = NO;
        
        if (_skewX == 0.0f && _skewY == 0.0f)
        {
            // optimization: no skewing / rotation simplifies the matrix math
            
            if (_rotation == 0.0f)
            {
                SPMatrixSet(_transformationMatrix,
                            _scaleX,
                            0.0f,
                            0.0f,
                            _scaleY,
                            _x - _pivotX*_scaleX,
                            _y - _pivotY*_scaleY);
            }
            else
            {
                float cos = cosf(_rotation);
                float sin = sinf(_rotation);
                float a = _scaleX *  cos;
                float b = _scaleX *  sin;
                float c = _scaleY * -sin;
                float d = _scaleY *  cos;
                float tx = _x - _pivotX * a - _pivotY * c;
                float ty = _y - _pivotX * b - _pivotY * d;

                SPMatrixSet(_transformationMatrix, a, b, c, d, tx, ty);
            }
        }
        else
        {
            SPMatrixIdentity(_transformationMatrix);
            SPMatrixScaleBy(_transformationMatrix, _scaleX, _scaleY);
            SPMatrixSkewBy(_transformationMatrix, _skewX, _skewY);
            SPMatrixRotateBy(_transformationMatrix, _rotation);
            SPMatrixTranslateBy(_transformationMatrix, _x, _y);
            
            if (_pivotX != 0.0 || _pivotY != 0.0)
            {
                // prepend pivot transformation
                _transformationMatrix.tx = _x - _transformationMatrix.a * _pivotX
                                              - _transformationMatrix.c * _pivotY;
                _transformationMatrix.ty = _y - _transformationMatrix.b * _pivotX
                                              - _transformationMatrix.d * _pivotY;
            }
        }
    }
    
    return _transformationMatrix;
}

- (void)setTransformationMatrix:(SPMatrix*)matrix
{
    _orientationChanged = NO;
    SPMatrixCopyFrom(_transformationMatrix, matrix);
    
    _pivotX = 0.0f;
    _pivotY = 0.0f;
    
    _x = matrix.tx;
    _y = matrix.ty;
    
    _scaleX = sqrtf(SP_SQUARE(matrix.a) + SP_SQUARE(matrix.b));
    _skewY  = acosf(matrix.a / _scaleX);
    
    if (!SP_IS_FLOAT_EQUAL(matrix.b, _scaleX * sinf(_skewY)))
    {
        _scaleX *= -1.0f;
        _skewY = acosf(matrix.a / _scaleX);
    }
    
    _scaleY = sqrtf(SP_SQUARE(matrix.c) + SP_SQUARE(matrix.d));
    _skewX  = acosf(matrix.d / _scaleY);
    
    if (!SP_IS_FLOAT_EQUAL(matrix.c, -_scaleY * sinf(_skewX)))
    {
        _scaleY *= -1.0f;
        _skewX = acosf(matrix.d / _scaleY);
    }
    
    if (SP_IS_FLOAT_EQUAL(_skewX, _skewY))
    {
        _rotation = _skewX;
        _skewX = _skewY = 0.0f;
    }
    else
    {
        _rotation = 0.0f;
    }
}

- (BOOL)hasVisibleArea
{
    return _alpha != 0.0f && _visible && _scaleX != 0.0f && _scaleY != 0.0f;
}

@end

// -------------------------------------------------------------------------------------------------

@implementation SPDisplayObject (Internal)

- (void)setParent:(SPDisplayObjectContainer*)parent
{ 
    SPDisplayObject* ancestor = parent;
    while (ancestor != self && ancestor != nil)
        ancestor = ancestor->_parent;
    
    if (ancestor == self)
        [NSException raise:SP_EXC_INVALID_OPERATION 
                    format:@"An object cannot be added as a child to itself or one of its children"];
    else
        _parent = parent; // only assigned, not retained (to avoid a circular reference).
}

- (void)dispatchEventOnChildren:(SPEvent*)event
{
    [self dispatchEvent:event];
}

@end
