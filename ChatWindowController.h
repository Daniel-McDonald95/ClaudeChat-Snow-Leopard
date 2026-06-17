#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "AnthropicClient.h"

@interface ChatWindowController : NSWindowController
    <AnthropicClientDelegate, NSWindowDelegate> {

    // UI elements
    WebView        *_webView;
    NSScrollView   *_scrollView;
    NSTextField    *_inputField;
    NSButton       *_sendButton;
    NSButton       *_attachButton;
    NSButton       *_clearButton;
    NSProgressIndicator *_spinner;

    // State
    AnthropicClient *_client;
    NSMutableArray  *_history;   // array of AnthropicMessage
    BOOL             _waiting;

    // Pending image (set when user picks a file before sending)
    NSData   *_pendingImageData;
    NSString *_pendingImageMime;
    NSString *_pendingImageDataURL; // for the WebView preview
}

- (void)reloadAPIKeyAndModel;
- (void)clearChat;

@end
