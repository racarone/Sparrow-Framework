//
//  SPOpenGL.h
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPMacros.h"

#define SP_USE_OPENGL_STATE_CACHE 1

// IPHONE
#if SP_TARGET_IPHONE
    #include <OpenGLES/ES2/gl.h>
    #include <OpenGLES/ES2/glext.h>

    #define GL_RGBA8                                GL_RGBA8_OES
    #define glClearDepth                            glClearDepthf
    #define glDepthRange                            glDepthRangef
    #define glCopyTextureLevels                     glCopyTextureLevelsAPPLE
    #define glRenderbufferStorageMultisample        glRenderbufferStorageMultisampleAPPLE
    #define glResolveMultisampleFramebuffer         glResolveMultisampleFramebufferAPPLE
    #define glFenceSync                             glFenceSyncAPPLE
    #define glIsSync                                glIsSyncAPPLE
    #define glDeleteSync                            glDeleteSyncAPPLE
    #define glClientWaitSync                        glClientWaitSyncAPPLE
    #define glWaitSync                              glWaitSyncAPPLE
    #define glGetInteger64v                         glGetInteger64vAPPLE
    #define glGetSynciv                             glGetSyncivAPPLE
    #define glDrawArraysInstanced                   glDrawArraysInstancedEXT
    #define glDrawElementsInstanced                 glDrawElementsInstancedEXT
    #define glVertexAttribDivisor                   glVertexAttribDivisorEXT
    #define glGenQueries                            glGenQueriesEXT
    #define glDeleteQueries                         glDeleteQueriesEXT
    #define glIsQuery                               glIsQueryEXT
    #define glBeginQuery                            glBeginQueryEXT
    #define glEndQuery                              glEndQueryEXT
    #define glGetQueryiv                            glGetQueryivEXT
    #define glGetQueryObjectuiv                     glGetQueryObjectuivEXT
    #define glGetBufferPointerv                     glGetBufferPointervOES
    #define glMapBuffer                             glMapBufferOES
    #define glUnmapBuffer                           glUnmapBufferOES
    #define glBindVertexArray                       glBindVertexArrayOES
    #define glGenVertexArrays                       glGenVertexArraysOES
    #define glDeleteVertexArrays                    glDeleteVertexArraysOES
    #define glIsVertexArray                         glIsVertexArrayOES

// OSX
#elif SP_TARGET_OSX
    #include <OpenGL/gl.h>
    #include <OpenGL/glext.h>

    #define glVertexAttribDivisor                   glVertexAttribDivisorARB

    #ifndef __gl3_h_
        #define glDrawArraysInstanced                   glDrawArraysInstancedARB
        #define glDrawElementsInstanced                 glDrawElementsInstancedARB
        #define glGenQueries                            glGenQueriesARB
        #define glDeleteQueries                         glDeleteQueriesARB
        #define glIsQuery                               glIsQueryARB
        #define glBeginQuery                            glBeginQueryARB
        #define glEndQuery                              glEndQueryARB
        #define glGetQueryiv                            glGetQueryivARB
        #define glGetQueryObjectuiv                     glGetQueryObjectuivARB
        #define glGetBufferPointerv                     glGetBufferPointervARB
        #define glMapBuffer                             glMapBufferARB
        #define glUnmapBuffer                           glUnmapBufferARB
        #define glBindVertexArray                       glBindVertexArrayAPPLE
        #define glGenVertexArrays                       glGenVertexArraysAPPLE
        #define glDeleteVertexArrays                    glDeleteVertexArraysAPPLE
        #define glIsVertexArray                         glIsVertexArrayAPPLE
    #endif
#endif

