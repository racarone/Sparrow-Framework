//
//  SPTextField.m
//  Sparrow
//
//  Created by Daniel Sperl on 29.06.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPBitmapFont.h"
#import "SPEnterFrameEvent.h"
#import "SPGLTexture.h"
#import "SPImage.h"
#import "SPQuad.h"
#import "SPQuadBatch.h"
#import "SPSprite.h"
#import "SPStage.h"
#import "SPSubTexture.h"
#import "SPTextField.h"
#import "SPTexture.h"
#import "SPUtils.h"

#import <CoreText/CoreText.h>

static NSMutableDictionary* gBitmapFonts = nil;

static CGSize GetSuggestedSizeAndFitForString(CFRange* cfRange, CFAttributedStringRef cfString, CGSize referenceSize)
{
    CTFramesetterRef ctFramesetter = CTFramesetterCreateWithAttributedString(cfString);
    CGSize cgFitSize = CTFramesetterSuggestFrameSizeWithConstraints(ctFramesetter, CFRangeMake(0, CFAttributedStringGetLength(cfString)),
                                                                    NULL, referenceSize, cfRange);
    CFRelease(ctFramesetter);
    return cgFitSize;
}

// --- class implementation ------------------------------------------------------------------------

@implementation SPTextField
{
    BOOL            _requiresRedraw;
    BOOL            _isRenderedText;
	
    SPQuadBatch*    _contents;
    SPRectangle*    _textBounds;
    SPQuad*         _hitArea;
    SPSprite*       _border;
}

@synthesize text        = _text;
@synthesize fontName    = _fontName;
@synthesize fontSize    = _fontSize;
@synthesize hAlign      = _hAlign;
@synthesize vAlign      = _vAlign;
@synthesize color       = _color;
@synthesize kerning     = _kerning;
@synthesize autoScale   = _autoScale;

- (instancetype)initWithWidth:(float)width height:(float)height text:(NSString*)text fontName:(NSString*)name 
          fontSize:(float)size color:(uint)color 
{
    if ((self = [super init]))
    {        
        _text = [text copy];
        _fontSize = size;
        _color = color;
        _hAlign = SPHAlignCenter;
        _vAlign = SPVAlignCenter;
        _autoScale = NO;
        _kerning = YES;
        _requiresRedraw = YES;
        self.fontName = name;
        
        _hitArea = [[SPQuad alloc] initWithWidth:width height:height];
        _hitArea.alpha = 0.0f;
        [self addChild:_hitArea];
        
        _contents = [[SPQuadBatch alloc] init];
        _contents.touchable = NO;
        [self addChild:_contents];
        
        [self addEventListener:@selector(onFlatten:) atObject:self forType:kSPEventTypeFlatten];
    }
    return self;
}

- (instancetype)initWithWidth:(float)width height:(float)height text:(NSString*)text
{
    return [self initWithWidth:width height:height text:text fontName:SP_DEFAULT_FONT_NAME
                     fontSize:SP_DEFAULT_FONT_SIZE color:SP_DEFAULT_FONT_COLOR];   
}

- (instancetype)initWithWidth:(float)width height:(float)height
{
    return [self initWithWidth:width height:height text:@""];
}

- (instancetype)initWithText:(NSString*)text
{
    return [self initWithWidth:128 height:128 text:text];
}

- (instancetype)init
{
    return [self initWithText:@""];
}

- (void)dealloc
{
    SP_RELEASE_AND_NIL(_text);
    SP_RELEASE_AND_NIL(_fontName);
    SP_RELEASE_AND_NIL(_contents);
    SP_RELEASE_AND_NIL(_textBounds);
    SP_RELEASE_AND_NIL(_hitArea);
    SP_RELEASE_AND_NIL(_border);

    [super dealloc];
}

- (void)onFlatten:(SPEvent*)event
{
    if (_requiresRedraw) [self redraw];
}

- (void)render:(SPRenderSupport*)support
{
    if (_requiresRedraw) [self redraw];    
    [super render:support];
}

- (SPRectangle*)textBounds
{
    if (_requiresRedraw) [self redraw];
    if (!_textBounds) _textBounds = [_contents boundsInSpace:_contents];
    return [[_textBounds copy] autorelease];
}

- (SPRectangle*)boundsInSpace:(SPDisplayObject*)targetSpace
{
    return [_hitArea boundsInSpace:targetSpace];
}

