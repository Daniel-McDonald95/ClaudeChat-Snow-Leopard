#import <Cocoa/Cocoa.h>

@interface PreferencesWindowController : NSWindowController {
    NSTextField       *_keyLabel;
    NSSecureTextField *_keyField;
    NSTextField       *_modelLabel;
    NSPopUpButton     *_modelPopup;
    NSButton          *_saveButton;
    NSButton          *_cancelButton;
}

@end
