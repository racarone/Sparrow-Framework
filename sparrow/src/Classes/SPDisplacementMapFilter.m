//
//  SPDisplacementMapFilter.m
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPDisplacementMapFilter.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPProgram.h>
#import <Sparrow/SPTexture.h>

// --- private interface ---------------------------------------------------------------------------

static NSString *const SPDisplacementMapFilterProgram = @"SPDisplacementMapFilterProgram";

@interface SPDisplacementMapFilter ()

- (NSString *)fragmentShader;
- (NSString *)vertexShader;
- (void)updateParametersWithWidth:(int)width height:(int)height;

@end


// --- class implementation ------------------------------------------------------------------------

@implementation SPDisplacementMapFilter
{
    SPTexture *_mapTexture;
    SPPoint *_mapPoint;
    SPColorChannel _componentX;
    SPColorChannel _componentY;
    float _scaleX;
    float _scaleY;
    BOOL _mapRepeat;
    BOOL _repeat;

    float _mapTexCoords[8];
    GLKMatrix4 _mapMatrix;

    SPProgram *_shaderProgram;
    uint _mapTexCoordBuffer;

    int _aMapTexCoords;
    int _uMapMatrix;
    int _uMvpMatrix;
    int _uTexture;
    int _uMapTexture;
}

#pragma mark Initialization

- (instancetype)initWithMapTexture:(SPTexture *)mapTexture
{
    if ((self = [super initWithNumPasses:1 resolution:1.0f]))
    {
        _mapTexture = [mapTexture retain];
        _mapPoint = [[SPPoint alloc] init];
        _componentX = 0;
        _componentY = 0;
        _scaleX = 0;
        _scaleY = 0;

        // the texture coordinates for the map texture are uploaded via a separate buffer
        glGenBuffers(1, &_mapTexCoordBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _mapTexCoordBuffer);
        glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(float) * 2, NULL, GL_STATIC_DRAW);
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
    [_mapTexture release];
    [_mapPoint release];
    [_shaderProgram release];
    [super dealloc];
}

+ (instancetype)displacementMapFilterWithMapTexture:(SPTexture *)texture
{
    return [[[self alloc] initWithMapTexture:texture] autorelease];
}

#pragma mark SPFragmentFilter (Subclasses)

- (void)createPrograms
{
    if (!_shaderProgram)
    {
        _shaderProgram = [[[Sparrow currentController] programByName:SPDisplacementMapFilterProgram] retain];

        if (!_shaderProgram)
        {
            NSString *vertexShader = [self vertexShader];
            NSString *fragmentShader = [self fragmentShader];

            _shaderProgram = [[SPProgram alloc] initWithVertexShader:vertexShader fragmentShader:fragmentShader];
            [[Sparrow currentController] registerProgram:_shaderProgram name:SPDisplacementMapFilterProgram];
        }

        self.vertexPosID = [_shaderProgram attributeByName:@"aPosition"];
        self.texCoordsID = [_shaderProgram attributeByName:@"aTexCoords"];
        _aMapTexCoords   = [_shaderProgram attributeByName:@"aMapTexCoords"];

        _uTexture       = [_shaderProgram uniformByName:@"uTexture"];
        _uMapTexture    = [_shaderProgram uniformByName:@"uMapTexture"];
        _uMvpMatrix     = [_shaderProgram uniformByName:@"uMvpMatrix"];
        _uMapMatrix     = [_shaderProgram uniformByName:@"uMapMatrix"];
    }
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture mvpMatrix:(SPMatrix *)matrix
{
    // already set by super class:
    //
    // vertex constants 0-3: mvpMatrix (3D)
    // vertex attribute 0:   vertex position (FLOAT_2)
    // vertex attribute 1:   texture coordinates (FLOAT_2)
    // texture 0:            input texture

    [self updateParametersWithWidth:texture.nativeWidth height:texture.nativeHeight];

    glBindBuffer(GL_ARRAY_BUFFER, _mapTexCoordBuffer);
    glEnableVertexAttribArray(_aMapTexCoords);
    glVertexAttribPointer(_aMapTexCoords, 2, GL_FLOAT, false, 0, 0);

    glUseProgram(_shaderProgram.name);

    glUniform1i(_uTexture, 0);
    glUniform1i(_uMapTexture, 1);

    GLKMatrix4 mvp = [matrix convertToGLKMatrix4];
    glUniformMatrix4fv(_uMvpMatrix, 1, false, mvp.m);
    glUniformMatrix4fv(_uMapMatrix, 1, false, _mapMatrix.m);

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _mapTexture.name);

    _mapRepeat = _mapTexture.repeat;
    _mapTexture.repeat = _repeat;
}

