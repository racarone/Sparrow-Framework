//
//  SPEventListener.m
//  Sparrow
//
//  Created by Daniel Sperl on 28.02.13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPEventListener.h"
#import "SPNSExtensions.h"

#import <objc/message.h>

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@implementation SPEventListener
{
    SPEventBlock    _block;
    id __weak       _target;
    SEL             _selector;
}

@synthesize target      = _target;
@synthesize selector    = _selector;

- (id)initWithTarget:(id)target selector:(SEL)selector block:(SPEventBlock)block
{
    if ((self = [super init]))
    {
        _target = target;
        _selector = selector;
        _block = block ? Block_copy(block) : NULL;

        if (target && selector)
        {
            typedef void (*EventIMP) (id,SEL,id);
            __block EventIMP method = (EventIMP)[_target methodForSelector:_selector];
            block = ^(id event) {
                method(target, selector, event);
            };
            _block = Block_copy(block);
        }
    }

    return self;
}

- (id)initWithTarget:(id)target selector:(SEL)selector
{
    return [self initWithTarget:target selector:selector block:nil];
}

- (id)initWithBlock:(SPEventBlock)block
{
    return [self initWithTarget:nil selector:nil block:block];
}

- (void)dealloc
{
    SP_RELEASE_AND_NIL(_block);
    [super dealloc];
}

- (void)invokeWithEvent:(SPEvent*)event
{
    _block(event);
}

- (BOOL)fitsTarget:(id)target andSelector:(SEL)selector orBlock:(SPEventBlock)block
{
    BOOL fitsTargetAndSelector = (target && (target == _target)) && (!selector || (selector == _selector));
    BOOL fitsBlock = block == _block;
    return fitsTargetAndSelector || fitsBlock;
}

@end

