//
//  FilterScene.m
//  Demo
//
//  Created by Robert Carone on 1/11/14.
//
//

#import "FilterScene.h"

@implementation FilterScene
{
    SPButton *_button;
    SPTextField *_infoText;
    SPImage *_image;
    NSMutableArray *_filterInfos;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        SPTexture *buttonTexture = [SPTexture textureWithContentsOfFile:@"button_normal.png"];

        _button = [SPButton buttonWithUpState:buttonTexture text:@"Switch Filter"];
        [_button addEventListener:@selector(onButtonPressed:) atObject:self forType:SPEventTypeTriggered];
        _button.x = CENTER_X - (int)_button.width / 2;
        _button.y = 15;
        [self addChild:_button];

        _image = [SPImage imageWithContentsOfFile:@"sparrow_rocket.png"];
        _image.x = CENTER_X - (int)_image.width / 2;
        _image.y = 170;
        [self addChild:_image];

        _infoText = [SPTextField textFieldWithWidth:300 height:32 text:@"" fontName:@"Verdana" fontSize:19 color:0x0];
        _infoText.x = 10;
        _infoText.y = 330;
        [self addChild:_infoText];

        [self initFilters];
        [self onButtonPressed:nil];
    }
    return self;
}

- (void)onButtonPressed:(SPTouchEvent*)event
{
    NSString *text = _filterInfos[0];
    SPFragmentFilter *filter = _filterInfos[1];

    [_filterInfos removeObjectAtIndex:0];
    [_filterInfos removeObjectAtIndex:0];
    [_filterInfos addObject:text];
    [_filterInfos addObject:filter];

    _infoText.text = text;
    _image.filter = filter;
}

- (void)initFilters
{
    _filterInfos = [@[ @"Identity",    [SPColorMatrixFilter colorMatrixFilter],
                       @"Blur",        [SPBlurFilter blurFilter],
                       @"Drop Shadow", [SPBlurFilter dropShadow]] mutableCopy];

    SPBlurFilter *glowFilter = [SPBlurFilter glowWithColor:SPColorYellow alpha:1.0f blur:3.0f];
    [_filterInfos addObjectsFromArray:@[@"Glow", glowFilter]];

    SPTexture *noiseTexture = [SPTexture textureWithContentsOfFile:@"noise.jpg"];
    SPDisplacementMapFilter *dispMapFilter = [SPDisplacementMapFilter
                                              displacementMapFilterWithMapTexture:noiseTexture];
    dispMapFilter.componentX = SPColorChannelRed;
    dispMapFilter.componentY = SPColorChannelGreen;
    dispMapFilter.scaleX = dispMapFilter.scaleY = 25;
    [_filterInfos addObjectsFromArray:@[@"Displacement Map", dispMapFilter]];

    SPColorMatrixFilter *invertFilter = [SPColorMatrixFilter colorMatrixFilter];
    [invertFilter invert];
    [_filterInfos addObjectsFromArray:@[@"Invert", invertFilter]];

    SPColorMatrixFilter *grayscaleFilter = [SPColorMatrixFilter colorMatrixFilter];
    [grayscaleFilter adjustSaturation:-1];
    [_filterInfos addObjectsFromArray:@[@"Grayscale", grayscaleFilter]];

    SPColorMatrixFilter *saturationFilter = [SPColorMatrixFilter colorMatrixFilter];
    [grayscaleFilter adjustSaturation:1];
    [_filterInfos addObjectsFromArray:@[@"Saturation", saturationFilter]];

    SPColorMatrixFilter *contrastFilter = [SPColorMatrixFilter colorMatrixFilter];
    [contrastFilter adjustContrast:0.75];
    [_filterInfos addObjectsFromArray:@[@"Contrast", contrastFilter]];

    SPColorMatrixFilter *brightnessFilter = [SPColorMatrixFilter colorMatrixFilter];
    [brightnessFilter adjustBrightness:-0.25];
    [_filterInfos addObjectsFromArray:@[@"Brightness", brightnessFilter]];

    SPColorMatrixFilter *hueFilter = [SPColorMatrixFilter colorMatrixFilter];
    [hueFilter adjustHue:1];
    [_filterInfos addObjectsFromArray:@[@"Hue", hueFilter]];

    SPGroupFilter *filterStack = [SPGroupFilter groupFilterWithFilters:@[hueFilter, glowFilter]];
    filterStack.resolution = 0.5;
    [_filterInfos addObjectsFromArray:@[@"Hue and Glow", filterStack]];

}

@end
