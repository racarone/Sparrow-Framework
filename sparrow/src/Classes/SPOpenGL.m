//
//  SPOpenGL.m
//  Sparrow
//
//  Created by Robert Carone on 10/8/13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPOpenGL.h>

#import <malloc/malloc.h>
#import <pthread.h>

const char* sglGetErrorString(uint error)
{
	switch (error)
    {
        case GL_NO_ERROR:                       return "GL_NO_ERROR";
		case GL_INVALID_ENUM:                   return "GL_INVALID_ENUM";
		case GL_INVALID_OPERATION:              return "GL_INVALID_OPERATION";
		case GL_INVALID_VALUE:                  return "GL_INVALID_VALUE";
		case GL_INVALID_FRAMEBUFFER_OPERATION:  return "GL_INVALID_FRAMEBUFFER_OPERATION";
		case GL_OUT_OF_MEMORY:                  return "GL_OUT_OF_MEMORY";
	}

	return "UNKNOWN_ERROR";
}

/** --------------------------------------------------------------------------------------------- */
#pragma mark - OpenGL State Cache
/** --------------------------------------------------------------------------------------------- */

#if SP_ENABLE_GL_STATE_CACHE

// undefine previous 'shims'
#undef glActiveTexture
#undef glBindBuffer
#undef glBindFramebuffer
#undef glBindRenderbuffer
#undef glBindTexture
#undef glBindVertexArray
#undef glBlendEquation
#undef glBlendEquationSeparate
#undef glBlendFunc
#undef glBlendFuncSeparate
#undef glClearColor
#undef glCreateProgram
#undef glDeleteBuffers
#undef glDeleteFramebuffers
#undef glDeleteProgram
#undef glDeleteRenderbuffers
#undef glDeleteTextures
#undef glDeleteVertexArrays
#undef glDisable
#undef glEnable
#undef glGetIntegerv
#undef glLinkProgram
#undef glScissor
#undef glUseProgram
#undef glViewport

// redefine extension mappings
#if TARGET_OS_IPHONE
#define glBindVertexArray       glBindVertexArrayOES
#define glDeleteVertexArrays    glDeleteVertexArraysOES
#endif

// constants
#define MAX_TEXTURE_UNITS   32
#define INVALID_STATE      -1

typedef struct _sglStateCache
{
    char enabledCaps[10];
    int  activeTextureUnit;
    int  texture[MAX_TEXTURE_UNITS];
    int  buffer[2];
    int  program;
    int  framebuffer;
    int  renderbuffer;
    int  vertexArray;
    int  blendEqAlpha;
    int  blendEqRGB;
    int  blendSrcAlpha;
    int  blendSrcRGB;
    int  blendDstAlpha;
    int  blendDstRGB;
    int  viewport[4];
    int  scissor[4];
} sglStateCache;

static sglStateCache invalidStateCache = { INVALID_STATE };
static pthread_key_t cacheKey;

__attribute__((constructor))
SP_INLINE void makeCacheKey()
{
    pthread_key_create(&cacheKey, NULL);
}

SP_INLINE sglStateCache* getCurrentStateCache()
{
    return pthread_getspecific(cacheKey);
}

/** --------------------------------------------------------------------------------------------- */
#pragma mark Internal
/** --------------------------------------------------------------------------------------------- */

SP_INLINE int getIndexForCapability(uint cap)
{
    switch (cap)
    {
        case GL_BLEND:                      return 0;
        case GL_CULL_FACE:                  return 1;
        case GL_DEPTH_TEST:                 return 2;
        case GL_DITHER:                     return 3;
        case GL_POLYGON_OFFSET_FILL:        return 4;
        case GL_SAMPLE_ALPHA_TO_COVERAGE:   return 5;
        case GL_SAMPLE_COVERAGE:            return 6;
        case GL_SCISSOR_TEST:               return 7;
        case GL_STENCIL_TEST:               return 8;
        case GL_TEXTURE_2D:                 return 9;
    }

    return INVALID_STATE;
}

SP_INLINE uint getCapabilityForIndex(int index)
{
    switch (index)
    {
        case 0: return GL_BLEND;
        case 1: return GL_CULL_FACE;
        case 2: return GL_DEPTH_TEST;
        case 3: return GL_DITHER;
        case 4: return GL_POLYGON_OFFSET_FILL;
        case 5: return GL_SAMPLE_ALPHA_TO_COVERAGE;
        case 6: return GL_SAMPLE_COVERAGE;
        case 7: return GL_SCISSOR_TEST;
        case 8: return GL_STENCIL_TEST;
        case 9: return GL_TEXTURE_2D;
    }

    return GL_NONE;
}

SP_INLINE void getChar(GLenum pname, GLchar* state, GLint* outParam)
{
    if (*state == INVALID_STATE)
    {
        GLint i;
        glGetIntegerv(pname, &i);
        *state = (GLchar)i;
    }

    *outParam = *state;
}

