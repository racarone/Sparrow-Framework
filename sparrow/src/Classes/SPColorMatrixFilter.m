//
//  SPColorMatrixFilter.m
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPColorMatrix.h>
#import <Sparrow/SPColorMatrixFilter.h>
#import <Sparrow/SPEffect.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPProgram.h>

static NSString *const SPColorMatrixProgram = @"SPColorMatrixProgram";

// --- shaders -------------------------------------------------------------------------------------

static NSString *const SPColorMatrixShader =
    @"uniform lowp mat4 uColorMatrix;"
    @"uniform lowp vec4 uColorOffset;"
    @"uniform lowp sampler2D uTexture;"

    @"varying lowp vec2 vTexCoords;"

    @"const lowp vec4 MIN_COLOR = vec4(0, 0, 0, 0.0001);"

    @"void main() {"
    @"  lowp vec4 texColor = texture2D(uTexture, vTexCoords);" // read texture color
    @"  texColor = max(texColor, MIN_COLOR);"                  // avoid division through zero in next step
    @"  texColor.xyz /= texColor.www;"                         // restore original(non-PMA) RGB values
    @"  texColor *= uColorMatrix;"                             // multiply color with 4x4 matrix
    @"  texColor += uColorOffset;"                             // add offset
    @"  texColor.xyz *= texColor.www;"                         // multiply with alpha again(PMA)
    @"  gl_FragColor = texColor;"                              // copy to output
    @"}";

// --- class implementation ------------------------------------------------------------------------

@implementation SPColorMatrixFilter
{
    SPEffect *_effect;
    SPUniform *_uColorMatrix;
    SPUniform *_uColorOffset;

    GLKMatrix4 _shaderMatrix;
    GLKVector4 _shaderOffset;

    SPColorMatrix *_colorMatrix;
    BOOL _colorMatrixDirty;
}

#pragma mark Initialization

- (instancetype)initWithMatrix:(SPColorMatrix *)colorMatrix
{
    if ((self = [super initWithNumPasses:1 resolution:1.0f]))
    {
        self.colorMatrix = colorMatrix;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithMatrix:[SPColorMatrix colorMatrixWithIdentity]];
}

- (void)dealloc
{
    [_effect release];
    [_uColorMatrix release];
    [_uColorOffset release];
    [_colorMatrix release];
    [super dealloc];
}

+ (instancetype)colorMatrixFilter
{
    return [[[self alloc] init] autorelease];
}

+ (instancetype)colorMatrixFilterWithMatrix:(SPColorMatrix *)colorMatrix
{
    return [[[self alloc] initWithMatrix:colorMatrix] autorelease];
}

#pragma mark Methods

- (void)invert
{
    [_colorMatrix invert];
    _colorMatrixDirty = YES;
}

- (void)adjustSaturation:(float)saturation
{
    [_colorMatrix adjustSaturation:saturation];
    _colorMatrixDirty = YES;
}

- (void)adjustContrast:(float)contrast
{
    [_colorMatrix adjustContrast:contrast];
    _colorMatrixDirty = YES;
}

- (void)adjustBrightness:(float)brightness
{
    [_colorMatrix adjustBrightness:brightness];
    _colorMatrixDirty = YES;
}

- (void)adjustHue:(float)hue
{
    [_colorMatrix adjustHue:hue];
    _colorMatrixDirty = YES;
}

- (void)reset
{
    [_colorMatrix identity];
    _colorMatrixDirty = YES;
}

- (void)concatColorMatrix:(SPColorMatrix *)colorMatrix
{
    [_colorMatrix concatColorMatrix:colorMatrix];
    _colorMatrixDirty = YES;
}

- (void)setColorMatrix:(SPColorMatrix *)colorMatrix
{
    SP_RELEASE_AND_COPY(_colorMatrix, colorMatrix);
    _colorMatrixDirty = YES;
}

#pragma mark SPFragmentFilter (Subclasses)

- (void)createEffects
{
    SPProgram *program = [[Sparrow currentController] programByName:SPColorMatrixProgram];
    if (!program)
    {
        program = [[SPProgram alloc] initWithVertexShader:[SPFragmentFilter standardVertexShader]
                                           fragmentShader:SPColorMatrixShader];

        [[Sparrow currentController] registerProgram:program name:SPColorMatrixProgram];
    }

    _effect = [[SPEffect alloc] initWithProgram:program];
    _uColorMatrix = [[SPUniform alloc] initWithName:@"uColorMatrix"];
    _uColorOffset = [[SPUniform alloc] initWithName:@"uColorOffset"];

    [_effect addUniformsFromArray:@[_uColorMatrix, _uColorOffset]];
}

- (SPEffect *)effectForPass:(int)pass
{
    return _effect;
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture
{
    if (_colorMatrixDirty)
        [self updateShaderMatrix];

    _uColorMatrix.matrix4Value = _shaderMatrix;
    _uColorOffset.vector4Value = _shaderOffset;

    [_effect prepareToDraw];
}

#pragma mark Private

- (void)updateShaderMatrix
{
    // the shader needs the matrix components in a different order,
    // and it needs the offsets in the range 0-1.

    const float *matrix = _colorMatrix.values;

    _shaderMatrix = (GLKMatrix4)
    {
        matrix[ 0], matrix[ 1], matrix[ 2], matrix[ 3],
        matrix[ 5], matrix[ 6], matrix[ 7], matrix[ 8],
        matrix[10], matrix[11], matrix[12], matrix[13],
        matrix[15], matrix[16], matrix[17], matrix[18]
    };

    _shaderOffset = (GLKVector4)
    {
        matrix[4] / 255.0f, matrix[9] / 255.0f, matrix[14] / 255.0f, matrix[19] / 255.0f
    };

    _colorMatrixDirty = NO;
}

@end
