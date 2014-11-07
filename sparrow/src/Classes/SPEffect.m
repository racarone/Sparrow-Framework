//
//  SPEffect.m
//  Sparrow
//
//  Created by Robert Carone on 11/5/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPMacros.h"
#import "SPEffect.h"
#import "SPMatrix.h"
#import "SPNSExtensions.h"
#import "SPOpenGL.h"
#import "SPProgram.h"
#import "SPTexture.h"
#import "SPUniform.h"

static NSMutableDictionary *globalUniforms = nil;
static int globalUniformsSeed = 0;

// --- class implementation ------------------------------------------------------------------------

@implementation SPEffect
{
    SPProgram *_program;
    NSMutableDictionary *_uniforms;
    NSMutableOrderedSet *_updateList;

    SPTexture *_mainTexture;
    GLKMatrix4 _mvpMatrix;
    GLKVector4 _tintColor;

    int _aPosition;
    int _aColor;
    int _aTexCoords;

    int _uTexture;
    int _uMvpMatrix;
    int _uTintColor;

    int _prevGlobalUniformsSeed;
    BOOL _uniformsDirty;
}

@synthesize attribPosition  = _aPosition;
@synthesize attribColor     = _aColor;
@synthesize attribTexCoords = _aTexCoords;

#pragma mark Initialization

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
     {
         globalUniforms = [[NSMutableDictionary alloc] init];
         globalUniformsSeed = 0;
     });
}

- (instancetype)initWithProgram:(SPProgram *)program
{
    if (self = [super init])
    {
        _uniforms = [[NSMutableDictionary alloc] init];
        _updateList = [[NSMutableOrderedSet alloc] init];

        _uTexture = _uMvpMatrix = _uTintColor = _aPosition =
        _aColor = _aTexCoords = SPNotFound;

        self.program = program;
    }

    return self;
}

- (instancetype)init
{
    return [self initWithProgram:nil];
}

- (void)dealloc
{
    [_program release];
    [_uniforms release];
    [_mainTexture release];
    [super dealloc];
}

#pragma mark Methods

- (void)prepareToDraw
{
    if (!_program)
        return;

    [self syncUpdateList];

    glUseProgram(_program.name);

    int textureUnit = 0;
    if (_mainTexture && _uTexture != SPNotFound)
    {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _mainTexture.name);
        ++textureUnit;
    }

    if (_uMvpMatrix != SPNotFound)
        glUniformMatrix4fv(_uMvpMatrix, 1, GL_FALSE, _mvpMatrix.m);

    if (_uTintColor != SPNotFound)
        glUniform4fv(_uTintColor, 1, _tintColor.v);

    for (SPUniform *uniform in _updateList)
    {
        int location = [_program uniformByName:uniform.name];
        if (location == SPNotFound)
            continue;

        switch (uniform.type)
        {
            case SPUniformTypeNone:
                break;

            case SPUniformTypeFloat:
                glUniform1f(location, uniform.floatValue);
                break;

            case SPUniformTypeInt:
                glUniform1i(location, uniform.intValue);
                break;

            case SPUniformTypeVector2:
                glUniform2fv(location, 1, uniform.vector2Value.v);
                break;

            case SPUniformTypeVector3:
                glUniform3fv(location, 1, uniform.vector3Value.v);
                break;

            case SPUniformTypeVector4:
                glUniform4fv(location, 1, uniform.vector4Value.v);
                break;

            case SPUniformTypeMatrix2:
                glUniformMatrix2fv(location, 1, false, uniform.matrix2Value.m);
                break;

            case SPUniformTypeMatrix3:
                glUniformMatrix3fv(location, 1, false, uniform.matrix3Value.m);
                break;

            case SPUniformTypeMatrix4:
                glUniformMatrix4fv(location, 1, false, uniform.matrix4Value.m);
                break;

            case SPUniformTypeTexture:
                glUniform1i(location, textureUnit);
                glActiveTexture(GL_TEXTURE0 + textureUnit);
                glBindTexture(GL_TEXTURE_2D, uniform.textureValue.name);
                ++textureUnit;
                break;
        }
    }
}

#pragma mark Uniforms

- (void)addUniform:(SPUniform *)uniform
{
    _uniforms[uniform.name] = uniform;
    _uniformsDirty = YES;
}

- (void)addUniformsFromArray:(NSArray *)uniforms
{
    for (SPUniform *uniform in uniforms)
        [self addUniform:uniform];
}

- (SPUniform *)uniformWithName:(NSString *)name
{
    return _uniforms[name];
}

- (void)removeUniformWithName:(NSString *)name
{
    [_uniforms removeObjectForKey:name];
    _uniformsDirty = YES;
}

- (void)removeAllUniforms
{
    [_uniforms removeAllObjects];
    _uniformsDirty = YES;
}

+ (void)addGlobalUniform:(SPUniform *)globalUniform
{
    globalUniforms[globalUniform.name] = globalUniform;
    globalUniformsSeed++;
}

+ (SPUniform *)globalUniformWithName:(NSString *)name
{
    return globalUniforms[name];
}

+ (void)removeGlobalUniformWithName:(NSString *)name
{
    [globalUniforms removeObjectForKey:name];
    globalUniformsSeed++;
}

#pragma Properties

- (void)setProgram:(SPProgram *)program
{
    if (program != _program)
    {
        SP_RELEASE_AND_RETAIN(_program, program);

        if (_program)
        {
            // default uniforms
            _uTexture   = [_program uniformByName:@"uTexture"];
            _uMvpMatrix = [_program uniformByName:@"uMvpMatrix"];
            _uTintColor = [_program uniformByName:@"uTintColor"];

            // default attributes
            _aPosition  = [_program attributeByName:@"aPosition"];
            _aColor     = [_program attributeByName:@"aColor"];
            _aTexCoords = [_program attributeByName:@"aTexCoords"];
        }
    }
}

- (NSArray *)uniforms
{
    return _uniforms.allValues;
}

#pragma Private

- (void)syncUpdateList
{
    if (_uniformsDirty || _prevGlobalUniformsSeed != globalUniformsSeed)
    {
        [_updateList removeAllObjects];
        [_updateList addObjectsFromArray:globalUniforms.allValues];
        [_updateList addObjectsFromArray:_uniforms.allValues];

        _prevGlobalUniformsSeed = globalUniformsSeed;
        _uniformsDirty = NO;
    }
}

@end
