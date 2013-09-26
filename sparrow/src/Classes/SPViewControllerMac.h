//
//  SPViewControllerMac.h
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//

#import "SPViewController.h"
#import "SPViewMac.h"

@interface SPViewControllerMac : SPViewController <SPViewMacDelegate>

/// -------------
/// @name Startup
/// -------------

/// Sets up Sparrow by instantiating the given class, which has to be a display object.
/// High resolutions are enabled, iPad content will keep its size (no doubling).
- (void)startWithRoot:(Class)rootClass;

/// Sets up Sparrow by instantiating the given class, which has to be a display object.
/// iPad content will keep its size (no doubling).
- (void)startWithRoot:(Class)rootClass supportHighResolutions:(BOOL)hd;

/// ----------------
/// @name Properties
/// ----------------

/// Used to pause and resume the controller.
@property (nonatomic, getter=isPaused) BOOL paused;

/// The total number of frames displayed since drawing began.
@property (nonatomic, readonly) NSInteger framesDisplayed;

/// Time interval since properties.
@property (nonatomic, readonly) NSTimeInterval timeSinceFirstResume;
@property (nonatomic, readonly) NSTimeInterval timeSinceLastResume;
@property (nonatomic, readonly) NSTimeInterval timeSinceLastUpdate;
@property (nonatomic, readonly) NSTimeInterval timeSinceLastDraw;

@property (nonatomic) BOOL pauseOnWillResignActive;
@property (nonatomic) BOOL resumeOnDidBecomeActive;

@end
