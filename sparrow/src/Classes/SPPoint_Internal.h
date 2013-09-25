//
//  SPPoint_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 9/20/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <GLKit/GLKMath.h>

#import "SPMacros.h"
#import "SPPoint.h"

#if defined(__ARM_NEON__)
    #include <arm_neon.h>
#endif

@interface SPPoint () {
@public

    float _x;
    float _y;
}

@end

#pragma mark -
#pragma mark Prototypes
#pragma mark -

SP_EXTERN SPPoint*          SPPointAlloc(void);
SP_INLINE SPPoint*          SPPointCreate(void);
SP_INLINE SPPoint*          SPPointCopy(SPPoint* self);
SP_INLINE SPPoint*          SPPointAddPoint(SPPoint* self, SPPoint* point);
SP_INLINE SPPoint*          SPPointSubtractPoint(SPPoint* self, SPPoint* point);
SP_INLINE SPPoint*          SPPointScaleBy(SPPoint* self, float scalar);
SP_INLINE SPPoint*          SPPointRotateBy(SPPoint* self, float angle);
SP_INLINE SPPoint*          SPPointNormalize(SPPoint* self);
SP_INLINE SPPoint*          SPPointInvert(SPPoint* self);
SP_INLINE float             SPPointDot(SPPoint* self, SPPoint* other);
SP_INLINE bool              SPPointIsEquivalent(SPPoint* self, SPPoint* other);
SP_INLINE void              SPPointCopyFromPoint(SPPoint* self, SPPoint* point);
SP_INLINE void              SPPointSet(SPPoint* self, float x, float y);
SP_INLINE GLKVector2        SPPointConvertToGLKVector2(SPPoint* self);
SP_INLINE float             SPPointDistanceFromPoints(SPPoint* p1, SPPoint* p2);
SP_INLINE float             SPPointAngleBetweenPoints(SPPoint* p1, SPPoint* p2);
SP_INLINE SPPoint*          SPPointInterpolateFromPoints(SPPoint* p1, SPPoint* p2, float ratio);
SP_INLINE float             SPPointGetLength(SPPoint* self);
SP_INLINE float             SPPointGetLengthSquared(SPPoint* self);
SP_INLINE float             SPPointGetAngle(SPPoint* self);
SP_INLINE bool              SPPointIsOrigin(SPPoint* self);

#pragma mark -
#pragma mark Implementations
#pragma mark -

SP_INLINE SPPoint* SPPointCreate(void)
{
    SPPoint* point = SPPointAlloc();
    SPPointSet(point, 0, 0);
    return SP_AUTORELEASE(point);
}

SP_INLINE SPPoint* SPPointCopy(SPPoint* self)
{
    SPPoint* point = SPPointAlloc();
    SPPointCopyFromPoint(point, self);
    return SP_AUTORELEASE(point);
}

SP_INLINE SPPoint* SPPointAddPoint(SPPoint* self, SPPoint* point)
{
    SPPoint* result = SPPointAlloc();
#if defined(__ARM_NEON__)
    *((float32x2_t*)&result->_x) = vadd_f32(*(float32x2_t*)&self->_x, *(float32x2_t*)&point->_x);
#else
    result->_x = self->_x + point->_x;
    result->_y = self->_y + point->_y;
#endif
    return SP_AUTORELEASE(result);
}

SP_INLINE SPPoint* SPPointSubtractPoint(SPPoint* self, SPPoint* point)
{
    SPPoint* result = SPPointAlloc();
#if defined(__ARM_NEON__)
    *((float32x2_t*)&result->_x) = vsub_f32(*(float32x2_t*)&self->_x, *(float32x2_t*)&point->_x);
#else
    result->_x = self->_x - point->_x;
    result->_y = self->_y - point->_y;
#endif
    return SP_AUTORELEASE(result);
}

SP_INLINE SPPoint* SPPointScaleBy(SPPoint* self, float scalar)
{
    SPPoint* result = SPPointAlloc();
#if defined(__ARM_NEON__)
    *((float32x2_t*)&result->_x) = vmul_f32(*(float32x2_t*)&self->_x, vdup_n_f32((float32_t)scalar));
#else
    result->_x = self->_x * scalar;
    result->_y = self->_y * scalar;
#endif
    return SP_AUTORELEASE(result);
}

SP_INLINE SPPoint* SPPointRotateBy(SPPoint* self, float angle)
{
    SPPoint* result = SPPointAlloc();
    float sina = sinf(angle);
    float cosa = cosf(angle);
    
    SPPointSet(result, (self->_x * cosa) - (self->_y * sina), (self->_x * sina) + (self->_y * cosa));
    return result;
}

