//
//  SPColorMatrixFilter.m
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPColorMatrixFilter.h"
#import "SPMatrix.h"
#import "SPNSExtensions.h"
#import "SPOpenGL.h"
#import "SPProgram.h"

// --- public constants ----------------------------------------------------------------------------

const SPColorMatrix SPColorMatrixIdentity = {{ 1,0,0,0,0,
                                               0,1,0,0,0,
                                               0,0,1,0,0,
                                               0,0,0,1,0 }};

// --- private constants ---------------------------------------------------------------------------

static const float LUMA_R = 0.299f;
static const float LUMA_G = 0.587f;
static const float LUMA_B = 0.114f;

static NSString *const SPColorMatrixProgram = @"SPColorMatrixProgram";

// --- internal interface --------------------------------------------------------------------------

@interface SPColorMatrixFilter ()

- (NSString *)fragmentShader;
- (NSString *)vertexShader;
- (void)updateShaderMatrix;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPColorMatrixFilter
{
    SPProgram *_shaderProgram;
    GLKMatrix4 _shaderMatrix;      // offset in range 0-1, changed order
    GLKVector4 _shaderOffset;
    int _uMvpMatrix;
    int _uColorMatrix;
    int _uColorOffset;
}

- (instancetype)init
{
    return [self initWithMatrix:SPColorMatrixIdentity];
}

- (instancetype)initWithMatrix:(SPColorMatrix)colorMatrix
{
    if ((self = [super initWithNumPasses:1 resolution:1.0f]))
    {
        self.colorMatrix = colorMatrix;
    }
    return self;
}

- (void)dealloc
{
    [_shaderProgram release];
    [super dealloc];
}

- (void)invert
{
    SPColorMatrix mtx = {
        -1, 0,  0,  0, 255,
        0, -1,  0,  0, 255,
        0,  0, -1,  0, 255,
        0,  0,  0,  1,   0
    };

    [self concatColorMatrix:mtx];
}

- (void)adjustSaturation:(float)saturation
{

    saturation += 1.0f;

    float invSat  = 1.0f - saturation;
    float invLumR = invSat * LUMA_R;
    float invLumG = invSat * LUMA_G;
    float invLumB = invSat * LUMA_B;

    SPColorMatrix mtx = {
        (invLumR + saturation),  invLumG,               invLumB,               0, 0,
        invLumR,                (invLumG + saturation), invLumB,               0, 0,
        invLumR,                 invLumG,              (invLumB + saturation), 0, 0,
        0,                       0,                     0,                     1, 0
    };

    [self concatColorMatrix:mtx];
}

- (void)adjustContrast:(float)contrast
{
    float s = contrast + 1.0f;
    float o = 128 * (1.0f - s);

    SPColorMatrix mtx = {
        s, 0, 0, 0, o,
        0, s, 0, 0, o,
        0, 0, s, 0, o,
        0, 0, 0, s, 0
    };

    [self concatColorMatrix:mtx];
}

- (void)adjustBrightness:(float)brightness
{
    brightness *= 255;

    SPColorMatrix mtx = {
        1, 0, 0, 0, brightness,
        0, 1, 0, 0, brightness,
        0, 0, 1, 0, brightness,
        0, 0, 0, 1, 0
    };

    [self concatColorMatrix:mtx];
}

- (void)adjustHue:(float)hue
{
    hue *= PI;

    float cos = cosf(hue);
    float sin = sinf(hue);

    SPColorMatrix mtx =
    {
        // r1
        ((LUMA_R + (cos * (1.0f - LUMA_R))) + (sin * -(LUMA_R))),
        ((LUMA_G + (cos * -(LUMA_G))) + (sin * -(LUMA_G))),
        ((LUMA_B + (cos * -(LUMA_B))) + (sin * (1.0f - LUMA_B))),
        0.0f,
        0.0f,
        // r2
        ((LUMA_R + (cos * -(LUMA_R))) + (sin * 0.143f)),
        ((LUMA_G + (cos * (1.0f - LUMA_G))) + (sin * 0.14f)),
        ((LUMA_B + (cos * -(LUMA_B))) + (sin * -0.283f)),
        0.0f,
        0.0f,
        // r3
        ((LUMA_R + (cos * -(LUMA_R))) + (sin * -((1.0f - LUMA_R)))),
        ((LUMA_G + (cos * -(LUMA_G))) + (sin * LUMA_G)),
        ((LUMA_B + (cos * (1.0f - LUMA_B))) + (sin * LUMA_B)),
        0.0f,
        0.0f,
        // r4
        0.0f, 0.0f, 0.0f, 1.0f, 0.0f
    };

    [self concatColorMatrix:mtx];
}

- (void)reset
{
    _colorMatrix = SPColorMatrixIdentity;
}

- (void)concatColorMatrix:(SPColorMatrix)colorMatrix
{
    int i = 0;
    SPColorMatrix temp;

    for (int y = 0; y < 4; ++y)
    {
        for (int x = 0; x < 5; ++x)
        {
            temp.m[i+x] = colorMatrix.m[i]   * _colorMatrix.m[x] +
                          colorMatrix.m[i+1] * _colorMatrix.m[x+ 5] +
                          colorMatrix.m[i+2] * _colorMatrix.m[x+10] +
                          colorMatrix.m[i+3] * _colorMatrix.m[x+15] +
            (x == 4 ? colorMatrix.m[i + 4] : 0);
        }
        i += 5;
    }

    _colorMatrix = temp;
    [self updateShaderMatrix];
}

