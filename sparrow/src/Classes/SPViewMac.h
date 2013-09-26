//
//  SPGLViewMac.h
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//

#import <Cocoa/Cocoa.h>

@protocol SPViewMacDelegate;

@interface SPViewMac : NSOpenGLView

- (void)display;

@property (nonatomic, strong) SPContext* openGLContext;
@property (nonatomic, assign) id<SPViewMacDelegate> delegate;

@end

@protocol SPViewMacDelegate <NSObject>

- (void)renderInRect:(CGRect)rect;
- (void)reshapeWithRect:(CGRect)rect;

@end