- (void)setWidth:(float)width
{
    // other than in SPDisplayObject, changing the size of the object should not change the scaling;
    // changing the size should just make the texture bigger/smaller, 
    // keeping the size of the text/font unchanged. (this applies to setHeight:, as well.)
    
    _hitArea.width = width;
    _requiresRedraw = YES;
    [self updateBorder];
}

- (void)setHeight:(float)height
{
    _hitArea.height = height;
    _requiresRedraw = YES;
    [self updateBorder];
}

- (void)setText:(NSString*)text
{
    if (![text isEqualToString:_text])
    {
        SP_ASSIGN_COPY(_text, text);
        _requiresRedraw = YES;
    }
}

- (void)setFontName:(NSString*)fontName
{
    if (![fontName isEqualToString:_fontName])
    {
        if ([fontName isEqualToString:SP_BITMAP_FONT_MINI] && ![gBitmapFonts objectForKey:fontName])
        {
            SPBitmapFont* miniFont = [[SPBitmapFont alloc] initWithMiniFont];
            [SPTextField registerBitmapFont:miniFont];
            [miniFont release];
        }

        SP_ASSIGN_COPY(_fontName, fontName);
        _requiresRedraw = YES;        
        _isRenderedText = !gBitmapFonts[_fontName];
    }
}

- (void)setFontSize:(float)fontSize
{
    if (fontSize != _fontSize)
    {
        _fontSize = fontSize;
        _requiresRedraw = YES;
    }
}
 
- (void)setHAlign:(SPHAlign)hAlign
{
    if (hAlign != _hAlign)
    {
        _hAlign = hAlign;
        _requiresRedraw = YES;
    }
}

- (void)setVAlign:(SPVAlign)vAlign
{
    if (vAlign != _vAlign)
    {
        _vAlign = vAlign;
        _requiresRedraw = YES;
    }
}

- (void)setColor:(uint)color
{
    if (color != _color)
    {
        _color = color;
        _requiresRedraw = YES;
        [self updateBorder];
    }
}

- (void)setKerning:(BOOL)kerning
{
	if (kerning != _kerning)
	{
		_kerning = kerning;
		_requiresRedraw = YES;
	}
}

- (void)setAutoScale:(BOOL)autoScale
{
    if (_autoScale != autoScale)
    {
        _autoScale = autoScale;
        _requiresRedraw = YES;
    }
}

+ (instancetype)textFieldWithWidth:(float)width height:(float)height text:(NSString*)text
                          fontName:(NSString*)name fontSize:(float)size color:(uint)color
{
    return [[[self alloc] initWithWidth:width height:height text:text
                               fontName:name fontSize:size color:color] autorelease];
}

+ (instancetype)textFieldWithWidth:(float)width height:(float)height text:(NSString*)text
{
    return [[[self alloc] initWithWidth:width height:height text:text] autorelease];
}

+ (instancetype)textFieldWithText:(NSString*)text
{
    return [[[self alloc] initWithText:text] autorelease];
}

+ (NSString*)registerBitmapFont:(SPBitmapFont*)font name:(NSString*)fontName
{
    if (!gBitmapFonts) gBitmapFonts = [[NSMutableDictionary alloc] init];
    if (!fontName) fontName = font.name;
    gBitmapFonts[fontName] = font;
    return fontName;
}

+ (NSString*)registerBitmapFont:(SPBitmapFont*)font
{
    return [self registerBitmapFont:font name:nil];
}

+ (NSString*)registerBitmapFontFromFile:(NSString*)path texture:(SPTexture*)texture name:(NSString*)fontName
{
    SPBitmapFont* font = [[[SPBitmapFont alloc] initWithContentsOfFile:path texture:texture] autorelease];
    return [self registerBitmapFont:font name:fontName];
}

+ (NSString*)registerBitmapFontFromFile:(NSString*)path texture:(SPTexture*)texture
{
    SPBitmapFont* font = [[[SPBitmapFont alloc] initWithContentsOfFile:path texture:texture] autorelease];
    return [self registerBitmapFont:font];
}

+ (NSString*)registerBitmapFontFromFile:(NSString*)path
{
    SPBitmapFont* font = [[[SPBitmapFont alloc] initWithContentsOfFile:path] autorelease];
    return [self registerBitmapFont:font];
}

+ (void)unregisterBitmapFont:(NSString*)name
{
    [gBitmapFonts removeObjectForKey:name];
}

