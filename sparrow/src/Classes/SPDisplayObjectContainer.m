//
//  SPDisplayObjectContainer.m
//  Sparrow
//
//  Created by Daniel Sperl on 15.03.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPDisplayObjectContainer_Internal.h>
#import <Sparrow/SPDisplayObject_Internal.h>
#import <Sparrow/SPEnterFrameEvent.h>
#import <Sparrow/SPEvent_Internal.h>
#import <Sparrow/SPFragmentFilter.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPRenderSupport.h>

// --- C functions ---------------------------------------------------------------------------------

static void getDescendantEventListeners(SPDisplayObject *object, NSString *eventType,
                                        NSMutableArray *listeners)
{
    // some events (ENTER_FRAME, ADDED_TO_STAGE, etc.) are dispatched very often and traverse
    // the entire display tree -- thus, it pays off handling them in their own c function.

    if ([object hasEventListenerForType:eventType])
        [listeners addObject:object];

    if ([object isKindOfClass:[SPDisplayObjectContainer class]])
        for (SPDisplayObject *child in (SPDisplayObjectContainer *)object)
            getDescendantEventListeners(child, eventType, listeners);
}

// --- class implementation ------------------------------------------------------------------------

@implementation SPDisplayObjectContainer
{
    NSMutableArray *_children;
    BOOL _touchGroup;
}

#pragma mark Initialization

- (instancetype)init
{    
  #if DEBUG
    if ([[self class] isEqual:[SPDisplayObjectContainer class]]) 
    { 
        [NSException raise:SPExceptionAbstractClass
                    format:@"Attempting to instantiate SPDisplayObjectContainer directly."];
        return nil; 
    }    
  #endif
    
    if ((self = [super init])) 
    {
        _children = [[NSMutableArray alloc] init];
    }    
    return self;
}