- (void)setColorMatrix:(SPColorMatrix)colorMatrix
{
    _colorMatrix = colorMatrix;
    [self updateShaderMatrix];
}

- (void)createPrograms
{
    if (!_shaderProgram)
    {
        _shaderProgram = [[[Sparrow currentController] programByName:SPColorMatrixProgram] retain];

        if (!_shaderProgram)
        {
            NSString *vertexShader = [self vertexShader];
            NSString *fragmentShader = [self fragmentShader];

            _shaderProgram = [[SPProgram alloc] initWithVertexShader:vertexShader fragmentShader:fragmentShader];
            [[Sparrow currentController] registerProgram:_shaderProgram name:SPColorMatrixProgram];
        }

        self.vertexPosID = [_shaderProgram attributeByName:@"aPosition"];
        self.texCoordsID = [_shaderProgram attributeByName:@"aTexCoords"];

        _uColorMatrix   = [_shaderProgram uniformByName:@"uColorMatrix"];
        _uColorOffset   = [_shaderProgram uniformByName:@"uColorOffset"];
        _uMvpMatrix     = [_shaderProgram uniformByName:@"uMvpMatrix"];
    }
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture mvpMatrix:(SPMatrix *)matrix
{
    glUseProgram(_shaderProgram.name);

    GLKMatrix4 mvp = [matrix convertToGLKMatrix4];
    glUniformMatrix4fv(_uMvpMatrix, 1, false, mvp.m);

    glUniformMatrix4fv(_uColorMatrix, 1, false, _shaderMatrix.m);
    glUniform4fv(_uColorOffset, 1, _shaderOffset.v);
}

- (NSString *)vertexShader
{
    NSMutableString *source = [NSMutableString string];

    // variables
    [source appendLine:@"attribute vec4 aPosition;"];
    [source appendLine:@"attribute lowp vec2 aTexCoords;"];

    [source appendLine:@"uniform mat4 uMvpMatrix;"];

    [source appendLine:@"varying lowp vec2 vTexCoords;"];

    [source appendLine:@"void main() {"];

    [source appendLine:@"  gl_Position = uMvpMatrix * aPosition;"];
    [source appendLine:@"  vTexCoords  = aTexCoords;"];

    [source appendLine:@"}"];

    return source;
}

- (NSString *)fragmentShader
{
    NSMutableString *source = [NSMutableString string];

    [source appendLine:@"uniform lowp mat4 uColorMatrix;"];
    [source appendLine:@"uniform lowp vec4 uColorOffset;"];
    [source appendLine:@"uniform lowp sampler2D uTexture;"];

    [source appendLine:@"varying lowp vec2 vTexCoords;"];

    [source appendLine:@"const lowp vec4 MIN_COLOR = vec4(0, 0, 0, 0.0001);"];

    [source appendLine:@"void main() {"];

    [source appendLine:@"  lowp vec4 texColor = texture2D(uTexture, vTexCoords);"]; // read texture color
    [source appendLine:@"  texColor = max(texColor, MIN_COLOR);"];                  // avoid division through zero in next step
    [source appendLine:@"  texColor.xyz /= texColor.www;"];                         // restore original(non-PMA) RGB values
    [source appendLine:@"  texColor *= uColorMatrix;"];                             // multiply color with 4x4 matrix
    [source appendLine:@"  texColor += uColorOffset;"];                             // add offset
    [source appendLine:@"  texColor.xyz *= texColor.www;"];                         // multiply with alpha again(PMA)
    [source appendLine:@"  gl_FragColor = texColor;"];                              // copy to output

    [source appendLine:@"}"];

    return source;
}

- (void)updateShaderMatrix
{
    // the shader needs the matrix components in a different order,
    // and it needs the offsets in the range 0-1.

    _shaderMatrix = (GLKMatrix4){
        _colorMatrix.m[ 0], _colorMatrix.m[ 1], _colorMatrix.m[ 2], _colorMatrix.m[ 3],
        _colorMatrix.m[ 5], _colorMatrix.m[ 6], _colorMatrix.m[ 7], _colorMatrix.m[ 8],
        _colorMatrix.m[10], _colorMatrix.m[11], _colorMatrix.m[12], _colorMatrix.m[13],
        _colorMatrix.m[15], _colorMatrix.m[16], _colorMatrix.m[17], _colorMatrix.m[18]
    };

    _shaderOffset = (GLKVector4){
        _colorMatrix.m[4] / 255.0f, _colorMatrix.m[9] / 255.0f, _colorMatrix.m[14] / 255.0f, _colorMatrix.m[19] / 255.0f
    };
}

+ (instancetype)colorMatrixFilter
{
    return [[[self alloc] init] autorelease];
}

+ (instancetype)colorMatrixFilterWithMatrix:(SPColorMatrix)colorMatrix
{
    return [[[self alloc] initWithMatrix:colorMatrix] autorelease];
}

@end
