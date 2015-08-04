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

#import "SPBaseEffect.h"
#import "SPBlendMode.h"
#import "SPDisplayObjectContainer.h"
#import "SPImage.h"
#import "SPMacros.h"
#import "SPMatrix.h"
#import "SPMatrix3D.h"
#import "SPOpenGL.h"
#import "SPQuadBatch.h"
#import "SPRenderSupport.h"
#import "SPTexture.h"
#import "SPVertexData.h"

// --- class implementation ------------------------------------------------------------------------

@implementation SPQuadBatch
{
    int _numQuads;
    BOOL _syncRequired;
    
    SPTexture *_texture;
    BOOL _premultipliedAlpha;
    BOOL _tinted;
    BOOL _batchable;
    
    SPBaseEffect *_baseEffect;
    uint _vertexBufferName;
    ushort *_indexData;
    uint _indexBufferName;
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
    
    glDeleteBuffers(1, &_vertexBufferName);
    glDeleteBuffers(1, &_indexBufferName);

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

- (void)onVertexDataChanged
{
    _syncRequired = YES;
}

- (void)reset
{
    _numQuads = 0;
    _syncRequired = YES;
    _baseEffect.texture = nil;
    SP_RELEASE_AND_NIL(_texture);
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

- (BOOL)isStateChangeWithTinted:(BOOL)tinted texture:(SPTexture *)texture alpha:(float)alpha
             premultipliedAlpha:(BOOL)pma blendMode:(uint)blendMode numQuads:(int)numQuads
{
    if (_numQuads == 0) return NO;
    else if (_numQuads + numQuads > 8192) return YES; // maximum buffer size
    else if (!_texture && !texture)
        return _premultipliedAlpha != pma || self.blendMode != blendMode;
    else if (_texture && texture)
        return _tinted != (tinted || alpha != 1.0f) ||
               _texture.name != texture.name ||
               self.blendMode != blendMode;
    else return YES;
}

- (void)renderWithMvpMatrix:(SPMatrix *)matrix
{
    [self renderWithMvpMatrix3D:[matrix convertTo3D] alpha:1.0f blendMode:self.blendMode];
}

- (void)renderWithMvpMatrix:(SPMatrix *)matrix alpha:(float)alpha blendMode:(uint)blendMode
{
    [self renderWithMvpMatrix3D:[matrix convertTo3D] alpha:alpha blendMode:blendMode];
}

- (void)renderWithMvpMatrix3D:(SPMatrix3D *)matrix
{
    [self renderWithMvpMatrix3D:matrix alpha:1.0f blendMode:self.blendMode];
}

- (void)renderWithMvpMatrix3D:(SPMatrix3D *)matrix alpha:(float)alpha blendMode:(uint)blendMode;
{
    if (!_numQuads) return;
    if (_syncRequired) [self syncBuffers];
    if (blendMode == SPBlendModeAuto)
        [NSException raise:SPExceptionInvalidOperation
                    format:@"cannot render object with blend mode AUTO"];
    
    _baseEffect.texture = _texture;
    _baseEffect.premultipliedAlpha = _premultipliedAlpha;
    _baseEffect.mvpMatrix3D = matrix;
    _baseEffect.useTinting = _tinted || alpha != 1.0f;
    _baseEffect.alpha = alpha;
    
    [_baseEffect prepareToDraw];
    
    [SPBlendMode applyBlendFactorsForBlendMode:blendMode premultipliedAlpha:_premultipliedAlpha];
    
    int attribPosition  = _baseEffect.attribPosition;
    int attribColor     = _baseEffect.attribColor;
    int attribTexCoords = _baseEffect.attribTexCoords;
    
    glEnableVertexAttribArray(attribPosition);
    glEnableVertexAttribArray(attribColor);
    
    if (_texture)
        glEnableVertexAttribArray(attribTexCoords);
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);
    
    glVertexAttribPointer(attribPosition, 2, GL_FLOAT, GL_FALSE, sizeof(SPVertex),
                          (void *)(offsetof(SPVertex, position)));
    
    glVertexAttribPointer(attribColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(SPVertex),
                          (void *)(offsetof(SPVertex, color)));
    
    if (_texture)
    {
        glVertexAttribPointer(attribTexCoords, 2, GL_FLOAT, GL_FALSE, sizeof(SPVertex),
                              (void *)(offsetof(SPVertex, texCoords)));
    }
    
    int numIndices = _numQuads * 6;
    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_SHORT, 0);
}

#pragma mark Utility Methods

- (void)transformQuadAtIndex:(int)index withMatrix:(SPMatrix *)matrix
{
    [_vertexData transformVerticesWithMatrix:matrix atIndex:index * 4 numVertices:4];
    _syncRequired = YES;
}

- (uint)vertexColorOfQuadAtIndex:(int)quadID vertexID:(int)vertexID
{
    return [_vertexData colorAtIndex:quadID * 4 + vertexID];
}

- (void)setVertexColor:(uint)color atIndex:(int)quadID vertexID:(int)vertexID
{
    [_vertexData setColor:color atIndex:quadID * 4 + vertexID];
    _syncRequired = YES;
}

