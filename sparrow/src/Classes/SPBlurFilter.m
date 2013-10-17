//
//  SPBlurFilter.m
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPBlurFilter.h"
#import "SPMatrix.h"
#import "SPNSExtensions.h"
#import "SPOpenGL.h"
#import "SPProgram.h"
#import "SPTexture.h"

enum {
    PROGRAM_NORMAL,
    PROGRAM_TINTED,
    PROGRAM_COUNT,
};

NSString *getBlurProgramName(BOOL useTinting)
{
    if (useTinting) return @"SPBlurFilter#1";
    else            return @"SPBlurFilter#0";
}

// --- private interface ---------------------------------------------------------------------------

@interface SPBlurFilter ()

- (NSString *)vertexShader:(BOOL)isTinted;
- (NSString *)fragmentShader:(BOOL)isTinted;
- (void)updateParamatersWithPass:(int)pass texWidth:(int)texWidth texHeight:(int)texHeight;
- (void)updateMarginsAndPasses;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPBlurFilter
{
    BOOL _uniformColor;
    float _offsets[4];
    float _weights[4];
    float _color[4];
    SPProgram *_programs[2];
    int _uOffsets[2];
    int _uWeights[2];
    int _uColor[2];
    int _uMvpMatrix[2];
}

- (instancetype)init
{
    return [self initWithBlur:1.0f];
}

- (instancetype)initWithBlur:(float)blur
{
    return [self initWithBlur:blur resolution:1.0f];
}

- (instancetype)initWithBlur:(float)blur resolution:(float)resolution
{
    if ((self = [super initWithNumPasses:1 resolution:resolution]))
    {
        _blurX = blur;
        _blurY = blur;

        [self updateMarginsAndPasses];
    }
    return self;
}

- (void)dealloc
{
    [_programs[0] release];
    [_programs[1] release];
    [super dealloc];
}

- (void)setUniformColor:(BOOL)enable
{
    [self setUniformColor:enable color:SPColorBlack];
}

- (void)setUniformColor:(BOOL)enable color:(uint)color
{
    [self setUniformColor:enable color:color alpha:1.0f];
}

- (void)setUniformColor:(BOOL)enable color:(uint)color alpha:(float)alpha
{
    _color[0] = SP_COLOR_PART_RED(color) / 255.0;
    _color[1] = SP_COLOR_PART_GREEN(color) / 255.0;
    _color[2] = SP_COLOR_PART_BLUE(color) / 255.0;
    _color[3] = alpha;
    _uniformColor = enable;
}

- (void)setBlurX:(float)blurX
{
    _blurX = blurX;
    [self updateMarginsAndPasses];
}

- (void)setBlurY:(float)blurY
{
    _blurY = blurY;
    [self updateMarginsAndPasses];
}

