//
//  SPRenderSupport.m
//  Sparrow
//
//  Created by Daniel Sperl on 28.09.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPBlendMode.h"
#import "SPDisplayObject.h"
#import "SPMacros.h"
#import "SPMatrix_Internal.h"
#import "SPQuad.h"
#import "SPQuadBatch.h"
#import "SPRenderSupport.h"
#import "SPTexture.h"
#import "SPVertexData.h"
#import "SPViewController.h"

#import <GLKit/GLKit.h>

// --- helper macros -------------------------------------------------------------------------------

#define CURRENT_STATE()  ((SPRenderState*)(_stateStack[_stateStackIndex]))
#define CURRENT_BATCH()  ((SPQuadBatch*)(_quadBatches[_quadBatchIndex]))

// --- helper class --------------------------------------------------------------------------------

@interface SPRenderState : NSObject

@property (nonatomic, copy) SPMatrix* modelviewMatrix;
@property (nonatomic) float alpha;
@property (nonatomic) uint blendMode;

+ (instancetype)renderState;

- (void)setupWithState:(SPRenderState*)state;
- (void)setupDerivedFromState:(SPRenderState*)state withModelviewMatrix:(SPMatrix*)matrix
                        alpha:(float)alpha blendMode:(uint)blendMode;

@end

@implementation SPRenderState

- (instancetype)init
{
    if ((self = [super init]))
    {
        _modelviewMatrix = [[SPMatrix alloc] init];
        _alpha = 1.0f;
        _blendMode = SP_BLEND_MODE_NORMAL;
    }
    return self;
}

- (void)dealloc
{
    SP_RELEASE_AND_NIL(_modelviewMatrix);
    [super dealloc];
}

- (void)setupWithState:(SPRenderState*)state
{
    _alpha = state->_alpha;
    _blendMode = state->_blendMode;

    SPMatrixCopyFrom(_modelviewMatrix, state->_modelviewMatrix);
}

- (void)setupDerivedFromState:(SPRenderState*)state withModelviewMatrix:(SPMatrix*)matrix
                        alpha:(float)alpha blendMode:(uint)blendMode
{
    _alpha = alpha * state->_alpha;
    _blendMode = blendMode == SP_BLEND_MODE_AUTO ? state->_blendMode : blendMode;

    SPMatrixCopyFrom(_modelviewMatrix, state->_modelviewMatrix);
    SPMatrixPrependMatrix(_modelviewMatrix, matrix);
}

+ (instancetype)renderState
{
    return [[[self alloc] init] autorelease];
}

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPRenderSupport
{
    SPMatrix*       _projectionMatrix;
    SPMatrix*       _mvpMatrix;
    int             _numDrawCalls;
    
    NSMutableArray* _stateStack;
    int             _stateStackIndex;
    int             _stateStackSize;
    
    NSMutableArray* _quadBatches;
    int             _quadBatchIndex;
    int             _quadBatchSize;

    NSMutableArray* _clipRectStack;
    int             _clipRectStackIndex;
    int             _clipRectStackSize;
}

@synthesize projectionMatrix    = _projectionMatrix;
@synthesize mvpMatrix           = _mvpMatrix;
@synthesize numDrawCalls        = _numDrawCalls;

- (instancetype)init
{
    if ((self = [super init]))
    {
        _projectionMatrix = [[SPMatrix alloc] init];
        _mvpMatrix        = [[SPMatrix alloc] init];
        
        _stateStack = [[NSMutableArray alloc] initWithObjects:[SPRenderState renderState], nil];
        _stateStackIndex = 0;
        _stateStackSize = 1;
        
        _quadBatches = [[NSMutableArray alloc] initWithObjects:[SPQuadBatch quadBatch], nil];
        _quadBatchIndex = 0;
        _quadBatchSize = 1;

        _clipRectStack = [[NSMutableArray alloc] init];
        _clipRectStackIndex = 0;
        _clipRectStackSize = 0;
        
        [self setupOrthographicProjectionWithLeft:0 right:320 top:0 bottom:480];
    }
    return self;
}

