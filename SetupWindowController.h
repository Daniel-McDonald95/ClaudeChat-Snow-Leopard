#import <Cocoa/Cocoa.h>

@protocol SetupWindowControllerDelegate <NSObject>
- (void)setupDidCompleteWithAPIKey:(NSString *)apiKey;
@end

@interface SetupWindowController : NSWindowController {
    id<SetupWindowControllerDelegate> _delegate;

    NSTextField       *_titleLabel;
    NSTextField       *_subtitleLabel;
    NSTextField       *_keyLabel;
    NSSecureTextField *_keyField;
    NSTextField       *_hintLabel;
    NSButton          *_startButton;
}

@property (nonatomic, assign) id<SetupWindowControllerDelegate> delegate;

@end
