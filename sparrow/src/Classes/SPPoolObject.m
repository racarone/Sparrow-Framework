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

#import <malloc/malloc.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define COMPLAIN_MISSING_IMP @"Class %@ needs this code:\nSP_IMPLEMENT_MEMORY_POOL();" 

@implementation SPPoolInfo
// empty
@end

#ifndef DISABLE_MEMORY_POOLING

typedef SPPoolInfo* (*PoolInfoIMP) (id, SEL);

@implementation SPPoolObject
{
    SPPoolObject*   _poolPredecessor;
    uint            _retainCount;
}

id doAlloc(id self, SEL _cmd, NSZone* zone)
{
#if DEBUG
    // make sure that people don't use pooling from multiple threads
    static id thread = nil;
    if (thread) NSAssert(thread == [NSThread currentThread], @"SPPoolObject is NOT thread safe!");
    else thread = [NSThread currentThread];
#endif

    SPPoolInfo* poolInfo = objc_msgSend(self, @selector(poolInfo));

    if (poolInfo->lastElement)
    {
        // recycle element, update poolInfo
        SPPoolObject* object = poolInfo->lastElement;
        poolInfo->lastElement = object->_poolPredecessor;

        // zero out memory. (do not overwrite isa & _poolPredecessor, thus the offset)
        //static size_t offset = sizeof(Class) + sizeof(SPPoolObject*);
        //memset((char*)(id)object + offset, 0, malloc_size(object) - offset);
        object->_retainCount = 1;
        return object;
    }
    else
    {
        // first allocation
        if (!poolInfo->poolClass)
        {
            poolInfo->poolClass = self;
            poolInfo->lastElement = NULL;
        }
        else if (poolInfo->poolClass != self)
        {
            [NSException raise:NSGenericException format:COMPLAIN_MISSING_IMP, self];
            return nil;
        }

        // pool is empty -> allocate
        SPPoolObject* object = NSAllocateObject(self, 0, NULL);
        object->_retainCount = 1;
        return object;
    }
}

+ (instancetype)alloc
{
    return doAlloc(self, _cmd, nil);
}

+ (instancetype)allocWithZone:(NSZone*)zone
{
    return doAlloc(self, _cmd, nil);
}

- (NSUInteger)retainCount
{
    return _retainCount;
}

- (instancetype)retain
{
    ++_retainCount;
    return self;
}

- (oneway void)release
{
    --_retainCount;
    
    if (!_retainCount)
    {
        SPPoolInfo* poolInfo = objc_msgSend(object_getClass(self), @selector(poolInfo));
        self->_poolPredecessor = poolInfo->lastElement;
        poolInfo->lastElement = self;
    }
}

- (void)purge
{
    // will call 'dealloc' internally -- which should not be called directly.
    [super release];
}

+ (int)purgePool
{
    SPPoolInfo* poolInfo = [self poolInfo];    
    SPPoolObject* lastElement;    
    
    int count=0;
    while ((lastElement = poolInfo->lastElement))
    {
        ++count;        
        poolInfo->lastElement = lastElement->_poolPredecessor;
        [lastElement purge];
    }
    
    return count;
}

+ (SPPoolInfo*)poolInfo
{
    [NSException raise:NSGenericException format:COMPLAIN_MISSING_IMP, self];
    return NULL;
}

@end

#else

@implementation SPPoolObject

+ (SPPoolInfo*)poolInfo 
{
    return nil;
}

+ (int)purgePool
{
    return 0;
}

@end

#endif