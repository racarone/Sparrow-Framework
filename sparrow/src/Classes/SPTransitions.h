//
//  SPTransitions.h
//  Sparrow
//
//  Created by Daniel Sperl on 11.05.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import "SPMacros.h"

SP_EXTERN NSString *const SPTransitionLinear;
SP_EXTERN NSString *const SPTransitionRandomize;

SP_EXTERN NSString *const SPTransitionEaseIn;
SP_EXTERN NSString *const SPTransitionEaseOut;
SP_EXTERN NSString *const SPTransitionEaseInOut;
SP_EXTERN NSString *const SPTransitionEaseOutIn;

SP_EXTERN NSString *const SPTransitionEaseInBack;
SP_EXTERN NSString *const SPTransitionEaseOutBack;
SP_EXTERN NSString *const SPTransitionEaseInOutBack;
SP_EXTERN NSString *const SPTransitionEaseOutInBack;

SP_EXTERN NSString *const SPTransitionEaseInElastic;
SP_EXTERN NSString *const SPTransitionEaseOutElastic;
SP_EXTERN NSString *const SPTransitionEaseInOutElastic;
SP_EXTERN NSString *const SPTransitionEaseOutInElastic;

SP_EXTERN NSString *const SPTransitionEaseInBounce;
SP_EXTERN NSString *const SPTransitionEaseOutBounce;
SP_EXTERN NSString *const SPTransitionEaseInOutBounce;
SP_EXTERN NSString *const SPTransitionEaseOutInBounce;

/** ------------------------------------------------------------------------------------------------
 
 The SPTransitions class contains static methods that define easing functions. Those functions
 will be used by SPTween to execute animations.
 
 Here is a visible representation of the available transformations:
 
 ![](http://gamua.com/img/blog/2010/sparrow-transitions.png)

 You can define your own transitions by extending this class. The name of the method you declare 
 acts as the key that is used to identify the transition when you create the tween.
 
------------------------------------------------------------------------------------------------- */
 
@interface SPTransitions : NSObject 

+ (float)linear:(float)ratio;
+ (float)randomize:(float)ratio;

+ (float)easeIn:(float)ratio;
+ (float)easeOut:(float)ratio;
+ (float)easeInOut:(float)ratio;
+ (float)easeOutIn:(float)ratio;

+ (float)easeInBack:(float)ratio;
+ (float)easeOutBack:(float)ratio;
+ (float)easeInOutBack:(float)ratio;
+ (float)easeOutInBack:(float)ratio;

+ (float)easeInElastic:(float)ratio;
+ (float)easeOutElastic:(float)ratio;
+ (float)easeInOutElastic:(float)ratio;
+ (float)easeOutInElastic:(float)ratio;

+ (float)easeInBounce:(float)ratio;
+ (float)easeOutBounce:(float)ratio;
+ (float)easeInOutBounce:(float)ratio;
+ (float)easeOutInBounce:(float)ratio;

@end
