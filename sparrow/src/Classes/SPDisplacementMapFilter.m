//
//  SPDisplacementMapFilter.m
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPDisplacementMapFilter.h>
#import <Sparrow/SPEffect.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPProgram.h>
#import <Sparrow/SPTexture.h>

static NSString *const SPDisplacementMapProgram = @"SPDisplacementMapProgram";

// --- shaders -------------------------------------------------------------------------------------

static NSString *const SPDisplacementMapVertexShader =
    @"attribute vec4 aPosition; \n"
    @"attribute vec4 aTexCoords; \n"
    @"attribute vec4 aMapTexCoords; \n"

    @"uniform mat4 uMvpMatrix; \n"

    @"varying lowp vec4 vTexCoords; \n"
    @"varying lowp vec4 vMapTexCoords; \n"

    @"void main() { \n"
    @"  gl_Position = uMvpMatrix * aPosition; \n"
    @"  vTexCoords = aTexCoords; \n"
    @"  vMapTexCoords = aMapTexCoords; \n"
    @"} \n";

static NSString *const SPDisplacementMapFragmentShader =
    @"uniform lowp mat4 uMapMatrix; \n"
    @"uniform lowp sampler2D uTexture; \n"
    @"uniform lowp sampler2D uMapTexture; \n"

    @"varying lowp vec4 vTexCoords; \n"
    @"varying lowp vec4 vMapTexCoords; \n"

    @"void main() { \n"
    @"  lowp vec4 tmpColor; \n"
    @"  tmpColor = texture2D(uTexture, (vTexCoords + (uMapMatrix * (texture2D(uMapTexture, vMapTexCoords.xy) - vec4(0.5, 0.5, 0.5, 0.5)))).xy); \n"
    @"  gl_FragColor = tmpColor; \n"
    @"} \n";

// --- class implementation ------------------------------------------------------------------------

@implementation SPDisplacementMapFilter
{
    SPPoint *_mapPoint;
    SPColorChannel _componentX;
    SPColorChannel _componentY;
    float _scaleX;
    float _scaleY;
    BOOL _mapRepeat;
    BOOL _repeat;

    SPEffect *_effect;
    SPUniform *_uMapMatrix;
    SPUniform *_uMapTexture;

    GLKMatrix4 _mapMatrix;

    float _mapTexCoords[8];
    uint _mapTexCoordBuffer;
}

#pragma mark Initialization

- (instancetype)initWithMapTexture:(SPTexture *)mapTexture
{
    if ((self = [super initWithNumPasses:1 resolution:1.0f]))
    {
        _mapPoint = [[SPPoint alloc] init];
        _componentX = 0;
        _componentY = 0;
        _scaleX = 0;
        _scaleY = 0;

        // the texture coordinates for the map texture are uploaded via a separate buffer
        glGenBuffers(1, &_mapTexCoordBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _mapTexCoordBuffer);
        glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(float) * 2, NULL, GL_STATIC_DRAW);
        
        self.mapTexture = mapTexture;
    }
    return self;
}

- (instancetype)init
{
    [self release];
    return nil;
}

- (void)dealloc
{
    [_mapPoint release];
    [_effect release];
    [_uMapMatrix release];
    [_uMapTexture release];
    [super dealloc];
}

+ (instancetype)displacementMapFilterWithMapTexture:(SPTexture *)texture
{
    return [[[self alloc] initWithMapTexture:texture] autorelease];
}

#pragma mark SPFragmentFilter (Subclasses)

- (void)createEffects
{
    SPProgram *program = [[Sparrow currentController] programByName:SPDisplacementMapProgram];
    if (!program)
    {
        program = [[SPProgram alloc] initWithVertexShader:SPDisplacementMapVertexShader
                                           fragmentShader:SPDisplacementMapFragmentShader];

        [[Sparrow currentController] registerProgram:program name:SPDisplacementMapProgram];
    }

    _effect = [[SPEffect alloc] initWithProgram:program];
    _uMapMatrix  = [[SPUniform alloc] initWithName:@"uMapMatrix"];
    _uMapTexture = [[SPUniform alloc] initWithName:@"uMapTexture"];

    [_effect addUniformsFromArray:@[_uMapMatrix, _uMapTexture]];
}

- (SPEffect *)effectForPass:(int)pass
{
    return _effect;
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture
{
    [self updateParametersWithWidth:texture.nativeWidth height:texture.nativeHeight];

    int aMapTexCoords = [_effect.program attributeByName:@"aMapTexCoords"];
    glBindBuffer(GL_ARRAY_BUFFER, _mapTexCoordBuffer);
    glEnableVertexAttribArray(aMapTexCoords);
    glVertexAttribPointer(aMapTexCoords, 2, GL_FLOAT, false, 0, 0);

    _uMapTexture.textureValue.repeat = _repeat;
    _uMapMatrix.matrix4Value = _mapMatrix;

    [_effect prepareToDraw];
}

- (void)deactivateWithPass:(int)pass texture:(SPTexture *)texture
{
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, 0);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

#pragma mark Properties

- (void)setMapPoint:(SPPoint *)mapPoint
{
    if (mapPoint) [_mapPoint copyFromPoint:mapPoint];
    else          [_mapPoint setX:0 y:0];
}

- (SPTexture *)mapTexture
{
    return _uMapTexture.textureValue;
}

- (void)setMapTexture:(SPTexture *)mapTexture
{
    _uMapTexture.textureValue = mapTexture;
}

#pragma mark Private

- (void)updateParametersWithWidth:(int)width height:(int)height
{
    // maps RGBA values of map texture to UV-offsets in input texture.

    int columnX;
    int columnY;

    if      (_componentX == SPColorChannelRed)      columnX = 0;
    else if (_componentX == SPColorChannelGreen)    columnX = 1;
    else if (_componentX == SPColorChannelBlue)     columnX = 2;
    else                                            columnX = 3;

    if      (_componentY == SPColorChannelRed)      columnY = 0;
    else if (_componentY == SPColorChannelGreen)    columnY = 1;
    else if (_componentY == SPColorChannelBlue)     columnY = 2;
    else                                            columnY = 3;

    float scale = Sparrow.contentScaleFactor;

    _mapMatrix = (GLKMatrix4){ 0 };
    _mapMatrix.m[(columnX * 4    )] = _scaleX * scale / width;
    _mapMatrix.m[(columnY * 4 + 1)] = _scaleY * scale / height;

    // vertex buffer: (containing map texture coordinates)
    // The size of input texture and map texture may be different. We need to calculate
    // the right values for the texture coordinates at the filter vertices.

    SPTexture *mapTexture = self.mapTexture;

    float mapX = _mapPoint.x / mapTexture.width;
    float mapY = _mapPoint.y / mapTexture.height;
    float maxU = width       / mapTexture.nativeWidth;
    float maxV = height      / mapTexture.nativeHeight;

    _mapTexCoords[0] = -mapX;        _mapTexCoords[1] = -mapY;
    _mapTexCoords[2] = -mapX + maxU; _mapTexCoords[3] = -mapY;
    _mapTexCoords[4] = -mapX;        _mapTexCoords[5] = -mapY + maxV;
    _mapTexCoords[6] = -mapX + maxU; _mapTexCoords[7] = -mapY + maxV;

    [mapTexture adjustTexCoords:_mapTexCoords numVertices:4 stride:0];
    
    glBindBuffer(GL_ARRAY_BUFFER, _mapTexCoordBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float)*8, _mapTexCoords, GL_STATIC_DRAW);
}

@end
