#import "SetupWindowController.h"
#import "KeychainHelper.h"

@interface SetupWindowController ()
- (void)buildWindow;
- (void)startButtonClicked:(id)sender;
@end

@implementation SetupWindowController
@synthesize delegate = _delegate;

- (id)init {
    // We create the window programmatically – pass nil for nibName
    if ((self = [super initWithWindowNibName:@"" owner:self])) {
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self buildWindow];
}

- (NSWindow *)createWindow {
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask;
    NSWindow *win = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 360, 280)
                                                 styleMask:style
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO] autorelease];
    [win setTitle:@"Welcome to iChatAI"];
    [win center];
    [win setReleasedWhenClosed:NO];
    return win;
}

// Override so we create the window ourselves (no nib)
- (void)loadWindow {
    [self setWindow:[self createWindow]];
    [self windowDidLoad];
}

- (void)buildWindow {
    NSView *contentView = [[self window] contentView];
    NSRect bounds = [contentView bounds]; // 360 x 280

    // Background gradient view (drawn via NSGradient in a custom view would be ideal,
    // but we use a plain NSView and fill via a cell to keep it simple)
    NSTextField *bgFill = [[[NSTextField alloc] initWithFrame:bounds] autorelease];
    [bgFill setBezeled:NO];
    [bgFill setEditable:NO];
    [bgFill setSelectable:NO];
    [bgFill setDrawsBackground:YES];
    [bgFill setBackgroundColor:[NSColor colorWithCalibratedRed:0.94 green:0.94 blue:0.96 alpha:1.0]];
    [contentView addSubview:bgFill positioned:NSWindowBelow relativeTo:nil];

    // App title
    _titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 210, 320, 40)];
    [_titleLabel setStringValue:@"iChatAI"];
    [_titleLabel setBezeled:NO];
    [_titleLabel setEditable:NO];
    [_titleLabel setSelectable:NO];
    [_titleLabel setDrawsBackground:NO];
    [_titleLabel setFont:[NSFont boldSystemFontOfSize:26]];
    [_titleLabel setTextColor:[NSColor colorWithCalibratedRed:0.17 green:0.17 blue:0.17 alpha:1.0]];
    [_titleLabel setAlignment:NSCenterTextAlignment];
    [contentView addSubview:_titleLabel];

    // Subtitle
    _subtitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 182, 320, 28)];
    [_subtitleLabel setStringValue:@"AI chat powered by Anthropic"];
    [_subtitleLabel setBezeled:NO];
    [_subtitleLabel setEditable:NO];
    [_subtitleLabel setSelectable:NO];
    [_subtitleLabel setDrawsBackground:NO];
    [_subtitleLabel setFont:[NSFont systemFontOfSize:13]];
    [_subtitleLabel setTextColor:[NSColor grayColor]];
    [_subtitleLabel setAlignment:NSCenterTextAlignment];
    [contentView addSubview:_subtitleLabel];

    // Separator line
    NSBox *sep = [[[NSBox alloc] initWithFrame:NSMakeRect(20, 175, 320, 1)] autorelease];
    [sep setBoxType:NSBoxSeparator];
    [contentView addSubview:sep];

    // API Key label
    _keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 148, 320, 18)];
    [_keyLabel setStringValue:@"Enter your Anthropic API Key:"];
    [_keyLabel setBezeled:NO];
    [_keyLabel setEditable:NO];
    [_keyLabel setSelectable:NO];
    [_keyLabel setDrawsBackground:NO];
    [_keyLabel setFont:[NSFont systemFontOfSize:12]];
    [_keyLabel setTextColor:[NSColor darkGrayColor]];
    [contentView addSubview:_keyLabel];

    // Secure text field
    _keyField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(20, 118, 320, 22)];
    [[_keyField cell] setPlaceholderString:@"sk-ant-…"];
    [_keyField setFont:[NSFont fontWithName:@"Courier New" size:12]];
    [[self window] setInitialFirstResponder:_keyField];
    [contentView addSubview:_keyField];

    // Hint label
    _hintLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 94, 320, 18)];
    [_hintLabel setStringValue:@"Your key is stored securely in the macOS Keychain."];
    [_hintLabel setBezeled:NO];
    [_hintLabel setEditable:NO];
    [_hintLabel setSelectable:NO];
    [_hintLabel setDrawsBackground:NO];
    [_hintLabel setFont:[NSFont systemFontOfSize:10]];
    [_hintLabel setTextColor:[NSColor grayColor]];
    [_hintLabel setAlignment:NSCenterTextAlignment];
    [contentView addSubview:_hintLabel];

    // Start button
    _startButton = [[NSButton alloc] initWithFrame:NSMakeRect(110, 20, 140, 32)];
    [_startButton setTitle:@"Get Started"];
    [_startButton setBezelStyle:NSRoundedBezelStyle];
    [_startButton setKeyEquivalent:@"\r"];
    [_startButton setTarget:self];
    [_startButton setAction:@selector(startButtonClicked:)];
    [contentView addSubview:_startButton];
}

- (void)startButtonClicked:(id)sender {
    NSString *key = [[_keyField stringValue] stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([key length] < 10) {
        NSRunAlertPanel(@"API Key Required",
                        @"Please enter a valid Anthropic API key to continue.",
                        @"OK", nil, nil);
        return;
    }

    if (![KeychainHelper saveAPIKey:key]) {
        NSRunAlertPanel(@"Keychain Error",
                        @"Could not save the API key to the Keychain. Please try again.",
                        @"OK", nil, nil);
        return;
    }

    [[self window] orderOut:self];
    [_delegate setupDidCompleteWithAPIKey:key];
}

- (void)dealloc {
    [_titleLabel release];
    [_subtitleLabel release];
    [_keyLabel release];
    [_keyField release];
    [_hintLabel release];
    [_startButton release];
    [super dealloc];
}

@end
