//
//  SPBlurFilter.m
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPBlurFilter.h>
#import <Sparrow/SPEffect.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPProgram.h>
#import <Sparrow/SPTexture.h>

static NSString *const SPBlurProgram = @"SSPBlurProgram";

// --- shaders -------------------------------------------------------------------------------------

static NSString *const SPBlurVertexShader =
    @"attribute vec4 aPosition; \n"
    @"attribute vec2 aTexCoords; \n"

    @"uniform mat4 uMvpMatrix; \n"
    @"uniform vec4 uOffsets; \n"

    @"varying lowp vec2 v0; \n"
    @"varying lowp vec2 v1; \n"
    @"varying lowp vec2 v2; \n"
    @"varying lowp vec2 v3; \n"
    @"varying lowp vec2 v4; \n"

    @"void main() { \n"
    @"  gl_Position = uMvpMatrix * aPosition; \n" // 4x4 matrix transform to output space
    @"  v0 = aTexCoords; \n"                      // pos:  0 |
    @"  v1 = aTexCoords - uOffsets.zw; \n"        // pos: -2 |
    @"  v2 = aTexCoords - uOffsets.xy; \n"        // pos: -1 | --> kernel positions
    @"  v3 = aTexCoords + uOffsets.xy; \n"        // pos: +1 |     (only 1st two parts are relevant)
    @"  v4 = aTexCoords + uOffsets.zw; \n"        // pos: +2 |
    @"} \n";

static NSString *const SPBlurFragmentShader =
    @"uniform lowp sampler2D uTexture; \n"
    @"uniform lowp vec4 uTintColor; \n"
    @"uniform lowp vec4 uWeights; \n"
    @"uniform lowp float uTinted; \n"

    @"varying lowp vec2 v0; \n"
    @"varying lowp vec2 v1; \n"
    @"varying lowp vec2 v2; \n"
    @"varying lowp vec2 v3; \n"
    @"varying lowp vec2 v4; \n"

    @"void main() { \n"
    @"  lowp vec4 ft0; \n"
    @"  lowp vec4 ft1; \n"
    @"  lowp vec4 ft2; \n"
    @"  lowp vec4 ft3; \n"
    @"  lowp vec4 ft4; \n"
    @"  lowp vec4 ft5; \n"

    @"  ft0 = texture2D(uTexture,v0); \n"             // read center pixel
    @"  ft5 = ft0 * uWeights.xxxx; \n"                // multiply with center weight

    @"  ft1 = texture2D(uTexture,v1); \n"             // read pixel -2
    @"  ft1 = ft1 * uWeights.zzzz; \n"                // multiply with weight
    @"  ft5 = ft5 + ft1; \n"                          // add to output color

    @"  ft2 = texture2D(uTexture,v2); \n"             // read pixel -1
    @"  ft2 = ft2 * uWeights.yyyy; \n"                // multiply with weight
    @"  ft5 = ft5 + ft2; \n"                          // add to output color

    @"  ft3 = texture2D(uTexture,v3); \n"             // read pixel +1
    @"  ft3 = ft3 * uWeights.yyyy; \n"                // multiply with weight
    @"  ft5 = ft5 + ft3; \n"                          // add to output color

    @"  ft4 = texture2D(uTexture,v4); \n"             // read pixel +2
    @"  ft4 = ft4 * uWeights.zzzz; \n"                // multiply with weight

    @"  if (uTinted == 1.0) { \n"
    @"      ft5 = ft5 + ft4;"                         // add to output color
    @"      ft5.xyz = uTintColor.xyz * ft5.www; \n"   // set rgb with correct alpha
    @"      gl_FragColor = ft5 * uTintColor.wwww; \n" // multiply alpha
    @"  } else { \n"
    @"      gl_FragColor = ft5 + ft4; \n"             // add to output color
    @"  } \n"
    @"} \n";

// --- class implementation ------------------------------------------------------------------------

@implementation SPBlurFilter
{
    BOOL _enableColor;
    GLKVector4 _offsets;
    GLKVector4 _weights;
    GLKVector4 _color;

    SPEffect *_effect;
    SPUniform *_uOffsets;
    SPUniform *_uWeights;
    SPUniform *_uTinted;
}

#pragma mark Initialization

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
        _color.a = 1.0f;

        [self updateMarginsAndPasses];
    }
    return self;
}