- (void)dealloc
{
    SP_RELEASE_AND_NIL(_projectionMatrix);
    SP_RELEASE_AND_NIL(_mvpMatrix);
    SP_RELEASE_AND_NIL(_stateStack);
    SP_RELEASE_AND_NIL(_quadBatches);
    SP_RELEASE_AND_NIL(_clipRectStack);

    [super dealloc];
}

- (void)nextFrame
{
    _stateStackIndex = 0;
    _quadBatchIndex = 0;
    _numDrawCalls = 0;
}

- (void)purgeBuffers
{
    [_quadBatches removeAllObjects];
    [_quadBatches addObject:[SPQuadBatch quadBatch]];
     _quadBatchIndex = 0;
     _quadBatchSize = 1;
}

- (void)clear
{
    [SPRenderSupport clearWithColor:0x0 alpha:0.0f];
}

- (void)clearWithColor:(uint)color
{
    [SPRenderSupport clearWithColor:color alpha:1.0f];
}

- (void)clearWithColor:(uint)color alpha:(float)alpha
{
    [SPRenderSupport clearWithColor:color alpha:alpha];
}

- (void)applyBlendModeWithPremulitpliedAlpha:(BOOL)pma
{
    [SPBlendMode applyBlendFactorsForBlendMode:CURRENT_STATE().blendMode premultipliedAlpha:pma];
}

+ (void)clearWithColor:(uint)color alpha:(float)alpha;
{
    float red   = SP_COLOR_PART_RED(color)   / 255.0f;
    float green = SP_COLOR_PART_GREEN(color) / 255.0f;
    float blue  = SP_COLOR_PART_BLUE(color)  / 255.0f;
    
    glClearColor(red, green, blue, alpha);
    glClear(GL_COLOR_BUFFER_BIT);
}

+ (uint)checkForOpenGLError
{
    GLenum error = glGetError();
    if (error != 0) NSLog(@"There was an OpenGL error: 0x%x", error);
    return error;
}

- (void)addDrawCalls:(int)count
{
    _numDrawCalls += count;
}

- (void)setupOrthographicProjectionWithLeft:(float)left right:(float)right
                                        top:(float)top bottom:(float)bottom;
{
    [_projectionMatrix setA:2.0f/(right-left) b:0.0f c:0.0f d:2.0f/(top-bottom)
                         tx:-(right+left) / (right-left)
                         ty:-(top+bottom) / (top-bottom)];
    
    [self applyClipRect];
}

#pragma mark - clip rect stack

- (SPRectangle*)pushClipRect:(SPRectangle*)clipRect
{
    if (_clipRectStack.count < _clipRectStackSize+1)
        [_clipRectStack addObject:[[[SPRectangle alloc] init] autorelease]];

    [_clipRectStack[_clipRectStackSize] copyFromRectangle:clipRect];
    SPRectangle* rectangle = _clipRectStack[_clipRectStackSize];

    // intersect with the last pushed clip rect
    if (_clipRectStackSize > 0)
        rectangle = [rectangle intersectionWithRectangle:_clipRectStack[_clipRectStackSize-1]];

    ++ _clipRectStackSize;
    [self applyClipRect];

    // return the intersected clip rect so callers can skip draw calls if it's empty
    return rectangle;
}

- (void)popClipRect
{
    if (_clipRectStackSize > 0)
    {
        -- _clipRectStackSize;
        [self applyClipRect];
    }
}

- (void)applyClipRect
{
    [self finishQuadBatch];

    if (_clipRectStackSize > 0)
    {
        SPRectangle* rect = _clipRectStack[_clipRectStackSize-1];
        SPRectangle* clip = [[rect copy] autorelease];
        SPPoint* point = nil;

        SPViewPort viewport;
        glGetIntegerv(GL_VIEWPORT, (int*)&viewport);

        // convert to pixel coordinates (matrix transformation ends up in range [-1, 1])
        point = SPMatrixTransformPointWith(_projectionMatrix, rect.x, rect.y);
        clip.x = point.x > -1 ? (( point.x + 1) / 2) * viewport.width  : 0.0;
        clip.y = point.y > -1 ? ((-point.y + 1) / 2) * viewport.height : 0.0;

        point = SPMatrixTransformPointWith(_projectionMatrix, rect.right, rect.bottom);
        clip.right  = point.x < 1 ? (( point.x + 1) / 2) * viewport.width  : viewport.width;
        clip.bottom = point.y < 1 ? ((-point.y + 1) / 2) * viewport.height : viewport.height;

        // an empty rectangle is not allowed, so we set it to the smallest possible size
        // if the bounds are outside the visible area.
        if (clip.right < 1 || clip.bottom < 1)
            [clip setX:0 y:0 width:1 height:1];
        // convert to OpenGL coordinate
        else
            clip.y = MAX((viewport.height - clip.y - clip.height), 0.0);

        glEnable(GL_SCISSOR_TEST);
        glScissor(clip.x, clip.y, clip.width, clip.height);
    }
    else glDisable(GL_SCISSOR_TEST);
}

