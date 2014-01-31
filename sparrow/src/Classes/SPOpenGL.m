//
//  SPOpenGL.m
//  Sparrow
//
//  Created by Robert Carone on 10/8/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPOpenGL.h>

const GLchar* sglGetErrorString(GLenum error)
{
	switch (error) {
        case GL_NO_ERROR:                       return "GL_NO_ERROR";
		case GL_INVALID_ENUM:                   return "GL_INVALID_ENUM";
		case GL_INVALID_OPERATION:              return "GL_INVALID_OPERATION";
		case GL_INVALID_VALUE:                  return "GL_INVALID_VALUE";
		case GL_INVALID_FRAMEBUFFER_OPERATION:  return "GL_INVALID_FRAMEBUFFER_OPERATION";
		case GL_OUT_OF_MEMORY:                  return "GL_OUT_OF_MEMORY";
	}
	return "";
}


// -------------------------------------------------------------------------------------------------
#  pragma mark - OpenGL State Cache
// -------------------------------------------------------------------------------------------------

#if SP_ENABLE_GL_STATE_CACHE

// undefine previous 'shims'

#undef glActiveTexture
#undef glBindBuffer
#undef glBindFramebuffer
#undef glBindRenderbuffer
#undef glBindTexture
#undef glBindVertexArray
#undef glBlendFunc
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

#define glBindVertexArray       glBindVertexArrayOES
#define glDeleteVertexArrays    glDeleteVertexArraysOES

// state definition

#define MAX_TEXTURE_UNITS   32
#define INVALID_STATE      -1

typedef struct
{
    GLint   textureUnit;
    GLint   texture[MAX_TEXTURE_UNITS];
    GLint   program;
    GLint   framebuffer;
    GLint   renderbuffer;
    GLint   viewport[4];
    GLint   scissor[4];
    GLint   buffer[2];
    GLint   vertexArray;
    GLchar  enabledCaps[10];
    GLint   blendSrc;
    GLint   blendDst;
} SGLState;


// -------------------------------------------------------------------------------------------------
#  pragma mark Internal
// -------------------------------------------------------------------------------------------------

SP_INLINE SGLState* __sglGetState(void)
{
    static dispatch_once_t once;
    static SGLState* globalState;

    dispatch_once(&once, ^{
        globalState = calloc(sizeof(SGLState), 1);
        memset(globalState, INVALID_STATE, sizeof(*globalState));
    });

    return globalState;
}

