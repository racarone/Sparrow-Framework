//
//  AsyncTextureScene.m
//  Demo
//
//  Created by Daniel Sperl on 12.02.13.
//
//

#import "AsyncTextureScene.h"

@implementation AsyncTextureScene
{
    SPButton *_fileButton;
    SPButton *_urlButton;
    SPImage  *_fileImage;
    SPImage  *_urlImage;
    SPTextField *_logText;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        SPTexture *buttonTexture = [SPTexture textureWithContentsOfFile:@"button_normal.png"];
        
        _fileButton = [SPButton buttonWithUpState:buttonTexture text:@"Load from File"];
        _fileButton.x = 20;
        _fileButton.y = 20;
        [_fileButton addEventListener:@selector(onFileButtonTriggered:) atObject:self
                              forType:SPEventTypeTriggered];
        [self addChild:_fileButton];
        
        _urlButton = [SPButton buttonWithUpState:buttonTexture text:@"Load from Web"];
        _urlButton.x = 300 - _urlButton.width;
        _urlButton.y = 20;
        [_urlButton addEventListener:@selector(onUrlButtonTriggered:) atObject:self
                              forType:SPEventTypeTriggered];
        [self addChild:_urlButton];

        _logText = [SPTextField textFieldWithWidth:280 height:50 text:@""
                                            fontName:@"Verdana" fontSize:12 color:0x0];
        _logText.x = 20;
        _logText.y = _fileButton.y + _fileButton.height + 5;
        [self addChild:_logText];
    }
    return self;
}

- (void)onFileButtonTriggered:(SPEvent *)event
{
    _fileImage.visible = NO;
    _logText.text = @"Loading texture ...";
    
    [SPTexture loadFromFile:@"async_local.png"
                 onComplete:^(SPTexture *texture, NSError *outError)
    {
        if (outError)
            _logText.text = [outError localizedDescription];
        else
        {
            _logText.text = @"File loaded successfully.";
            
            if (!_fileImage)
            {
                _fileImage = [[SPImage alloc] initWithTexture:texture];
                _fileImage.x = (int)(self.stage.width - texture.width) / 2;
                _fileImage.y = 110;
                [self addChild:_fileImage];
            }
            else
            {
                _fileImage.visible = YES;
                _fileImage.texture = texture;
            }
        }
    }];
}

- (void)onUrlButtonTriggered:(SPEvent *)event
{
    _urlImage.visible = NO;
    _logText.text = @"Loading texture ...";
    
    // If your texture name contains a suffix like "@2x", you can use
    // "[SPTexture loadTextureFromSuffixedURL:...]". In this case, we have
    // no control over the image name, so we assign the scale factor directly.
    
    float scale = Sparrow.contentScaleFactor;
    NSURL *url = scale == 1.0f ? [NSURL URLWithString:@"http://i.imgur.com/24mT16x.png"] :
                                 [NSURL URLWithString:@"http://i.imgur.com/kE2Bqnk.png"];
    
    [SPTexture loadFromURL:url generateMipmaps:NO scale:scale
                onComplete:^(SPTexture *texture, NSError *outError)
     {
         if (outError)
             _logText.text = [outError localizedDescription];
         else
         {
             _logText.text = @"File loaded successfully.";
             
             if (!_urlImage)
             {
                 _urlImage = [[SPImage alloc] initWithTexture:texture];
                 _urlImage.x = (int)(self.stage.width - texture.width) / 2;
                 _urlImage.y = 275;
                 [self addChild:_urlImage];
             }
             else
             {
                 _urlImage.visible = YES;
                 _urlImage.texture = texture;
             }
         }
     }];
}

@end
