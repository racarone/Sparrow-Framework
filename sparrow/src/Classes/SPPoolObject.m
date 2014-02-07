//
//  SPPoolObject.m
//  Sparrow
//
//  Created by Daniel Sperl on 17.09.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPMacros.h>
#import <Sparrow/SPPoolObject.h>

#import <libkern/OSAtomic.h>
#import <malloc/malloc.h>
#import <objc/runtime.h>

#ifndef DISABLE_MEMORY_POOLING

// --- hash table ----------------------------------------------------------------------------------

#define HASH_MASK (SP_POOL_OBJECT_MAX_CLASSES - 1)

typedef struct
{
    Class key;
    OSQueueHead value;
}
Pair;

typedef struct
{
    Pair table[SP_POOL_OBJECT_MAX_CLASSES];
}
PoolCache;

SP_INLINE PoolCache *poolCache(void)
{
    static PoolCache instance = (PoolCache){{ nil, OS_ATOMIC_QUEUE_INIT }};
    return &instance;
}

SP_INLINE unsigned hashPtr(void *ptr)
{
  #ifdef __LP64__
    return (unsigned)(((uintptr_t)ptr) >> 3);
  #else
    return ((uintptr_t)ptr) >> 2;
  #endif
}

SP_INLINE Pair *getPairWith(PoolCache *cache, unsigned key)
{
    unsigned h = key & HASH_MASK;
    return &(cache->table[h]);
}

SP_INLINE void initPoolWith(PoolCache *cache, Class class)
{
    unsigned key = hashPtr(class);
    Pair *pair = getPairWith(cache, key);
    pair->key = class;
    pair->value = (OSQueueHead)OS_ATOMIC_QUEUE_INIT;
}

SP_INLINE OSQueueHead *getPoolWith(PoolCache *cache, Class class)
{
    unsigned key = hashPtr(class);
    Pair *pair = getPairWith(cache, key);
    //assert(pair->key == class);
    return &pair->value;
}

// --- queue ---------------------------------------------------------------------------------------

#define QUEUE_OFFSET sizeof(Class)

#define DEQUEUE(pool)       OSAtomicDequeue(pool, QUEUE_OFFSET)
#define ENQUEUE(pool, obj)  OSAtomicEnqueue(pool, obj, QUEUE_OFFSET)

// --- class implementation ------------------------------------------------------------------------

typedef volatile int32_t RCint;

@implementation SPPoolObject
{
    RCint _rc;
  #ifdef __LP64__
    uint8_t _extra[4];
  #endif
}

+ (void)initialize
{ 
    if (self == [SPPoolObject class])
        return;

    initPoolWith(poolCache(), self);
}

+ (instancetype)alloc
{
    OSQueueHead *poolQueue = getPoolWith(poolCache(), self);
    SPPoolObject *object = DEQUEUE(poolQueue);

    if (object)
    {
        // zero out memory. (do not overwrite isa, thus the offset)
        static size_t offset = sizeof(Class);
        memset((char *)object + offset, 0, malloc_size(object) - offset);
        object->_rc = 1;
    }
    else
    {
        // pool is empty -> allocate
        object = NSAllocateObject(self, 0, NULL);
        object->_rc = 1;
    }

    return object;
}

+ (instancetype)allocWithZone:(NSZone *)zone
{
    return [self alloc];
}

- (NSUInteger)retainCount
{
    return _rc;
}

- (instancetype)retain
{
    OSAtomicIncrement32(&_rc);
    return self;
}

- (oneway void)release
{
    if (OSAtomicDecrement32(&_rc))
        return;

    OSQueueHead *poolQueue = getPoolWith(poolCache(), object_getClass(self));
    ENQUEUE(poolQueue, self);
}

- (void)purge
{
    // will call 'dealloc' internally -- which should not be called directly.
    [super release];
}

+ (NSUInteger)purgePool
{
    OSQueueHead *poolQueue = getPoolWith(poolCache(), self);
    SPPoolObject *lastElement;

    NSUInteger count = 0;
    while ((lastElement = DEQUEUE(poolQueue)))
    {
        ++count;
        [lastElement purge];
    }

    return count;
}

@end

#else // DISABLE_MEMORY_POOLING

@implementation SPPoolObject

+ (NSUInteger)purgePool
{
    return 0;
}

@end

#endif