- (void)deactivateWithPass:(int)pass texture:(SPTexture *)texture
{
    _mapTexture.repeat = _mapRepeat;

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

#pragma mark Private

- (NSString *)fragmentShader
{
    NSMutableString *source = [NSMutableString string];

    [source appendLine:@"uniform lowp mat4 uMapMatrix;"];
    [source appendLine:@"uniform sampler2D uTexture;"];
    [source appendLine:@"uniform sampler2D uMapTexture;"];

    [source appendLine:@"varying lowp vec4 vTexCoords;"];
    [source appendLine:@"varying lowp vec4 vMapTexCoords;"];

    [source appendLine:@"void main() {"];

    // optimized with PVRShader
    [source appendLine:@"  lowp vec4 tmpColor;"];
    [source appendLine:@"  tmpColor = texture2D(uTexture, (vTexCoords + (uMapMatrix * (texture2D(uMapTexture, vMapTexCoords.xy) - vec4(0.5, 0.5, 0.5, 0.5)))).xy);"];
    [source appendLine:@"  gl_FragColor = tmpColor;"];

    [source appendLine:@"}"];

    return source;
}

- (NSString *)vertexShader
{
    NSMutableString *source = [NSMutableString string];

    // variables
    [source appendLine:@"attribute vec4 aPosition;"];
    [source appendLine:@"attribute lowp vec4 aTexCoords;"];
    [source appendLine:@"attribute lowp vec4 aMapTexCoords;"];

    [source appendLine:@"uniform mat4 uMvpMatrix;"];

    [source appendLine:@"varying lowp vec4 vTexCoords;"];
    [source appendLine:@"varying lowp vec4 vMapTexCoords;"];

    [source appendLine:@"void main() {"];

    [source appendLine:@"  gl_Position = uMvpMatrix * aPosition;"];
    [source appendLine:@"  vTexCoords = aTexCoords;"];
    [source appendLine:@"  vMapTexCoords = aMapTexCoords;"];

    [source appendLine:@"}"];

    return source;
}

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

    memset(&_mapMatrix, 0, sizeof(_mapMatrix));

    float scale = Sparrow.contentScaleFactor;
    _mapMatrix.m[(columnX * 4    )] = _scaleX * scale / width;
    _mapMatrix.m[(columnY * 4 + 1)] = _scaleY * scale / height;

    // vertex buffer: (containing map texture coordinates)
    // The size of input texture and map texture may be different. We need to calculate
    // the right values for the texture coordinates at the filter vertices.

    float mapX = _mapPoint.x / _mapTexture.nativeWidth;
    float mapY = _mapPoint.y / _mapTexture.nativeHeight;
    float maxU = width       / _mapTexture.nativeWidth;
    float maxV = height      / _mapTexture.nativeHeight;

    _mapTexCoords[0] = -mapX;        _mapTexCoords[1] = -mapY;
    _mapTexCoords[2] = -mapX + maxU; _mapTexCoords[3] = -mapY;
    _mapTexCoords[4] = -mapX;        _mapTexCoords[5] = -mapY + maxV;
    _mapTexCoords[6] = -mapX + maxU; _mapTexCoords[7] = -mapY + maxV;

    [_mapTexture adjustTexCoords:_mapTexCoords numVertices:4 stride:0];
    
    glBindBuffer(GL_ARRAY_BUFFER, _mapTexCoordBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float)*8, _mapTexCoords, GL_STATIC_DRAW);
}

@end
