#import "ChatWindowController.h"
#import "KeychainHelper.h"
#import "AnthropicClient.h"

@interface ChatWindowController ()
- (void)buildWindow;
- (void)sendMessage;
- (void)attachImage;
- (void)clearChat;
- (void)callJS:(NSString *)js;
- (void)setWaiting:(BOOL)waiting;
- (void)prefsChanged:(NSNotification *)note;
@end

@implementation ChatWindowController

- (id)init {
    if ((self = [super initWithWindowNibName:@"" owner:self])) {
        _history = [[NSMutableArray alloc] init];
    }
    return self;
}

// ---------------------------------------------------------------------------
// Window creation
// ---------------------------------------------------------------------------

- (NSWindow *)createChatWindow {
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask |
                       NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *win = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 460, 580)
                                                 styleMask:style
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO] autorelease];
    [win setTitle:@"iChatAI"];
    [win setMinSize:NSMakeSize(340, 380)];
    [win center];
    [win setReleasedWhenClosed:NO];
    [win setDelegate:self];
    return win;
}

- (void)loadWindow {
    [self setWindow:[self createChatWindow]];
    [self windowDidLoad];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self buildWindow];
    [self reloadAPIKeyAndModel];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(prefsChanged:)
                                                 name:@"iChatAIPrefsChanged"
                                               object:nil];
}

