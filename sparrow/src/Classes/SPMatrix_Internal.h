//
//  SPMatrix_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 9/20/13.
//
//

#import "SPMacros.h"
#import "SPMatrix.h"
#import "SPPoint_Internal.h"

#if defined(__ARM_NEON__)
    #include <arm_neon.h>
#endif

@interface SPMatrix () {
@public
    
    float _a, _b, _c, _d;
    float _tx, _ty;
}

@end

#pragma mark -
#pragma mark Prototypes
#pragma mark -

GLK_EXTERN SPMatrix*        SPMatrixAlloc(void);
GLK_INLINE SPMatrix*        SPMatrixCreate(void);
GLK_INLINE SPMatrix*        SPMatrixCopy(SPMatrix* self);
GLK_INLINE void             SPMatrixSet(SPMatrix* self, float a, float b, float c, float d, float tx, float ty);
GLK_INLINE bool             SPMatrixIsEquivilant(SPMatrix* self, SPMatrix* matrix);
GLK_INLINE void             SPMatrixAppendMatrix(SPMatrix* self, SPMatrix* lhs);
GLK_INLINE void             SPMatrixPrependMatrix(SPMatrix* self, SPMatrix* rhs);
GLK_INLINE void             SPMatrixTranslateBy(SPMatrix* self, float dx, float dy);
GLK_INLINE void             SPMatrixScaleBy(SPMatrix* self, float sx, float sy);
GLK_INLINE void             SPMatrixSkewBy(SPMatrix* self, float sx, float sy);
GLK_INLINE void             SPMatrixScale(SPMatrix* self, float scale);
GLK_INLINE void             SPMatrixRotateBy(SPMatrix* self, float angle);
GLK_INLINE void             SPMatrixIdentity(SPMatrix* self);
GLK_INLINE void             SPMatrixInvert(SPMatrix* self);
GLK_INLINE void             SPMatrixCopyFrom(SPMatrix* self, SPMatrix* matrix);
GLK_INLINE GLKMatrix4       SPMatrixConvertToGLKMatrix4(SPMatrix* self);
GLK_INLINE GLKMatrix3       SPMatrixConvertToGLKMatrix3(SPMatrix* self);
GLK_INLINE SPPoint*         SPMatrixTransformPoint(SPMatrix* self, SPPoint* point);
GLK_INLINE SPPoint*         SPMatrixTransformPointWith(SPMatrix* self, float x, float y);
GLK_INLINE float            SPMatrixGetDeterminant(SPMatrix* self);

#pragma mark -
#pragma mark Implementations
#pragma mark -

GLK_INLINE SPMatrix* SPMatrixCreate(void)
{
    SPMatrix* result = SPMatrixAlloc();
    SPMatrixIdentity(result);
    return SP_AUTORELEASE(result);
}

GLK_INLINE SPMatrix* SPMatrixCopy(SPMatrix* self)
{
    SPMatrix* result = SPMatrixAlloc();
    SPMatrixCopyFrom(result, self);
    return result;
}

GLK_INLINE void SPMatrixSet(SPMatrix* self, float a, float b, float c, float d, float tx, float ty)
{
    self->_a = a; self->_b = b; self->_c = c; self->_d = d;
    self->_tx = tx; self->_ty = ty;
}

GLK_INLINE bool SPMatrixIsEquivilant(SPMatrix* self, SPMatrix* matrix)
{
    if (matrix == self) return true;
    else if (!matrix) return false;
    else
    {
        return SP_IS_FLOAT_EQUAL(self->_a, matrix->_a) && SP_IS_FLOAT_EQUAL(self->_b, matrix->_b) &&
               SP_IS_FLOAT_EQUAL(self->_c, matrix->_c) && SP_IS_FLOAT_EQUAL(self->_d, matrix->_d) &&
               SP_IS_FLOAT_EQUAL(self->_tx, matrix->_tx) && SP_IS_FLOAT_EQUAL(self->_ty, matrix->_ty);
    }
}

GLK_INLINE void SPMatrixAppendMatrix(SPMatrix* self, SPMatrix* lhs)
{
    SPMatrixSet(self, lhs->_a * self->_a  + lhs->_c * self->_b,
                      lhs->_b * self->_a  + lhs->_d * self->_b,
                      lhs->_a * self->_c  + lhs->_c * self->_d,
                      lhs->_b * self->_c  + lhs->_d * self->_d,
                      lhs->_a * self->_tx + lhs->_c * self->_ty + lhs->_tx,
                      lhs->_b * self->_tx + lhs->_d * self->_ty + lhs->_ty);
}

