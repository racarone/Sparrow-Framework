//
//  FragmentFilter.m
//  Sparrow
//
//  Created by Robert Carone on 9/16/13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPBlendMode.h"
#import "SPContext.h"
#import "SPDisplayObject.h"
#import "SPImage.h"
#import "SPEffect.h"
#import "SPMatrix.h"
#import "SPOpenGL.h"
#import "SPProgram.h"
#import "SPQuadBatch.h"
#import "SPRectangle.h"
#import "SPRenderSupport.h"
#import "SPRenderTexture.h"
#import "SPFragmentFilter.h"
#import "SPStage.h"
#import "SPGLTexture.h"
#import "SPTexture.h"
#import "SPUtils.h"
#import "SPVertexData.h"

#define MIN_TEXTURE_SIZE 64

// --- class extension -----------------------------------------------------------------------------

@interface SPFragmentFilter ()

@property (nonatomic, assign) float marginX;
@property (nonatomic, assign) float marginY;
@property (nonatomic, assign) int numPasses;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPFragmentFilter
{
    int _numPasses;
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
        
        [self createEffects];
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

- (BOOL)isCached
{
    return _cacheRequested || _cache;
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
        _cache = [[self renderPassesWithObject:object support:support intoCache:YES] retain];
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

- (void)createEffects
{
    [NSException raise:SPExceptionAbstractMethod format:@"Method has to be implemented in subclass!"];
}

- (SPEffect *)effectForPass:(int)pass
{
    [NSException raise:SPExceptionAbstractMethod format:@"Method has to be implemented in subclass!"];
    return nil;
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture
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

- (void)calcBoundsWithObject:(SPDisplayObject *)object stage:(SPStage *)stage scale:(float)scale
                   intersect:(BOOL)intersectWithStage intoBounds:(out SPRectangle **)bounds
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
        [result inflateXBy:marginX yBy:marginY];

        int minSize = MIN_TEXTURE_SIZE / scale;
        result.width  = result.width  > minSize ? result.width  : minSize;
        result.height = result.height > minSize ? result.height : minSize;
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

- (SPQuadBatch *)renderPassesWithObject:(SPDisplayObject *)object support:(SPRenderSupport *)support
                              intoCache:(BOOL)intoCache
{
    SPTexture *cacheTexture = nil;
    SPStage *stage = object.stage;
    float scale = Sparrow.contentScaleFactor * _resolution;

    if (stage == nil)
        [NSException raise:SPExceptionInvalidOperation format:@"Filtered object must be on the stage."];

    // the bounds of the object in stage coordinates
    SPRectangle *bounds = nil;
    [self calcBoundsWithObject:object stage:stage scale:scale intersect:!intoCache intoBounds:&bounds];

    if (bounds.isEmpty)
    {
        [self disposePassTextures];
        return intoCache ? [SPQuadBatch quadBatch] : nil;
    }

    [self updateBuffers:bounds];
    [self updatePassTexturesWithWidth:bounds.width height:bounds.height scale:scale];

    [support finishQuadBatch];
    [support addDrawCalls:_numPasses];
    [support pushStateWithMatrix:[SPMatrix matrixWithIdentity] alpha:1.0f blendMode:SPBlendModeAuto];

    // save original projection matrix and render target
    [_projMatrix copyFromMatrix:support.projectionMatrix];
    SPTexture *previousRenderTarget = [support.renderTarget retain];

    // use cache?
    if (intoCache)
        cacheTexture = [self texureWithWidth:bounds.width height:bounds.height scale:scale];

    // draw the original object into a texture
    [support setRenderTarget:_passTextures[0]];
    [support clear];
    [support setBlendMode:SPBlendModeNormal];
    [support setupOrthographicProjectionWithLeft:bounds.left right:bounds.right top:bounds.bottom bottom:bounds.top];
    [object render:support];
    [support finishQuadBatch];

    // prepare drawing of actual filter passes
    [support applyBlendModeForPremultipliedAlpha:YES];
    [support.modelviewMatrix identity]; // now we'll draw in stage coordinates!
    [support pushClipRect:bounds];

    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);

    glEnableVertexAttribArray(SPAttributePosition);
    glVertexAttribPointer(SPAttributePosition, 2, GL_FLOAT, false, sizeof(SPVertex),
                          (void *)(offsetof(SPVertex, position)));

    glEnableVertexAttribArray(SPAttributeTexCoords);
    glVertexAttribPointer(SPAttributeTexCoords, 2, GL_FLOAT, false, sizeof(SPVertex),
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

        SPEffect* passEffect = [self effectForPass:i];
        SPTexture* passTexture = [self passTextureForPass:i];

        passEffect.mainTexture = passTexture;
        passEffect.mvpMatrix = [support.mvpMatrix convertToGLKMatrix4];

        [self activateWithPass:i texture:passTexture];
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
        if (_passTextures)
            [_passTextures removeAllObjects];
        else
            _passTextures = [[NSMutableArray alloc] initWithCapacity:numPassTextures];

        for (int i=0; i<numPassTextures; ++i)
            [_passTextures addObject:[self texureWithWidth:width height:height scale:scale]];
    }
}

- (SPTexture *)texureWithWidth:(int)width height:(int)height scale:(float)scale
{
    SPTextureProperties properties = {
        .format = SPTextureFormatRGBA,
        .scale  = scale,
        .width  = width  * scale,
        .height = height * scale,
        .numMipmaps = 0,
        .generateMipmaps = NO,
        .premultipliedAlpha = YES
    };

    return [[[SPGLTexture alloc] initWithData:NULL properties:properties] autorelease];
}

@end