SP_INLINE void getInt(GLenum pname, GLint* state, GLint* outParam)
{
    if (*state == INVALID_STATE)
        glGetIntegerv(pname, state);

    *outParam = *state;
}

SP_INLINE void getIntv(GLenum pname, GLint count, GLint statev[], GLint* outParams)
{
    if (*statev == INVALID_STATE)
        glGetIntegerv(pname, statev);

    memcpy(outParams, statev, sizeof(GLint)*count);
}

/** --------------------------------------------------------------------------------------------- */
#pragma mark State
/** --------------------------------------------------------------------------------------------- */

sglStateCacheRef sglStateCacheCreate(void)
{
    sglStateCacheRef newCache = malloc(sizeof(struct _sglStateCache));
    memset(newCache, INVALID_STATE, sizeof(struct _sglStateCache));
    return  newCache;
}

void sglStateCacheDestroy(sglStateCacheRef cache)
{
    free(cache);
}

void sglStateCacheReset(sglStateCacheRef cache)
{
    *getCurrentStateCache() = invalidStateCache;
}

sglStateCacheRef sglStateCacheGetCurrent(void)
{
    return getCurrentStateCache();
}

void sglStateCacheSetCurrent(sglStateCacheRef cache)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (currentStateCache == cache)
        return;

    // use a temporary invalid state cache to force any changes in states
    sglStateCache tempInvalidCache = invalidStateCache;
    pthread_setspecific(cacheKey, &tempInvalidCache);

    if (cache->framebuffer != INVALID_STATE)
        sglBindFramebuffer(GL_FRAMEBUFFER, cache->framebuffer);

    if (cache->renderbuffer != INVALID_STATE)
        sglBindRenderbuffer(GL_RENDERBUFFER, cache->renderbuffer);

    if (cache->buffer[0] != INVALID_STATE)
        sglBindBuffer(GL_ARRAY_BUFFER, cache->buffer[0]);

    if (cache->buffer[1] != INVALID_STATE)
        sglBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cache->buffer[1]);

    if (cache->vertexArray != INVALID_STATE)
        sglBindVertexArray(cache->vertexArray);

    if (cache->blendEqAlpha != INVALID_STATE && cache->blendEqRGB != INVALID_STATE)
        sglBlendEquationSeparate(cache->blendEqRGB, cache->blendEqAlpha);

    if (cache->blendSrcRGB != INVALID_STATE &&
        cache->blendDstRGB != INVALID_STATE &&
        cache->blendSrcAlpha != INVALID_STATE &&
        cache->blendDstAlpha != INVALID_STATE)
        sglBlendFuncSeparate(cache->blendSrcRGB, cache->blendDstRGB,
                             cache->blendSrcAlpha, cache->blendDstAlpha);

    if (cache->program != INVALID_STATE)
        sglUseProgram(cache->program);

    if (cache->viewport[0] != INVALID_STATE &&
        cache->viewport[1] != INVALID_STATE &&
        cache->viewport[2] != INVALID_STATE &&
        cache->viewport[3] != INVALID_STATE)
        sglViewport(cache->viewport[0], cache->viewport[1],
                    cache->viewport[2], cache->viewport[3]);

    if (cache->scissor[0] != INVALID_STATE &&
        cache->scissor[1] != INVALID_STATE &&
        cache->scissor[2] != INVALID_STATE &&
        cache->scissor[3] != INVALID_STATE)
        sglScissor(cache->scissor[0], cache->scissor[1],
                   cache->scissor[2], cache->scissor[3]);

    for (int i=0; i<32; ++i)
    {
        if (cache->texture[i] != INVALID_STATE)
        {
            sglActiveTexture(GL_TEXTURE0 + i);
            sglBindTexture(GL_TEXTURE_2D, cache->texture[i]);
        }
    }

    for (int i=0; i<10; ++i)
    {
        if (cache->enabledCaps[i] == true)
            sglEnable(getCapabilityForIndex(i));
        else if (cache->enabledCaps[i] == false)
            sglDisable(getCapabilityForIndex(i));
    }

    pthread_setspecific(cacheKey, cache);
}

/** --------------------------------------------------------------------------------------------- */
#pragma mark OpenGL
/** --------------------------------------------------------------------------------------------- */

void sglActiveTexture(GLenum texture)
{
    int textureUnit = texture-GL_TEXTURE0;
    sglStateCacheRef currentStateCache = getCurrentStateCache();

    if (textureUnit != currentStateCache->activeTextureUnit)
    {
        currentStateCache->activeTextureUnit = textureUnit;
        glActiveTexture(texture);
    }
}

