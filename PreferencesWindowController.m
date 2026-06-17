#import "PreferencesWindowController.h"
#import "KeychainHelper.h"

@interface PreferencesWindowController ()
- (void)buildWindow;
- (void)saveClicked:(id)sender;
- (void)cancelClicked:(id)sender;
@end

@implementation PreferencesWindowController

- (id)init {
    if ((self = [super initWithWindowNibName:@"" owner:self])) {}
    return self;
}

- (NSWindow *)createWindow {
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask;
    NSWindow *win = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 360, 220)
                                                 styleMask:style
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO] autorelease];
    [win setTitle:@"iChatAI Preferences"];
    [win center];
    [win setReleasedWhenClosed:NO];
    return win;
}

- (void)loadWindow {
    [self setWindow:[self createWindow]];
    [self windowDidLoad];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self buildWindow];
}

- (void)buildWindow {
    NSView *cv = [[self window] contentView];

    // API Key label
    _keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 174, 320, 18)];
    [_keyLabel setStringValue:@"Anthropic API Key:"];
    [_keyLabel setBezeled:NO]; [_keyLabel setEditable:NO];
    [_keyLabel setSelectable:NO]; [_keyLabel setDrawsBackground:NO];
    [_keyLabel setFont:[NSFont systemFontOfSize:12]];
    [cv addSubview:_keyLabel];

    // Secure text field
    _keyField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(20, 148, 320, 22)];
    [[_keyField cell] setPlaceholderString:@"sk-ant-…"];
    [_keyField setFont:[NSFont fontWithName:@"Courier New" size:12]];
    NSString *existing = [KeychainHelper loadAPIKey];
    if (existing) [_keyField setStringValue:existing];
    [[self window] setInitialFirstResponder:_keyField];
    [cv addSubview:_keyField];

    // Model label
    _modelLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 112, 320, 18)];
    [_modelLabel setStringValue:@"Model:"];
    [_modelLabel setBezeled:NO]; [_modelLabel setEditable:NO];
    [_modelLabel setSelectable:NO]; [_modelLabel setDrawsBackground:NO];
    [_modelLabel setFont:[NSFont systemFontOfSize:12]];
    [cv addSubview:_modelLabel];

    // Model popup
    _modelPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, 84, 320, 26) pullsDown:NO];
    [_modelPopup addItemWithTitle:@"claude-haiku-4-5-20251001 (Fast)"];
    [_modelPopup addItemWithTitle:@"claude-sonnet-4-6 (Balanced)"];
    [_modelPopup addItemWithTitle:@"claude-opus-4-8 (Powerful)"];

    // Select the stored model
    NSString *storedModel = [[NSUserDefaults standardUserDefaults] stringForKey:@"iChatAIModel"];
    if ([storedModel hasPrefix:@"claude-sonnet"]) [_modelPopup selectItemAtIndex:1];
    else if ([storedModel hasPrefix:@"claude-opus"])   [_modelPopup selectItemAtIndex:2];
    else                                               [_modelPopup selectItemAtIndex:0];
    [cv addSubview:_modelPopup];

    NSBox *sep = [[[NSBox alloc] initWithFrame:NSMakeRect(20, 56, 320, 1)] autorelease];
    [sep setBoxType:NSBoxSeparator];
    [cv addSubview:sep];

    // Cancel button
    _cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(170, 16, 80, 32)];
    [_cancelButton setTitle:@"Cancel"];
    [_cancelButton setBezelStyle:NSRoundedBezelStyle];
    [_cancelButton setKeyEquivalent:@"\033"];
    [_cancelButton setTarget:self];
    [_cancelButton setAction:@selector(cancelClicked:)];
    [cv addSubview:_cancelButton];

    // Save button
    _saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(258, 16, 80, 32)];
    [_saveButton setTitle:@"Save"];
    [_saveButton setBezelStyle:NSRoundedBezelStyle];
    [_saveButton setKeyEquivalent:@"\r"];
    [_saveButton setTarget:self];
    [_saveButton setAction:@selector(saveClicked:)];
    [cv addSubview:_saveButton];
}

- (void)saveClicked:(id)sender {
    NSString *key = [[_keyField stringValue] stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([key length] < 10) {
        NSRunAlertPanel(@"Invalid Key", @"Please enter a valid Anthropic API key.", @"OK", nil, nil);
        return;
    }

    [KeychainHelper saveAPIKey:key];

    // Save model preference
    NSInteger idx = [_modelPopup indexOfSelectedItem];
    NSString *model = @"claude-haiku-4-5-20251001";
    if (idx == 1) model = @"claude-sonnet-4-6";
    else if (idx == 2) model = @"claude-opus-4-8";
    [[NSUserDefaults standardUserDefaults] setObject:model forKey:@"iChatAIModel"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Notify app delegate so the chat window can pick up the new key/model
    [[NSNotificationCenter defaultCenter] postNotificationName:@"iChatAIPrefsChanged" object:self];

    [[self window] orderOut:self];
}

- (void)cancelClicked:(id)sender {
    [[self window] orderOut:self];
}

- (void)dealloc {
    [_keyLabel release];
    [_keyField release];
    [_modelLabel release];
    [_modelPopup release];
    [_saveButton release];
    [_cancelButton release];
    [super dealloc];
}

@end
