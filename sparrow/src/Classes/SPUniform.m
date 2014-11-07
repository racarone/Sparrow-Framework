//
//  SPUniform.m
//  Sparrow
//
//  Created by Robert Carone on 10/29/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPMacros.h"
#import "SPMatrix.h"
#import "SPPoint.h"
#import "SPProgram.h"
#import "SPUniform.h"

typedef union
{
    int intValue;
    float floatValue;
    GLKVector2 vector2Value;
    GLKVector3 vector3Value;
    GLKVector4 vector4Value;
    GLKMatrix2 matrix2Value;
    GLKMatrix3 matrix3Value;
    GLKMatrix4 matrix4Value;
} SPUniformStorage;

// --- class implementation ------------------------------------------------------------------------

@implementation SPUniform
{
    NSString *_name;
    SPUniformStorage _value;
    SPUniformType _type;
    SPTexture *_texture;
}

#pragma mark Initializers

- (instancetype)initWithName:(NSString *)name
{
    if (self = [super init])
    {
        _name = [name copy];
        _type = SPUniformTypeNone;
    }
    return self;
}

- (void)dealloc
{
    [_name release];
    [_texture release];
    [super dealloc];
}

+ (instancetype)uniformWithName:(NSString *)name
{
    return [[[self alloc] initWithName:name] autorelease];
}

#pragma mark NSObject

- (NSUInteger)hash
{
    return [_name hash];
}

- (BOOL)isEqual:(id)object
{
    if (!object)
        return NO;
    else if (object == self)
        return YES;
    else if ([object isKindOfClass:[SPUniform class]])
        return [((SPUniform *)object)->_name isEqualToString:_name];

    return NO;
}

#pragma mark Properties

- (SPTexture *)textureValue
{
    if (_type == SPUniformTypeNone)
        _type = SPUniformTypeTexture;

    return _texture;
}

- (void)setTextureValue:(SPTexture *)textureValue
{
    if (_type == SPUniformTypeNone)
        _type = SPUniformTypeTexture;

    SP_RELEASE_AND_RETAIN(_texture, textureValue);
}

- (float)floatValue
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeFloat;
        _value.floatValue = 0;
    }

    return _value.floatValue;
}

- (void)setFloatValue:(float)value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeFloat;
        _value.floatValue = 0;
    }

    _value.floatValue = value;
}

- (int)intValue
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeFloat;
        _value.intValue = 0;
    }

    return _value.intValue;
}

- (void)setIntValue:(int)value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeFloat;
        _value.intValue = 0;
    }

    _value.intValue = value;
}

- (GLKVector2)vector2Value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeVector2;
        _value.vector2Value = (GLKVector2){ 0 };
    }

    return _value.vector2Value;
}

- (void)setVector2Value:(GLKVector2)value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeVector2;
        _value.vector2Value = (GLKVector2){ 0 };
    }

    _value.vector2Value = value;
}

- (GLKVector3)vector3Value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeVector3;
        _value.vector3Value = (GLKVector3){ 0 };
    }

    return _value.vector3Value;
}

- (void)setVector3Value:(GLKVector3)value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeVector3;
        _value.vector3Value = (GLKVector3){ 0 };
    }

    _value.vector3Value = value;
}

- (GLKVector4)vector4Value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeVector4;
        _value.vector4Value = (GLKVector4){ 0 };
    }

    return _value.vector4Value;
}

- (void)setVector4Value:(GLKVector4)value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeVector4;
        _value.vector4Value = (GLKVector4){ 0 };
    }

    _value.vector4Value = value;
}

- (GLKMatrix2)matrix2Value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeMatrix2;
        _value.matrix2Value = (GLKMatrix2){ 0 };
    }

    return _value.matrix2Value;
}

- (void)setMatrix2Value:(GLKMatrix2)value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeMatrix2;
        _value.matrix2Value = (GLKMatrix2){ 0 };
    }

    _value.matrix2Value = value;
}

- (GLKMatrix3)matrix3Value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeMatrix3;
        _value.matrix3Value = GLKMatrix3Identity;
    }

    return _value.matrix3Value;
}

- (void)setMatrix3Value:(GLKMatrix3)value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeMatrix3;
        _value.matrix3Value = GLKMatrix3Identity;
    }

    _value.matrix3Value = value;
}

- (GLKMatrix4)matrix4Value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeMatrix4;
        _value.matrix4Value = GLKMatrix4Identity;
    }

    return _value.matrix4Value;
}

- (void)setMatrix4Value:(GLKMatrix4)value
{
    if (_type == SPUniformTypeNone)
    {
        _type = SPUniformTypeMatrix4;
        _value.matrix4Value = GLKMatrix4Identity;
    }

    _value.matrix4Value = value;
}

- (SPPoint *)pointValue
{
    return [SPPoint pointWithGLKVector2:self.vector2Value];
}

- (void)setPointValue:(SPPoint *)pointValue
{
    self.vector2Value = pointValue.convertToGLKVector;
}

- (SPMatrix *)matrixValue
{
    return [SPMatrix matrixWithGLKMatrix4:self.matrix4Value];
}

- (void)setMatrixValue:(SPMatrix *)matrixValue
{
    self.matrix4Value = matrixValue.convertToGLKMatrix4;
}

@end
