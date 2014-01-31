//
//  FragmentFilter.m
//  Sparrow
//
//  Created by Robert Carone on 9/16/13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPBlendMode.h>
#import <Sparrow/SPContext.h>
#import <Sparrow/SPDisplayObject.h>
#import <Sparrow/SPImage.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPQuadBatch.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPRenderSupport.h>
#import <Sparrow/SPRenderTexture.h>
#import <Sparrow/SPFragmentFilter.h>
#import <Sparrow/SPStage.h>
#import <Sparrow/SPGLTexture.h>
#import <Sparrow/SPTexture.h>
#import <Sparrow/SPUtils.h>
#import <Sparrow/SPVertexData.h>

#define MIN_TEXTURE_SIZE 64

// --- private interface ---------------------------------------------------------------------------

@interface SPFragmentFilter ()

@property (nonatomic, assign) float marginX;
@property (nonatomic, assign) float marginY;
@property (nonatomic, assign) int numPasses;
@property (nonatomic, assign) int vertexPosID;
@property (nonatomic, assign) int texCoordsID;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPFragmentFilter
{
    int _numPasses;
    int _vertexPosID;
    int _texCoordsID;
    float _marginX;
    float _marginY;
    float _offsetX;
    float _offsetY;

    NSMutableArray *_passTextures;
    int _savedFramebuffer;
    int _savedViewport[4];
    SPMatrix *_projMatrix;
    SPQuadBatch *_cache;
    BOOL _cacheRequested;

    SPVertexData *_vertexData;
    ushort _indexData[6];
    uint _vertexBufferName;
    uint _indexBufferName;
}

#pragma mark Initialization

- (instancetype)initWithNumPasses:(int)numPasses resolution:(float)resolution
{
  #if DEBUG
    if ([self isMemberOfClass:[SPFragmentFilter class]])
    {
        [NSException raise:SPExceptionAbstractClass
                    format:@"Attempting to initialize abstract class SPFragmentFilter."];
        return nil;
    }
  #endif

    if ((self = [super init]))
    {
        _numPasses = numPasses;
        _resolution = resolution;
        _mode = SPFragmentFilterModeReplace;
        _passTextures = [[NSMutableArray alloc] initWithCapacity:numPasses];
        _projMatrix = [[SPMatrix alloc] init];

        _vertexData = [[SPVertexData alloc] initWithSize:4 premultipliedAlpha:true];
        _vertexData.vertices[1].texCoords.x = 1.0f;
        _vertexData.vertices[2].texCoords.y = 1.0f;
        _vertexData.vertices[3].texCoords.x = 1.0f;
        _vertexData.vertices[3].texCoords.y = 1.0f;

        _indexData[0] = 0;
        _indexData[1] = 1;
        _indexData[2] = 2;
        _indexData[3] = 1;
        _indexData[4] = 3;
        _indexData[5] = 2;

        [self createPrograms];
    }
    return self;
}

- (instancetype)initWithNumPasses:(int)numPasses
{
    return [self initWithNumPasses:numPasses resolution:1.0f];
}

- (instancetype)init
{
    return [self initWithNumPasses:1];
}

- (void)dealloc
{
    glDeleteBuffers(1, &_vertexBufferName);
    glDeleteBuffers(1, &_indexBufferName);

    [_vertexData release];
    [_passTextures release];
    [_cache release];
    [_projMatrix release];

    [super dealloc];
}

#pragma mark Methods

- (void)cache
{
    _cacheRequested = YES;
    [self disposeCache];
}

- (void)clearCache
{
    _cacheRequested = NO;
    [self disposeCache];
}

- (void)renderObject:(SPDisplayObject *)object support:(SPRenderSupport *)support
{
    // bottom layer
    if (_mode == SPFragmentFilterModeAbove)
        [object render:support];

    // center layer
    if (_cacheRequested)
    {
        _cacheRequested = false;
        _cache = [self renderPassesWithObject:object support:support intoCache:YES];
        [self disposePassTextures];
    }

    if (_cache)
        [_cache render:support];
    else
        [self renderPassesWithObject:object support:support intoCache:NO];

    // top layer
    if (_mode == SPFragmentFilterModeBelow)
        [object render:support];
}

#pragma mark Subclasses