+ (SPBitmapFont*)registeredBitmapFont:(NSString*)name
{
    return gBitmapFonts[name];
}

- (void)redraw
{
    if (_requiresRedraw)
    {
        [_contents reset];
        
        if (_isRenderedText) [self createRenderedContents];
        else                 [self createComposedContents];
        
        _requiresRedraw = NO;
    }
}

- (void)createRenderedContents
{
    float width    = _hitArea.width;
    float height   = _hitArea.height;
    float fontSize = _fontSize == SP_NATIVE_FONT_SIZE ? SP_DEFAULT_FONT_SIZE : _fontSize;

    // get cfstring
    CFAttributedStringRef cfAttributedText = CFAttributedStringCreate(NULL, (CFStringRef)_text, NULL);
    CFMutableAttributedStringRef cfText = CFAttributedStringCreateMutableCopy(NULL, 0, cfAttributedText);
    

    // get font
    CTFontRef ctFont = CTFontCreateWithName((CFStringRef)_fontName, fontSize, NULL);
    CFRange cfTextRange = CFRangeMake(0, CFAttributedStringGetLength(cfText));
    CFAttributedStringSetAttribute(cfText, cfTextRange, kCTFontAttributeName, ctFont);

    float color4f[4] = {
        SP_COLOR_PART_RED(_color)   / 255.0f,
        SP_COLOR_PART_GREEN(_color) / 255.0f,
        SP_COLOR_PART_BLUE(_color)  / 255.0f,
        1.0f
    };

    CGColorSpaceRef cgColorSpace = CGColorSpaceCreateDeviceRGB();
#ifdef SP_TARGET_IPHONE
    CGColorRef cgColor = CGColorCreate(cgColorSpace, color4f);
#else
    CGColorRef cgColor = CGColorCreateGenericRGB(color4f[0], color4f[1], color4f[2], color4f[3]);
#endif

    CFAttributedStringSetAttribute(cfText, cfTextRange, kCTForegroundColorAttributeName, cgColor);

    CTTextAlignment theAlignment;
    switch(_hAlign) {
        case SPHAlignLeft:
            theAlignment = kCTTextAlignmentLeft;
            break;

        case SPHAlignCenter:
            theAlignment = kCTTextAlignmentCenter;
            break;

        case SPHAlignRight:
            theAlignment = kCTTextAlignmentRight;
            break;
    }

    CTLineBreakMode lineBreakMode = kCTLineBreakByWordWrapping;

#define PARAGRAPH_SETTING_COUNT 2
    CTParagraphStyleSetting ctSettings[PARAGRAPH_SETTING_COUNT] = {
        {
            kCTParagraphStyleSpecifierAlignment,
            sizeof(CTTextAlignment),
            &theAlignment
        },
        {
            kCTParagraphStyleSpecifierLineBreakMode,
            sizeof(CTLineBreakMode),
            &lineBreakMode
        }
    };

    // attributed string paragraph settings
    CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(ctSettings, PARAGRAPH_SETTING_COUNT);
    CFAttributedStringSetAttribute(cfText, cfTextRange, kCTParagraphStyleAttributeName, paragraphStyle);

    CGSize  cgTextSize;
    CFRange cfFitRange;

    if(_autoScale)
    {
        CGSize maxSize = CGSizeMake(width, FLT_MAX);
        fontSize += 1.0f;

        do
        {
            fontSize -= 1.0f;
            CFNumberRef cfNumberSize = CFNumberCreate(NULL, kCFNumberCGFloatType, &fontSize);
            CFAttributedStringSetAttribute(cfText, cfTextRange, kCTFontSizeAttribute, cfNumberSize);
            cgTextSize = GetSuggestedSizeAndFitForString(&cfFitRange, cfText, maxSize);
            CFRelease(cfNumberSize);
        }
        while(cgTextSize.height > height);
    }
    else
    {
        cgTextSize = GetSuggestedSizeAndFitForString(&cfFitRange, cfText, CGSizeMake(width, height));
    }

    float xOffset = 0;
    if(_hAlign == SPHAlignCenter)      xOffset = (width - cgTextSize.width) / 2.0f;
    else if(_hAlign == SPHAlignRight)  xOffset =  width - cgTextSize.width;

    float yOffset = 0;
    if(_vAlign == SPVAlignCenter)      yOffset = (height - cgTextSize.height) / 2.0f;
    else if(_vAlign == SPVAlignBottom) yOffset =  height - cgTextSize.height;

    if (!_textBounds) _textBounds = [[SPRectangle alloc] init];
    [_textBounds setX:xOffset y:yOffset width:cgTextSize.width height:cgTextSize.height];

    // only textures with sidelengths that are powers of 2 support all OpenGL ES features
    float scale = Sparrow.contentScaleFactor;
    float legalWidth  = [SPUtils nextPowerOfTwo:width  * scale];
    float legalHeight = [SPUtils nextPowerOfTwo:height * scale];

    SPGLTexture* glTexture = nil;
    {
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;

        int bytesPerPixel = 4;
        void* imageData = calloc(legalWidth * legalHeight * bytesPerPixel, 1);

        CGContextRef context = CGBitmapContextCreate(imageData, legalWidth, legalHeight, 8,
                                                     bytesPerPixel * legalWidth, cgColorSpace,
                                                     bitmapInfo);

        // prepare our view for drawing
        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CGContextScaleCTM(context, scale, scale);

        // create frame
        CTFramesetterRef ctFramesetter = CTFramesetterCreateWithAttributedString(cfText);

        // path
        CGMutablePathRef cgPath = CGPathCreateMutable();
        CGRect cfTextRect = CGRectMake(0, (legalHeight/scale) - height - yOffset, width, height);
        CGPathAddRect(cgPath, NULL, cfTextRect);

        CTFrameRef ctFrame = CTFramesetterCreateFrame(ctFramesetter, CFRangeMake(0, CFAttributedStringGetLength(cfText)),
                                                      cgPath, NULL);
        
        // draw frame
        CTFrameDraw(ctFrame, context);

        // create texture
        glTexture = [[SPGLTexture alloc] initWithData:imageData
                                                width:legalWidth
                                               height:legalHeight
                                      generateMipmaps:NO
                                                scale:scale
                                   premultipliedAlpha:YES];

        // release
        CFRelease(ctFramesetter);
        CFRelease(cgPath);
        CFRelease(ctFrame);
        CGContextRelease(context);
        free(imageData);
    }

    CFRelease(paragraphStyle);
    CFRelease(cfAttributedText);
    CFRelease(ctFont);
    CFRelease(cgColor);
    CFRelease(cgColorSpace);
    CFRelease(cfText);

    SPImage* image = [[SPImage alloc] initWithTexture:glTexture];
    [glTexture release];

    [_contents addQuad:image];
    [image release];
}

