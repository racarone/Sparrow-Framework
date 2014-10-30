//
//  SPOpenGL.h
//  Sparrow
//
//  Created by Robert Carone on 10/8/13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPMacros.h>

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

// -----------------------------------------------------------
// EXPERIMENTAL FEATURE: Activate the OpenGL state cache here!
// -----------------------------------------------------------

#define SP_ENABLE_GL_STATE_CACHE 0

typedef struct _sglStateCache * sglStateCacheRef;

/// Creates and returns a state cache.
SP_EXTERN sglStateCacheRef sglStateCacheCreate(void);

/// Destroys a state cache instance.
SP_EXTERN void sglStateCacheDestroy(sglStateCacheRef cache);

/// Resets all state cache values.
SP_EXTERN void sglStateCacheReset(sglStateCacheRef cache);

/// Returns the state cache for the current thread.
SP_EXTERN sglStateCacheRef sglStateCacheGetCurrent(void);

/// Sets the state cache for the current thread.
SP_EXTERN void sglStateCacheSetCurrent(sglStateCacheRef cache);

/// Returns a string representing an OpenGL error code.
SP_EXTERN const char* sglGetErrorString(uint error);

/// Extension remappings

#if SP_TARGET_IOS
  #ifndef GL_DEPTH24_STENCIL8
    #define GL_DEPTH24_STENCIL8         GL_DEPTH24_STENCIL8_OES
  #endif
  #ifndef GL_VERTEX_ARRAY_BINDING
    #define GL_VERTEX_ARRAY_BINDING     GL_VERTEX_ARRAY_BINDING_OES
  #endif
    #define glBindVertexArray           glBindVertexArrayOES
    #define glGenVertexArrays           glGenVertexArraysOES
    #define glDeleteVertexArrays        glDeleteVertexArraysOES
    #define glIsVertexArray             glIsVertexArrayOES
#endif

/// OpenGL remappings
#if SP_ENABLE_GL_STATE_CACHE
    #undef  glBindVertexArray
    #undef  glDeleteVertexArrays

    #define glActiveTexture             sglActiveTexture
    #define glBindBuffer                sglBindBuffer
    #define glBindFramebuffer           sglBindFramebuffer
    #define glBindRenderbuffer          sglBindRenderbuffer
    #define glBindTexture               sglBindTexture
    #define glBindVertexArray           sglBindVertexArray
    #define glBlendEquation             sglBlendEquation
    #define glBlendEquationSeparate     sglBlendEquationSeparate
    #define glBlendFunc                 sglBlendFunc
    #define glBlendFuncSeparate         sglBlendFuncSeparate
    #define glDeleteBuffers             sglDeleteBuffers
    #define glDeleteFramebuffers        sglDeleteFramebuffers
    #define glDeleteProgram             sglDeleteProgram
    #define glDeleteRenderbuffers       sglDeleteRenderbuffers
    #define glDeleteTextures            sglDeleteTextures
    #define glDeleteVertexArrays        sglDeleteVertexArrays
    #define glDisable                   sglDisable
    #define glEnable                    sglEnable
    #define glGetIntegerv               sglGetIntegerv
    #define glScissor                   sglScissor
    #define glUseProgram                sglUseProgram
    #define glViewport                  sglViewport

    SP_EXTERN void                      sglActiveTexture(GLenum texture);
    SP_EXTERN void                      sglBindBuffer(GLenum target, GLuint buffer);
    SP_EXTERN void                      sglBindFramebuffer(GLenum target, GLuint framebuffer);
    SP_EXTERN void                      sglBindRenderbuffer(GLenum target, GLuint renderbuffer);
    SP_EXTERN void                      sglBindTexture(GLenum target, GLuint texture);
    SP_EXTERN void                      sglBindVertexArray(GLuint array);
    SP_EXTERN void                      sglBlendEquation(GLenum mode);
    SP_EXTERN void                      sglBlendEquationSeparate(GLenum modeRGB, GLenum modeAlpha);
    SP_EXTERN void                      sglBlendFunc(GLenum sfactor, GLenum dfactor);
    SP_EXTERN void                      sglBlendFuncSeparate(GLenum srcRGB, GLenum dstRGB, GLenum srcAlpha, GLenum dstAlpha);
    SP_EXTERN void                      sglDeleteBuffers(GLsizei n, const GLuint* buffers);
    SP_EXTERN void                      sglDeleteFramebuffers(GLsizei n, const GLuint* framebuffers);
    SP_EXTERN void                      sglDeleteProgram(GLuint program);
    SP_EXTERN void                      sglDeleteRenderbuffers(GLsizei n, const GLuint* renderbuffers);
    SP_EXTERN void                      sglDeleteTextures(GLsizei n, const GLuint* textures);
    SP_EXTERN void                      sglDeleteVertexArrays(GLsizei n, const GLuint* arrays);
    SP_EXTERN void                      sglDisable(GLenum cap);
    SP_EXTERN void                      sglEnable(GLenum cap);
    SP_EXTERN void                      sglGetIntegerv(GLenum pname, GLint* params);
    SP_EXTERN void                      sglScissor(GLint x, GLint y, GLsizei width, GLsizei height);
    SP_EXTERN void                      sglUseProgram(GLuint program);
    SP_EXTERN void                      sglViewport(GLint x, GLint y, GLsizei width, GLsizei height);
#endif