SP_INLINE SPPoint* SPPointNormalize(SPPoint* self)
{
    float inverseLength = 1.0f / SPPointGetLength(self);
    return SPPointScaleBy(self, inverseLength);
}

SP_INLINE SPPoint* SPPointInvert(SPPoint* self)
{
    SPPoint* result = SPPointAlloc();
#if defined(__ARM_NEON__)
    *((float32x2_t*)&result->_x) = vneg_f32(*(float32x2_t*)&self->_x);
#else
    result->_x = -self->_x;
    result->_y = -self->_y;
#endif
    return SP_AUTORELEASE(result);
}

SP_INLINE float SPPointDot(SPPoint* self, SPPoint* other)
{
#if defined(__ARM_NEON__)
    float32x2_t v = vmul_f32(*(float32x2_t*)&self->_x, *(float32x2_t*)&other->_x);
    v = vpadd_f32(v, v);
    return vget_lane_f32(v, 0);
#else
    return self->_x * other->_x + self->_y * other->_y;
#endif
}

SP_INLINE bool SPPointIsEquivalent(SPPoint* self, SPPoint* other)
{
    if (other == self) return true;
    else if (!other) return false;

#if defined(__ARM_NEON__)
    float32x2_t v1 = *(float32x2_t*)&self->_x;
    float32x2_t v2 = *(float32x2_t*)&other->_x;
    uint32x2_t vCmp = vceq_f32(v1, v2);
    uint32x2_t vAnd = vand_u32(vCmp, vext_u32(vCmp, vCmp, 1));
    vAnd = vand_u32(vAnd, vdup_n_u32(1));
    return (bool)vget_lane_u32(vAnd, 0);
#else
    bool compare = false;
    if (self->_x == other->_x &&
        self->_y == other->_y)
        compare = true;
    return compare;
#endif
}

SP_INLINE void SPPointCopyFromPoint(SPPoint* self, SPPoint* point)
{
#if defined(__ARM_NEON__)
    *((float32x2_t*)&self->_x) = *(float32x2_t*)&point->_x;
#else
    self->_x = point->_x;
    self->_y = point->_y;
#endif
}

SP_INLINE void SPPointSet(SPPoint* self, float x, float y)
{
    self->_x = x;
    self->_y = y;
}

SP_INLINE GLKVector2 SPPointConvertToGLKVector2(SPPoint* self)
{
    return GLKVector2MakeWithArray(&self->_x);
}

SP_INLINE float SPPointDistanceFromPoints(SPPoint* p1, SPPoint* p2)
{
    return SPPointGetLength(SPPointSubtractPoint(p1, p2));
}

SP_INLINE float SPPointAngleBetweenPoints(SPPoint* p1, SPPoint* p2)
{
    float cos = SPPointDot(p1, p2) / (SPPointGetLength(p1) * SPPointGetLength(p2));
    return cos >= 1.0f ? 0.0f : acosf(cos);
}

SP_INLINE SPPoint* SPPointInterpolateFromPoints(SPPoint* p1, SPPoint* p2, float ratio)
{
    SPPoint* result = SPPointAlloc();
#if defined(__ARM_NEON__)
    float32x2_t vDiff = vsub_f32(*(float32x2_t*)&p2->_x, *(float32x2_t*)&p1->_x);
    vDiff = vmul_f32(vDiff, vdup_n_f32((float32_t)ratio));
    *((float32x2_t*)&result->_x) = vadd_f32(*(float32x2_t *)&p1->_x, vDiff);
#else
    result->_x = p1->_x + ((p2->_x - p1->_x) * ratio);
    result->_y = p1->_y + ((p2->_y - p1->_y) * ratio);
#endif
    return SP_AUTORELEASE(result);
}

SP_INLINE float SPPointGetLength(SPPoint* self)
{
#if defined(__ARM_NEON__)
    float32x2_t v = vmul_f32(*(float32x2_t*)&self->_x, *(float32x2_t*)&self->_x);
    v = vpadd_f32(v, v);
    return sqrtf(vget_lane_f32(v, 0));
#else
    return sqrtf(SP_SQUARE(self->_x) + SP_SQUARE(self->_y));
#endif
}

SP_INLINE float SPPointGetLengthSquared(SPPoint* self)
{
    return SP_SQUARE(self->_x) + SP_SQUARE(self->_y);
}

SP_INLINE float SPPointGetAngle(SPPoint* self)
{
    return atan2f(self->_y, self->_x);
}

SP_INLINE bool SPPointIsOrigin(SPPoint* self)
{
    return self->_x == 0.0f && self->_y == 0.0f;
}