- (void)createPrograms
{
    [NSException raise:SPExceptionAbstractMethod format:@"Method has to be implemented in subclass!"];
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture mvpMatrix:(SPMatrix *)matrix
{
    [NSException raise:SPExceptionAbstractMethod format:@"Method has to be implemented in subclass!"];
}

- (void)deactivateWithPass:(int)pass texture:(SPTexture *)texture
{
    // override in subclass
}

+ (NSString *)standardVertexShader
{
    return
    @"attribute vec4 aPosition; \n"
    @"attribute lowp vec2 aTexCoords; \n"
    @"uniform mat4 uMvpMatrix; \n"
    @"varying lowp vec2 vTexCoords; \n"
    @"void main() { \n"
    @"  gl_Position = uMvpMatrix * aPosition; \n"
    @"  vTexCoords  = aTexCoords; \n"
    @"} \n";
}

+ (NSString *)standardFragmentShader
{
    return
    @"uniform lowp sampler2D uTexture;"
    @"varying lowp vec2 vTexCoords;"
    @"void main() { \n"
    @"  gl_FragColor = texture2D(uTexture, vTexCoords); \n"
    @"} \n";
}

#pragma mark Private

- (void)calcBoundsWithObject:(SPDisplayObject *)object
                       stage:(SPStage *)stage
                       scale:(float)scale
                   intersect:(BOOL)intersectWithStage
                  intoBounds:(out SPRectangle **)bounds
               intoBoundsPOT:(out SPRectangle **)boundsPOT
{
    float marginX;
    float marginY;

    // optimize for full-screen effects
    if (object == stage || object == [[Sparrow currentController] root])
    {
        marginX = marginY = 0;
        *bounds = [SPRectangle rectangleWithX:0 y:0 width:stage.width height:stage.height];
    }
    else
    {
        marginX = _marginX;
        marginY = _marginY;
        *bounds = [object boundsInSpace:stage];
    }

    if (intersectWithStage)
        *bounds = [*bounds intersectionWithRectangle:stage.bounds];

    SPRectangle* result = *bounds;
    if (!result.isEmpty)
    {
        // the bounds are a rectangle around the object, in stage coordinates,
        // and with an optional margin.
        [*bounds inflateXBy:marginX yBy:marginY];

        // To fit into a POT-texture, we extend it towards the right and bottom.
        int minSize = MIN_TEXTURE_SIZE / scale;
        float minWidth  = result.width  > minSize ? result.width  : minSize;
        float minHeight = result.height > minSize ? result.height : minSize;

        *boundsPOT = [SPRectangle rectangleWithX:result.x
                                               y:result.y
                                           width:[SPUtils nextPowerOfTwo:minWidth  * scale] / scale
                                          height:[SPUtils nextPowerOfTwo:minHeight * scale] / scale];
    }
}

- (SPQuadBatch *)compileWithObject:(SPDisplayObject *)object
{
    if (_cache)
        return _cache;
    else
    {
        if (!object.stage)
            [NSException raise:SPExceptionInvalidOperation
                        format:@"Filtered object must be on the stage."];

        SPRenderSupport* support = [[[SPRenderSupport alloc] init] autorelease];
        [support pushStateWithMatrix:[object transformationMatrixToSpace:object.stage]
                               alpha:object.alpha
                           blendMode:object.blendMode];

        return [self renderPassesWithObject:object support:support intoCache:YES];
    }
}

- (void)disposeCache
{
    SP_RELEASE_AND_NIL(_cache);
}

- (void)disposePassTextures
{
    [_passTextures removeAllObjects];
}

- (SPTexture *)passTextureForPass:(int)pass
{
    return _passTextures[pass % 2];
}

- (SPQuadBatch *)renderPassesWithObject:(SPDisplayObject *)object
                                support:(SPRenderSupport *)support
                              intoCache:(BOOL)intoCache
{
    SPTexture *cacheTexture = nil;
    SPStage *stage = object.stage;
    float scale = Sparrow.contentScaleFactor * _resolution;

    if (stage == nil)
        [NSException raise:SPExceptionInvalidOperation format:@"Filtered object must be on the stage."];

    // the bounds of the object in stage coordinates
    SPRectangle *boundsPOT = nil;
    SPRectangle *bounds = nil;
    [self calcBoundsWithObject:object stage:stage scale:scale intersect:!intoCache
                    intoBounds:&bounds intoBoundsPOT:&boundsPOT];

    if (bounds.isEmpty)
    {
        [self disposePassTextures];
        return intoCache ? [SPQuadBatch quadBatch] : nil;
    }

    [self updateBuffers:boundsPOT];
    [self updatePassTexturesWithWidth:boundsPOT.width height:boundsPOT.height scale:scale];

    [support finishQuadBatch];
    [support addDrawCalls:_numPasses];
    [support pushStateWithMatrix:[SPMatrix matrixWithIdentity] alpha:1.0f blendMode:SPBlendModeAuto];

    // save original projection matrix and render target
    [_projMatrix copyFromMatrix:support.projectionMatrix];
    SPTexture *previousRenderTarget = [support.renderTarget retain];

    // use cache?
    if (intoCache)
        cacheTexture = [self texureWithWidth:boundsPOT.width height:boundsPOT.height scale:scale];

    // draw the original object into a texture
    [support setRenderTarget:_passTextures[0]];
    [Sparrow.context setScissorBox:nil]; // we want the entire texture cleared
    [support clear];
    [support setBlendMode:SPBlendModeNormal];
    [support setupOrthographicProjectionWithLeft:boundsPOT.left right:boundsPOT.right top:boundsPOT.bottom bottom:boundsPOT.top];
    [object render:support];
    [support finishQuadBatch];

    // prepare drawing of actual filter passes
    [support applyBlendModeForPremultipliedAlpha:YES];
    [support.modelviewMatrix identity]; // now we'll draw in stage coordinates!
    [support pushClipRect:bounds];

    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);

    glEnableVertexAttribArray(_vertexPosID);
    glVertexAttribPointer(_vertexPosID, 2, GL_FLOAT, false, sizeof(SPVertex),
                          (void *)(offsetof(SPVertex, position)));

    glEnableVertexAttribArray(_texCoordsID);
    glVertexAttribPointer(_texCoordsID, 2, GL_FLOAT, false, sizeof(SPVertex),
                          (void *)(offsetof(SPVertex, texCoords)));

    // draw all passes
    for (int i=0; i<_numPasses; ++i)
    {
        if (i < _numPasses - 1) // intermediate pass
        {
            // draw into pass texture
            [support setRenderTarget:[self passTextureForPass:i+1]];
            [support clear];
        }
        else // final pass
        {
            if (intoCache)
            {
                // draw into cache texture
                [support setRenderTarget:cacheTexture];
                [support clear];
            }
            else
            {
                // draw into back buffer, at original (stage) coordinates
                [support setRenderTarget:previousRenderTarget];
                [support setProjectionMatrix:_projMatrix];
                [support.modelviewMatrix translateXBy:_offsetX yBy:_offsetY];
                [support setBlendMode:object.blendMode];
                [support applyBlendModeForPremultipliedAlpha:YES];
            }
        }

        SPTexture* passTexture = [self passTextureForPass:i];
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, passTexture.name);

        [self activateWithPass:i texture:passTexture mvpMatrix:support.mvpMatrix];
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, 0);
        [self deactivateWithPass:i texture:passTexture];
    }

    [support popState];
    [support popClipRect];

    SPQuadBatch *cache = nil;
    if (intoCache)
    {
        // restore support settings
        [support setRenderTarget:previousRenderTarget];
        [support setProjectionMatrix:_projMatrix];

        // Create an image containing the cache. To have a display object that contains
        // the filter output in object coordinates, we wrap it in a QuadBatch: that way,
        // we can modify it with a transformation matrix.

        cache = [SPQuadBatch quadBatch];
        SPImage* image = [SPImage imageWithTexture:cacheTexture];

        SPMatrix* matrix = [stage transformationMatrixToSpace:object];
        [matrix translateXBy:bounds.x + _offsetX yBy:bounds.y + _offsetY];
        [cache addQuad:image alpha:1.0 blendMode:SPBlendModeAuto matrix:matrix];
    }

    [previousRenderTarget release];
    return cache;
}

