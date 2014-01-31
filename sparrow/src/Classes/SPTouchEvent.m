//
//  SPTouchEvent.m
//  Sparrow
//
//  Created by Daniel Sperl on 02.05.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPDisplayObject.h>
#import <Sparrow/SPDisplayObjectContainer.h>
#import <Sparrow/SPEvent_Internal.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPTouchEvent.h>

NSString *const SPEventTypeTouch = @"SPEventTypeTouch";

@implementation SPTouchEvent
{
    NSSet *_touches;
}

#pragma mark Initialization

- (instancetype)initWithType:(NSString *)type bubbles:(BOOL)bubbles touches:(NSSet *)touches
{   
    if ((self = [super initWithType:type bubbles:bubbles]))
    {        
        _touches = [touches retain];
    }
    return self;
}

- (instancetype)initWithType:(NSString *)type touches:(NSSet *)touches
{   
    return [self initWithType:type bubbles:YES touches:touches];
}

- (instancetype)initWithType:(NSString *)type bubbles:(BOOL)bubbles
{
    return [self initWithType:type bubbles:bubbles touches:[NSSet set]];
}

- (void)dealloc
{
    [_touches release];
    [super dealloc];
}

+ (instancetype)eventWithType:(NSString *)type touches:(NSSet *)touches
{
    return [[[self alloc] initWithType:type touches:touches] autorelease];
}

#pragma mark Methods

- (NSSet *)touchesWithTarget:(SPDisplayObject *)target
{
    NSMutableSet *touchesFound = [NSMutableSet set];
    for (SPTouch *touch in _touches)
    {
        if ([target isEqual:touch.target] ||
            ([target isKindOfClass:[SPDisplayObjectContainer class]] &&
             [(SPDisplayObjectContainer *)target containsChild:touch.target]))
        {
            [touchesFound addObject: touch];
        }
    }    
    return touchesFound;    
}

- (NSSet *)touchesWithTarget:(SPDisplayObject *)target andPhase:(SPTouchPhase)phase
{
    NSMutableSet *touchesFound = [NSMutableSet set];
    for (SPTouch *touch in _touches)
    {
        if (touch.phase == phase &&
            ([target isEqual:touch.target] || 
             ([target isKindOfClass:[SPDisplayObjectContainer class]] &&
              [(SPDisplayObjectContainer *)target containsChild:touch.target])))
        {
            [touchesFound addObject: touch];
        }
    }    
    return touchesFound;    
}

#pragma mark Private

- (SPEvent *)clone
{
    return [SPTouchEvent eventWithType:self.type touches:self.touches];
}

#pragma mark Properties

- (double)timestamp
{
    return [[_touches anyObject] timestamp];
}

@end
