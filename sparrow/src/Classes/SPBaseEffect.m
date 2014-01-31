//
//  SPBaseEffect.m
//  Sparrow
//
//  Created by Daniel Sperl on 12.03.13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPBaseEffect.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPProgram.h>
#import <Sparrow/SPTexture.h>

static NSString *getProgramName(BOOL hasTexture, BOOL useTinting)
{
    if (hasTexture)
    {
        if (useTinting) return @"SPQuad#11";
        else            return @"SPQuad#10";
    }
    else
    {
        if (useTinting) return @"SPQuad#01";
        else            return @"SPQuad#00";
    }
}

// --- private interface ---------------------------------------------------------------------------

@interface SPBaseEffect ()

- (NSString *)vertexShaderForTexture:(SPTexture *)texture useTinting:(BOOL)useTinting;
- (NSString *)fragmentShaderForTexture:(SPTexture *)texture useTinting:(BOOL)useTinting;

@end


// --- class implementation ------------------------------------------------------------------------

@implementation SPBaseEffect
{
    SPMatrix  *_mvpMatrix;
    SPTexture *_texture;
    float _alpha;
    BOOL _useTinting;
    BOOL _premultipliedAlpha;
    
    SPProgram *_program;
    int _aPosition;
    int _aColor;
    int _aTexCoords;
    int _uMvpMatrix;
    int _uAlpha;
}

@synthesize attribPosition = _aPosition;
@synthesize attribColor = _aColor;
@synthesize attribTexCoords = _aTexCoords;

#pragma mark Initialization

- (instancetype)init
{
    if ((self = [super init]))
    {
        _mvpMatrix = [[SPMatrix alloc] init];
        _premultipliedAlpha = NO;
        _useTinting = YES;
        _alpha = 1.0f;
    }
    return self;
}

- (void)dealloc
{
    [_mvpMatrix release];
    [_texture release];
    [_program release];
    [super dealloc];
}

#pragma mark Methods

- (void)prepareToDraw
{
    BOOL hasTexture = _texture != nil;
    BOOL useTinting = _useTinting || !_texture || _alpha != 1.0f;

    if (!_program)
    {
        NSString *programName = getProgramName(hasTexture, useTinting);
        _program = [[Sparrow.currentController programByName:programName] retain];
        
        if (!_program)
        {
            NSString *vertexShader   = [self vertexShaderForTexture:_texture   useTinting:useTinting];
            NSString *fragmentShader = [self fragmentShaderForTexture:_texture useTinting:useTinting];
            _program = [[SPProgram alloc] initWithVertexShader:vertexShader fragmentShader:fragmentShader];
            [Sparrow.currentController registerProgram:_program name:programName];
        }
        
        _aPosition  = [_program attributeByName:@"aPosition"];
        _aColor     = [_program attributeByName:@"aColor"];
        _aTexCoords = [_program attributeByName:@"aTexCoords"];
        _uMvpMatrix = [_program uniformByName:@"uMvpMatrix"];
        _uAlpha     = [_program uniformByName:@"uAlpha"];
    }
    
    GLKMatrix4 glkMvpMatrix = [_mvpMatrix convertToGLKMatrix4];
    
    glUseProgram(_program.name);
    glUniformMatrix4fv(_uMvpMatrix, 1, NO, glkMvpMatrix.m);
    
    if (useTinting)
    {
        if (_premultipliedAlpha) glUniform4f(_uAlpha, _alpha, _alpha, _alpha, _alpha);
        else                     glUniform4f(_uAlpha, 1.0f, 1.0f, 1.0f, _alpha);
    }
    
    if (hasTexture)
    {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _texture.name);
    }
}

#pragma mark Properties

- (void)setMvpMatrix:(SPMatrix *)value
{
    [_mvpMatrix copyFromMatrix:value];
}

- (void)setAlpha:(float)value
{
    if ((value >= 1.0f && _alpha < 1.0f) || (value < 1.0f && _alpha >= 1.0f))
        SP_RELEASE_AND_NIL(_program);

    _alpha = value;
}

- (void)setUseTinting:(BOOL)value
{
    if (value != _useTinting)
    {
        _useTinting = value;
        SP_RELEASE_AND_NIL(_program);
    }
}

- (void)setTexture:(SPTexture *)value
{
    if ((_texture && !value) || (!_texture && value))
        SP_RELEASE_AND_NIL(_program);

    SP_RELEASE_AND_RETAIN(_texture, value);
}

#pragma mark Private

- (NSString *)vertexShaderForTexture:(SPTexture *)texture useTinting:(BOOL)useTinting
{
    BOOL hasTexture = texture != nil;
    NSMutableString *source = [NSMutableString string];
    
    // variables
    
    [source appendLine:@"attribute vec4 aPosition;"];
    if (useTinting) [source appendLine:@"attribute vec4 aColor;"];
    if (hasTexture) [source appendLine:@"attribute vec2 aTexCoords;"];

    [source appendLine:@"uniform mat4 uMvpMatrix;"];
    if (useTinting) [source appendLine:@"uniform vec4 uAlpha;"];
    
    if (useTinting) [source appendLine:@"varying lowp vec4 vColor;"];
    if (hasTexture) [source appendLine:@"varying lowp vec2 vTexCoords;"];
    
    // main
    
    [source appendLine:@"void main() {"];
    
    [source appendLine:@"  gl_Position = uMvpMatrix * aPosition;"];
    if (useTinting) [source appendLine:@"  vColor = aColor * uAlpha;"];
    if (hasTexture) [source appendLine:@"  vTexCoords  = aTexCoords;"];
    
    [source appendString:@"}"];
    
    return source;
}

- (NSString *)fragmentShaderForTexture:(SPTexture *)texture useTinting:(BOOL)useTinting
{
    BOOL hasTexture = texture != nil;
    NSMutableString *source = [NSMutableString string];
    
    // variables
    
    if (useTinting)
        [source appendLine:@"varying lowp vec4 vColor;"];
    
    if (hasTexture)
    {
        [source appendLine:@"varying lowp vec2 vTexCoords;"];
        [source appendLine:@"uniform lowp sampler2D uTexture;"];
    }
    
    // main
    
    [source appendLine:@"void main() {"];
    
    if (hasTexture)
    {
        if (useTinting)
            [source appendLine:@"  gl_FragColor = texture2D(uTexture, vTexCoords) * vColor;"];
        else
            [source appendLine:@"  gl_FragColor = texture2D(uTexture, vTexCoords);"];
    }
    else
        [source appendLine:@"  gl_FragColor = vColor;"];
    
    [source appendString:@"}"];
    
    return source;
}

@end
