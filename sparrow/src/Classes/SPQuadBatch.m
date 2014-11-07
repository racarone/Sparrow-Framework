//
//  SPQuadBatch.m
//  Sparrow
//
//  Created by Daniel Sperl on 01.03.13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPBaseEffect.h>
#import <Sparrow/SPBlendMode.h>
#import <Sparrow/SPDisplayObjectContainer.h>
#import <Sparrow/SPImage.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPQuadBatch.h>
#import <Sparrow/SPRenderSupport.h>
#import <Sparrow/SPTexture.h>
#import <Sparrow/SPVertexData.h>

#define MAX_NUM_QUADS 16383

enum
{
    ATTRIB_POSITION,
    ATTRIB_COLOR,
    ATTRIB_TEXCOORD,
    ATTRIB_MAX,
};

// --- class implementation ------------------------------------------------------------------------

@implementation SPQuadBatch
{
    int _numQuads;
    BOOL _syncRequired;
    
    SPTexture *_texture;
    BOOL _premultipliedAlpha;
    BOOL _tinted;

    SPEffect *_effect;
    SPBaseEffect *_baseEffect;
    uint _vertexBufferName;
    ushort *_indexData;
    uint _indexBufferName;

    uint _vertexArrayName;
    uint _attribCache[ATTRIB_MAX];
}

#pragma mark Initialization

- (instancetype)initWithCapacity:(int)capacity
{
    if ((self = [super init]))
    {
        _numQuads = 0;
        _syncRequired = NO;
        _vertexData = [[SPVertexData alloc] init];
        _baseEffect = [[SPBaseEffect alloc] init];

        if (capacity > 0)
            self.capacity = capacity;
    }
    
    return self;
}

- (instancetype)init
{
    return [self initWithCapacity:0];
}

- (void)dealloc
{
    free(_indexData);

    [self destroyBuffers];

    [_texture release];
    [_vertexData release];
    [_baseEffect release];
    [super dealloc];
}

+ (instancetype)quadBatch
{
    return [[[self alloc] init] autorelease];
}

#pragma mark Methods

- (void)reset
{
    _numQuads = 0;
    _syncRequired = YES;
    SP_RELEASE_AND_NIL(_texture);
    SP_RELEASE_AND_NIL(_effect);
}

- (void)addQuad:(SPQuad *)quad
{
    [self addQuad:quad alpha:quad.alpha blendMode:quad.blendMode matrix:nil];
}

- (void)addQuad:(SPQuad *)quad alpha:(float)alpha
{
    [self addQuad:quad alpha:alpha blendMode:quad.blendMode matrix:nil];
}

- (void)addQuad:(SPQuad *)quad alpha:(float)alpha blendMode:(uint)blendMode
{
    [self addQuad:quad alpha:alpha blendMode:blendMode matrix:nil];
}

- (void)addQuad:(SPQuad *)quad alpha:(float)alpha blendMode:(uint)blendMode matrix:(SPMatrix *)matrix
{
    if (!matrix) matrix = quad.transformationMatrix;
    if (_numQuads + 1 > self.capacity) [self expand];
    if (_numQuads == 0)
    {
        SP_RELEASE_AND_RETAIN(_effect, quad.effect);
        SP_RELEASE_AND_RETAIN(_texture, quad.texture);
        _premultipliedAlpha = quad.premultipliedAlpha;
        self.blendMode = blendMode;
        [_vertexData setPremultipliedAlpha:_premultipliedAlpha updateVertices:NO];
    }
    
    int vertexID = _numQuads * 4;
    
    [quad copyVertexDataTo:_vertexData atIndex:vertexID];
    [_vertexData transformVerticesWithMatrix:matrix atIndex:vertexID numVertices:4];
    
    if (alpha != 1.0f)
        [_vertexData scaleAlphaBy:alpha atIndex:vertexID numVertices:4];
    
    if (!_tinted)
        _tinted = alpha != 1.0f || quad.tinted;
    
    _syncRequired = YES;
    _numQuads++;
}

