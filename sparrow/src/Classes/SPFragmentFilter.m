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

#import "SparrowClass.h"
#import "SPBlendMode.h"
#import "SPDisplayObject.h"
#import "SPImage.h"
#import "SPMatrix.h"
#import "SPOpenGL.h"
#import "SPQuadBatch.h"
#import "SPRectangle.h"
#import "SPRenderSupport.h"
#import "SPRenderTexture.h"
#import "SPFragmentFilter.h"
#import "SPStage.h"
#import "SPGLTexture.h"
#import "SPTexture.h"
#import "SPUtils.h"

#define MIN_TEXTURE_SIZE 64

// --- helper class --------------------------------------------------------------------------------

@interface SPRenderTarget : NSObject {
    SPTexture *_texture;
    uint _framebuffer;
}

- (instancetype)initWithWidth:(int)width height:(float)height scale:(float)scale;
+ (instancetype)renderTargetWithWidth:(int)width height:(float)height scale:(float)scale;

- (void)bindWithSupport:(SPRenderSupport *)support;
- (void)bind;

@property (nonatomic, readonly) SPTexture *texture;
@property (nonatomic, readonly) uint framebuffer;
@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;

@end

@implementation SPRenderTarget

@synthesize texture     = _texture;
@synthesize framebuffer = _framebuffer;

- (instancetype)initWithWidth:(int)width height:(float)height scale:(float)scale
{
    if ((self = [super init]))
    {
        int legalWidth  = [SPUtils nextPowerOfTwo:width  * scale];
        int legalHeight = [SPUtils nextPowerOfTwo:height * scale];

        _texture = [[SPGLTexture alloc] initWithData:NULL
                                               width:legalWidth
                                              height:legalHeight
                                     generateMipmaps:NO
                                               scale:scale
                                  premultipliedAlpha:YES];
        
        [self createFramebuffer];
    }

    return self;
}

- (void)dealloc
{
    glDeleteFramebuffers(1, &_framebuffer);
    [_texture release];
    [super dealloc];
}

- (void)createFramebuffer
{
    GLint  previousFramebuffer = -1;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &previousFramebuffer);

    // create framebuffer
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);

    // attach renderbuffer
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture.name, 0);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        NSLog(@"failed to create frame buffer for render texture");

    // bind previous framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, previousFramebuffer);
}

- (void)bindWithSupport:(SPRenderSupport *)support
{
    [support applyClipRect];

    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _texture.nativeWidth, _texture.nativeHeight);
}

- (void)bind
{
    [self bindWithSupport:nil];
}

- (int)width
{
    return _texture.width;
}

- (int)height
{
    return _texture.height;
}

+ (instancetype)renderTargetWithWidth:(int)width height:(float)height scale:(float)scale
{
    return [[[self alloc] initWithWidth:width height:height scale:scale] autorelease];
}

@end

// --- internal interface --------------------------------------------------------------------------

@interface SPFragmentFilter ()

- (void)calcBoundsWithObject:(SPDisplayObject *)object stage:(SPStage *)stage
                       scale:(float)scale intersect:(BOOL)intersectWithStage
                      bounds:(out SPRectangle**)bounds boundsPOT:(out SPRectangle**)boundsPOT;
- (SPQuadBatch *)compileWithObject:(SPDisplayObject *)object;
- (void)disposeCache;
- (void)disposePassTextures;
- (SPRenderTarget *)passTextureForPass:(int)pass;
- (SPQuadBatch *)renderPassesWithObject:(SPDisplayObject *)object support:(SPRenderSupport *)support intoCache:(BOOL)intoCache;
- (void)updateBuffers:(SPRectangle *)bounds;
- (void)updatePassTexturesWithWidth:(int)width height:(int)height scale:(float)scale;

@property (nonatomic) float marginX;
@property (nonatomic) float marginY;
@property (nonatomic) int numPasses;
@property (nonatomic) int vertexPosID;
@property (nonatomic) int texCoordsID;
@property (nonatomic) int baseTextureID;

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

- (instancetype)initWithNumPasses:(int)numPasses resolution:(float)resolution
{
    if ([self isMemberOfClass:[SPFragmentFilter class]])
    {
        [NSException raise:SPExceptionAbstractClass
                    format:@"Attempting to initialize abstract class SPFragmentFilter."];
        return nil;
    }

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

- (void)renderObject:(SPDisplayObject *)object withSupport:(SPRenderSupport *)support
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

#pragma mark - Subclasses

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

#pragma mark - Internal

- (void)calcBoundsWithObject:(SPDisplayObject *)object stage:(SPStage *)stage
                       scale:(float)scale intersect:(BOOL)intersectWithStage
                      bounds:(out SPRectangle**)bounds boundsPOT:(out SPRectangle**)boundsPOT
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
        [*bounds inflateWithXBy:marginX yBy:marginY];

        // To fit into a POT-texture, we extend it towards the right and bottom.
        int minSize = MIN_TEXTURE_SIZE / scale;
        float minWidth  = result.width  > minSize ? result.width  : minSize;
        float minHeight = result.height > minSize ? result.height : minSize;

        *boundsPOT = [SPRectangle rectangleWithX:result.x
                                               y:result.y
                                           width:[SPUtils nextPowerOfTwo:minWidth * scale] / scale
                                          height:[SPUtils nextPowerOfTwo:minHeight * scale] / scale];
    }
}