- (float)vertexAlphaAtIndex:(int)quadID vertexID:(int)vertexID
{
    return [_vertexData alphaAtIndex:quadID * 4 + vertexID];
}

- (void)setVertexAlpha:(float)alpha atIndex:(int)quadID vertexID:(int)vertexID
{
    [_vertexData setAlpha:alpha atIndex:quadID * 4 + vertexID];
    _syncRequired = YES;
}

- (uint)quadColorAtIndex:(int)quadID
{
    return [_vertexData colorAtIndex:quadID * 4];
}

- (void)setQuadColor:(uint)color atIndex:(int)quadID
{
    for (int i=0; i<4; ++i)
        [_vertexData setColor:color atIndex:quadID * 4 + i];
    
    _syncRequired = YES;
}

- (float)quadAlphaAtIndex:(int)quadID
{
    return [_vertexData alphaAtIndex:quadID * 4];
}

- (void)setQuadAlpha:(float)alpha atIndex:(int)quadID
{
    for (int i=0; i<4; ++i)
        [_vertexData setAlpha:alpha atIndex:quadID * 4 + i];
    
    _syncRequired = YES;
}

- (void)setQuad:(SPQuad *)quad atIndex:(int)quadID
{
    SPMatrix *matrix = quad.transformationMatrix;
    float alpha = quad.alpha;
    int vertexID = quadID * 4;
    
    [quad copyVertexDataTo:_vertexData atIndex:vertexID];
    [_vertexData transformVerticesWithMatrix:matrix atIndex:vertexID numVertices:4];
    if (alpha != 1.0) [_vertexData scaleAlphaBy:alpha atIndex:vertexID numVertices:4];
    
    _syncRequired = YES;
}

- (SPRectangle *)boundsOfQuadAtIndex:(int)quadID
{
    return [self boundsOfQuadAtIndex:quadID afterTransformation:nil];
}

- (SPRectangle *)boundsOfQuadAtIndex:(int)quadID afterTransformation:(SPMatrix *)matrix
{
    return [_vertexData boundsAfterTransformation:matrix atIndex:quadID * 4 numVertices:4];
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

#pragma mark SPDisplayObject

- (SPRectangle *)boundsInSpace:(SPDisplayObject *)targetSpace
{
    SPMatrix *matrix = targetSpace == self ? nil : [self transformationMatrixToSpace:targetSpace];
    return [_vertexData boundsAfterTransformation:matrix atIndex:0 numVertices:_numQuads*4];
}

- (void)render:(SPRenderSupport *)support
{
    if (_numQuads)
    {
        if (_batchable)
            [support batchQuadBatch:self];
        else
        {
            [support finishQuadBatch];
            [support addDrawCalls:1];
            [self renderWithMvpMatrix3D:support.mvpMatrix3D alpha:support.alpha blendMode:support.blendMode];
        }
    }
}

#pragma mark Compilation Methods

+ (NSMutableArray<SPQuadBatch*> *)compileObject:(SPDisplayObject *)object
{
    return [self compileObject:object intoArray:nil];
}

+ (NSMutableArray<SPQuadBatch*> *)compileObject:(SPDisplayObject *)object intoArray:(NSMutableArray<SPQuadBatch*> *)quadBatches
{
    if (!quadBatches) quadBatches = [NSMutableArray array];
    
    [self compileObject:object intoArray:quadBatches atPosition:-1
             withMatrix:[SPMatrix matrixWithIdentity] alpha:1.0f blendMode:SPBlendModeAuto];

    return quadBatches;
}

+ (void)optimize:(NSMutableArray<SPQuadBatch*> *)quadBatches
{
    SPQuadBatch *batch1, *batch2;
    for (int i=0; i<quadBatches.count; ++i)
    {
        batch1 = quadBatches[i];
        for (int j=i+1; j<quadBatches.count; )
        {
            batch2 = quadBatches[j];
            if (![batch1 isStateChangeWithTinted:batch2.tinted texture:batch2.texture alpha:batch2.alpha
                              premultipliedAlpha:batch2.premultipliedAlpha blendMode:batch2.blendMode
                                        numQuads:batch2.numQuads])
            {
                [batch1 addQuadBatch:batch2];
                [quadBatches removeObjectAtIndex:j];
            }
            else ++j;
        }
    }
}

+ (int)compileObject:(SPDisplayObject *)object intoArray:(NSMutableArray<SPQuadBatch*> *)quadBatches
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
        SPTexture *texture = [(id)object texture];
        BOOL tinted = [(id)object tinted];
        BOOL pma = [(id)object premultipliedAlpha];
        int numQuads = batch ? batch.numQuads : 1;
        
        SPQuadBatch *currentBatch = quadBatches[quadBatchID];
        
        if ([currentBatch isStateChangeWithTinted:tinted texture:texture alpha:alpha * objectAlpha
                               premultipliedAlpha:pma blendMode:blendMode numQuads:numQuads])
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

    if (!_vertexBufferName || !_indexBufferName)
        [NSException raise:SPExceptionOperationFailed format:@"could not create vertex buffers"];

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(ushort) * numIndices, _indexData, GL_STATIC_DRAW);

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

    _syncRequired = NO;
}

@end
