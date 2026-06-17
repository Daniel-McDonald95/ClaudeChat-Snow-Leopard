#import <Foundation/Foundation.h>

@protocol AnthropicClientDelegate <NSObject>
- (void)anthropicClientDidReceiveResponse:(NSString *)text;
- (void)anthropicClientDidFailWithError:(NSString *)errorMessage;
@end

// A single pending message (may include an image)
@interface AnthropicMessage : NSObject {
    NSString *_role;
    NSString *_text;
    NSData   *_imageData;
    NSString *_imageMimeType;
}
@property (nonatomic, retain) NSString *role;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSData   *imageData;
@property (nonatomic, retain) NSString *imageMimeType;

+ (AnthropicMessage *)userMessage:(NSString *)text;
+ (AnthropicMessage *)userMessage:(NSString *)text imageData:(NSData *)data mimeType:(NSString *)mime;
+ (AnthropicMessage *)assistantMessage:(NSString *)text;
@end

@interface AnthropicClient : NSObject {
    id<AnthropicClientDelegate> _delegate;
    NSString *_apiKey;
    NSString *_model;
    NSTask   *_task;
}

@property (nonatomic, assign) id<AnthropicClientDelegate> delegate;
@property (nonatomic, retain) NSString *model;

- (id)initWithAPIKey:(NSString *)apiKey;
- (void)sendMessages:(NSArray *)messages;
- (void)cancel;

@end
