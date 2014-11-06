//
//  SPBaseEffect.m
//  Sparrow
//
//  Created by Daniel Sperl on 12.03.13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPBaseEffect.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPProgram.h>

// --- class implementation ------------------------------------------------------------------------

@implementation SPBaseEffect
{
    BOOL _useTinting;
}

#pragma mark Initialization

- (instancetype)initWithProgram:(SPProgram *)program
{
    if (![self isMemberOfClass:[SPBaseEffect class]])
        [NSException raise:SPExceptionInvalidOperation format:@"Do not subclass SPBaseEffect!"
                                                              @"Subclass SPEffect instead."];

    if (self = [super initWithProgram:program])
    {
        _useTinting = YES;
    }

    return self;
}

#pragma mark Methods

- (void)prepareToDraw
{
    if (!self.program)
    {
        NSString *programName = [self programName];
        self.program = [Sparrow.currentController programByName:programName];

        if (!self.program)
        {
            self.program = [[[SPProgram alloc] initWithVertexShader:[self vertexShader] fragmentShader:[self fragmentShader]] autorelease];
            [Sparrow.currentController registerProgram:self.program name:programName];
        }
    }

    [super prepareToDraw];
}

#pragma mark Properties

- (void)setUseTinting:(BOOL)value
{
    if (value != _useTinting)
    {
        _useTinting = value;
        self.program = nil;
    }
}

- (void)setMainTexture:(SPTexture *)value
{
    if ((self.mainTexture && !value) || (!self.mainTexture && value))
        self.program = nil;

    [super setMainTexture:value];
}

#pragma mark Private

- (NSString *)programName
{
    BOOL hasTexture = self.mainTexture != nil;
    if (hasTexture)
    {
        if (_useTinting) return @"SPQuad#11";
        else             return @"SPQuad#10";
    }
    else
    {
        if (_useTinting) return @"SPQuad#01";
        else             return @"SPQuad#00";
    }
}

- (NSString *)vertexShader
{
    BOOL hasTexture = self.mainTexture != nil;
    NSMutableString *source = [NSMutableString string];

    // variables

    [source appendLine:@"attribute vec4 aPosition;"];
    if (_useTinting) [source appendLine:@"attribute vec4 aColor;"];
    if (hasTexture)  [source appendLine:@"attribute vec2 aTexCoords;"];

    [source appendLine:@"uniform mat4 uMvpMatrix;"];
    if (_useTinting)  [source appendLine:@"uniform vec4 uTintColor;"];

    if (_useTinting)  [source appendLine:@"varying lowp vec4 vTintColor;"];
    if (hasTexture) [source appendLine:@"varying lowp vec2 vTexCoords;"];

    // main

    [source appendLine:@"void main() {"];

    [source appendLine:@"  gl_Position = uMvpMatrix * aPosition;"];
    if (_useTinting)  [source appendLine:@"  vTintColor = aColor * uTintColor;"];
    if (hasTexture) [source appendLine:@"  vTexCoords  = aTexCoords;"];

    [source appendLine:@"}"];

    return source;
}

- (NSString *)fragmentShader
{
    BOOL hasTexture = self.mainTexture != nil;
    NSMutableString *source = [NSMutableString string];

    // variables

    if (_useTinting)
        [source appendLine:@"varying lowp vec4 vTintColor;"];

    if (hasTexture)
    {
        [source appendLine:@"varying lowp vec2 vTexCoords;"];
        [source appendLine:@"uniform lowp sampler2D uTexture;"];
    }

    // main

    [source appendLine:@"void main() {"];

    if (hasTexture)
    {
        if (_useTinting)
            [source appendLine:@"  gl_FragColor = texture2D(uTexture, vTexCoords) * vTintColor;"];
        else
            [source appendLine:@"  gl_FragColor = texture2D(uTexture, vTexCoords);"];
    }
    else
        [source appendLine:@"  gl_FragColor = vTintColor;"];
    
    [source appendLine:@"}"];
    
    return source;
}

@end
