//
//  SPGLUniformCache.h
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import "SPMacros.h"

#pragma mark -
#pragma mark - SPGLUniformCache
#pragma mark -

typedef struct __SPGLUniformCache*  SPGLUniformCacheRef;

SP_EXTERN SPGLUniformCacheRef       SPGLUniformCacheCreate(uint program);
SP_EXTERN void                      SPGLUniformCacheDestroy(SPGLUniformCacheRef cache);
SP_EXTERN void                      SPGLUniformCacheFreeUniforms(SPGLUniformCacheRef cache);

SP_EXTERN Boolean                   SPGLUniformCacheIsUniformDirty(SPGLUniformCacheRef cache, uint index, const void* data, uint size);
SP_EXTERN Boolean                   SPGLUniformCacheIsUniformDirtyFloat(SPGLUniformCacheRef cache, uint index, float value);
SP_EXTERN Boolean                   SPGLUniformCacheIsUniformDirtyInt(SPGLUniformCacheRef cache, uint index, int value);

SP_EXTERN uint                      SPGLUniformCacheGetProgram(SPGLUniformCacheRef cache);

#pragma mark -
#pragma mark - SPGLProgramCache
#pragma mark -

typedef struct __SPGLProgramCache*  SPGLProgramCacheRef;

SP_EXTERN SPGLProgramCacheRef       SPGLProgramCacheCreate(uint capacity);
SP_EXTERN void                      SPGLProgramCacheDestroy(SPGLProgramCacheRef cache);
SP_EXTERN void                      SPGLProgramCacheFreeUniformCaches(SPGLProgramCacheRef cache);

SP_EXTERN void                      SPGLProgramCacheCreateWithProgram(SPGLProgramCacheRef cache, uint program);
SP_EXTERN void                      SPGLProgramCacheDestroyCacheWithProgram(SPGLProgramCacheRef cache, uint program);
SP_EXTERN SPGLUniformCacheRef       SPGLProgramCacheGetUniformCacheForProgram(SPGLProgramCacheRef cache, uint program);
