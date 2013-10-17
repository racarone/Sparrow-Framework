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

#import "SPPoolObject.h"
#import "SPMacros.h"

#import <libkern/OSAtomic.h>
#import <malloc/malloc.h>
#import <objc/runtime.h>

#ifndef DISABLE_MEMORY_POOLING

// --- hash table ----------------------------------------------------------------------------------

#define HASH_MASK (SP_POOL_OBJECT_MAX_CLASSES - 1)

struct __SPPoolCachePair
{
    Class key;
    OSQueueHead value;
};
typedef struct __SPPoolCachePair SPPoolCachePair;

struct __SPPoolCache
{
    SPPoolCachePair table[SP_POOL_OBJECT_MAX_CLASSES];
};
typedef struct __SPPoolCache SPPoolCache;

SP_INLINE SPPoolCache* getPoolCache(void)
{
    static SPPoolCache instance = (SPPoolCache){{ nil, OS_ATOMIC_QUEUE_INIT }};
    return &instance;
}

SP_INLINE SPPoolCachePair* getValueForKey(SPPoolCache* hash, size_t key)
{
    return &hash->table[key & HASH_MASK];
}

SP_INLINE size_t generateKeyForClass(Class class)
{
    return (((size_t)class) & HASH_MASK);
}

SP_INLINE void addClassToCache(Class class)
{
    SPPoolCache *poolHash = getPoolCache();
    size_t hashKey = generateKeyForClass(class);
    poolHash->table[hashKey].key = class;
}

SP_INLINE OSQueueHead* getQueueWithClass(Class class)
{
    SPPoolCache *poolHash = getPoolCache();
    size_t hashKey = generateKeyForClass(class);
    OSQueueHead *queue = NULL;

    SPPoolCachePair *poolValue = getValueForKey(poolHash, hashKey);
    if (poolValue->key == class)
        queue = &poolValue->value;

    return queue;
}

// --- queue ---------------------------------------------------------------------------------------

#define QUEUE_OFFSET        sizeof(Class)
#define DEQUEUE(pool)       OSAtomicDequeue(pool, QUEUE_OFFSET)
#define ENQUEUE(pool, obj)  OSAtomicEnqueue(pool, obj, QUEUE_OFFSET)

// --- class implementation ------------------------------------------------------------------------

#if SP_POOL_OBJECT_IS_ATOMIC
    #define INCREMENT_32(var)    OSAtomicIncrement32Barrier(&var)
    #define DECREMENT_32(var)    OSAtomicDecrement32Barrier(&var)
    #define MEMORY_BARRIER()     OSMemoryBarrier()
#else
    #define INCREMENT_32(var)    (++ var)
    #define DECREMENT_32(var)    (-- var)
    #define MEMORY_BARRIER()
#endif

#define RETAIN_COUNT _refOrLink.ref

@implementation SPPoolObject
{
    union // since link is only used while in the queue
    {
        int32_t ref;
        SPPoolObject *link;
    }
    _refOrLink;
}

+ (void)initialize
{
    if (self == [SPPoolObject class])
        return;

    addClassToCache(self);
}

+ (id)allocWithZone:(NSZone *)zone
{
  #if DEBUG && !SP_POOL_OBJECT_IS_ATOMIC
    // make sure that people don't use pooling from multiple threads
    static id thread = nil;
    if (thread) NSAssert(thread == [NSThread currentThread], @"SPPoolObject is NOT thread safe! Must set SP_POOL_OBJECT_IS_ATOMIC to 1.");
    else thread = [NSThread currentThread];
  #endif

    OSQueueHead *poolQueue = getQueueWithClass(self);
    SPPoolObject *object = DEQUEUE(poolQueue);

    if (object)
    {
        // zero out memory. (do not overwrite isa, thus the offset)
        static size_t offset = sizeof(Class);
        memset((char *)(id)object + offset, 0, malloc_size(object) - offset);
        object->RETAIN_COUNT = 1;
    }
    else
    {
        // pool is empty -> allocate
        object = NSAllocateObject(self, 0, NULL);
        object->RETAIN_COUNT = 1;
    }

    return object;
}

- (NSUInteger)retainCount
{
    MEMORY_BARRIER();
    return RETAIN_COUNT;
}

- (instancetype)retain
{
    INCREMENT_32(RETAIN_COUNT);
    return self;
}

- (oneway void)release
{
    if (DECREMENT_32(RETAIN_COUNT) == 0)
    {
        OSQueueHead *poolQueue = getQueueWithClass(object_getClass(self));
        ENQUEUE(poolQueue, self);
    }
}

- (void)purge
{
    // will call 'dealloc' internally -- which should not be called directly.
    [super release];
}

+ (int)purgePool
{
    OSQueueHead *poolQueue = getQueueWithClass(self);
    SPPoolObject *lastElement;

    int count = 0;
    while ((lastElement = DEQUEUE(poolQueue)))
    {
        ++count;
        [lastElement purge];
    }

    return count;
}

@end

#else

@implementation SPPoolObject

+ (int)purgePool
{
    return 0;
}

@end

#endif
