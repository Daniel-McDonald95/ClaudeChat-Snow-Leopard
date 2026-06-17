#import <Foundation/Foundation.h>

// Minimal JSON serializer/deserializer for Snow Leopard (10.6)
// NSJSONSerialization is 10.7+ only.

@interface SimpleJSON : NSObject

// Serialize an NS object graph (NSDictionary, NSArray, NSString, NSNumber, NSNull) to a JSON string
+ (NSString *)stringify:(id)object;

// Parse a JSON string into an NS object graph
+ (id)parse:(NSString *)jsonString error:(NSError **)outError;

@end