- (void)createPrograms
{
    if (!_programs[PROGRAM_NORMAL])
    {
        NSString *programName = getBlurProgramName(NO);
        _programs[PROGRAM_NORMAL] = [[[Sparrow currentController] programByName:programName] retain];

        if (!_programs[PROGRAM_NORMAL])
        {
            NSString *vertexShader = [self vertexShader:NO];
            NSString *fragmentShader = [self fragmentShader:NO];
            _programs[PROGRAM_NORMAL] = [[SPProgram alloc] initWithVertexShader:vertexShader fragmentShader:fragmentShader];
            [[Sparrow currentController] registerProgram:_programs[PROGRAM_NORMAL] name:programName];
        }

        _uOffsets[PROGRAM_NORMAL] = [_programs[PROGRAM_NORMAL] uniformByName:@"uOffsets"];
        _uWeights[PROGRAM_NORMAL] = [_programs[PROGRAM_NORMAL] uniformByName:@"uWeights"];
        _uColor[PROGRAM_NORMAL] = [_programs[PROGRAM_NORMAL] uniformByName:@"uColor"];
        _uMvpMatrix[PROGRAM_NORMAL] = [_programs[PROGRAM_NORMAL] uniformByName:@"uMvpMatrix"];
    }

    if (!_programs[PROGRAM_TINTED])
    {
        NSString *programName = getBlurProgramName(YES);
        _programs[PROGRAM_TINTED] = [[[Sparrow currentController] programByName:programName] retain];

        if (!_programs[PROGRAM_TINTED])
        {
            NSString *vertexShader = [self vertexShader:YES];
            NSString *fragmentShader = [self fragmentShader:YES];
            _programs[PROGRAM_TINTED] = [[SPProgram alloc] initWithVertexShader:vertexShader fragmentShader:fragmentShader];
            [[Sparrow currentController] registerProgram:_programs[PROGRAM_TINTED] name:programName];
        }

        _uOffsets[PROGRAM_TINTED] = [_programs[PROGRAM_TINTED] uniformByName:@"uOffsets"];
        _uWeights[PROGRAM_TINTED] = [_programs[PROGRAM_TINTED] uniformByName:@"uWeights"];
        _uColor[PROGRAM_TINTED] = [_programs[PROGRAM_TINTED] uniformByName:@"uColor"];
        _uMvpMatrix[PROGRAM_TINTED] = [_programs[PROGRAM_TINTED] uniformByName:@"uMvpMatrix"];
    }

    self.vertexPosID = [_programs[PROGRAM_NORMAL] attributeByName:@"aPosition"];
    self.texCoordsID = [_programs[PROGRAM_NORMAL] attributeByName:@"aTexCoords"];
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture mvpMatrix:(SPMatrix *)matrix
{
    [self updateParamatersWithPass:pass texWidth:texture.nativeWidth texHeight:texture.nativeHeight];

    BOOL isColorPass = _uniformColor && pass == self.numPasses - 1;
    int idx = isColorPass ? PROGRAM_TINTED : PROGRAM_NORMAL;

    glUseProgram(_programs[idx].name);

    GLKMatrix4 mvp = [matrix convertToGLKMatrix4];
    glUniformMatrix4fv(_uMvpMatrix[idx], 1, false, mvp.m);

    glUniform4fv(_uOffsets[idx], 1, _offsets);
    glUniform4fv(_uWeights[idx], 1, _weights);

    if (isColorPass)
        glUniform4fv(_uColor[idx], 1, _color);
}

- (NSString *)vertexShader:(BOOL)isTinted
{
    NSMutableString *vertSource = [NSMutableString string];

    // attributes
    [vertSource appendLine:@"attribute vec4 aPosition;"];
    [vertSource appendLine:@"attribute lowp vec2 aTexCoords;"];

    // uniforms
    [vertSource appendLine:@"uniform mat4 uMvpMatrix;"];
    [vertSource appendLine:@"uniform lowp vec4 uOffsets;"];

    // varying
    [vertSource appendLine:@"varying lowp vec2 v0;"];
    [vertSource appendLine:@"varying lowp vec2 v1;"];
    [vertSource appendLine:@"varying lowp vec2 v2;"];
    [vertSource appendLine:@"varying lowp vec2 v3;"];
    [vertSource appendLine:@"varying lowp vec2 v4;"];

    // main
    [vertSource appendLine:@"void main() {"];

    [vertSource appendLine:@"  gl_Position = uMvpMatrix * aPosition;"];     // 4x4 matrix transform to output space
    [vertSource appendLine:@"  v0 = aTexCoords;"];                          // pos:  0 |
    [vertSource appendLine:@"  v1 = aTexCoords - uOffsets.zw;"];            // pos: -2 |
    [vertSource appendLine:@"  v2 = aTexCoords - uOffsets.xy;"];            // pos: -1 | --> kernel positions
    [vertSource appendLine:@"  v3 = aTexCoords + uOffsets.xy;"];            // pos: +1 |     (only 1st two parts are relevant)
    [vertSource appendLine:@"  v4 = aTexCoords + uOffsets.zw;"];            // pos: +2 |

    [vertSource appendLine:@"}"];

    return vertSource;
}

- (NSString *)fragmentShader:(BOOL)isTinted
{
    NSMutableString *fragSource = [NSMutableString string];

    // variables

    [fragSource appendLine:@"varying lowp vec2 v0;"];
    [fragSource appendLine:@"varying lowp vec2 v1;"];
    [fragSource appendLine:@"varying lowp vec2 v2;"];
    [fragSource appendLine:@"varying lowp vec2 v3;"];
    [fragSource appendLine:@"varying lowp vec2 v4;"];

    if (isTinted) [fragSource appendLine:@"uniform lowp vec4 uColor;"];
    [fragSource appendLine:@"uniform sampler2D uTexture;"];
    [fragSource appendLine:@"uniform lowp vec4 uWeights;"];

    // main

    [fragSource appendLine:@"void main() {"];

    [fragSource appendLine:@"  lowp vec4 ft0;"];
    [fragSource appendLine:@"  lowp vec4 ft1;"];
    [fragSource appendLine:@"  lowp vec4 ft2;"];
    [fragSource appendLine:@"  lowp vec4 ft3;"];
    [fragSource appendLine:@"  lowp vec4 ft4;"];
    [fragSource appendLine:@"  lowp vec4 ft5;"];

    [fragSource appendLine:@"  ft0 = texture2D(uTexture,v0);"];  // read center pixel
    [fragSource appendLine:@"  ft5 = ft0 * uWeights.xxxx;"];     // multiply with center weight

    [fragSource appendLine:@"  ft1 = texture2D(uTexture,v1);"];  // read pixel -2
    [fragSource appendLine:@"  ft1 = ft1 * uWeights.zzzz;"];     // multiply with weight
    [fragSource appendLine:@"  ft5 = ft5 + ft1;"];               // add to output color

    [fragSource appendLine:@"  ft2 = texture2D(uTexture,v2);"];  // read pixel -1
    [fragSource appendLine:@"  ft2 = ft2 * uWeights.yyyy;"];     // multiply with weight
    [fragSource appendLine:@"  ft5 = ft5 + ft2;"];               // add to output color

    [fragSource appendLine:@"  ft3 = texture2D(uTexture,v3);"];  // read pixel +1
    [fragSource appendLine:@"  ft3 = ft3 * uWeights.yyyy;"];     // multiply with weight
    [fragSource appendLine:@"  ft5 = ft5 + ft3;"];               // add to output color

    [fragSource appendLine:@"  ft4 = texture2D(uTexture,v4);"];  // read pixel +2
    [fragSource appendLine:@"  ft4 = ft4 * uWeights.zzzz;"];     // multiply with weight

    if (isTinted)
    {
        [fragSource appendLine:@"  ft5 = ft5 + ft4;"];                   // add to output color
        [fragSource appendLine:@"  ft5.xyz = uColor.xyz * ft5.www;"];    // set rgb with correct alpha
        [fragSource appendLine:@"  gl_FragColor = ft5 * uColor.wwww;"];  // multiply alpha
    }
    else
    {
        [fragSource appendLine:@"  gl_FragColor = ft5 + ft4;"];          // add to output color
    }

    [fragSource appendLine:@"}"];

    return fragSource;
}

- (void)updateParamatersWithPass:(int)pass texWidth:(int)texWidth texHeight:(int)texHeight
{
    static const float MAX_SIGMA = 2.0f;

    // algorithm described here:
    // http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
    //
    // To run in constrained mode, we can only make 5 texture lookups in the fragment
    // shader. By making use of linear texture sampling, we can produce similar output
    // to what would be 9 lookups.

    bool horizontal = pass < _blurX;
    float sigma;
    float pixelSize;

    if (horizontal)
    {
        sigma = MIN(1.0f, _blurX - pass) * MAX_SIGMA;
        pixelSize = 1.0f / texWidth;
    }
    else
    {
        sigma = MIN(1.0f, _blurY - (pass - ceilf(_blurX))) * MAX_SIGMA;
        pixelSize = 1.0f / texHeight;
    }

    const float twoSigmaSq = 2.0f * sigma * sigma;
    const float multiplier = 1.0f / sqrtf(twoSigmaSq * PI);

    // get weights on the exact pixels(sTmpWeights) and calculate sums(_weights)
    float sTmpWeights[6];

    for (int i = 0; i < 5; ++i)
        sTmpWeights[i] = multiplier * expf(-i*i / twoSigmaSq);

    _weights[0] = sTmpWeights[0];
    _weights[1] = sTmpWeights[1] + sTmpWeights[2];
    _weights[2] = sTmpWeights[3] + sTmpWeights[4];

    // normalize weights so that sum equals "1.0"

    float weightSum = _weights[0] + (2.0f * _weights[1]) + (2.0f * _weights[2]);
    float invWeightSum = 1.0f / weightSum;

    _weights[0] *= invWeightSum;
    _weights[1] *= invWeightSum;
    _weights[2] *= invWeightSum;

    // calculate intermediate offsets

    float offset1 = (pixelSize * sTmpWeights[1] + 2*pixelSize * sTmpWeights[2]) / _weights[1];
    float offset2 = (3*pixelSize * sTmpWeights[3] + 4*pixelSize * sTmpWeights[4]) / _weights[2];

    // depending on pass, we move in x- or y-direction

    if (horizontal)
    {
        _offsets[0] = offset1;
        _offsets[1] = 0;
        _offsets[2] = offset2;
        _offsets[3] = 0;
    }
    else
    {
        _offsets[0] = 0;
        _offsets[1] = offset1;
        _offsets[2] = 0;
        _offsets[3] = offset2;
    }
}

- (void)updateMarginsAndPasses
{
    if (_blurX == 0 && _blurY == 0)
        _blurX = 0.001;

    self.numPasses = ceilf(_blurX) + ceilf(_blurY);
    self.marginX = 4.0f + ceilf(_blurX);
    self.marginY = 4.0f + ceilf(_blurY);
}

+ (instancetype)blurFilter
{
    return [[[self alloc] init] autorelease];
}

+ (instancetype)blurFilterWithBlur:(float)blur
{
    return [[[self alloc] initWithBlur:blur] autorelease];
}

+ (instancetype)blurFilterWithBlur:(float)blur resolution:(float)resolution
{
    return [[[self alloc] initWithBlur:blur resolution:resolution] autorelease];
}

+ (instancetype)dropShadow
{
    return [self dropShadowWithDistance:4.0f];
}

+ (instancetype)dropShadowWithDistance:(float)distance
{
    return [self dropShadowWithDistance:distance angle:0.785f];
}

+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle
{
    return [self dropShadowWithDistance:distance angle:angle color:SPColorBlack];
}

+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color
{
    return [self dropShadowWithDistance:distance angle:angle color:color alpha:0.5f];
}

+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color alpha:(float)alpha
{
    return [self dropShadowWithDistance:distance angle:angle color:color alpha:alpha blur:1.0f];
}

+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color alpha:(float)alpha blur:(float)blur
{
    return [self dropShadowWithDistance:distance angle:angle color:color alpha:alpha blur:blur resolution:0.5f];
}

+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color alpha:(float)alpha blur:(float)blur resolution:(float)resolution
{
    SPBlurFilter *dropShadow = [SPBlurFilter blurFilterWithBlur:blur resolution:resolution];
    dropShadow.offsetX = cosf(angle) * distance;
    dropShadow.offsetY = sinf(angle) * distance;
    dropShadow.mode = SPFragmentFilterModeBelow;
    [dropShadow setUniformColor:YES color:color alpha:alpha];
    return dropShadow;
}

+ (instancetype)glow
{
    return [self glowWithColor:SPColorYellow];
}

+ (instancetype)glowWithColor:(uint)color
{
    return [self glowWithColor:color alpha:1.0f];
}

+ (instancetype)glowWithColor:(uint)color alpha:(float)alpha
{
    return [self glowWithColor:color alpha:alpha blur:1.0f];
}

+ (instancetype)glowWithColor:(uint)color alpha:(float)alpha blur:(float)blur
{
    return [self glowWithColor:color alpha:alpha blur:blur resolution:0.5f];
}

+ (instancetype)glowWithColor:(uint)color alpha:(float)alpha blur:(float)blur resolution:(float)resolution
{
    SPBlurFilter *glow = [SPBlurFilter blurFilterWithBlur:blur resolution:resolution];
    glow.mode = SPFragmentFilterModeBelow;
    [glow setUniformColor:YES color:color alpha:alpha];
    return glow;
}

@end
