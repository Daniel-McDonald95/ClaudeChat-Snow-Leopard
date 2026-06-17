#import "AnthropicClient.h"
#import "SimpleJSON.h"

// ---------------------------------------------------------------------------
// Base64 encoder (avoids undocumented -base64Encoding on 10.6)
// ---------------------------------------------------------------------------
static NSString *CCBase64EncodeData(NSData *data) {
    static const char t[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const uint8_t *b = (const uint8_t *)[data bytes];
    NSUInteger len = [data length];
    NSMutableString *s = [NSMutableString stringWithCapacity:((len + 2) / 3) * 4 + 4];
    for (NSUInteger i = 0; i < len; i += 3) {
        uint8_t b0 = b[i];
        uint8_t b1 = (i+1 < len) ? b[i+1] : 0;
        uint8_t b2 = (i+2 < len) ? b[i+2] : 0;
        [s appendFormat:@"%c%c%c%c",
            t[b0 >> 2],
            t[((b0 & 0x3) << 4) | (b1 >> 4)],
            (i+1 < len) ? t[((b1 & 0xF) << 2) | (b2 >> 6)] : '=',
            (i+2 < len) ? t[b2 & 0x3F] : '='];
    }
    return s;
}

// ---------------------------------------------------------------------------
// AnthropicMessage
// ---------------------------------------------------------------------------

@implementation AnthropicMessage
@synthesize role = _role;
@synthesize text = _text;
@synthesize imageData = _imageData;
@synthesize imageMimeType = _imageMimeType;

+ (AnthropicMessage *)userMessage:(NSString *)text {
    AnthropicMessage *m = [[[AnthropicMessage alloc] init] autorelease];
    m.role = @"user"; m.text = text;
    return m;
}
+ (AnthropicMessage *)userMessage:(NSString *)text imageData:(NSData *)data mimeType:(NSString *)mime {
    AnthropicMessage *m = [[[AnthropicMessage alloc] init] autorelease];
    m.role = @"user"; m.text = text; m.imageData = data; m.imageMimeType = mime;
    return m;
}
+ (AnthropicMessage *)assistantMessage:(NSString *)text {
    AnthropicMessage *m = [[[AnthropicMessage alloc] init] autorelease];
    m.role = @"assistant"; m.text = text;
    return m;
}

- (void)dealloc {
    [_role release]; [_text release]; [_imageData release]; [_imageMimeType release];
    [super dealloc];
}
@end

// ---------------------------------------------------------------------------
// AnthropicClient
// ---------------------------------------------------------------------------

@implementation AnthropicClient
@synthesize delegate = _delegate;
@synthesize model = _model;

- (id)initWithAPIKey:(NSString *)apiKey {
    if ((self = [super init])) {
        _apiKey = [apiKey copy];
        _model  = [@"claude-haiku-4-5-20251001" retain];
    }
    return self;
}

- (void)dealloc {
    [self cancel];
    [_apiKey release];
    [_model release];
    [super dealloc];
}

- (void)cancel {
    [[NSNotificationCenter defaultCenter] removeObserver:self
        name:NSFileHandleReadToEndOfFileCompletionNotification
        object:nil];
    if (_task) {
        if ([_task isRunning]) [_task terminate];
        [_task release];
        _task = nil;
    }
}

// ---------------------------------------------------------------------------
// Build JSON body
// ---------------------------------------------------------------------------
- (NSString *)buildRequestJSON:(NSArray *)messages {
    NSMutableArray *jsonMessages = [NSMutableArray array];

    for (AnthropicMessage *msg in messages) {
        NSDictionary *jsonMsg;

        if (msg.imageData != nil) {
            NSString *b64 = CCBase64EncodeData(msg.imageData);
            NSDictionary *imageSource = [NSDictionary dictionaryWithObjectsAndKeys:
                @"base64",         @"type",
                msg.imageMimeType, @"media_type",
                b64,               @"data",
                nil];
            NSDictionary *imagePart = [NSDictionary dictionaryWithObjectsAndKeys:
                @"image",    @"type",
                imageSource, @"source",
                nil];
            NSMutableArray *contentParts = [NSMutableArray arrayWithObject:imagePart];
            if (msg.text && [msg.text length] > 0) {
                NSDictionary *textPart = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"text",  @"type",
                    msg.text, @"text",
                    nil];
                [contentParts addObject:textPart];
            }
            jsonMsg = [NSDictionary dictionaryWithObjectsAndKeys:
                msg.role,     @"role",
                contentParts, @"content",
                nil];
        } else {
            jsonMsg = [NSDictionary dictionaryWithObjectsAndKeys:
                msg.role, @"role",
                msg.text, @"content",
                nil];
        }
        [jsonMessages addObject:jsonMsg];
    }

    NSDictionary *body = [NSDictionary dictionaryWithObjectsAndKeys:
        _model,                             @"model",
        [NSNumber numberWithInteger:2048],   @"max_tokens",
        jsonMessages,                       @"messages",
        nil];

    return [SimpleJSON stringify:body];
}

