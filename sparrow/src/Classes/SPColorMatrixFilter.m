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

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPColorMatrix.h>
#import <Sparrow/SPColorMatrixFilter.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPProgram.h>

// --- private interface ---------------------------------------------------------------------------

static NSString *const SPColorMatrixProgram = @"SPColorMatrixProgram";

@interface SPColorMatrixFilter ()

- (NSString *)fragmentShader;
- (void)updateShaderMatrix;

@end


// --- class implementation ------------------------------------------------------------------------

@implementation SPColorMatrixFilter
{
    SPProgram *_shaderProgram;
    SPColorMatrix *_colorMatrix;
    BOOL _colorMatrixDirty;
    GLKMatrix4 _shaderMatrix; // offset in range 0-1, changed order
    GLKVector4 _shaderOffset;
    int _uMvpMatrix;
    int _uColorMatrix;
    int _uColorOffset;
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
    [_shaderProgram release];
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

- (void)createPrograms
{
    if (!_shaderProgram)
    {
        _shaderProgram = [[[Sparrow currentController] programByName:SPColorMatrixProgram] retain];

        if (!_shaderProgram)
        {
            _shaderProgram = [[SPProgram alloc] initWithVertexShader:[SPFragmentFilter standardVertexShader]
                                                      fragmentShader:[self fragmentShader]];

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
    if (_colorMatrixDirty)
        [self updateShaderMatrix];

    glUseProgram(_shaderProgram.name);

    GLKMatrix4 mvp = [matrix convertToGLKMatrix4];
    glUniformMatrix4fv(_uMvpMatrix, 1, false, mvp.m);

    glUniformMatrix4fv(_uColorMatrix, 1, false, _shaderMatrix.m);
    glUniform4fv(_uColorOffset, 1, _shaderOffset.v);
}

#pragma mark Private

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

    const float *matrix = _colorMatrix.values;

    _shaderMatrix = (GLKMatrix4){
        matrix[ 0], matrix[ 1], matrix[ 2], matrix[ 3],
        matrix[ 5], matrix[ 6], matrix[ 7], matrix[ 8],
        matrix[10], matrix[11], matrix[12], matrix[13],
        matrix[15], matrix[16], matrix[17], matrix[18]
    };

    _shaderOffset = (GLKVector4){
        matrix[4] / 255.0f, matrix[9] / 255.0f, matrix[14] / 255.0f, matrix[19] / 255.0f
    };

    _colorMatrixDirty = NO;
}

@end
