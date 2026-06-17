#import "iChatAIAppDelegate.h"
#import "ChatWindowController.h"
#import "PreferencesWindowController.h"
#import "KeychainHelper.h"

@interface iChatAIAppDelegate ()
- (void)launchChatWindow;
@end

@implementation iChatAIAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *apiKey = [KeychainHelper loadAPIKey];

    if (!apiKey || [apiKey length] == 0) {
        // First run – show setup sheet
        _setupController = [[SetupWindowController alloc] init];
        _setupController.delegate = self;
        [_setupController showWindow:self];
        [[_setupController window] makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
    } else {
        [self launchChatWindow];
    }
}

- (void)_closeXIBWindow { /* no longer needed */ }

- (void)launchChatWindow {
    if (!_chatController) {
        _chatController = [[ChatWindowController alloc] init];
    }
    [_chatController showWindow:self];
    [[_chatController window] makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

// SetupWindowControllerDelegate
- (void)setupDidCompleteWithAPIKey:(NSString *)apiKey {
    [self launchChatWindow];
}

- (IBAction)showPreferences:(id)sender {
    if (!_prefsController) {
        _prefsController = [[PreferencesWindowController alloc] init];
    }
    [_prefsController showWindow:self];
    [[_prefsController window] makeKeyAndOrderFront:self];
}

- (IBAction)clearChat:(id)sender {
    [_chatController clearChat];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

- (void)dealloc {
    [_chatController release];
    [_setupController release];
    [_prefsController release];
    [super dealloc];
}

@end
