//
//  SPOpenGL.m
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//

#import "SPOpenGL_Internal.h"
#import "SPOpenGL.h"

#import <Foundation/Foundation.h>

#if SP_USE_OPENGL_STATE_CACHE

#undef glActiveTexture            
#undef glBindBuffer               
#undef glBindFramebuffer          
#undef glBindRenderbuffer         
#undef glBindTexture              
#undef glBlendFunc                
#undef glClearColor               
#undef glCreateProgram            
#undef glDeleteBuffers            
#undef glDeleteFramebuffers       
#undef glDeleteProgram            
#undef glDeleteRenderbuffers      
#undef glDeleteTextures           
#undef glDisable                  
#undef glDisableVertexAttribArray 
#undef glEnable                   
#undef glEnableVertexAttribArray  
#undef glScissor                  
#undef glUniform1f                
#undef glUniform1fv               
#undef glUniform1i                
#undef glUniform1iv               
#undef glUniform2f                
#undef glUniform2fv               
#undef glUniform2i                
#undef glUniform2iv               
#undef glUniform3f                
#undef glUniform3fv               
#undef glUniform3i                
#undef glUniform3iv               
#undef glUniform4f                
#undef glUniform4fv               
#undef glUniform4i                
#undef glUniform4iv               
#undef glUniformMatrix2fv         
#undef glUniformMatrix3fv         
#undef glUniformMatrix4fv         
#undef glUseProgram               
#undef glViewport                 

// --- internal ------------------------------------------------------------------------------------

#define MAX_TEXTURE_UNITS 32

struct __SPGLState {
    GLuint      textureUnit;
    GLuint      texture[MAX_TEXTURE_UNITS];
    GLuint      program;
    GLuint      framebuffer;
    GLuint      renderbuffer;
    GLint       viewport[4];
    GLint       scissor[4];
    GLfloat     clearColor[4];
    GLuint      buffer[2];
    GLuint      vao;
    GLboolean   enabledVertexAttribs[32];
    GLint       enabledCaps[10];
    GLenum      blendSrc;
    GLenum      blendDst;
};
typedef struct __SPGLState* SPGLStateRef;

static SPGLStateRef __SPGetGLState(void)
{
    static dispatch_once_t  once;
    static SPGLStateRef     globalState;

    dispatch_once(&once, ^{
        globalState = calloc(sizeof(struct __SPGLState), 1);
        memset(globalState, -1, sizeof(*globalState));
    });

    return globalState;
}

static SPGLProgramCacheRef __SPGetProgramCache(void)
{
    static dispatch_once_t      once;
    static SPGLProgramCacheRef  globalProgramCache;

    dispatch_once(&once, ^{
        globalProgramCache = SPGLProgramCacheCreate(8);
    });

    return globalProgramCache;
}

static GLuint __SPGetIndexForCapability(GLuint cap)
{
    switch (cap) {
        case GL_TEXTURE_2D:                 return 0;
        case GL_CULL_FACE:                  return 1;
        case GL_BLEND:                      return 2;
        case GL_DITHER:                     return 3;
        case GL_STENCIL_TEST:               return 4;
        case GL_DEPTH_TEST:                 return 5;
        case GL_SCISSOR_TEST:               return 6;
        case GL_POLYGON_OFFSET_FILL:        return 7;
        case GL_SAMPLE_ALPHA_TO_COVERAGE:   return 8;
        case GL_SAMPLE_COVERAGE:            return 9;
    }
    return -1;
}

// --- implementation ------------------------------------------------------------------------------

void sglActiveTexture(GLenum texture)
{
    GLuint textureUnit = texture-GL_TEXTURE0;
    SPGLStateRef currentState = __SPGetGLState();

    if (textureUnit != currentState->textureUnit)
    {
        currentState->textureUnit = textureUnit;
        glActiveTexture(texture);
    }
}

void sglBindBuffer(GLenum target, GLuint buffer)
{
    GLuint index = target-GL_ARRAY_BUFFER;
    SPGLStateRef currentState = __SPGetGLState();

    if (buffer != currentState->buffer[index])
    {
        currentState->buffer[index] = buffer;
        glBindBuffer(target, buffer);
    }
}

void sglBindFramebuffer(GLenum target, GLuint framebuffer)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (framebuffer != currentState->framebuffer)
    {
        currentState->framebuffer = framebuffer;
        glBindFramebuffer(target, framebuffer);
    }
}

