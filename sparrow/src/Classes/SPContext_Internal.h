//
//  SPContext_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 1/11/14.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPContext.h>

@interface SPContext (Internal)

- (uint)createFramebufferForTexture:(SPTexture *)texture;
- (void)destroyFramebufferForTexture:(SPTexture *)texture;

@end
