//
//  SPViewController_Internal.h
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//

#import "SPViewController.h"

@interface SPViewController ()

- (void)initializeContext;
- (void)readjustStageSize;
- (void)renderInRect:(CGRect)rect;
- (void)advanceTime:(double)passedTime;

@property (nonatomic, assign) Class             rootClass;
@property (nonatomic, strong) SPContext*        context;
@property (nonatomic, strong) SPRenderSupport*  support;
@property (nonatomic, strong) SPTouchProcessor* touchProcessor;
@property (nonatomic, assign) BOOL              supportHighResolutions;
@property (nonatomic, assign) float             contentScaleFactor;
@property (nonatomic, strong) GLKTextureLoader* textureLoader;

@end