- (void)buildWindow {
    NSView *cv = [[self window] contentView];
    NSRect bounds = [cv bounds]; // 460 x 580

    // ---- Bottom bar (56px tall) ----
    NSView *bottomBar = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, bounds.size.width, 56)] autorelease];
    [bottomBar setAutoresizingMask:NSViewWidthSizable];

    // Subtle top border on the bottom bar
    NSBox *barSep = [[[NSBox alloc] initWithFrame:NSMakeRect(0, 55, bounds.size.width, 1)] autorelease];
    [barSep setBoxType:NSBoxSeparator];
    [barSep setAutoresizingMask:NSViewWidthSizable];
    [bottomBar addSubview:barSep];

    // Attach (paperclip) button
    _attachButton = [[NSButton alloc] initWithFrame:NSMakeRect(8, 14, 28, 28)];
    [_attachButton setBezelStyle:NSTexturedRoundedBezelStyle];
    [_attachButton setTitle:@"📎"];
    [_attachButton setFont:[NSFont systemFontOfSize:14]];
    [_attachButton setToolTip:@"Attach image"];
    [_attachButton setTarget:self];
    [_attachButton setAction:@selector(attachImage)];
    [bottomBar addSubview:_attachButton];

    // Input text field
    CGFloat sendW = 62;
    CGFloat attachRight = 8 + 28 + 6;
    CGFloat inputW = bounds.size.width - attachRight - sendW - 16;
    _inputField = [[NSTextField alloc] initWithFrame:NSMakeRect(attachRight, 16, inputW, 24)];
    [[_inputField cell] setPlaceholderString:@"Message iChatAI…"];
    [_inputField setAutoresizingMask:NSViewWidthSizable];
    [_inputField setFont:[NSFont systemFontOfSize:13]];
    [[_inputField cell] setWraps:NO];
    [[_inputField cell] setScrollable:YES];
    [bottomBar addSubview:_inputField];

    // Send button
    _sendButton = [[NSButton alloc] initWithFrame:NSMakeRect(bounds.size.width - sendW - 8, 14, sendW, 28)];
    [_sendButton setTitle:@"Send"];
    [_sendButton setBezelStyle:NSRoundedBezelStyle];
    [_sendButton setKeyEquivalent:@"\r"];
    [_sendButton setAutoresizingMask:NSViewMinXMargin];
    [_sendButton setTarget:self];
    [_sendButton setAction:@selector(sendMessage)];
    [bottomBar addSubview:_sendButton];

    // Spinner (replaces send button label while waiting)
    _spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(bounds.size.width - sendW - 8 + 18, 18, 20, 20)];
    [_spinner setStyle:NSProgressIndicatorSpinningStyle];
    [_spinner setHidden:YES];
    [_spinner setAutoresizingMask:NSViewMinXMargin];
    [bottomBar addSubview:_spinner];

    [cv addSubview:bottomBar];

    // ---- Title bar accent (32px, sits above the bottom bar) ----
    // We'll use it as the top status strip
    NSView *topStrip = [[[NSView alloc] initWithFrame:NSMakeRect(0, bounds.size.height - 32,
                                                                  bounds.size.width, 32)] autorelease];
    [topStrip setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];

    NSBox *topSep = [[[NSBox alloc] initWithFrame:NSMakeRect(0, 0, bounds.size.width, 1)] autorelease];
    [topSep setBoxType:NSBoxSeparator];
    [topSep setAutoresizingMask:NSViewWidthSizable];
    [topStrip addSubview:topSep];

    // Clear chat link-style button in top strip
    _clearButton = [[NSButton alloc] initWithFrame:NSMakeRect(bounds.size.width - 80, 6, 72, 20)];
    [_clearButton setTitle:@"Clear Chat"];
    [_clearButton setBezelStyle:NSRecessedBezelStyle];
    [_clearButton setFont:[NSFont systemFontOfSize:11]];
    [_clearButton setAutoresizingMask:NSViewMinXMargin];
    [_clearButton setTarget:self];
    [_clearButton setAction:@selector(clearChat)];
    [topStrip addSubview:_clearButton];

    [cv addSubview:topStrip];

    // ---- WebView (fills remaining space between strips) ----
    CGFloat webY = 56;
    CGFloat webH = bounds.size.height - 56 - 32;
    _webView = [[WebView alloc] initWithFrame:NSMakeRect(0, webY, bounds.size.width, webH)
                                    frameName:nil
                                    groupName:nil];
    [_webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_webView setDrawsBackground:NO];
    [cv addSubview:_webView];

    // Load the HTML template from the app bundle
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"chat" ofType:@"html"];
    if (htmlPath) {
        NSURL *url = [NSURL fileURLWithPath:htmlPath];
        [[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
    }

    [[self window] makeFirstResponder:_inputField];
}

// ---------------------------------------------------------------------------
// API key / model
// ---------------------------------------------------------------------------

- (void)reloadAPIKeyAndModel {
    NSString *key = [KeychainHelper loadAPIKey];
    if (!key) return;

    [_client release];
    _client = [[AnthropicClient alloc] initWithAPIKey:key];
    _client.delegate = self;

    NSString *model = [[NSUserDefaults standardUserDefaults] stringForKey:@"iChatAIModel"];
    if (model && [model length] > 0) {
        _client.model = model;
    }
}

- (void)prefsChanged:(NSNotification *)note {
    [self reloadAPIKeyAndModel];
}

// ---------------------------------------------------------------------------
// Sending
// ---------------------------------------------------------------------------

- (void)sendMessage {
    if (_waiting) return;

    NSString *text = [[_inputField stringValue]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    BOOL hasImage = (_pendingImageData != nil);
    if ([text length] == 0 && !hasImage) return;

    // Show the image in the chat if one is pending
    if (hasImage && _pendingImageDataURL) {
        [self callJS:[NSString stringWithFormat:@"addImageMessage('user','%@')", _pendingImageDataURL]];
    }

    // Show the text in the chat
    if ([text length] > 0) {
        NSString *escaped = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        [self callJS:[NSString stringWithFormat:@"addMessage('user','%@')", escaped]];
    }

    // Build the message for history
    AnthropicMessage *msg;
    if (hasImage) {
        msg = [AnthropicMessage userMessage:text
                                  imageData:_pendingImageData
                                   mimeType:_pendingImageMime];
    } else {
        msg = [AnthropicMessage userMessage:text];
    }
    [_history addObject:msg];

    // Clear input and pending image
    [_inputField setStringValue:@""];
    [_pendingImageData release];   _pendingImageData = nil;
    [_pendingImageMime release];   _pendingImageMime = nil;
    [_pendingImageDataURL release]; _pendingImageDataURL = nil;
    [_attachButton setTitle:@"📎"];

    [self setWaiting:YES];
    [self callJS:@"showTyping()"];

    [_client sendMessages:_history];
}

// ---------------------------------------------------------------------------
// Image attachment
// ---------------------------------------------------------------------------

- (void)attachImage {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setTitle:@"Choose Image"];

    NSArray *types = [NSArray arrayWithObjects:@"png", @"jpg", @"jpeg", @"gif", @"tiff", @"bmp", nil];
    [panel setAllowedFileTypes:types];

    NSInteger result = [panel runModal];
    if (result == NSFileHandlingPanelOKButton) {
        NSURL *url = [[panel URLs] objectAtIndex:0];
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (!data) return;

        NSString *ext = [[[url path] pathExtension] lowercaseString];
        NSString *mime = @"image/jpeg";
        if ([ext isEqualToString:@"png"])  mime = @"image/png";
        if ([ext isEqualToString:@"gif"])  mime = @"image/gif";
        if ([ext isEqualToString:@"tiff"] || [ext isEqualToString:@"tif"]) mime = @"image/tiff";

        [_pendingImageData release];
        _pendingImageData = [data retain];
        [_pendingImageMime release];
        _pendingImageMime = [mime retain];

        // Build data URL for preview in WebView (simple base64 for 10.6)
        static const char t[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        const uint8_t *bytes = (const uint8_t *)[data bytes];
        NSUInteger dlen = [data length];
        NSMutableString *b64 = [NSMutableString stringWithCapacity:((dlen + 2) / 3) * 4];
        for (NSUInteger bi = 0; bi < dlen; bi += 3) {
            uint8_t b0 = bytes[bi];
            uint8_t b1 = (bi+1 < dlen) ? bytes[bi+1] : 0;
            uint8_t b2 = (bi+2 < dlen) ? bytes[bi+2] : 0;
            [b64 appendFormat:@"%c%c%c%c",
                t[b0 >> 2], t[((b0 & 0x3) << 4)|(b1 >> 4)],
                (bi+1 < dlen) ? t[((b1 & 0xF) << 2)|(b2 >> 6)] : '=',
                (bi+2 < dlen) ? t[b2 & 0x3F] : '='];
        }
        [_pendingImageDataURL release];
        _pendingImageDataURL = [[NSString alloc] initWithFormat:@"data:%@;base64,%@", mime, b64];

        [_attachButton setTitle:@"🖼️"];
    }
}

// ---------------------------------------------------------------------------
// Clear chat
// ---------------------------------------------------------------------------

- (void)clearChat {
    [_history removeAllObjects];
    [self callJS:@"clearMessages()"];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

- (void)callJS:(NSString *)js {
    [[_webView windowScriptObject] evaluateWebScript:js];
}

- (void)setWaiting:(BOOL)waiting {
    _waiting = waiting;
    [_sendButton setEnabled:!waiting];
    [_inputField setEnabled:!waiting];
    [_attachButton setEnabled:!waiting];
    if (waiting) {
        [_spinner setHidden:NO];
        [_spinner startAnimation:nil];
    } else {
        [_spinner stopAnimation:nil];
        [_spinner setHidden:YES];
    }
}

// ---------------------------------------------------------------------------
// AnthropicClientDelegate
// ---------------------------------------------------------------------------

- (void)anthropicClientDidReceiveResponse:(NSString *)text {
    [self setWaiting:NO];

    // Add to history
    AnthropicMessage *reply = [AnthropicMessage assistantMessage:text];
    [_history addObject:reply];

    // Show in WebView
    NSString *escaped = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    [self callJS:[NSString stringWithFormat:@"addMessage('assistant','%@')", escaped]];

    [[self window] makeFirstResponder:_inputField];
}

- (void)anthropicClientDidFailWithError:(NSString *)errorMessage {
    [self setWaiting:NO];

    NSString *escaped = [errorMessage stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    [self callJS:[NSString stringWithFormat:@"addMessage('assistant','⚠️ Error: %@')", escaped]];

    [[self window] makeFirstResponder:_inputField];
}

// ---------------------------------------------------------------------------
// NSWindowDelegate
// ---------------------------------------------------------------------------

- (BOOL)windowShouldClose:(id)sender {
    [NSApp terminate:nil];
    return NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_webView release];
    [_inputField release];
    [_sendButton release];
    [_attachButton release];
    [_clearButton release];
    [_spinner release];
    [_client release];
    [_history release];
    [_pendingImageData release];
    [_pendingImageMime release];
    [_pendingImageDataURL release];
    [super dealloc];
}

@end