- (void)dealloc
{
    // 'self' is becoming invalid; thus, we have to remove any references to it.
    [_children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
    [_children release];
    [super dealloc];
}

#pragma mark Methods

- (void)addChild:(SPDisplayObject *)child
{
    [self addChild:child atIndex:(int)[_children count]];
}

- (void)addChild:(SPDisplayObject *)child atIndex:(int)index
{
    if (index >= 0 && index <= [_children count])
    {
        [child retain];
        [child removeFromParent];
        [_children insertObject:child atIndex:MIN(_children.count, index)];
        child.parent = self;

        [child dispatchEventWithType:SPEventTypeAdded];

        if (self.stage)
            [child broadcastEventWithType:SPEventTypeAddedToStage];

        [child release];
    }
    else [NSException raise:SPExceptionIndexOutOfBounds format:@"Invalid child index"]; 
}

- (BOOL)containsChild:(SPDisplayObject *)child
{
    while (child)
    {
        if (child == self) return YES;
        else child = child.parent;
    }
    
    return NO;
}

- (SPDisplayObject *)childAtIndex:(int)index
{
    return _children[index];
}

- (SPDisplayObject *)childByName:(NSString *)name
{
    for (SPDisplayObject *currentChild in _children)
        if ([currentChild.name isEqualToString:name]) return currentChild;
    
    return nil;
}

- (int)childIndex:(SPDisplayObject *)child
{
    NSUInteger index = [_children indexOfObject:child];
    if (index == NSNotFound) return SPNotFound;
    else                     return (int)index;
}

- (void)setIndex:(int)index ofChild:(SPDisplayObject *)child
{
    NSUInteger oldIndex = [_children indexOfObject:child];
    if (oldIndex == NSNotFound) 
        [NSException raise:SPExceptionInvalidOperation format:@"Not a child of this container"];
    else
    {
        [child retain];
        [_children removeObjectAtIndex:oldIndex];
        [_children insertObject:child atIndex:index];
        [child release];
    }
}

- (void)removeChild:(SPDisplayObject *)child
{
    int childIndex = [self childIndex:child];
    if (childIndex != SPNotFound)
        [self removeChildAtIndex:childIndex];
}

- (void)removeChildAtIndex:(int)index
{
    if (index >= 0 && index < [_children count])
    {
        SPDisplayObject *child = _children[index];
        [child dispatchEventWithType:SPEventTypeRemoved];

        if (self.stage)
            [child broadcastEventWithType:SPEventTypeRemovedFromStage];
        
        child.parent = nil; 
        NSUInteger newIndex = (int)[_children indexOfObject:child]; // index might have changed in event handler
        if (newIndex != NSNotFound) [_children removeObjectAtIndex:newIndex];
    }
    else [NSException raise:SPExceptionIndexOutOfBounds format:@"Invalid child index"];        
}

- (void)swapChild:(SPDisplayObject *)child1 withChild:(SPDisplayObject *)child2
{
    int index1 = [self childIndex:child1];
    int index2 = [self childIndex:child2];
    [self swapChildAtIndex:index1 withChildAtIndex:index2];
}

- (void)swapChildAtIndex:(int)index1 withChildAtIndex:(int)index2
{    
    int numChildren = (int)[_children count];
    if (index1 < 0 || index1 >= numChildren || index2 < 0 || index2 >= numChildren)
        [NSException raise:SPExceptionInvalidOperation format:@"invalid child indices"];
    [_children exchangeObjectAtIndex:index1 withObjectAtIndex:index2];
}

- (void)sortChildren:(NSComparator)comparator
{
    if ([_children respondsToSelector:@selector(sortWithOptions:usingComparator:)])
        [_children sortWithOptions:NSSortStable usingComparator:comparator];
    else
        [NSException raise:SPExceptionInvalidOperation 
                    format:@"sortChildren is only available in iOS 4 and above"];
}

- (void)removeAllChildren
{
    for (int i=(int)_children.count-1; i>=0; --i)
        [self removeChildAtIndex:i];
}

- (SPDisplayObject *)objectAtIndexedSubscript:(int)index
{
    return _children[index];
}

- (void)setObject:(SPDisplayObject *)child atIndexedSubscript:(int)index
{
    if (index != _children.count)
        [self removeChildAtIndex:index];

    [self addChild:child atIndex:index];
}

- (int)numChildren
{
    return (int)[_children count];
}

- (NSArray *)children
{
    return [_children copy];
}

- (void)setChildren:(NSArray *)children
{
    [self removeAllChildren];

    for (SPDisplayObject *child in children)
        [self addChild:child];
}

#pragma mark SPDisplayObject

- (void)render:(SPRenderSupport *)support
{
    for (SPDisplayObject *child in _children)
    {
        if (child.hasVisibleArea)
        {
            [support pushStateWithMatrix:child.transformationMatrix
                                   alpha:child.alpha
                               blendMode:child.blendMode];

            if (child.filter) [child.filter renderObject:child support:support];
            else              [child render:support];

            [support popState];
        }
    }
}

- (SPRectangle *)boundsInSpace:(SPDisplayObject *)targetSpace
{
    int numChildren = (int)[_children count];

    if (numChildren == 0)
    {
        SPMatrix *transformationMatrix = [self transformationMatrixToSpace:targetSpace];
        SPPoint *transformedPoint = [transformationMatrix transformPointWithX:self.x y:self.y];
        return [SPRectangle rectangleWithX:transformedPoint.x y:transformedPoint.y
                                     width:0.0f height:0.0f];
    }
    else if (numChildren == 1)
    {
        return [_children[0] boundsInSpace:targetSpace];
    }
    else
    {
        float minX = FLT_MAX, maxX = -FLT_MAX, minY = FLT_MAX, maxY = -FLT_MAX;
        for (SPDisplayObject *child in _children)
        {
            SPRectangle *childBounds = [child boundsInSpace:targetSpace];
            minX = MIN(minX, childBounds.x);
            maxX = MAX(maxX, childBounds.x + childBounds.width);
            minY = MIN(minY, childBounds.y);
            maxY = MAX(maxY, childBounds.y + childBounds.height);
        }
        return [SPRectangle rectangleWithX:minX y:minY width:maxX-minX height:maxY-minY];
    }
}

- (SPDisplayObject *)hitTestPoint:(SPPoint *)localPoint
{
    if (!self.visible || !self.touchable)
        return nil;

    for (int i=(int)[_children count]-1; i>=0; --i) // front to back!
    {
        SPDisplayObject *child = _children[i];
        SPMatrix *transformationMatrix = [self transformationMatrixToSpace:child];
        SPPoint  *transformedPoint = [transformationMatrix transformPoint:localPoint];
        SPDisplayObject *target = [child hitTestPoint:transformedPoint];

        if (target)
            return _touchGroup ? self : target;
    }

    return nil;
}

- (void)broadcastEvent:(SPEvent *)event
{
    if (event.bubbles)
        [NSException raise:SPExceptionInvalidOperation
                    format:@"Broadcast of bubbling events is prohibited"];

    // the event listeners might modify the display tree, which could make the loop crash.
    // thus, we collect them in a list and iterate over that list instead.
    NSMutableArray *listeners = [[NSMutableArray alloc] init];
    [self appendDescendantEventListenersOfObject:self withEventType:event.type toArray:listeners];
    [event setTarget:self];
    [listeners makeObjectsPerformSelector:@selector(dispatchEvent:) withObject:event];
    [listeners release];
}

- (void)broadcastEventWithType:(NSString *)type
{
    SPEvent *event = [[SPEvent alloc] initWithType:type bubbles:NO];
    [self broadcastEvent:event];
    [event release];
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained *)stackbuf
                                    count:(NSUInteger)len
{
    return [_children countByEnumeratingWithState:state objects:stackbuf count:len];
}

@end

// -------------------------------------------------------------------------------------------------

@implementation SPDisplayObjectContainer (Internal)

- (void)appendDescendantEventListenersOfObject:(SPDisplayObject *)object withEventType:(NSString *)type
                                       toArray:(NSMutableArray *)listeners
{
    getDescendantEventListeners(object, type, listeners);
}

@end