#pragma mark Update

- (void)updateBuffers:(SPRectangle *)bounds
{
    SPVertex *vertices = _vertexData.vertices;
    vertices[0].position = GLKVector2Make(bounds.x,     bounds.y);
    vertices[1].position = GLKVector2Make(bounds.right, bounds.y);
    vertices[2].position = GLKVector2Make(bounds.x,     bounds.bottom);
    vertices[3].position = GLKVector2Make(bounds.right, bounds.bottom);

    const int indexSize = sizeof(ushort) * 6;
    const int vertexSize = sizeof(SPVertex) * 4;

    if (!_vertexBufferName)
    {
        glGenBuffers(1, &_vertexBufferName);
        glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);

        glGenBuffers(1, &_indexBufferName);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexSize, _indexData, GL_STATIC_DRAW);
    }

    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);
    glBufferData(GL_ARRAY_BUFFER, vertexSize, _vertexData.vertices, GL_STATIC_DRAW);
}

- (void)updatePassTexturesWithWidth:(int)width height:(int)height scale:(float)scale
{
    int numPassTextures = _numPasses > 1 ? 2 : 1;
    BOOL needsUpdate = _passTextures.count != numPassTextures ||
                            [(SPTexture *)_passTextures[0] width]  != width ||
                            [(SPTexture *)_passTextures[0] height] != height;

    if (needsUpdate)
    {
        [_passTextures removeAllObjects];

        for (int i=0; i<numPassTextures; ++i)
            [_passTextures addObject:[self texureWithWidth:width height:height scale:scale]];
    }
}

- (SPTexture *)texureWithWidth:(int)width height:(int)height scale:(float)scale
{
    int legalWidth  = [SPUtils nextPowerOfTwo:width  * scale];
    int legalHeight = [SPUtils nextPowerOfTwo:height * scale];

    SPTextureProperties properties = {
        .format = SPTextureFormatRGBA,
        .scale  = scale,
        .width  = legalWidth,
        .height = legalHeight,
        .numMipmaps = 0,
        .generateMipmaps = NO,
        .premultipliedAlpha = YES
    };

    return [[[SPGLTexture alloc] initWithData:NULL properties:properties] autorelease];
}

@end