void sglBindBuffer(GLenum target, GLuint buffer)
{
    int index = target-GL_ARRAY_BUFFER;
    sglStateCacheRef currentStateCache = getCurrentStateCache();

    if (buffer != currentStateCache->buffer[index])
    {
        currentStateCache->buffer[index] = buffer;
        glBindBuffer(target, buffer);
    }
}

void sglBindFramebuffer(GLenum target, GLuint framebuffer)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (framebuffer != currentStateCache->framebuffer)
    {
        currentStateCache->framebuffer = framebuffer;
        glBindFramebuffer(target, framebuffer);
    }
}

void sglBindRenderbuffer(GLenum target, GLuint renderbuffer)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (renderbuffer != currentStateCache->renderbuffer)
    {
        currentStateCache->renderbuffer = renderbuffer;
        glBindRenderbuffer(target, renderbuffer);
    }
}

void sglBindTexture(GLenum target, GLuint texture)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (currentStateCache->activeTextureUnit == INVALID_STATE)
        sglActiveTexture(GL_TEXTURE0);

    if (texture != currentStateCache->texture[currentStateCache->activeTextureUnit])
    {
        currentStateCache->texture[currentStateCache->activeTextureUnit] = texture;
        glBindTexture(target, texture);
    }
}

void sglBindVertexArray(GLuint array)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (array != currentStateCache->vertexArray)
    {
        currentStateCache->vertexArray = array;
        glBindVertexArray(array);
    }
}

void sglBlendEquation(GLenum mode)
{
    sglBlendEquationSeparate(mode, mode);
}

void sglBlendEquationSeparate(GLenum modeRGB, GLenum modeAlpha)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (currentStateCache->blendEqRGB != modeRGB || currentStateCache->blendEqAlpha != modeAlpha)
    {
        currentStateCache->blendEqRGB = modeRGB;
        currentStateCache->blendEqAlpha = modeAlpha;
        glBlendEquationSeparate(modeRGB, modeAlpha);
    }
}

void sglBlendFunc(GLenum sfactor, GLenum dfactor)
{
    sglBlendFuncSeparate(sfactor, dfactor, sfactor, dfactor);
}

void sglBlendFuncSeparate(GLenum srcRGB, GLenum dstRGB, GLenum srcAlpha, GLenum dstAlpha)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (srcRGB != currentStateCache->blendSrcRGB ||
        dstRGB != currentStateCache->blendDstRGB ||
        srcAlpha != currentStateCache->blendSrcAlpha ||
        dstAlpha != currentStateCache->blendDstAlpha)
    {
        currentStateCache->blendSrcRGB = srcRGB;
        currentStateCache->blendDstRGB = dstRGB;
        currentStateCache->blendSrcAlpha = srcAlpha;
        currentStateCache->blendDstAlpha = dstAlpha;
        glBlendFuncSeparate(srcRGB, dstRGB, srcAlpha, dstAlpha);
    }
}

void sglDeleteBuffers(GLsizei n, const GLuint* buffers)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    for (int i=0; i<n; i++)
    {
        if (currentStateCache->buffer[0] == buffers[i]) currentStateCache->buffer[0] = INVALID_STATE;
        if (currentStateCache->buffer[1] == buffers[i]) currentStateCache->buffer[1] = INVALID_STATE;
    }

    glDeleteBuffers(n, buffers);
}

void sglDeleteFramebuffers(GLsizei n, const GLuint* framebuffers)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    for (int i=0; i<n; i++)
    {
        if (currentStateCache->framebuffer == framebuffers[i])
            currentStateCache->framebuffer = INVALID_STATE;
    }

    glDeleteFramebuffers(n, framebuffers);
}

void sglDeleteProgram(GLuint program)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (currentStateCache->program == program)
        currentStateCache->program = INVALID_STATE;

    glDeleteProgram(program);
}

void sglDeleteRenderbuffers(GLsizei n, const GLuint* renderbuffers)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    for (int i=0; i<n; i++)
    {
        if (currentStateCache->renderbuffer == renderbuffers[i])
            currentStateCache->renderbuffer = INVALID_STATE;
    }

    glDeleteRenderbuffers(n, renderbuffers);
}

void sglDeleteTextures(GLsizei n, const GLuint* textures)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    for (int i=0; i<n; i++)
    {
        for (int j=0; j<32; j++)
        {
            if (currentStateCache->texture[j] == textures[i])
                currentStateCache->texture[j] = INVALID_STATE;
        }
    }

    glDeleteTextures(n, textures);
}

void sglDeleteVertexArrays(GLsizei n, const GLuint* arrays)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    for (int i=0; i<n; i++)
    {
        if (currentStateCache->vertexArray == arrays[i])
            currentStateCache->vertexArray = INVALID_STATE;
    }

    glDeleteVertexArrays(n, arrays);
}