// STATE CACHE
#if SP_USE_OPENGL_STATE_CACHE
    #undef glBindVertexArray
    #undef glDeleteVertexArrays

    #define glActiveTexture             sglActiveTexture
    #define glBindBuffer                sglBindBuffer
    #define glBindFramebuffer           sglBindFramebuffer
    #define glBindRenderbuffer          sglBindRenderbuffer
    #define glBindTexture               sglBindTexture
    #define glBlendFunc                 sglBlendFunc
    #define glClearColor                sglClearColor
    #define glCreateProgram             sglCreateProgram
    #define glDeleteBuffers             sglDeleteBuffers
    #define glDeleteFramebuffers        sglDeleteFramebuffers
    #define glDeleteProgram             sglDeleteProgram
    #define glDeleteRenderbuffers       sglDeleteRenderbuffers
    #define glDeleteTextures            sglDeleteTextures
    #define glDisable                   sglDisable
    #define glDisableVertexAttribArray  sglDisableVertexAttribArray
    #define glEnable                    sglEnable
    #define glEnableVertexAttribArray   sglEnableVertexAttribArray
    #define glScissor                   sglScissor
    #define glUniform1f                 sglUniform1f
    #define glUniform1fv                sglUniform1fv
    #define glUniform1i                 sglUniform1i
    #define glUniform1iv                sglUniform1iv
    #define glUniform2f                 sglUniform2f
    #define glUniform2fv                sglUniform2fv
    #define glUniform2i                 sglUniform2i
    #define glUniform2iv                sglUniform2iv
    #define glUniform3f                 sglUniform3f
    #define glUniform3fv                sglUniform3fv
    #define glUniform3i                 sglUniform3i
    #define glUniform3iv                sglUniform3iv
    #define glUniform4f                 sglUniform4f
    #define glUniform4fv                sglUniform4fv
    #define glUniform4i                 sglUniform4i
    #define glUniform4iv                sglUniform4iv
    #define glUniformMatrix2fv          sglUniformMatrix2fv
    #define glUniformMatrix3fv          sglUniformMatrix3fv
    #define glUniformMatrix4fv          sglUniformMatrix4fv
    #define glUseProgram                sglUseProgram
    #define glViewport                  sglViewport

    SP_EXTERN void		sglActiveTexture(GLenum texture);
    SP_EXTERN void		sglBindBuffer(GLenum target, GLuint buffer);
    SP_EXTERN void		sglBindFramebuffer(GLenum target, GLuint framebuffer);
    SP_EXTERN void		sglBindRenderbuffer(GLenum target, GLuint renderbuffer);
    SP_EXTERN void		sglBindTexture(GLenum target, GLuint texture);
    SP_EXTERN void		sglBlendFunc(GLenum sfactor, GLenum dfactor);
    SP_EXTERN void		sglClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
    SP_EXTERN GLuint    sglCreateProgram(void);
    SP_EXTERN void		sglDeleteBuffers(GLsizei n, const GLuint* buffers);
    SP_EXTERN void		sglDeleteFramebuffers(GLsizei n, const GLuint* framebuffers);
    SP_EXTERN void		sglDeleteProgram(GLuint program);
    SP_EXTERN void		sglDeleteRenderbuffers(GLsizei n, const GLuint* renderbuffers);
    SP_EXTERN void		sglDeleteTextures(GLsizei n, const GLuint* textures);
    SP_EXTERN void		sglDisable(GLenum cap);
    SP_EXTERN void		sglDisableVertexAttribArray(GLuint index);
    SP_EXTERN void		sglEnable(GLenum cap);
    SP_EXTERN void		sglEnableVertexAttribArray(GLuint index);
    SP_EXTERN void		sglScissor(GLint x, GLint y, GLsizei width, GLsizei height);
    SP_EXTERN void		sglUniform1f(GLint location, GLfloat x);
    SP_EXTERN void		sglUniform1fv(GLint location, GLsizei count, const GLfloat* v);
    SP_EXTERN void		sglUniform1i(GLint location, GLint x);
    SP_EXTERN void		sglUniform1iv(GLint location, GLsizei count, const GLint* v);
    SP_EXTERN void		sglUniform2f(GLint location, GLfloat x, GLfloat y);
    SP_EXTERN void		sglUniform2fv(GLint location, GLsizei count, const GLfloat* v);
    SP_EXTERN void		sglUniform2i(GLint location, GLint x, GLint y);
    SP_EXTERN void		sglUniform2iv(GLint location, GLsizei count, const GLint* v);
    SP_EXTERN void		sglUniform3f(GLint location, GLfloat x, GLfloat y, GLfloat z);
    SP_EXTERN void		sglUniform3fv(GLint location, GLsizei count, const GLfloat* v);
    SP_EXTERN void		sglUniform3i(GLint location, GLint x, GLint y, GLint z);
    SP_EXTERN void		sglUniform3iv(GLint location, GLsizei count, const GLint* v);
    SP_EXTERN void		sglUniform4f(GLint location, GLfloat x, GLfloat y, GLfloat z, GLfloat w);
    SP_EXTERN void		sglUniform4fv(GLint location, GLsizei count, const GLfloat* v);
    SP_EXTERN void		sglUniform4i(GLint location, GLint x, GLint y, GLint z, GLint w);
    SP_EXTERN void		sglUniform4iv(GLint location, GLsizei count, const GLint* v);
    SP_EXTERN void		sglUniformMatrix2fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat* value);
    SP_EXTERN void		sglUniformMatrix3fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat* value);
    SP_EXTERN void		sglUniformMatrix4fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat* value);
    SP_EXTERN void		sglUseProgram(GLuint program);
    SP_EXTERN void		sglViewport(GLint x, GLint y, GLsizei width, GLsizei height);

#endif //!SP_USE_OPENGL_STATE_CACHE