- (void)createComposedContents
{
    SPBitmapFont* bitmapFont = gBitmapFonts[_fontName];
    if (!bitmapFont)
        [NSException raise:SP_EXC_INVALID_OPERATION 
                    format:@"bitmap font %@ not registered!", _fontName];
    
    [bitmapFont fillQuadBatch:_contents withWidth:_hitArea.width height:_hitArea.height
                         text:_text fontSize:_fontSize color:_color hAlign:_hAlign vAlign:_vAlign
                    autoScale:_autoScale kerning:_kerning];
    
    _textBounds = nil; // will be created on demand
}

- (BOOL)border
{
    return _border != nil;
}

- (void)setBorder:(BOOL)value
{
    if (value && !_border)
    {
        _border = [SPSprite sprite];
        
        for (int i=0; i<4; ++i)
            [_border addChild:[[[SPQuad alloc] initWithWidth:1.0f height:1.0f] autorelease]];
        
        [self addChild:_border];
        [self updateBorder];
    }
    else if (!value && _border)
    {
        [_border removeFromParent];
        _border = nil;
    }
}

- (void)updateBorder
{
    if (!_border) return;
    
    float width  = _hitArea.width;
    float height = _hitArea.height;
    
    SPQuad* topLine    = (SPQuad*)[_border childAtIndex:0];
    SPQuad* rightLine  = (SPQuad*)[_border childAtIndex:1];
    SPQuad* bottomLine = (SPQuad*)[_border childAtIndex:2];
    SPQuad* leftLine   = (SPQuad*)[_border childAtIndex:3];
    
    topLine.width = width; topLine.height = 1;
    bottomLine.width = width; bottomLine.height = 1;
    leftLine.width = 1; leftLine.height = height;
    rightLine.width = 1; rightLine.height = height;
    rightLine.x = width - 1;
    bottomLine.y = height - 1;
    topLine.color = rightLine.color = bottomLine.color = leftLine.color = _color;
    
    [_border flatten];
}

@end