- (void)addQuadBatch:(SPQuadBatch *)quadBatch
{
    [self addQuadBatch:quadBatch alpha:quadBatch.alpha blendMode:quadBatch.blendMode matrix:nil];
}

- (void)addQuadBatch:(SPQuadBatch *)quadBatch alpha:(float)alpha
{
    [self addQuadBatch:quadBatch alpha:alpha blendMode:quadBatch.blendMode matrix:nil];
}

- (void)addQuadBatch:(SPQuadBatch *)quadBatch alpha:(float)alpha blendMode:(uint)blendMode
{
    [self addQuadBatch:quadBatch alpha:alpha blendMode:blendMode matrix:nil];
}

- (void)addQuadBatch:(SPQuadBatch *)quadBatch alpha:(float)alpha blendMode:(uint)blendMode
              matrix:(SPMatrix *)matrix
{
    int vertexID = _numQuads * 4;
    int numQuads = quadBatch.numQuads;
    int numVertices = numQuads * 4;
    
    if (!matrix) matrix = quadBatch.transformationMatrix;
    if (_numQuads + numQuads > self.capacity) self.capacity = _numQuads + numQuads;
    if (_numQuads == 0)
    {
        SP_RELEASE_AND_RETAIN(_effect, quadBatch.effect);
        SP_RELEASE_AND_RETAIN(_texture, quadBatch.texture);
        _premultipliedAlpha = quadBatch.premultipliedAlpha;
        self.blendMode = blendMode;
        [_vertexData setPremultipliedAlpha:_premultipliedAlpha updateVertices:NO];
    }
    
    [quadBatch->_vertexData copyToVertexData:_vertexData atIndex:vertexID numVertices:numVertices];
    [_vertexData transformVerticesWithMatrix:matrix atIndex:vertexID numVertices:numVertices];
    
    if (alpha != 1.0f)
        [_vertexData scaleAlphaBy:alpha atIndex:vertexID numVertices:numVertices];
    
    if (!_tinted)
        _tinted = alpha != 1.0f || quadBatch.tinted;
    
    _syncRequired = YES;
    _numQuads += numQuads;
}

- (BOOL)isStateChangeWithEffect:(SPEffect *)effect texture:(SPTexture *)texture tinted:(BOOL)tinted
                          alpha:(float)alpha premultipliedAlpha:(BOOL)pma blendMode:(uint)blendMode
                       numQuads:(int)numQuads
{
    if (_numQuads == 0) return NO;
    else if (_numQuads + numQuads > MAX_NUM_QUADS) return YES; // maximum buffer size
    else if (_effect != effect)
        return YES;
    else if (!_texture && !texture)
        return self.blendMode != blendMode;
    else if (_texture && texture)
        return _tinted != (tinted || alpha != 1.0f) ||
               _texture.name != texture.name ||
               self.blendMode != blendMode;
    else return YES;
}

- (SPRectangle *)boundsInSpace:(SPDisplayObject *)targetSpace
{
    SPMatrix *matrix = targetSpace == self ? nil : [self transformationMatrixToSpace:targetSpace];
    return [_vertexData boundsAfterTransformation:matrix atIndex:0 numVertices:_numQuads*4];
}

- (void)render:(SPRenderSupport *)support
{
    if (_numQuads)
    {
        [support finishQuadBatch];
        [support addDrawCalls:1];

        [self renderWithMvpMatrix:support.mvpMatrix alpha:support.alpha blendMode:support.blendMode];
    }
}

#pragma mark Utility Methods

- (void)vertexDataDidChange
{
    _syncRequired = YES;
}

- (void)transformQuadAtIndex:(int)quadID matrix:(SPMatrix *)matrix
{
    [_vertexData transformVerticesWithMatrix:matrix atIndex:quadID * 4 numVertices:4];
    _syncRequired = YES;
}

- (uint)vertexColorOfQuad:(int)quadID atIndex:(int)vertexID
{
    return [_vertexData colorAtIndex:quadID * 4 + vertexID];
}

