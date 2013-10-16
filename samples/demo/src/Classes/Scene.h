//
//  Scene.h
//  Demo
//
//  Created by Sperl Daniel on 06.02.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SPSprite.h"

SP_EXTERN NSString *const EventTypeSceneClosing;

// A scene is just a sprite with a back button that dispatches a "closing" event
// when that button was hit. All scenes inherit from this class.

@interface Scene : SPSprite

@end