GLK_INLINE void SPMatrixPrependMatrix(SPMatrix* self, SPMatrix* rhs)
{
    SPMatrixSet(self, self->_a * rhs->_a + self->_c * rhs->_b,
                      self->_b * rhs->_a + self->_d * rhs->_b,
                      self->_a * rhs->_c + self->_c * rhs->_d,
                      self->_b * rhs->_c + self->_d * rhs->_d,
                      self->_tx + self->_a * rhs->_tx + self->_c * rhs->_ty,
                      self->_ty + self->_b * rhs->_tx + self->_d * rhs->_ty);
}

GLK_INLINE void SPMatrixTranslateBy(SPMatrix* self, float dx, float dy)
{
    self->_tx += dx;
    self->_ty += dy;
}

GLK_INLINE void SPMatrixScaleBy(SPMatrix* self, float sx, float sy)
{
    if (sx != 1.0f)
    {
        self->_a  *= sx;
        self->_c  *= sx;
        self->_tx *= sx;
    }

    if (sy != 1.0f)
    {
        self->_b  *= sy;
        self->_d  *= sy;
        self->_ty *= sy;
    }
}

GLK_INLINE void SPMatrixSkewBy(SPMatrix* self, float sx, float sy)
{
    float sinX = sinf(sx);
    float cosX = cosf(sx);
    float sinY = sinf(sy);
    float cosY = cosf(sy);

    SPMatrixSet(self, self->_a  * cosY - self->_b  * sinX,
                      self->_a  * sinY + self->_b  * cosX,
                      self->_c  * cosY - self->_d  * sinX,
                      self->_c  * sinY + self->_d  * cosX,
                      self->_tx * cosY - self->_ty * sinX,
                      self->_tx * sinY + self->_ty * cosX);
}

GLK_INLINE void SPMatrixScale(SPMatrix* self, float scale)
{
    SPMatrixScaleBy(self, scale, scale);
}

GLK_INLINE void SPMatrixRotateBy(SPMatrix* self, float angle)
{
    if (angle == 0.0f) return;

    float cos = cosf(angle);
    float sin = sinf(angle);

    SPMatrixSet(self, self->_a * cos -  self->_b * sin,  self->_a * sin +  self->_b * cos,
                      self->_c * cos -  self->_d * sin,  self->_c * sin +  self->_d * cos,
                      self->_tx * cos - self->_ty * sin, self->_tx * sin + self->_ty * cos);
}

GLK_INLINE void SPMatrixIdentity(SPMatrix* self)
{
    SPMatrixSet(self, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f);
}

GLK_INLINE void SPMatrixInvert(SPMatrix* self)
{
    float det = SPMatrixGetDeterminant(self);
    SPMatrixSet(self, self->_d/det, -self->_b/det, -self->_c/det, self->_a/det, (self->_c*self->_ty-self->_d*self->_tx)/det, (self->_b*self->_tx-self->_a*self->_ty)/det);
}

GLK_INLINE void SPMatrixCopyFrom(SPMatrix* self, SPMatrix* matrix)
{
    SPMatrixSet(self, matrix->_a, matrix->_b, matrix->_c, matrix->_d, matrix->_tx, matrix->_ty);
}

GLK_INLINE GLKMatrix4 SPMatrixConvertToGLKMatrix4(SPMatrix* self)
{
    GLKMatrix4 matrix = GLKMatrix4Identity;

    matrix.m00 = self->_a;
    matrix.m01 = self->_b;
    matrix.m10 = self->_c;
    matrix.m11 = self->_d;
    matrix.m30 = self->_tx;
    matrix.m31 = self->_ty;

    return matrix;
}

GLK_INLINE GLKMatrix3 SPMatrixConvertToGLKMatrix3(SPMatrix* self)
{
    return GLKMatrix3Make(self->_a,  self->_b,  0.0f,
                          self->_c,  self->_d,  0.0f,
                          self->_tx, self->_ty, 1.0f);
}

GLK_INLINE SPPoint* SPMatrixTransformPoint(SPMatrix* self, SPPoint* point)
{
    SPPoint* result = SPPointAlloc();
    result->_x = self->_a*point.x + self->_c*point.y + self->_tx;
    result->_y = self->_b*point.x + self->_d*point.y + self->_ty;
    return SP_AUTORELEASE(result);
}

GLK_INLINE SPPoint* SPMatrixTransformPointWith(SPMatrix* self, float x, float y)
{
    SPPoint* result = SPPointAlloc();
    result->_x = self->_a*x + self->_c*y + self->_tx;
    result->_y = self->_b*x + self->_d*y + self->_ty;
    return SP_AUTORELEASE(result);
}

GLK_INLINE float SPMatrixGetDeterminant(SPMatrix* self)
{
    return self->_a * self->_d - self->_c * self->_b;
}