void sglBindRenderbuffer(GLenum target, GLuint renderbuffer)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (renderbuffer != currentState->renderbuffer)
    {
        currentState->renderbuffer = renderbuffer;
        glBindRenderbuffer(target, renderbuffer);
    }
}

void sglBindTexture(GLenum target, GLuint texture)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (texture != currentState->texture[currentState->textureUnit])
    {
        currentState->texture[currentState->textureUnit] = texture;
        glBindTexture(target, texture);
    }
}

void sglBlendFunc(GLenum sfactor, GLenum dfactor)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (sfactor != currentState->blendSrc || dfactor != currentState->blendDst)
    {
        currentState->blendSrc = sfactor;
        currentState->blendDst = dfactor;
        glBlendFunc(sfactor, dfactor);
    }
}

void sglClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (red   != currentState->clearColor[0] ||
        green != currentState->clearColor[1] ||
        blue  != currentState->clearColor[2] ||
        alpha != currentState->clearColor[3])
    {
        currentState->clearColor[0] = red;
        currentState->clearColor[1] = green;
        currentState->clearColor[2] = blue;
        currentState->clearColor[3] = alpha;

        glClearColor(red, green, blue, alpha);
    }
}

GLuint sglCreateProgram(void)
{
    GLuint newProgram = glCreateProgram();
    SPGLProgramCacheCreateWithProgram(__SPGetProgramCache(), newProgram);
    return newProgram;
}

void sglDeleteBuffers(GLsizei n, const GLuint* buffers)
{
    SPGLStateRef currentState = __SPGetGLState();
    for (int i=0; i<n; i++)
    {
        if (currentState->buffer[0] == buffers[i]) currentState->buffer[0] = 0;
        if (currentState->buffer[1] == buffers[i]) currentState->buffer[1] = 0;
    }

    glDeleteBuffers(n, buffers);
}

void sglDeleteFramebuffers(GLsizei n, const GLuint* framebuffers)
{
    SPGLStateRef currentState = __SPGetGLState();
    for (int i=0; i<n; i++)
    {
        if (currentState->framebuffer == framebuffers[i])
            currentState->framebuffer = 0;
    }

    glDeleteFramebuffers(n, framebuffers);
}

void sglDeleteProgram(GLuint program)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (currentState->program == program)
    {
        currentState->program = 0;
    }

    SPGLProgramCacheDestroyCacheWithProgram(__SPGetProgramCache(), program);
    glDeleteProgram(program);
}

void sglDeleteRenderbuffers(GLsizei n, const GLuint* renderbuffers)
{
    SPGLStateRef currentState = __SPGetGLState();
    for (int i=0; i<n; i++)
    {
        if (currentState->renderbuffer == renderbuffers[i])
            currentState->renderbuffer = 0;
    }

    glDeleteRenderbuffers(n, renderbuffers);
}

void sglDeleteTextures(GLsizei n, const GLuint* textures)
{
    SPGLStateRef currentState = __SPGetGLState();
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

void sglDisable(GLenum cap)
{
    SPGLStateRef currentState = __SPGetGLState();
    GLuint index = __SPGetIndexForCapability(cap);

    if (currentState->enabledCaps[index] != GL_FALSE)
    {
        currentState->enabledCaps[index] = GL_FALSE;
        glDisable(cap);
    }
}

void sglDisableVertexAttribArray(GLuint index)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (currentState->enabledVertexAttribs[index] != GL_FALSE)
    {
        currentState->enabledVertexAttribs[index] = GL_FALSE;
        glDisableVertexAttribArray(index);
    }
}

void sglEnable(GLenum cap)
{
    SPGLStateRef currentState = __SPGetGLState();
    GLuint index = __SPGetIndexForCapability(cap);

    if (currentState->enabledCaps[index] != GL_TRUE)
    {
        currentState->enabledCaps[index] = GL_TRUE;
        glDisable(cap);
    }
}

void sglEnableVertexAttribArray(GLuint index)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (currentState->enabledVertexAttribs[index] != GL_TRUE)
    {
        currentState->enabledVertexAttribs[index] = GL_TRUE;
        glEnableVertexAttribArray(index);
    }
}

void sglScissor(GLint x, GLint y, GLsizei width, GLsizei height)
{
    SPGLStateRef currentState = __SPGetGLState();
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

void sglUniform1f(GLint location, GLfloat x)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirtyFloat(uniformCache, location, x))
        glUniform1f(location, x);
}

