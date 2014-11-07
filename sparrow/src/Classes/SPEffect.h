//
//  SPEffect.h
//  Sparrow
//
//  Created by Robert Carone on 11/5/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPUniform.h>

@class SPProgram;
@class SPTexture;

/** ------------------------------------------------------------------------------------------------

 An SPEffect represents a program state, which includes its uniforms. Every effect is considered
 unique, therefore if you wish for quads to be batched together they must share the same effect.

 Initialize an effect with a program and then configure it by adding SPUniform objects to it. When 
 the 'prepareToDraw' method is called all global and local uniforms that correspond to the set
 program are uploaded. Local uniforms always take precedence over global uniforms.
 
 The properties 'mainTexture', 'mvpMatrix' and 'tintColor' correspond to the uniform names
 'uTexture', 'uMvpMatrix' and 'uTintColor' respectively. These are provided for quick access to the
 common uniforms among standard effects, however they will not be uploaded if an effect's program
 does not declare them.
 
 Your program should include the following attributes as required: 'aPosition", 'aColor',
 'aTexCoords'. These are the attributes that Sparrow will setup for you  automatically. 
 (Note: an effect must at least contain the attribute 'aPosition')

------------------------------------------------------------------------------------------------- */

@interface SPEffect : NSObject

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes an effect with the specified program. _Designated Initializer_.
- (instancetype)initWithProgram:(SPProgram *)program;

/// -------------
/// @name Methods
/// -------------

/// Binds the effect's program and updates builtin uniforms as well as any custom uniforms added
/// to the effect.
- (void)prepareToDraw;

/// --------------
/// @name Uniforms
/// --------------

/// Adds a uniform.
- (void)addUniform:(SPUniform *)uniform;

/// Adds an array of uniforms.
- (void)addUniformsFromArray:(NSArray *)uniforms;

/// Returns the uniform with the specified name.
- (SPUniform *)uniformWithName:(NSString *)name;

/// Removes the uniform with the specified name.
- (void)removeUniformWithName:(NSString *)name;

/// Removes all uniforms.
- (void)removeAllUniforms;

/// Adds a global uniform.
+ (void)addGlobalUniform:(SPUniform *)globalUniform;

/// Returns the global uniform with the specified name.
+ (SPUniform *)globalUniformWithName:(NSString *)name;

/// Removes the global uniform with the specified name.
+ (void)removeGlobalUniformWithName:(NSString *)name;

/// ----------------
/// @name Properties
/// ----------------

/// The effec's program.
@property (nonatomic, strong) SPProgram *program;

/// THe main texture of the effect.
/// (The value for the unifrom 'uTexture')
@property (nonatomic, strong) SPTexture *mainTexture;

/// THe model view projection matrix of the effect.
/// (The value for the unifrom 'uMvpMatrix')
@property (nonatomic, assign) GLKMatrix4 mvpMatrix;

/// THe model view projection matrix of the effect.
/// (The value for the unifrom 'uTintColor')
@property (nonatomic, assign) GLKVector4 tintColor;

/// Returns an array of all uniforms currently added to this effect.
@property (nonatomic, readonly) NSArray *uniforms;

/// The default position attribute for the effect.
/// (The index of the attribute 'aPosition'; or SPNotFound if there is none.)
@property (nonatomic, readonly) int attribPosition;

/// The default color attribute for the effect.
/// (The index of the attribute 'aColor'; or SPNotFound if there is none.)
@property (nonatomic, readonly) int attribColor;

/// The default texture coordinate attribute for the effect.
/// (The index of the attribute 'aTexCoords'; or SPNotFound if there is none.)
@property (nonatomic, readonly) int attribTexCoords;

@end