#pragma mark - state stack

- (void)pushStateWithMatrix:(SPMatrix*)matrix alpha:(float)alpha blendMode:(uint)blendMode
{
    SPRenderState* previousState = CURRENT_STATE();
    
    if (_stateStackSize == _stateStackIndex + 1)
    {
        [_stateStack addObject:[SPRenderState renderState]];
        ++_stateStackSize;
    }
    
    ++_stateStackIndex;
    
    [CURRENT_STATE() setupDerivedFromState:previousState withModelviewMatrix:matrix
                                     alpha:alpha blendMode:blendMode];
}

- (void)popState
{
    if (_stateStackIndex == 0)
        [NSException raise:SP_EXC_INVALID_OPERATION format:@"The state stack must not be empty"];
        
    --_stateStackIndex;
}

- (float)alpha
{
    return CURRENT_STATE().alpha;
}

- (uint)blendMode
{
    return CURRENT_STATE().blendMode;
}

- (SPMatrix*)modelviewMatrix
{
    return CURRENT_STATE().modelviewMatrix;
}

- (SPMatrix*)mvpMatrix
{
    SPMatrixCopyFrom(_mvpMatrix, CURRENT_STATE().modelviewMatrix);
    SPMatrixAppendMatrix(_mvpMatrix, _projectionMatrix);
    return _mvpMatrix;
}

#pragma mark - rendering

- (void)batchQuad:(SPQuad*)quad
{
    SPRenderState* currentState = CURRENT_STATE();
    SPQuadBatch* currentBatch = CURRENT_BATCH();
    
    float alpha = currentState.alpha;
    uint blendMode = currentState.blendMode;
    SPMatrix* modelviewMatrix = currentState.modelviewMatrix;
    
    if ([currentBatch isStateChangeWithTinted:quad.tinted texture:quad.texture alpha:alpha
                           premultipliedAlpha:quad.premultipliedAlpha blendMode:blendMode
                                     numQuads:1])
    {
        [self finishQuadBatch];
        currentBatch = CURRENT_BATCH();
    }
    
    [currentBatch addQuad:quad alpha:alpha blendMode:blendMode matrix:modelviewMatrix];
}

- (void)batchQuadBatch:(SPQuadBatch*)quadBatch
{
    SPRenderState* currentState = CURRENT_STATE();
    SPQuadBatch* currentBatch = CURRENT_BATCH();

    float alpha = currentState.alpha;
    uint blendMode = currentState.blendMode;
    SPMatrix* modelviewMatrix = currentState.modelviewMatrix;

    if ([currentBatch isStateChangeWithTinted:quadBatch.tinted texture:quadBatch.texture alpha:alpha
                           premultipliedAlpha:quadBatch.premultipliedAlpha blendMode:blendMode
                                     numQuads:quadBatch.numQuads])
    {
        [self finishQuadBatch];
        currentBatch = CURRENT_BATCH();
    }

    [currentBatch addQuadBatch:quadBatch alpha:alpha blendMode:blendMode matrix:modelviewMatrix];
}

- (void)finishQuadBatch
{
    SPQuadBatch* currentBatch = CURRENT_BATCH();
    
    if (currentBatch.numQuads)
    {
        [currentBatch renderWithMvpMatrix:_projectionMatrix];
        [currentBatch reset];
        
        ++_quadBatchIndex;
        ++_numDrawCalls;
        
        if (_quadBatchSize <= _quadBatchIndex)
        {
            [_quadBatches addObject:[SPQuadBatch quadBatch]];
            ++_quadBatchSize;
        }
    }
}

@end