- (void)setVertexColor:(uint)color ofQuad:(int)quadID atIndex:(int)vertexID
{
    [_vertexData setColor:color atIndex:quadID * 4 + vertexID];
    _syncRequired = YES;
}

- (float)vertexAlphaOfQuad:(int)quadID atIndex:(int)vertexID
{
    return [_vertexData alphaAtIndex:quadID * 4 + vertexID];
}

- (void)setVertexAlpha:(float)alpha ofQuad:(int)quadID atIndex:(int)vertexID
{
    [_vertexData setAlpha:alpha atIndex:quadID * 4 + vertexID];
    _syncRequired = YES;
}

- (uint)vertexColorOfQuad:(int)quadID
{
    return [_vertexData colorAtIndex:quadID * 4];
}

- (void)setVertexColor:(uint)color ofQuad:(int)quadID
{
    for (int i=0; i<4; ++i)
        [_vertexData setColor:color atIndex:quadID * 4 + i];

    _syncRequired = YES;
}

- (float)vertexAlphaOfQuad:(int)quadID
{
    return [_vertexData alphaAtIndex:quadID * 4];
}

- (void)setVertexAlpha:(float)alpha ofQuad:(int)quadID
{
    for (int i=0; i<4; ++i)
        [_vertexData setAlpha:alpha atIndex:quadID * 4 + i];

    _syncRequired = YES;
}

- (SPRectangle *)boundsOfQuad:(int)quadID
{
    return [self boundsOfQuad:quadID afterTransformation:nil];
}

- (SPRectangle *)boundsOfQuad:(int)quadID afterTransformation:(SPMatrix *)matrix
{
    return [_vertexData boundsAfterTransformation:matrix atIndex:quadID * 4 numVertices:4];
}

#pragma mark Custom Rendering

- (void)renderWithMvpMatrix:(SPMatrix *)matrix
{
    [self renderWithMvpMatrix:matrix alpha:1.0f blendMode:self.blendMode];
}

- (void)renderWithMvpMatrix:(SPMatrix *)matrix alpha:(float)alpha blendMode:(uint)blendMode;
{
    if (!_numQuads) return;
    if (_syncRequired) [self syncBuffers];
    if (blendMode == SPBlendModeAuto)
        [NSException raise:SPExceptionInvalidOperation
                    format:@"cannot render object with blend mode AUTO"];

    BOOL tinted = _tinted || alpha != 1.0f;
    SPEffect *currentEffect = _effect ?: _baseEffect;

    if (currentEffect == _baseEffect)
        _baseEffect.useTinting = tinted;

    if (tinted)
    {
        if (_premultipliedAlpha)
            currentEffect.tintColor = GLKVector4Make(alpha, alpha, alpha, alpha);
        else
            currentEffect.tintColor = GLKVector4Make(1.0f, 1.0f, 1.0f, alpha);
    }

    currentEffect.mainTexture = _texture;
    currentEffect.mvpMatrix = [matrix convertToGLKMatrix4];
    
    [currentEffect prepareToDraw];

    [SPBlendMode applyBlendFactorsForBlendMode:blendMode premultipliedAlpha:_premultipliedAlpha];

    int attribPosition = _baseEffect.attribPosition;
    int attribColor    = _baseEffect.attribColor;
    int attribTexCoord = _baseEffect.attribTexCoords;

    glBindVertexArray(_vertexArrayName);

    // if the cache values differ, reconfigure the vertex array
    if (_attribCache[ATTRIB_POSITION] != attribPosition ||
        _attribCache[ATTRIB_COLOR]    != attribColor ||
        _attribCache[ATTRIB_TEXCOORD] != attribTexCoord)
    {
        // disable previous attributes

        if (_attribCache[ATTRIB_COLOR] != SPNotFound)
            glDisableVertexAttribArray(_attribCache[ATTRIB_COLOR]);

        if (_attribCache[ATTRIB_TEXCOORD] != SPNotFound)
            glDisableVertexAttribArray(_attribCache[ATTRIB_TEXCOORD]);

        // enable current attributes

        glEnableVertexAttribArray(attribPosition);

        if (attribColor != SPNotFound)
            glEnableVertexAttribArray(attribColor);

        if (attribTexCoord != SPNotFound)
            glEnableVertexAttribArray(attribTexCoord);

        // setup attribute pointers

        glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);

        glVertexAttribPointer(attribPosition, 2, GL_FLOAT, GL_FALSE, sizeof(SPVertex),
                              (void *)(offsetof(SPVertex, position)));

        if (attribColor != SPNotFound)
            glVertexAttribPointer(attribColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(SPVertex),
                                  (void *)(offsetof(SPVertex, color)));

        if (attribTexCoord != SPNotFound)
            glVertexAttribPointer(attribTexCoord, 2, GL_FLOAT, GL_FALSE, sizeof(SPVertex),
                                  (void *)(offsetof(SPVertex, texCoords)));

        // bind element buffer

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);

        _attribCache[ATTRIB_POSITION] = attribPosition;
        _attribCache[ATTRIB_COLOR]    = attribColor;
        _attribCache[ATTRIB_TEXCOORD] = attribTexCoord;
    }
    
    int numIndices = _numQuads * 6;
    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_SHORT, 0);

    glBindVertexArray(0);
}

