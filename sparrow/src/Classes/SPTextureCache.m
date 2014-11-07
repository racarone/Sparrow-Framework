//
//  SPTextureCache.m
//  Sparrow
//
//  Created by Daniel Sperl on 25.03.14.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPTexture.h"
#import "SPTextureCache.h"

@implementation SPTextureCache
{
    NSMapTable *_cache;
    dispatch_queue_t _queue;
}

#pragma mark Initialization

- (instancetype)init
{
    if ((self = [super init]))
    {
        _cache = [[NSMapTable strongToWeakObjectsMapTable] retain];
        _queue = dispatch_queue_create("Sparrow-TextureCacheQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)dealloc
{
    [(id)_queue release];
    [_cache release];
    [super dealloc];
}

#pragma mark Methods

- (SPTexture *)textureForKey:(NSString *)key
{
    __block SPTexture *texture;
    dispatch_sync(_queue, ^
    {
        texture = [[_cache objectForKey:key] retain];
    });

    return [texture autorelease];
}

- (void)setTexture:(SPTexture *)texture forKey:(NSString *)key
{
    dispatch_barrier_async(_queue, ^
    {
        [_cache setObject:texture forKey:key];
    });
}

- (void)purge
{
    [_cache removeAllObjects];
}

@end