void sglUniform1fv(GLint location, GLsizei count, const GLfloat* v)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)v, sizeof(GLfloat)*count))
        glUniform1fv(location, count, v);
}

void sglUniform1i(GLint location, GLint x)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirtyInt(uniformCache, location, x))
        glUniform1i(location, x);
}

void sglUniform1iv(GLint location, GLsizei count, const GLint* v)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)v, sizeof(GLint)*count))
        glUniform1iv(location, count, v);
}

void sglUniform2f(GLint location, GLfloat x, GLfloat y)
{
    GLfloat ary[] = {x ,y};
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)ary, sizeof(ary)))
        glUniform2f(location, x, y);
}

void sglUniform2fv(GLint location, GLsizei count, const GLfloat* v)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)v, sizeof(GLfloat)*count*2))
        glUniform2fv(location, count, v);
}

void sglUniform2i(GLint location, GLint x, GLint y)
{
    GLint ary[] = {x ,y};
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)ary, sizeof(ary)))
        glUniform2i(location, x, y);
}

void sglUniform2iv(GLint location, GLsizei count, const GLint* v)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)v, sizeof(GLint)*count*2))
        glUniform2iv(location, count, v);
}

void sglUniform3f(GLint location, GLfloat x, GLfloat y, GLfloat z)
{
    GLfloat ary[] = {x ,y, z};
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)ary, sizeof(ary)))
        glUniform3f(location, x, y, z);
}

void sglUniform3fv(GLint location, GLsizei count, const GLfloat* v)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)v, sizeof(GLfloat)*count*3))
        glUniform3fv(location, count, v);
}

void sglUniform3i(GLint location, GLint x, GLint y, GLint z)
{
    GLint ary[] = {x ,y, z};
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)ary, sizeof(ary)))
        glUniform3i(location, x, y, z);
}

void sglUniform3iv(GLint location, GLsizei count, const GLint* v)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)v, sizeof(GLint)*count*3))
        glUniform3iv(location, count, v);
}

void sglUniform4f(GLint location, GLfloat x, GLfloat y, GLfloat z, GLfloat w)
{
    GLfloat ary[] = {x ,y, z, w};
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)ary, sizeof(ary)))
        glUniform4f(location, x, y, z, w);
}

void sglUniform4fv(GLint location, GLsizei count, const GLfloat* v)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)v, sizeof(GLfloat)*count*4))
        glUniform4fv(location, count, v);
}

void sglUniform4i(GLint location, GLint x, GLint y, GLint z, GLint w)
{
    GLint ary[] = {x ,y, z, w};
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)ary, sizeof(ary)))
        glUniform4i(location, x, y, z, w);
}

void sglUniform4iv(GLint location, GLsizei count, const GLint* v)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)v, sizeof(GLint)*count*4))
        glUniform4iv(location, count, v);
}

void sglUniformMatrix2fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat* value)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)value, sizeof(GLfloat)*count*(2*2)))
        glUniformMatrix2fv(location, count, transpose, value);
}

void sglUniformMatrix3fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat* value)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)value, sizeof(GLfloat)*count*(3*3)))
        glUniformMatrix3fv(location, count, transpose, value);
}

void sglUniformMatrix4fv(GLint location, GLsizei count, GLboolean transpose, const GLfloat* value)
{
    SPGLStateRef currentState = __SPGetGLState();
    SPGLUniformCacheRef uniformCache = SPGLProgramCacheGetUniformCacheForProgram(__SPGetProgramCache(), currentState->program);

    if (SPGLUniformCacheIsUniformDirty(uniformCache, location, (void*)value, sizeof(GLfloat)*count*(4*4)))
        glUniformMatrix4fv(location, count, transpose, value);
}

void sglUseProgram(GLuint program)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (program != currentState->program)
    {
        currentState->program = program;
        glUseProgram(program);
    }
}

void sglViewport(GLint x, GLint y, GLsizei width, GLsizei height)
{
    SPGLStateRef currentState = __SPGetGLState();
    if (x      != currentState->viewport[0] ||
        y      != currentState->viewport[1] ||
        width  != currentState->viewport[2] ||
        height != currentState->viewport[3])
    {
        currentState->viewport[0] = x;
        currentState->viewport[1] = y;
        currentState->viewport[2] = width;
        currentState->viewport[3] = height;

        glViewport(x, y, width, height);
    }
}

#endif // !SP_USE_OPENGL_STATE_CACHE