#pragma mark Compilation Methods

+ (NSMutableArray *)compileObject:(SPDisplayObject *)object
{
    return [self compileObject:object intoArray:nil];
}

+ (NSMutableArray *)compileObject:(SPDisplayObject *)object intoArray:(NSMutableArray *)quadBatches
{
    if (!quadBatches) quadBatches = [NSMutableArray array];
    
    [self compileObject:object intoArray:quadBatches atPosition:-1
             withMatrix:[SPMatrix matrixWithIdentity] alpha:1.0f blendMode:SPBlendModeAuto];

    return quadBatches;
}

+ (int)compileObject:(SPDisplayObject *)object intoArray:(NSMutableArray *)quadBatches
          atPosition:(int)quadBatchID withMatrix:(SPMatrix *)transformationMatrix
               alpha:(float)alpha blendMode:(uint)blendMode
{
    BOOL isRootObject = NO;
    float objectAlpha = object.alpha;
    
    SPQuad *quad = [object isKindOfClass:[SPQuad class]] ? (SPQuad *)object : nil;
    SPQuadBatch *batch = [object isKindOfClass:[SPQuadBatch class]] ? (SPQuadBatch *)object :nil;
    SPDisplayObjectContainer *container = [object isKindOfClass:[SPDisplayObjectContainer class]] ?
                                          (SPDisplayObjectContainer *)object : nil;
    if (quadBatchID == -1)
    {
        isRootObject = YES;
        quadBatchID = 0;
        objectAlpha = 1.0f;
        blendMode = object.blendMode;
        if (quadBatches.count == 0) [quadBatches addObject:[SPQuadBatch quadBatch]];
        else [quadBatches[0] reset];
    }
    
    if (container)
    {
        SPDisplayObjectContainer *container = (SPDisplayObjectContainer *)object;
        SPMatrix *childMatrix = [SPMatrix matrixWithIdentity];
        
        for (SPDisplayObject *child in container)
        {
            if ([child hasVisibleArea])
            {
                uint childBlendMode = child.blendMode;
                if (childBlendMode == SPBlendModeAuto) childBlendMode = blendMode;
                
                [childMatrix copyFromMatrix:transformationMatrix];
                [childMatrix prependMatrix:child.transformationMatrix];
                quadBatchID = [self compileObject:child intoArray:quadBatches atPosition:quadBatchID
                                       withMatrix:childMatrix alpha:alpha * objectAlpha
                                        blendMode:childBlendMode];
            }
        }
    }
    else if (quad || batch)
    {
        SPEffect *effect = [(id)object effect];
        SPTexture *texture = [(id)object texture];
        BOOL tinted = [(id)object tinted];
        BOOL pma = [(id)object premultipliedAlpha];
        int numQuads = batch ? batch.numQuads : 1;
        
        SPQuadBatch *currentBatch = quadBatches[quadBatchID];

        if ([currentBatch isStateChangeWithEffect:effect texture:texture tinted:tinted
                                            alpha:alpha * objectAlpha premultipliedAlpha:pma
                                        blendMode:blendMode numQuads:numQuads])
        {
            quadBatchID++;
            if (quadBatches.count <= quadBatchID) [quadBatches addObject:[SPQuadBatch quadBatch]];
            currentBatch = quadBatches[quadBatchID];
            [currentBatch reset];
        }
        
        if (quad)
            [currentBatch addQuad:quad alpha:alpha * objectAlpha blendMode:blendMode
                           matrix:transformationMatrix];
        else
            [currentBatch addQuadBatch:batch alpha:alpha * objectAlpha blendMode:blendMode
                                matrix:transformationMatrix];
    }
    else
    {
        [NSException raise:SPExceptionInvalidOperation format:@"Unsupported display object: %@",
                                                           [object class]];
    }
    
    if (isRootObject)
    {
        // remove unused batches
        for (int i=(int)quadBatches.count-1; i>quadBatchID; --i)
            [quadBatches removeLastObject];
    }
    
    return quadBatchID;
}