SP_INLINE GLuint __sglGetIndexForCapability(GLuint cap)
{
    switch (cap) {
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

SP_INLINE void __sglGetChar(GLenum pname, GLchar* state, GLint* outParam)
{
    if (*state == INVALID_STATE)
    {
        GLint i;
        glGetIntegerv(pname, &i);
        *state = (GLchar)i;
    }

    *outParam = *state;
}

SP_INLINE void __sglGetInt(GLenum pname, GLint* state, GLint* outParam)
{
    if (*state == INVALID_STATE)
        glGetIntegerv(pname, state);

    *outParam = *state;
}

SP_INLINE void __sglGetIntv(GLenum pname, GLint count, GLint statev[], GLint* outParams)
{
    if (*statev == INVALID_STATE)
        glGetIntegerv(pname, statev);

    memcpy(outParams, statev, sizeof(GLint)*count);
}


// -------------------------------------------------------------------------------------------------
#  pragma mark Public
// -------------------------------------------------------------------------------------------------

void sglActiveTexture(GLenum texture)
{
    GLuint textureUnit = texture-GL_TEXTURE0;
    SGLState* currentState = __sglGetState();

    if (textureUnit != currentState->textureUnit)
    {
        currentState->textureUnit = textureUnit;
        glActiveTexture(texture);
    }
}

void sglBindBuffer(GLenum target, GLuint buffer)
{
    GLuint index = target-GL_ARRAY_BUFFER;
    SGLState* currentState = __sglGetState();

    if (buffer != currentState->buffer[index])
    {
        currentState->buffer[index] = buffer;
        glBindBuffer(target, buffer);
    }
}

void sglBindFramebuffer(GLenum target, GLuint framebuffer)
{
    SGLState* currentState = __sglGetState();
    if (framebuffer != currentState->framebuffer)
    {
        currentState->framebuffer = framebuffer;
        glBindFramebuffer(target, framebuffer);
    }
}

void sglBindRenderbuffer(GLenum target, GLuint renderbuffer)
{
    SGLState* currentState = __sglGetState();
    if (renderbuffer != currentState->renderbuffer)
    {
        currentState->renderbuffer = renderbuffer;
        glBindRenderbuffer(target, renderbuffer);
    }
}

void sglBindTexture(GLenum target, GLuint texture)
{
    SGLState* currentState = __sglGetState();
    if (texture != currentState->texture[currentState->textureUnit])
    {
        currentState->texture[currentState->textureUnit] = texture;
        glBindTexture(target, texture);
    }
}

void sglBindVertexArray(GLuint array)
{
    SGLState* currentState = __sglGetState();
    if (array != currentState->vertexArray) {
        currentState->vertexArray = array;
        glBindVertexArray(array);
    }
}

void sglBlendFunc(GLenum sfactor, GLenum dfactor)
{
    SGLState* currentState = __sglGetState();
    if (sfactor != currentState->blendSrc || dfactor != currentState->blendDst)
    {
        currentState->blendSrc = sfactor;
        currentState->blendDst = dfactor;
        glBlendFunc(sfactor, dfactor);
    }
}

void sglDeleteBuffers(GLsizei n, const GLuint* buffers)
{
    SGLState* currentState = __sglGetState();
    for (int i=0; i<n; i++)
    {
        if (currentState->buffer[0] == buffers[i]) currentState->buffer[0] = 0;
        if (currentState->buffer[1] == buffers[i]) currentState->buffer[1] = 0;
    }

    glDeleteBuffers(n, buffers);
}

void sglDeleteFramebuffers(GLsizei n, const GLuint* framebuffers)
{
    SGLState* currentState = __sglGetState();
    for (int i=0; i<n; i++)
    {
        if (currentState->framebuffer == framebuffers[i])
            currentState->framebuffer = 0;
    }

    glDeleteFramebuffers(n, framebuffers);
}

void sglDeleteProgram(GLuint program)
{
    SGLState* currentState = __sglGetState();
    if (currentState->program == program)
        currentState->program = 0;

    glDeleteProgram(program);
}

void sglDeleteRenderbuffers(GLsizei n, const GLuint* renderbuffers)
{
    SGLState* currentState = __sglGetState();
    for (int i=0; i<n; i++)
    {
        if (currentState->renderbuffer == renderbuffers[i])
            currentState->renderbuffer = 0;
    }

    glDeleteRenderbuffers(n, renderbuffers);
}

void sglDeleteTextures(GLsizei n, const GLuint* textures)
{
    SGLState* currentState = __sglGetState();
    for (int i=0; i<n; i++)
    {
        for (int j=0; j<32; j++)
        {
            if (currentState->texture[j] == textures[i])
                currentState->texture[j] = 0;
        }
    }

    glDeleteTextures(n, textures);
}

void sglDeleteVertexArrays(GLsizei n, const GLuint* arrays)
{
    SGLState* currentState = __sglGetState();
    for (int i=0; i<n; i++)
    {
        if (currentState->vertexArray == arrays[i])
            currentState->vertexArray = 0;
    }

    glDeleteVertexArrays(n, arrays);
}

void sglDisable(GLenum cap)
{
    SGLState* currentState = __sglGetState();
    GLuint index = __sglGetIndexForCapability(cap);

    if (currentState->enabledCaps[index] != GL_FALSE)
    {
        currentState->enabledCaps[index] = GL_FALSE;
        glDisable(cap);
    }
}

void sglEnable(GLenum cap)
{
    SGLState* currentState = __sglGetState();
    GLuint index = __sglGetIndexForCapability(cap);

    if (currentState->enabledCaps[index] != GL_TRUE)
    {
        currentState->enabledCaps[index] = GL_TRUE;
        glEnable(cap);
    }
}

void sglGetIntegerv(GLenum pname, GLint* params)
{
    SGLState* currentState = __sglGetState();

    switch (pname) {
        case GL_BLEND:
        case GL_CULL_FACE:
        case GL_DEPTH_TEST:
        case GL_DITHER:
        case GL_POLYGON_OFFSET_FILL:
        case GL_SAMPLE_ALPHA_TO_COVERAGE:
        case GL_SAMPLE_COVERAGE:
        case GL_SCISSOR_TEST:
        case GL_STENCIL_TEST:
            __sglGetChar(pname, &currentState->enabledCaps[__sglGetIndexForCapability(pname)], params);
            return;

        case GL_ACTIVE_TEXTURE:
            __sglGetInt(pname, &currentState->textureUnit, params);
            return;

        case GL_ARRAY_BUFFER_BINDING:
            __sglGetInt(pname, &currentState->buffer[0], params);
            return;

        case GL_CURRENT_PROGRAM:
            __sglGetInt(pname, &currentState->program, params);
            return;

        case GL_ELEMENT_ARRAY_BUFFER_BINDING:
            __sglGetInt(pname, &currentState->buffer[1], params);
            return;

        case GL_FRAMEBUFFER_BINDING:
            __sglGetInt(pname, &currentState->framebuffer, params);
            return;

        case GL_RENDERBUFFER_BINDING:
            __sglGetInt(pname, &currentState->renderbuffer, params);
            return;

        case GL_SCISSOR_BOX:
            __sglGetIntv(pname, 4, (GLint *)currentState->scissor, params);
            return;

        case GL_TEXTURE_BINDING_2D:
            __sglGetInt(pname, &currentState->textureUnit, params);
            return;

        case GL_VERTEX_ARRAY_BINDING:
            __sglGetInt(pname, &currentState->vertexArray, params);
            return;

        case GL_VIEWPORT:
            __sglGetIntv(pname, 4, (GLint *)currentState->viewport, params);
            return;
    }

    glGetIntegerv(pname, params);
}

void sglScissor(GLint x, GLint y, GLsizei width, GLsizei height)
{
    SGLState* currentState = __sglGetState();
    if (x      != currentState->scissor[0] ||
        y      != currentState->scissor[1] ||
        width  != currentState->scissor[2] ||
        height != currentState->scissor[3])
    {
        currentState->scissor[0] = x;
        currentState->scissor[1] = y;
        currentState->scissor[2] = width;
        currentState->scissor[3] = height;

        glScissor(x, y, width, height);
    }
}

void sglUseProgram(GLuint program)
{
    SGLState* currentState = __sglGetState();
    if (program != currentState->program)
    {
        currentState->program = program;
        glUseProgram(program);
    }
}

void sglViewport(GLint x, GLint y, GLsizei width, GLsizei height)
{
    SGLState* currentState = __sglGetState();
    if (width  != currentState->viewport[2] ||
        height != currentState->viewport[3] ||
        x      != currentState->viewport[0] ||
        y      != currentState->viewport[1])
    {
        currentState->viewport[0] = x;
        currentState->viewport[1] = y;
        currentState->viewport[2] = width;
        currentState->viewport[3] = height;
        
        glViewport(x, y, width, height);
    }
}

#endif // !SP_ENABLE_GL_STATE_CACHE
