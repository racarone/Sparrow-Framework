//
//  SPFilterStack.h
//  Sparrow
//
//  Created by Robert Carone on 11/6/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPFragmentFilter.h>

/** ------------------------------------------------------------------------------------------------

 The SPGroupFilter class can render multiple filters at once. Initialize a group filter with an
 array of filters or modify the group using the 'filter' property. Filters are rendered in order.
 
 For example, if you wanted an object to be hue adjusted and glowing:

    SPColorMatrixFilter *myHueFilter = [SPColorMatrixFilter colorMatrixFilter];
    [myHueFilter adjustHue:1];

    NSArray *myFilters = @[myHueFilter, [SPBlurFilter glow]];
    myObject.filter = [SPGroupFilter groupFilterWithFilters:myFilters];

------------------------------------------------------------------------------------------------- */

@interface SPGroupFilter : SPFragmentFilter

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a group filter with the specified array of filters.
- (instancetype)initWithFilters:(NSArray *)filters;

/// Factory method.
+ (instancetype)groupFilterWithFilters:(NSArray *)filters;

/// ----------------
/// @name Properties
/// ----------------

/// The array of filters this group will render.
@property (nonatomic, copy) NSArray *filters;

@end