void sglDisable(GLenum cap)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    int index = getIndexForCapability(cap);

    if (currentStateCache->enabledCaps[index] != false)
    {
        currentStateCache->enabledCaps[index] = false;
        glDisable(cap);
    }
}

void sglEnable(GLenum cap)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    int index = getIndexForCapability(cap);

    if (currentStateCache->enabledCaps[index] != true)
    {
        currentStateCache->enabledCaps[index] = true;
        glEnable(cap);
    }
}

void sglGetIntegerv(GLenum pname, GLint* params)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();

    switch (pname)
    {
        case GL_BLEND:
        case GL_CULL_FACE:
        case GL_DEPTH_TEST:
        case GL_DITHER:
        case GL_POLYGON_OFFSET_FILL:
        case GL_SAMPLE_ALPHA_TO_COVERAGE:
        case GL_SAMPLE_COVERAGE:
        case GL_SCISSOR_TEST:
        case GL_STENCIL_TEST:
            getChar(pname, &currentStateCache->enabledCaps[getIndexForCapability(pname)], params);
            return;

        case GL_ACTIVE_TEXTURE:
            getInt(pname, &currentStateCache->activeTextureUnit, params);
            return;

        case GL_ARRAY_BUFFER_BINDING:
            getInt(pname, &currentStateCache->buffer[0], params);
            return;

        case GL_CURRENT_PROGRAM:
            getInt(pname, &currentStateCache->program, params);
            return;

        case GL_ELEMENT_ARRAY_BUFFER_BINDING:
            getInt(pname, &currentStateCache->buffer[1], params);
            return;

        case GL_FRAMEBUFFER_BINDING:
            getInt(pname, &currentStateCache->framebuffer, params);
            return;

        case GL_RENDERBUFFER_BINDING:
            getInt(pname, &currentStateCache->renderbuffer, params);
            return;

        case GL_SCISSOR_BOX:
            getIntv(pname, 4, currentStateCache->scissor, params);
            return;

        case GL_TEXTURE_BINDING_2D:
            getInt(pname, &currentStateCache->activeTextureUnit, params);
            return;

        case GL_VERTEX_ARRAY_BINDING:
            getInt(pname, &currentStateCache->vertexArray, params);
            return;

        case GL_VIEWPORT:
            getIntv(pname, 4, currentStateCache->viewport, params);
            return;

        case GL_BLEND_DST_ALPHA:
            getInt(pname, &currentStateCache->blendSrcAlpha, params);
            return;

        case GL_BLEND_DST_RGB:
            getInt(pname, &currentStateCache->blendDstRGB, params);
            return;

        case GL_BLEND_SRC_ALPHA:
            getInt(pname, &currentStateCache->blendSrcAlpha, params);
            return;

        case GL_BLEND_SRC_RGB:
            getInt(pname, &currentStateCache->blendSrcRGB, params);
            return;

        case GL_BLEND_EQUATION_ALPHA:
            getInt(pname, &currentStateCache->blendEqAlpha, params);
            return;

        case GL_BLEND_EQUATION_RGB:
            getInt(pname, &currentStateCache->blendEqRGB, params);
            return;
    }

    glGetIntegerv(pname, params);
}

void sglScissor(GLint x, GLint y, GLsizei width, GLsizei height)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (x      != currentStateCache->scissor[0] ||
        y      != currentStateCache->scissor[1] ||
        width  != currentStateCache->scissor[2] ||
        height != currentStateCache->scissor[3])
    {
        currentStateCache->scissor[0] = x;
        currentStateCache->scissor[1] = y;
        currentStateCache->scissor[2] = width;
        currentStateCache->scissor[3] = height;

        glScissor(x, y, width, height);
    }
}

void sglUseProgram(GLuint program)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (program != currentStateCache->program)
    {
        currentStateCache->program = program;
        glUseProgram(program);
    }
}

void sglViewport(GLint x, GLint y, GLsizei width, GLsizei height)
{
    sglStateCacheRef currentStateCache = getCurrentStateCache();
    if (width  != currentStateCache->viewport[2] ||
        height != currentStateCache->viewport[3] ||
        x      != currentStateCache->viewport[0] ||
        y      != currentStateCache->viewport[1])
    {
        currentStateCache->viewport[0] = x;
        currentStateCache->viewport[1] = y;
        currentStateCache->viewport[2] = width;
        currentStateCache->viewport[3] = height;
        
        glViewport(x, y, width, height);
    }
}

#else

sglStateCacheRef sglStateCacheCreate(void)                       { return NULL; }
void             sglStateCacheDestroy(sglStateCacheRef cache)    {}
void             sglStateCacheReset(sglStateCacheRef cache)      {}
sglStateCacheRef sglStateCacheGetCurrent(void)                   { return NULL; }
void             sglStateCacheSetCurrent(sglStateCacheRef cache) {}

#endif