#pragma mark Properties

- (int)capacity
{
    return _vertexData.numVertices / 4;
}

- (void)setCapacity:(int)newCapacity
{
    NSAssert(newCapacity > 0, @"capacity must not be zero");

    int oldCapacity = self.capacity;
    int numVertices = newCapacity * 4;
    int numIndices  = newCapacity * 6;

    _vertexData.numVertices = numVertices;

    if (!_indexData) _indexData = malloc(sizeof(ushort) * numIndices);
    else             _indexData = realloc(_indexData, sizeof(ushort) * numIndices);

    for (int i=oldCapacity; i<newCapacity; ++i)
    {
        _indexData[i*6  ] = i*4;
        _indexData[i*6+1] = i*4 + 1;
        _indexData[i*6+2] = i*4 + 2;
        _indexData[i*6+3] = i*4 + 1;
        _indexData[i*6+4] = i*4 + 3;
        _indexData[i*6+5] = i*4 + 2;
    }

    [self destroyBuffers];
    _syncRequired = YES;
}

#pragma mark Private

- (void)expand
{
    int oldCapacity = self.capacity;
    self.capacity = oldCapacity < 8 ? 16 : oldCapacity * 2;
}

- (void)createBuffers
{
    [self destroyBuffers];

    int numVertices = _vertexData.numVertices;
    int numIndices = numVertices / 4 * 6;
    if (numVertices == 0) return;

    glGenBuffers(1, &_vertexBufferName);
    glGenBuffers(1, &_indexBufferName);
    glGenVertexArrays(1, &_vertexArrayName);

    if (!_vertexBufferName || !_indexBufferName)
        [NSException raise:SPExceptionOperationFailed format:@"could not create vertex buffers"];

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(ushort) * numIndices, _indexData, GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

    _syncRequired = YES;
}

- (void)destroyBuffers
{
    if (_vertexBufferName)
    {
        glDeleteBuffers(1, &_vertexBufferName);
        _vertexBufferName = 0;
    }

    if (_indexBufferName)
    {
        glDeleteBuffers(1, &_indexBufferName);
        _indexBufferName = 0;
    }

    if (_vertexArrayName)
    {
        glDeleteVertexArrays(1, &_vertexArrayName);
        _vertexArrayName = 0;
    }

    memset(_attribCache, SPNotFound, sizeof(_attribCache));
}

- (void)syncBuffers
{
    if (!_vertexBufferName)
        [self createBuffers];

    // don't use 'glBufferSubData'! It's much slower than uploading
    // everything via 'glBufferData', at least on the iPad 1.

    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);
    glBufferData(GL_ARRAY_BUFFER, sizeof(SPVertex) * _vertexData.numVertices,
                 _vertexData.vertices, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    _syncRequired = NO;
}

@end
