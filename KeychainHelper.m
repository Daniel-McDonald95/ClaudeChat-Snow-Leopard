#import "KeychainHelper.h"
#import <Security/Security.h>

static const char *kServiceName = "iChatAI";
static const char *kAccountName = "AnthropicAPIKey";

@implementation KeychainHelper

+ (BOOL)saveAPIKey:(NSString *)apiKey {
    const char *password = [apiKey UTF8String];
    UInt32 passwordLength = (UInt32)strlen(password);

    // Check if an entry already exists
    SecKeychainItemRef existingItem = NULL;
    OSStatus findStatus = SecKeychainFindGenericPassword(
        NULL,
        (UInt32)strlen(kServiceName), kServiceName,
        (UInt32)strlen(kAccountName), kAccountName,
        NULL, NULL,
        &existingItem
    );

    OSStatus status;
    if (findStatus == noErr && existingItem != NULL) {
        // Update existing item
        status = SecKeychainItemModifyAttributesAndData(
            existingItem,
            NULL,
            passwordLength,
            password
        );
        CFRelease(existingItem);
    } else {
        // Add new item
        status = SecKeychainAddGenericPassword(
            NULL,
            (UInt32)strlen(kServiceName), kServiceName,
            (UInt32)strlen(kAccountName), kAccountName,
            passwordLength, password,
            NULL
        );
    }

    return (status == noErr);
}

+ (NSString *)loadAPIKey {
    void *passwordData = NULL;
    UInt32 passwordLength = 0;

    OSStatus status = SecKeychainFindGenericPassword(
        NULL,
        (UInt32)strlen(kServiceName), kServiceName,
        (UInt32)strlen(kAccountName), kAccountName,
        &passwordLength, &passwordData,
        NULL
    );

    if (status == noErr && passwordData != NULL) {
        NSString *key = [[[NSString alloc] initWithBytes:passwordData
                                                  length:passwordLength
                                                encoding:NSUTF8StringEncoding] autorelease];
        SecKeychainItemFreeContent(NULL, passwordData);
        return key;
    }
    return nil;
}

+ (BOOL)deleteAPIKey {
    SecKeychainItemRef item = NULL;
    OSStatus status = SecKeychainFindGenericPassword(
        NULL,
        (UInt32)strlen(kServiceName), kServiceName,
        (UInt32)strlen(kAccountName), kAccountName,
        NULL, NULL,
        &item
    );

    if (status == noErr && item != NULL) {
        status = SecKeychainItemDelete(item);
        CFRelease(item);
        return (status == noErr);
    }
    return NO;
}

@end
