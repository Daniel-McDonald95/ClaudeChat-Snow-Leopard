#import <Cocoa/Cocoa.h>
#import "SetupWindowController.h"

@class ChatWindowController;
@class PreferencesWindowController;

@interface iChatAIAppDelegate : NSObject
    <NSApplicationDelegate, SetupWindowControllerDelegate> {

    ChatWindowController       *_chatController;
    SetupWindowController      *_setupController;
    PreferencesWindowController *_prefsController;
}

- (IBAction)showPreferences:(id)sender;
- (IBAction)clearChat:(id)sender;

@end
