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

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPBlurFilter.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPProgram.h>
#import <Sparrow/SPTexture.h>

#pragma mark - SPBlurProgram

@interface SPBlurProgram : SPProgram

- (instancetype)initWithTintedFragmentShader:(BOOL)isTinted;

@property (nonatomic, readonly) BOOL tinted;
@property (nonatomic, readonly) int aPosition;
@property (nonatomic, readonly) int aTexCoords;
@property (nonatomic, readonly) int uOffsets;
@property (nonatomic, readonly) int uWeights;
@property (nonatomic, readonly) int uColor;
@property (nonatomic, readonly) int uMvpMatrix;

@end


// --- blur implementation -------------------------------------------------------------------------

@implementation SPBlurProgram
{
    BOOL _tinted;
    int _aPosition;
    int _aTexCoords;
    int _uOffsets;
    int _uWeights;
    int _uColor;
    int _uMvpMatrix;
}

#pragma mark Initialization

- (instancetype)initWithTintedFragmentShader:(BOOL)isTinted
{
    if ((self = [super initWithVertexShader:[self vertexShader]
                             fragmentShader:[self fragmentShader:isTinted]]))
    {
        _tinted = isTinted;
        _aPosition = [self attributeByName:@"aPosition"];
        _aTexCoords = [self attributeByName:@"aTexCoords"];
        _uOffsets = [self uniformByName:@"uOffsets"];
        _uWeights = [self uniformByName:@"uWeights"];
        _uColor = [self uniformByName:@"uColor"];
        _uMvpMatrix = [self uniformByName:@"uMvpMatrix"];
    }
    return self;
}

#pragma mark Methods

- (NSString *)vertexShader
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

#pragma mark Class

+ (NSString *)programNameForTinting:(BOOL)tinting
{
    if (tinting) return @"SPBlurFilter#01";
    else         return @"SPBlurFilter#00";
}

@end

#pragma mark - SPBlurFilter

@interface SPBlurFilter ()

- (void)updateParamatersWithPass:(int)pass texWidth:(int)texWidth texHeight:(int)texHeight;
- (void)updateMarginsAndPasses;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPBlurFilter
{
    BOOL _enableColorUniform;
    float _offsets[4];
    float _weights[4];
    float _color[4];
    SPBlurProgram *_program;
    SPBlurProgram *_tintedProgram;
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

        [self updateMarginsAndPasses];
    }
    return self;
}

- (void)dealloc
{
    [_program release];
    [_tintedProgram release];

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

#pragma mark Methods

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
    _enableColorUniform = enable;
}

#pragma mark SPFragmentFilter (Subclasses)

- (void)createPrograms
{
    if (!_program)
    {
        NSString *programName = [SPBlurProgram programNameForTinting:NO];
        _program = (SPBlurProgram *)[[[Sparrow currentController] programByName:programName] retain];

        if (!_program)
        {
            _program = [[SPBlurProgram alloc] initWithTintedFragmentShader:NO];
            [[Sparrow currentController] registerProgram:_program name:programName];
        }
    }

    if (!_tintedProgram)
    {
        NSString *programName = [SPBlurProgram programNameForTinting:YES];
        _tintedProgram = (SPBlurProgram *)[[[Sparrow currentController] programByName:programName] retain];

        if (!_tintedProgram)
        {
            _tintedProgram = [[SPBlurProgram alloc] initWithTintedFragmentShader:YES];
            [[Sparrow currentController] registerProgram:_tintedProgram name:programName];
        }
    }

    self.vertexPosID = _program.aPosition;
    self.texCoordsID = _program.aTexCoords;
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture mvpMatrix:(SPMatrix *)matrix
{
    [self updateParamatersWithPass:pass texWidth:texture.nativeWidth texHeight:texture.nativeHeight];

    BOOL isColorPass = _enableColorUniform && pass == self.numPasses - 1;
    SPBlurProgram *program = isColorPass ? _tintedProgram : _program;

    glUseProgram(program.name);

    GLKMatrix4 mvp = [matrix convertToGLKMatrix4];
    glUniformMatrix4fv(program.uMvpMatrix, 1, false, mvp.m);

    glUniform4fv(program.uOffsets, 1, _offsets);
    glUniform4fv(program.uWeights, 1, _weights);

    if (isColorPass)
        glUniform4fv(program.uColor, 1, _color);
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

#pragma mark Private

- (void)updateParamatersWithPass:(int)pass texWidth:(int)texWidth texHeight:(int)texHeight
{
    static const float MAX_SIGMA = 2.0f;

    // algorithm described here:
    // http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
    //
    // Normally, we'd have to use 9 texture lookups in the fragment shader. But by making smart
    // use of linear texture sampling, we can produce the same output with only 5 lookups.

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

+ (instancetype)glowWithColor:(uint)color alpha:(float)alpha blur:(float)blur resolution:(float)resolution
{
    SPBlurFilter *glow = [SPBlurFilter blurFilterWithBlur:blur resolution:resolution];
    glow.mode = SPFragmentFilterModeBelow;
    [glow setUniformColor:YES color:color alpha:alpha];
    return glow;
}

@end
