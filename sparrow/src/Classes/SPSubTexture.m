//
//  SPSubTexture.m
//  Sparrow
//
//  Created by Daniel Sperl on 27.06.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPMacros.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPGLTexture.h>
#import <Sparrow/SPSubTexture.h>
#import <Sparrow/SPVertexData.h>

@implementation SPSubTexture
{
    SPTexture *_parent;
    SPMatrix *_transformationMatrix;
    SPRectangle *_frame;
    float _width;
    float _height;
}

@synthesize frame = _frame;

#pragma mark Initialization

- (instancetype)initWithRegion:(SPRectangle *)region ofTexture:(SPTexture *)texture
{
    return [self initWithRegion:region frame:nil ofTexture:texture];
}

- (instancetype)initWithRegion:(SPRectangle *)region frame:(SPRectangle *)frame
                     ofTexture:(SPTexture *)texture
{
    return [self initWithRegion:region frame:frame rotated:NO ofTexture:texture];
}

- (instancetype)initWithRegion:(SPRectangle *)region frame:(SPRectangle *)frame
                       rotated:(BOOL)rotated ofTexture:(SPTexture *)texture
{
    if ((self = [super init]))
    {
        if (!region)
             region = [SPRectangle rectangleWithX:0 y:0 width:texture.width height:texture.height];

        _parent = [texture retain];
        _frame  = [frame copy];
        _transformationMatrix = [[SPMatrix alloc] init];
        _width  = rotated ? region.height : region.width;
        _height = rotated ? region.width  : region.height;

        if (rotated)
        {
            [_transformationMatrix translateXBy:0 yBy:-1];
            [_transformationMatrix rotateBy:PI / 2.0f];
        }

        [_transformationMatrix scaleXBy:region.width  / texture.width
                                    yBy:region.height / texture.height];
        [_transformationMatrix translateXBy:region.x / texture.width
                                        yBy:region.y / texture.height];
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
    [_parent release];
    [_transformationMatrix release];
    [_frame release];
    [super dealloc];
}

+ (instancetype)textureWithRegion:(SPRectangle *)region ofTexture:(SPTexture *)texture
{
    return [[[self alloc] initWithRegion:region ofTexture:texture] autorelease];
}

#pragma mark SPTexture

- (void)adjustVertexData:(SPVertexData *)vertexData atIndex:(int)index numVertices:(int)count
{
    SPVertex *vertices = vertexData.vertices;
    size_t stride = sizeof(SPVertex) - sizeof(GLKVector2);

    [self adjustPositions:&vertices[index].position  numVertices:count stride:stride];
    [self adjustTexCoords:&vertices[index].texCoords numVertices:count stride:stride];
}

- (void)adjustTexCoords:(void *)data numVertices:(int)count stride:(int)stride
{
    SPTexture *texture = self;
    SPMatrix *matrix = [[SPMatrix alloc] init];

    do
    {
        SPSubTexture *subTexture = (SPSubTexture *)texture;
        [matrix appendMatrix:subTexture->_transformationMatrix];
        texture = subTexture->_parent;
    }
    while ([texture isKindOfClass:[SPSubTexture class]]);

    for (int i=0; i<count; ++i)
    {
        float *dataf = (float *)data;
        SPPoint *texCoords = [matrix transformPointWithX:dataf[0] y:dataf[1]];
        dataf[0] = texCoords.x;
        dataf[1] = texCoords.y;
        data += sizeof(GLKVector2) + stride;
    }

    [matrix release];
}

- (void)adjustPositions:(void *)data numVertices:(int)count stride:(int)stride
{
    if (_frame)
    {
        if (count != 4)
            [NSException raise:SPExceptionInvalidOperation
                        format:@"Textures with a frame can only be used on quads"];

        float deltaRight  = _frame.width  + _frame.x - _width;
        float deltaBottom = _frame.height + _frame.y - _height;

        float *dataf;
        size_t step = sizeof(GLKVector2) + stride;

        dataf = (float *)data;
        dataf[0] -= _frame.x;
        dataf[1] -= _frame.y;

        dataf = (float *)(data + step);
        dataf[0] -= deltaRight;
        dataf[1] -= _frame.y;

        dataf = (float *)(data + 2*step);
        dataf[0] -= _frame.x;
        dataf[1] -= deltaBottom;

        dataf = (float *)(data + 3*step);
        dataf[0] -= deltaRight;
        dataf[1] -= deltaBottom;
    }
}

- (float)width
{
    return _width;
}

- (float)height
{
    return _height;
}

- (float)nativeWidth
{
    return _width * self.scale;
}

- (float)nativeHeight
{
    return _height * self.scale;
}

- (uint)name
{
    return _parent.name;
}

- (SPGLTexture *)root
{
    return _parent.root;
}

- (void)setRepeat:(BOOL)value
{
    _parent.repeat = value;
}

- (BOOL)repeat
{
    return _parent.repeat;
}

- (SPTextureSmoothing)smoothing
{    
    return _parent.smoothing;
}

- (void)setSmoothing:(SPTextureSmoothing)value
{
    _parent.smoothing = value;
}

- (BOOL)premultipliedAlpha
{
    return _parent.premultipliedAlpha;
}

- (float)scale
{
    return _parent.scale;
}

#pragma mark Properties

- (SPRectangle *)clipping
{
    SPPoint *topLeft     = [_transformationMatrix transformPointWithX:0.0f y:0.0f];
    SPPoint *bottomRight = [_transformationMatrix transformPointWithX:1.0f y:1.0f];
    SPRectangle *clipping = [SPRectangle rectangleWithX:topLeft.x y:topLeft.y
                                                  width:bottomRight.x - topLeft.x
                                                 height:bottomRight.y - topLeft.y];
    [clipping normalize];
    return clipping;
}

@end
