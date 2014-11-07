//
//  SPUniform.h
//  Sparrow
//
//  Created by Robert Carone on 10/29/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKMath.h>

@class SPTexture;

/// An enum to identify the type of a uniform.
typedef NS_ENUM(int, SPUniformType)
{
    SPUniformTypeNone,    /// The uniform does not currently hold any data.
    SPUniformTypeFloat,   /// The uniform holds a float value.
    SPUniformTypeInt,     /// The uniform holds an integer value.
    SPUniformTypeVector2, /// The uniform holds a vector of 2 float values.
    SPUniformTypeVector3, /// The uniform holds a vector of 3 float values.
    SPUniformTypeVector4, /// The uniform holds a vector of 4 float values.
    SPUniformTypeMatrix2, /// The uniform holds a 2x2 matrix of float values.
    SPUniformTypeMatrix3, /// The uniform holds a 3x3 matrix of float values.
    SPUniformTypeMatrix4, /// The uniform holds a 4x4 matrix of float values.
    SPUniformTypeTexture, /// The uniform holds a reference to a texture.
};

/** ------------------------------------------------------------------------------------------------
 
 An SPUniform is used to hold uniform data for an SPEffect object.

 Create an SPUniform object and set its initial value. Once its value is specified, the 'type'
 property changes to match the type of the initial value you provided (and can never change 
 afterward).
 
 To use the uniform, add it to an SPEffect that needs to access the uniform.
 
 To update the uniform’s value, choose the appropriate property on the uniform object based on the 
 data type it encapsulates.

------------------------------------------------------------------------------------------------- */

@interface SPUniform : NSObject

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a new uniform object with the specified name. _Designated Initializer_.
- (instancetype)initWithName:(NSString *)name;

/// Factory method.
+ (instancetype)uniformWithName:(NSString *)name;

/// ----------------
/// @name Properties
/// ----------------

/// The uniform’s name.
@property (nonatomic, readonly) NSString *name;

/// A uniform's type is set to SPUniformTypeNone until the first time the uniform’s value is set.
/// Once the uniform is given an initial value, its type cannot be changed.
@property (nonatomic, readonly) SPUniformType type;

/// The uniform's value as an integer value.
@property (nonatomic, assign) int intValue;

/// The uniform's value as a floating point value.
@property (nonatomic, assign) float floatValue;

/// The uniform's value as a GLKVector2 value.
@property (nonatomic, assign) GLKVector2 vector2Value;

/// The uniform's value as a GLKVector3 value.
@property (nonatomic, assign) GLKVector3 vector3Value;

/// The uniform's value as a GLKVector4 value.
@property (nonatomic, assign) GLKVector4 vector4Value;

/// The uniform's value as a GLKMatrix2 value.
@property (nonatomic, assign) GLKMatrix2 matrix2Value;

/// The uniform's value as a GLKMatrix3 value.
@property (nonatomic, assign) GLKMatrix3 matrix3Value;

/// The uniform's value as a GLKMatrix4 value.
@property (nonatomic, assign) GLKMatrix4 matrix4Value;

/// The uniform's value as a texture.
@property (nonatomic, strong) SPTexture *textureValue;

@end