- (SPQuadBatch *)compileWithObject:(SPDisplayObject *)object
{
    if (_cache)
        return _cache;

    else
    {
        SPStage* stage = object.stage;
        if (!stage) [NSException raise:SPExceptionInvalidOperation format:@"Filtered object must be on the stage."];

        SPRenderSupport* support = [[[SPRenderSupport alloc] init] autorelease];
        [support pushStateWithMatrix:[object transformationMatrixToSpace:stage] alpha:object.alpha blendMode:object.blendMode];
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

- (SPRenderTarget *)passTextureForPass:(int)pass
{
    return _passTextures[pass % 2];
}

- (SPQuadBatch *)renderPassesWithObject:(SPDisplayObject *)object support:(SPRenderSupport *)support intoCache:(BOOL)intoCache
{
    SPRenderTarget *cacheTexture = nil;
    SPStage *stage = [object stage];
    float scale = [Sparrow contentScaleFactor];

    if (stage == nil) [NSException raise:SPExceptionInvalidOperation format:@"Filtered object must be on the stage."];

    // the bounds of the object in stage coordinates
    SPRectangle *boundsPOT = nil;
    SPRectangle *bounds = nil;
    [self calcBoundsWithObject:object stage:stage scale:_resolution * scale
                     intersect:!intoCache bounds:&bounds boundsPOT:&boundsPOT];

    if (bounds.isEmpty)
    {
        [self disposePassTextures];
        return intoCache ? [SPQuadBatch quadBatch] : nil;
    }

    [self updateBuffers:boundsPOT];
    [self updatePassTexturesWithWidth:boundsPOT.width height:boundsPOT.height scale:_resolution * scale];

    [support finishQuadBatch];
    [support addDrawCalls:_numPasses];
    [support pushStateWithMatrix:[SPMatrix matrixWithIdentity] alpha:1.0f blendMode:SPBlendModeAuto];
    {
        // save original projection matrix and render target
        [_projMatrix copyFromMatrix:support.projectionMatrix];
        [self saveFramebuffer];

        // use cache?
        if (intoCache)
        {
            cacheTexture = [SPRenderTarget renderTargetWithWidth:boundsPOT.width
                                                          height:boundsPOT.height
                                                           scale:_resolution * scale];
        }

        // draw the original object into a texture
        [_passTextures[0] bindWithSupport:support];
        glDisable(GL_SCISSOR_TEST); // we want the entire texture cleared
        [SPRenderSupport clearWithColor:0x0 alpha:0];
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
                [[self passTextureForPass:i+1] bindWithSupport:support];
                [SPRenderSupport clearWithColor:0x0 alpha:0];
            }
            else // final pass
            {
                if (intoCache)
                {
                    // draw into cache texture
                    [cacheTexture bindWithSupport:support];
                    [SPRenderSupport clearWithColor:0x0 alpha:0];
                }
                else
                {
                    // draw into back buffer, at original (stage) coordinates
                    [support applyClipRect];
                    [self restoreFramebuffer];
                    [support setProjectionMatrix:_projMatrix];
                    [support.modelviewMatrix translateXBy:_offsetX yBy:_offsetY];
                    [support setBlendMode:object.blendMode];
                    [support applyBlendModeForPremultipliedAlpha:YES];
                }
            }

            SPTexture* passTexture = [[self passTextureForPass:i] texture];
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, passTexture.name);

            [self activateWithPass:i texture:passTexture mvpMatrix:support.mvpMatrix];
            {
                glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, 0);
            }
            [self deactivateWithPass:i texture:passTexture];
        }

    }
    [support popState];
    [support popClipRect];

    if (intoCache)
    {
        // restore support settings
        [self restoreFramebuffer];
        [support setProjectionMatrix:_projMatrix];

        // Create an image containing the cache. To have a display object that contains
        // the filter output in object coordinates, we wrap it in a QuadBatch: that way,
        // we can modify it with a transformation matrix.

        SPQuadBatch* quadBatch = [SPQuadBatch quadBatch];
        SPImage* image = [SPImage imageWithTexture:cacheTexture.texture];

        SPMatrix* matrix = [stage transformationMatrixToSpace:object];
        [matrix translateXBy:bounds.x + _offsetX yBy:bounds.y + _offsetY];
        [quadBatch addQuad:image alpha:1.0 blendMode:SPBlendModeAuto matrix:matrix];
        return quadBatch;
    }
    else return nil;
}

#pragma mark - Update

- (void)updateBuffers:(SPRectangle *)bounds
{
    [_vertexData setPositionWithX:bounds.x      y:bounds.y      atIndex:0];
    [_vertexData setPositionWithX:bounds.right  y:bounds.y      atIndex:1];
    [_vertexData setPositionWithX:bounds.x      y:bounds.bottom atIndex:2];
    [_vertexData setPositionWithX:bounds.right  y:bounds.bottom atIndex:3];

    const int indexSize  = sizeof(ushort) * 6;
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
        [(SPRenderTarget *)_passTextures[0] width]  != width ||
        [(SPRenderTarget *)_passTextures[0] height] != height;

    if (needsUpdate)
    {
        [_passTextures removeAllObjects];
        for (int i=0; i<numPassTextures; ++i)
        {
            SPRenderTarget* renderTarget = [SPRenderTarget renderTargetWithWidth:width height:height scale:scale];
            [_passTextures addObject:renderTarget];
        }
    }
}

#pragma mark - Framebuffers

- (void)saveFramebuffer
{
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &_savedFramebuffer);
    glGetIntegerv(GL_VIEWPORT, _savedViewport);
}

- (void)restoreFramebuffer
{
    glBindFramebuffer(GL_FRAMEBUFFER, _savedFramebuffer);
    glViewport(_savedViewport[0], _savedViewport[1], _savedViewport[2], _savedViewport[3]);
}

@end
