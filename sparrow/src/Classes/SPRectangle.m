//
//  SPRectangle.m
//  Sparrow
//
//  Created by Daniel Sperl on 21.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPMacros.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPRectangle.h>

@implementation SPRectangle

#pragma mark Initialization

- (instancetype)initWithX:(float)x y:(float)y width:(float)width height:(float)height
{
    if (self)
    {
        _x = x;
        _y = y;
        _width = width;
        _height = height;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithX:0.0f y:0.0f width:0.0f height:0.0f];
}

+ (instancetype)rectangleWithX:(float)x y:(float)y width:(float)width height:(float)height
{
    return [[[self allocWithZone:nil] initWithX:x y:y width:width height:height] autorelease];
}

+ (instancetype)rectangle
{
    return [[[self alloc] init] autorelease];
}

#pragma mark Methods

- (BOOL)containsX:(float)x y:(float)y
{
    return x >= _x && y >= _y && x <= _x + _width && y <= _y + _height;
}

- (BOOL)containsPoint:(SPPoint *)point
{
    return [self containsX:point.x y:point.y];
}

- (BOOL)containsRectangle:(SPRectangle *)rectangle
{
    if (!rectangle) return NO;
    
    float rX = rectangle->_x;
    float rY = rectangle->_y;
    float rWidth = rectangle->_width;
    float rHeight = rectangle->_height;

    return rX >= _x && rX + rWidth <= _x + _width &&
           rY >= _y && rY + rHeight <= _y + _height;
}

- (BOOL)intersectsRectangle:(SPRectangle *)rectangle
{
    if (!rectangle) return  NO;
    
    float rX = rectangle->_x;
    float rY = rectangle->_y;
    float rWidth = rectangle->_width;
    float rHeight = rectangle->_height;
    
    BOOL outside = 
        (rX <= _x && rX + rWidth <= _x)  || (rX >= _x + _width && rX + rWidth >= _x + _width) ||
        (rY <= _y && rY + rHeight <= _y) || (rY >= _y + _height && rY + rHeight >= _y + _height);
    return !outside;
}

- (SPRectangle *)intersectionWithRectangle:(SPRectangle *)rectangle
{
    if (!rectangle) return nil;
    
    float left   = MAX(_x, rectangle->_x);
    float right  = MIN(_x + _width, rectangle->_x + rectangle->_width);
    float top    = MAX(_y, rectangle->_y);
    float bottom = MIN(_y + _height, rectangle->_y + rectangle->_height);
    
    if (left > right || top > bottom)
        return [SPRectangle rectangleWithX:0 y:0 width:0 height:0];
    else
        return [SPRectangle rectangleWithX:left y:top width:right-left height:bottom-top];
}

- (SPRectangle *)uniteWithRectangle:(SPRectangle *)rectangle
{
    if (!rectangle) return [[self copy] autorelease];
    
    float left   = MIN(_x, rectangle->_x);
    float right  = MAX(_x + _width, rectangle->_x + rectangle->_width);
    float top    = MIN(_y, rectangle->_y);
    float bottom = MAX(_y + _height, rectangle->_y + rectangle->_height);
    return [SPRectangle rectangleWithX:left y:top width:right-left height:bottom-top];
}

- (void)inflateXBy:(float)dx yBy:(float)dy
{
    _x -= dx;
    _width += 2 * dx;

    _y -= dy;
    _height += 2 * dy;
}

- (void)setX:(float)x y:(float)y width:(float)width height:(float)height
{
    _x = x;
    _y = y;
    _width = width;
    _height = height;
}

- (void)setEmpty
{
    _x = _y = _width = _height = 0;
}

- (void)copyFromRectangle:(SPRectangle *)rectangle
{
    _x = rectangle->_x;
    _y = rectangle->_y;
    _width = rectangle->_width;
    _height = rectangle->_height;
}

- (BOOL)isEqualToRectangle:(SPRectangle *)other
{
    if (other == self) return YES;
    else if (!other) return NO;
    else
    {
        SPRectangle *rect = (SPRectangle *)other;
        return SP_IS_FLOAT_EQUAL(_x, rect->_x) && SP_IS_FLOAT_EQUAL(_y, rect->_y) &&
               SP_IS_FLOAT_EQUAL(_width, rect->_width) && SP_IS_FLOAT_EQUAL(_height, rect->_height);
    }
}

- (void)normalize
{
    if (_width < 0.0f)
    {
        _width = -_width;
        _x -= _width;
    }

    if (_height < 0.0f)
    {
        _height = -_height;
        _y -= _height;
    }
}

#pragma mark NSObject

- (BOOL)isEqual:(id)object
{
    if (!object)
        return NO;
    else if (object == self)
        return YES;
    else if (![object isKindOfClass:[SPRectangle class]])
        return NO;
    else
        return [self isEqualToRectangle:object];
}

- (NSUInteger)hash
{
    return SPHashInt(SPFloatToIntBits(_x)) ^
           SPShiftAnRotateInt(SPHashInt(SPFloatToIntBits(_y)), CHAR_BIT) ^
           SPShiftAnRotateInt(SPHashInt(SPFloatToIntBits(_width)), CHAR_BIT) ^
           SPShiftAnRotateInt(SPHashInt(SPFloatToIntBits(_height)), CHAR_BIT);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[SPRectangle: x=%f, y=%f, width=%f, height=%f]",
            _x, _y, _width, _height];
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithX:_x y:_y width:_width height:_height];
}

#pragma mark Properties

- (float)top { return _y; }
- (void)setTop:(float)value { _y = value; }

- (float)bottom { return _y + _height; }
- (void)setBottom:(float)value { _height = value - _y; }

- (float)left { return _x; }
- (void)setLeft:(float)value { _x = value; }

- (float)right { return _x + _width; }
- (void)setRight:(float)value { _width = value - _x; }

- (SPPoint *)topLeft { return [SPPoint pointWithX:_x y:_y]; }
- (void)setTopLeft:(SPPoint *)value { _x = value.x; _y = value.y; }

- (SPPoint *)bottomRight { return [SPPoint pointWithX:_x+_width y:_y+_height]; }
- (void)setBottomRight:(SPPoint *)value { self.right = value.x; self.bottom = value.y; }

- (SPPoint *)size { return [SPPoint pointWithX:_width y:_height]; }
- (void)setSize:(SPPoint *)value { _width = value.x; _height = value.y; }

- (BOOL)isEmpty
{
    return _width == 0 || _height == 0;
}

@end