- (void)dealloc
{
    [_effect release];
    [_uOffsets release];
    [_uWeights release];
    [_uTinted release];
    [super dealloc];
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

#pragma mark SPFragmentFilter (Subclasses)

- (void)createEffects
{
    SPProgram *program = [[Sparrow currentController] programByName:SPBlurProgram];
    if (!program)
    {
        program = [[SPProgram alloc] initWithVertexShader:SPBlurVertexShader
                                           fragmentShader:SPBlurFragmentShader];

        [[Sparrow currentController] registerProgram:program name:SPBlurProgram];
    }

    _effect = [[SPEffect alloc] initWithProgram:program];
    _uOffsets = [[SPUniform alloc] initWithName:@"uOffsets"];
    _uWeights = [[SPUniform alloc] initWithName:@"uWeights"];
    _uTinted  = [[SPUniform alloc] initWithName:@"uTinted"];

    [_effect addUniformsFromArray:@[_uOffsets, _uWeights, _uTinted]];
}

- (SPEffect *)effectForPass:(int)pass
{
    return _effect;
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture
{
    [self updateParamatersWithPass:pass texWidth:texture.nativeWidth texHeight:texture.nativeHeight];

    BOOL isColorPass = _enableColor && pass == self.numPasses - 1;

    _effect.tintColor = _color;
    _uTinted.floatValue = isColorPass ? 1 : 0;

    _uOffsets.vector4Value = _offsets;
    _uWeights.vector4Value = _weights;

    [_effect prepareToDraw];
}

#pragma mark Properties

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

- (uint)color
{
    return SP_COLOR(_color.r * 255, _color.g * 255, _color.b * 255);
}

- (void)setColor:(uint)color
{
    _color = GLKVector4Make(SP_COLOR_PART_RED(color)   / 255.0f,
                            SP_COLOR_PART_GREEN(color) / 255.0f,
                            SP_COLOR_PART_BLUE(color)  / 255.0f,
                            _color.a);
    _enableColor = YES;
}

- (float)alpha
{
    return _color.a;
}

- (void)setAlpha:(float)alpha
{
    _color.a = alpha;
    _enableColor = YES;
}

#pragma mark Private

- (void)updateParamatersWithPass:(int)pass texWidth:(int)texWidth texHeight:(int)texHeight
{
    static const float MAX_SIGMA = 2.0f;

    // algorithm described here:
    // http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
    //
    // Normally, we'd have to use 9 texture lookups in the fragment shader. But by making smart
    // use of linear texture sampling, we can produce the same output with only 5 lookups.

    const bool horizontal = pass < _blurX;
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

    _weights.v[0] = sTmpWeights[0];
    _weights.v[1] = sTmpWeights[1] + sTmpWeights[2];
    _weights.v[2] = sTmpWeights[3] + sTmpWeights[4];

    // normalize weights so that sum equals "1.0"

    const float weightSum = _weights.v[0] + (2.0f * _weights.v[1]) + (2.0f * _weights.v[2]);
    const float invWeightSum = 1.0f / weightSum;

    _weights.v[0] *= invWeightSum;
    _weights.v[1] *= invWeightSum;
    _weights.v[2] *= invWeightSum;

    // calculate intermediate offsets

    float offset1 = (  pixelSize * sTmpWeights[1] + 2*pixelSize * sTmpWeights[2]) / _weights.v[1];
    float offset2 = (3*pixelSize * sTmpWeights[3] + 4*pixelSize * sTmpWeights[4]) / _weights.v[2];

    // depending on pass, we move in x- or y-direction

    if (horizontal)
    {
        _offsets.v[0] = offset1;
        _offsets.v[1] = 0;
        _offsets.v[2] = offset2;
        _offsets.v[3] = 0;
    }
    else
    {
        _offsets.v[0] = 0;
        _offsets.v[1] = offset1;
        _offsets.v[2] = 0;
        _offsets.v[3] = offset2;
    }
}

- (void)updateMarginsAndPasses
{
    if (_blurX == 0 && _blurY == 0)
        _blurX = 0.001;

    self.numPasses = ceilf(_blurX) + ceilf(_blurY);
    self.marginX = (3.0f + ceilf(_blurX)) / self.resolution;
    self.marginY = (3.0f + ceilf(_blurY)) / self.resolution;
}

#pragma mark Drop Shadow

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

+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color
                                 alpha:(float)alpha
{
    return [self dropShadowWithDistance:distance angle:angle color:color alpha:alpha blur:1.0f];
}

+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color
                                 alpha:(float)alpha blur:(float)blur
{
    return [self dropShadowWithDistance:distance angle:angle color:color alpha:alpha blur:blur resolution:0.5f];
}

+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color
                                 alpha:(float)alpha blur:(float)blur resolution:(float)resolution
{
    SPBlurFilter *dropShadow = [SPBlurFilter blurFilterWithBlur:blur resolution:resolution];
    dropShadow.offsetX = cosf(angle) * distance;
    dropShadow.offsetY = sinf(angle) * distance;
    dropShadow.mode = SPFragmentFilterModeBelow;
    dropShadow.color = color;
    dropShadow.alpha = alpha;
    dropShadow.enableColor = YES;
    return dropShadow;
}

#pragma mark Glow

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

+ (instancetype)glowWithColor:(uint)color alpha:(float)alpha blur:(float)blur
                   resolution:(float)resolution
{
    SPBlurFilter *glow = [SPBlurFilter blurFilterWithBlur:blur resolution:resolution];
    glow.mode = SPFragmentFilterModeBelow;
    glow.color = color;
    glow.alpha = alpha;
    glow.enableColor = YES;
    return glow;
}

@end
