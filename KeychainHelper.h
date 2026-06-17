#import <Foundation/Foundation.h>

@interface KeychainHelper : NSObject

+ (BOOL)saveAPIKey:(NSString *)apiKey;
+ (NSString *)loadAPIKey;
+ (BOOL)deleteAPIKey;

@end
