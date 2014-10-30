//
//  MaskScene.m
//  Demo
//
//  Created by Robert Carone on 1/11/14.
//
//

#import "MaskScene.h"

@implementation MaskScene
{
    SPSprite *_contents;
    SPQuad *_clipQuad;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        _contents = [SPSprite sprite];
        [self addChild:_contents];

        float stageWidth  = [Sparrow stage].width;
        float stageHeight = [Sparrow stage].height;

        SPQuad *touchQuad = [SPQuad quadWithWidth:stageWidth height:stageHeight];
        touchQuad.alpha = 0; // only used to get touch events
        [self addChild:touchQuad atIndex:0];

        SPImage *image = [SPImage imageWithContentsOfFile:@"sparrow_front.png"];
        image.x = (stageWidth - image.width) / 2;
        image.y = 80;
        [_contents addChild:image];

        // just to prove it works, use a filter on the image.
        SPColorMatrixFilter *cm = [SPColorMatrixFilter colorMatrixFilter];
        [cm adjustHue:-0.5];
        image.filter = cm;

        NSString *scissorString = @"Move a finger over the screen to move the clipping rectangle.";

        SPTextField *scissorText = [SPTextField textFieldWithWidth:256 height:128 text:scissorString];
        scissorText.x = (stageWidth - scissorText.width) / 2;
        scissorText.y = 240;
        [_contents addChild:scissorText];

        NSString *maskString = @"Currently, Sparrow supports only stage-aligned clipping; more "
                               @"complex masks will be supported in future versions.";

        SPTextField *maskText = [SPTextField textFieldWithWidth:256 height:128 text:maskString];
        maskText.x = scissorText.x;
        maskText.y = 290;
        [_contents addChild:maskText];

        SPRectangle *scissorRect = [SPRectangle rectangleWithX:0 y:0 width:150 height:150];
        scissorRect.x = (stageWidth - scissorRect.width) / 2;
        scissorRect.y = (stageHeight - scissorRect.height) / 2 + 5;
        [_contents setClipRect:scissorRect];

        _clipQuad = [SPQuad quadWithWidth:scissorRect.width height:scissorRect.height color:SPColorRed];
        _clipQuad.x = scissorRect.x;
        _clipQuad.y = scissorRect.y;
        _clipQuad.alpha = 0.1f;
        _clipQuad.touchable = NO;
        [self addChild:_clipQuad];

        [self addEventListener:@selector(onTouch:) atObject:self forType:SPEventTypeTouch];
    }
    return self;
}

- (void)onTouch:(SPTouchEvent *)event
{
    SPTouch *touch = [[event touches] anyObject];

    if(touch && (touch.phase == SPTouchPhaseBegan || touch.phase == SPTouchPhaseMoved))
    {
        SPPoint* localPos = [touch locationInSpace:self];
        SPRectangle* clipRect = _contents.clipRect;

        clipRect.x = localPos.x - clipRect.width/2;
        clipRect.y = localPos.y - clipRect.height/2;

        _clipQuad.x = clipRect.x;
        _clipQuad.y = clipRect.y;
    }
}

@end
