//
//  SPGLUniformCache.m
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPOpenGL_Internal.h"

// --- SPGLUniform ---------------------------------------------------------------------------------

struct __SPGLUniform {
    uint    size;
    void*   data;
};
typedef struct __SPGLUniform* SPGLUniformRef;

SPGLUniformRef  SPGLUniformCreate(void)
{
    SPGLUniformRef uniform = calloc(sizeof(struct __SPGLUniform), 1);
    return uniform;
}

void SPGLUniformDestroy(SPGLUniformRef uniform)
{
    free(uniform->data);
    free(uniform);
}

Boolean SPGLUniformIsDirty(SPGLUniformRef uniform, const void* data, uint size)
{
    if (size != uniform->size)
    {
        uniform->size = size;
        if (!uniform->data) uniform->data = malloc(size);
        else                uniform->data = realloc(uniform->data, size);
    }

    Boolean dirty = memcmp(uniform->data, data, size) != 0;
    if (dirty) memcpy(uniform->data, data, size);

    return dirty;
}

// --- SPGLUniformCache ----------------------------------------------------------------------------

struct __SPGLUniformCache {
    uint            program;
    SPGLUniformRef* uniforms;
    uint            uniformsCap;
    uint            uniformsSize;
};

void __SPGLUniformCacheResizeIfNeeded(SPGLUniformCacheRef cache, uint size)
{
    if (!cache->uniforms)
    {
        cache->uniformsCap = 4;
        cache->uniforms = calloc(sizeof(SPGLUniformRef)*cache->uniformsCap, 1);
    }
    else if (size >= cache->uniformsCap)
    {
        cache->uniformsCap <<= 2;
        cache->uniforms = realloc(cache->uniforms, sizeof(SPGLUniformRef)*cache->uniformsCap);
    }

    if (cache->uniformsSize < size)
    {
        uint oldSize = cache->uniformsSize;
        for (int i=oldSize; i<size; i++)
        {
            cache->uniforms[i] = SPGLUniformCreate();
            cache->uniformsSize++;
        }
    }
}

SPGLUniformCacheRef SPGLUniformCacheCreate(uint programName)
{
    SPGLUniformCacheRef cache = calloc(sizeof(struct __SPGLUniformCache), 1);
    cache->program = programName;
    return cache;
}

void SPGLUniformCacheDestroy(SPGLUniformCacheRef cache)
{
    SPGLUniformCacheFreeUniforms(cache);
    free(cache->uniforms);
    free(cache);
}

void SPGLUniformCacheFreeUniforms(SPGLUniformCacheRef cache)
{
    if (cache->uniforms)
    {
        for (int i=0; i<cache->uniformsSize; i++)
        {
            SPGLUniformDestroy(cache->uniforms[i]);
            cache->uniforms[i] = NULL;
        }
    }

    cache->uniformsSize = 0;
}

Boolean SPGLUniformCacheIsUniformDirty(SPGLUniformCacheRef cache, uint index, const void* data, uint size)
{
    __SPGLUniformCacheResizeIfNeeded(cache, index+1);
    return SPGLUniformIsDirty(cache->uniforms[index], data, size);
}

Boolean SPGLUniformCacheIsUniformDirtyFloat(SPGLUniformCacheRef cache, uint index, float value)
{
    __SPGLUniformCacheResizeIfNeeded(cache, index+1);
    return SPGLUniformIsDirty(cache->uniforms[index], &value, sizeof(float));
}

Boolean SPGLUniformCacheIsUniformDirtyInt(SPGLUniformCacheRef cache, uint index, int value)
{
    __SPGLUniformCacheResizeIfNeeded(cache, index+1);
    return SPGLUniformIsDirty(cache->uniforms[index], &value, sizeof(int));
}

uint SPGLUniformCacheGetProgram(SPGLUniformCacheRef cache)
{
    return cache->program;
}

// --- SPGLProgramCache ----------------------------------------------------------------------------

struct __SPGLProgramCache {

    SPGLUniformCacheRef*    uniformCaches;
    uint                    uniformCachesCap;
    uint                    uniformCachesSize;
};

void __SPGLProgramCacheSetCapacity(SPGLProgramCacheRef cache, uint capacity)
{
    if (!cache->uniformCaches)
    {
        cache->uniformCachesCap = 4;
        cache->uniformCaches = calloc(sizeof(SPGLUniformCacheRef)*cache->uniformCachesCap, 1);
    }
    else if (capacity >= cache->uniformCachesCap)
    {
        cache->uniformCachesCap <<= 2;
        cache->uniformCaches = realloc(cache->uniformCaches, sizeof(SPGLUniformCacheRef)*cache->uniformCachesCap);
    }
}

SPGLProgramCacheRef SPGLProgramCacheCreate(uint capacity)
{
    SPGLProgramCacheRef cache = calloc(sizeof(struct __SPGLProgramCache), 1);
    __SPGLProgramCacheSetCapacity(cache, capacity);
    return cache;
}

void SPGLProgramCacheDestroy(SPGLProgramCacheRef cache)
{
    SPGLProgramCacheFreeUniformCaches(cache);
    free(cache->uniformCaches);
    free(cache);
}

void SPGLProgramCacheFreeUniformCaches(SPGLProgramCacheRef cache)
{
    if (cache->uniformCaches)
    {
        for (int i=0; i<cache->uniformCachesSize; i++)
        {
            SPGLUniformCacheDestroy(cache->uniformCaches[i]);
            cache->uniformCaches[i] = NULL;
        }
    }

    cache->uniformCachesSize = 0;
}

void SPGLProgramCacheCreateWithProgram(SPGLProgramCacheRef cache, uint program)
{
    __SPGLProgramCacheSetCapacity(cache, program+1);
    SPGLProgramCacheDestroyCacheWithProgram(cache, program);
    cache->uniformCaches[program] = SPGLUniformCacheCreate(program);
}

void SPGLProgramCacheDestroyCacheWithProgram(SPGLProgramCacheRef cache, uint program)
{
    if (cache->uniformCaches[program])
    {
        SPGLUniformCacheDestroy(cache->uniformCaches[program]);
        cache->uniformCaches[program] = NULL;
    }
}

SPGLUniformCacheRef SPGLProgramCacheGetUniformCacheForProgram(SPGLProgramCacheRef cache, uint program)
{
    SPGLUniformCacheRef uniformCache = cache->uniformCaches[program];
    assert(uniformCache);
    return uniformCache;
}