// ---------------------------------------------------------------------------
// Send via bundled curl binary (supports TLS 1.2 + ECDHE on Snow Leopard)
// ---------------------------------------------------------------------------
- (void)sendMessages:(NSArray *)messages {
    [self cancel];

    NSString *curlPath = [[NSBundle mainBundle] pathForResource:@"curl-static" ofType:nil];
    if (!curlPath) {
        [_delegate anthropicClientDidFailWithError:@"curl-static not found in app bundle."];
        return;
    }

    // Ensure the binary is executable (Xcode can strip the execute bit from resources)
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm fileAttributesAtPath:curlPath traverseLink:YES];
    NSNumber *perms = [attrs objectForKey:NSFilePosixPermissions];
    if (!perms || ([perms shortValue] & 0111) == 0) {
        [fm changeFileAttributes:
            [NSDictionary dictionaryWithObject:[NSNumber numberWithShort:0755]
                                        forKey:NSFilePosixPermissions]
                          atPath:curlPath];
    }

    NSString *bodyString = [self buildRequestJSON:messages];

    NSString *proxyBase = [[NSUserDefaults standardUserDefaults] stringForKey:@"CCProxyBaseURL"];
    NSString *endpoint;
    if (proxyBase && [proxyBase length] > 0) {
        endpoint = [proxyBase stringByAppendingString:@"/v1/messages"];
    } else {
        endpoint = @"https://api.anthropic.com/v1/messages";
    }

    _task = [[NSTask alloc] init];
    [_task setLaunchPath:curlPath];
    [_task setArguments:[NSArray arrayWithObjects:
        @"-k", @"-s", @"--max-time", @"30",
        @"-H", [NSString stringWithFormat:@"x-api-key: %@", _apiKey],
        @"-H", @"anthropic-version: 2023-06-01",
        @"-H", @"content-type: application/json",
        @"-d", bodyString,
        endpoint,
        nil]];

    NSPipe *outPipe = [NSPipe pipe];
    [_task setStandardOutput:outPipe];
    [_task setStandardError:[NSPipe pipe]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(curlReadComplete:)
                                                 name:NSFileHandleReadToEndOfFileCompletionNotification
                                               object:[outPipe fileHandleForReading]];
    [_task launch];
    [[outPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
}

- (void)curlReadComplete:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSFileHandleReadToEndOfFileCompletionNotification
                                                  object:[note object]];
    [_task release];
    _task = nil;

    NSData *data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if (!data || [data length] == 0) {
        [_delegate anthropicClientDidFailWithError:@"No response from api.anthropic.com."];
        return;
    }

    NSString *jsonString = [[[NSString alloc] initWithData:data
                                                  encoding:NSUTF8StringEncoding] autorelease];
    id parsed = [SimpleJSON parse:jsonString error:nil];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        [_delegate anthropicClientDidFailWithError:
            [NSString stringWithFormat:@"Unexpected response: %@", jsonString]];
        return;
    }

    NSDictionary *dict = (NSDictionary *)parsed;

    // API-level error
    if ([[dict objectForKey:@"type"] isEqualToString:@"error"]) {
        NSDictionary *err = [dict objectForKey:@"error"];
        NSString *msg = [err objectForKey:@"message"];
        [_delegate anthropicClientDidFailWithError:msg ?: @"API error"];
        return;
    }

    // Extract text from content blocks
    NSArray *content = [dict objectForKey:@"content"];
    NSMutableString *text = [NSMutableString string];
    for (id block in content) {
        if ([block isKindOfClass:[NSDictionary class]]) {
            if ([[block objectForKey:@"type"] isEqualToString:@"text"]) {
                NSString *t = [block objectForKey:@"text"];
                if (t) [text appendString:t];
            }
        }
    }

    [_delegate anthropicClientDidReceiveResponse:text];
}

@end
