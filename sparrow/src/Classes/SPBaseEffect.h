//
//  SPBaseEffect.h
//  Sparrow
//
//  Created by Daniel Sperl on 12.03.13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPEffect.h>

/** The standard effect used by SPQuadBatch. You shouldn't have to use this class directly. */

@interface SPBaseEffect : SPEffect

/// Indicates if the colors of the vertices should tint the texture colors. (Default: `YES`)
@property (nonatomic, assign) BOOL useTinting;

@end
