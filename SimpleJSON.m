#import "SimpleJSON.h"

// ---------------------------------------------------------------------------
// Internal parser
// ---------------------------------------------------------------------------

@interface _SJParser : NSObject {
    NSString  *_src;
    NSUInteger _pos;
    NSUInteger _len;
}
- (id)initWithString:(NSString *)src;
- (id)parseValue:(NSError **)err;
@end

@implementation _SJParser

- (id)initWithString:(NSString *)src {
    if ((self = [super init])) {
        _src = [src retain];
        _pos = 0;
        _len = [src length];
    }
    return self;
}

- (void)dealloc {
    [_src release];
    [super dealloc];
}

- (unichar)ch { return (_pos < _len) ? [_src characterAtIndex:_pos] : 0; }

- (void)skipWS {
    while (_pos < _len) {
        unichar c = [_src characterAtIndex:_pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') _pos++;
        else break;
    }
}

- (NSString *)parseString:(NSError **)err {
    _pos++; // skip opening "
    NSMutableString *s = [NSMutableString stringWithCapacity:32];
    while (_pos < _len) {
        unichar c = [_src characterAtIndex:_pos];
        if (c == '"') { _pos++; return s; }
        if (c == '\\') {
            _pos++;
            if (_pos >= _len) break;
            unichar esc = [_src characterAtIndex:_pos];
            switch (esc) {
                case '"':  [s appendString:@"\""]; break;
                case '\\': [s appendString:@"\\"]; break;
                case '/':  [s appendString:@"/"]; break;
                case 'n':  [s appendString:@"\n"]; break;
                case 'r':  [s appendString:@"\r"]; break;
                case 't':  [s appendString:@"\t"]; break;
                case 'b':  [s appendString:@"\b"]; break;
                case 'f':  [s appendString:@"\f"]; break;
                case 'u': {
                    if (_pos + 4 < _len) {
                        NSString *hex = [_src substringWithRange:NSMakeRange(_pos + 1, 4)];
                        unsigned int cp = 0;
                        [[NSScanner scannerWithString:hex] scanHexInt:&cp];
                        unichar uc = (unichar)cp;
                        [s appendString:[NSString stringWithCharacters:&uc length:1]];
                        _pos += 4;
                    }
                    break;
                }
                default: {
                    unichar tmp = esc;
                    [s appendString:[NSString stringWithCharacters:&tmp length:1]];
                }
            }
        } else {
            unichar tmp = c;
            [s appendString:[NSString stringWithCharacters:&tmp length:1]];
        }
        _pos++;
    }
    return s; // unterminated – return what we have
}

- (NSNumber *)parseNumber {
    NSUInteger start = _pos;
    BOOL isFloat = NO;
    while (_pos < _len) {
        unichar c = [_src characterAtIndex:_pos];
        if (c == '.' || c == 'e' || c == 'E') isFloat = YES;
        if (c == '-' || c == '+' || c == '.' ||
            (c >= '0' && c <= '9') || c == 'e' || c == 'E') {
            _pos++;
        } else break;
    }
    NSString *numStr = [_src substringWithRange:NSMakeRange(start, _pos - start)];
    return isFloat ? [NSNumber numberWithDouble:[numStr doubleValue]]
                   : [NSNumber numberWithLongLong:[numStr longLongValue]];
}

- (NSArray *)parseArray:(NSError **)err {
    _pos++; // skip [
    NSMutableArray *arr = [NSMutableArray array];
    [self skipWS];
    if (_pos < _len && [_src characterAtIndex:_pos] == ']') { _pos++; return arr; }
    while (_pos < _len) {
        id val = [self parseValue:err];
        if (val) [arr addObject:val];
        [self skipWS];
        if (_pos >= _len) break;
        unichar c = [_src characterAtIndex:_pos];
        if (c == ']') { _pos++; break; }
        if (c == ',') _pos++;
    }
    return arr;
}

- (NSDictionary *)parseObject:(NSError **)err {
    _pos++; // skip {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [self skipWS];
    if (_pos < _len && [_src characterAtIndex:_pos] == '}') { _pos++; return dict; }
    while (_pos < _len) {
        [self skipWS];
        if ([self ch] != '"') break;
        NSString *key = [self parseString:err];
        [self skipWS];
        if ([self ch] == ':') _pos++;
        [self skipWS];
        id val = [self parseValue:err];
        if (key && val) [dict setObject:val forKey:key];
        [self skipWS];
        if (_pos >= _len) break;
        unichar c = [_src characterAtIndex:_pos];
        if (c == '}') { _pos++; break; }
        if (c == ',') _pos++;
    }
    return dict;
}

- (id)parseValue:(NSError **)err {
    [self skipWS];
    if (_pos >= _len) return nil;
    unichar c = [_src characterAtIndex:_pos];
    if (c == '"') return [self parseString:err];
    if (c == '{') return [self parseObject:err];
    if (c == '[') return [self parseArray:err];
    if (c == 't') { _pos += 4; return [NSNumber numberWithBool:YES]; }
    if (c == 'f') { _pos += 5; return [NSNumber numberWithBool:NO]; }
    if (c == 'n') { _pos += 4; return [NSNull null]; }
    if (c == '-' || (c >= '0' && c <= '9')) return [self parseNumber];
    return nil;
}

@end

// ---------------------------------------------------------------------------
// Public interface
// ---------------------------------------------------------------------------

@implementation SimpleJSON

+ (NSString *)stringify:(id)obj {
    if (!obj || [obj isKindOfClass:[NSNull class]]) return @"null";

    if ([obj isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)obj;
        s = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        s = [s stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
        s = [s stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
        return [NSString stringWithFormat:@"\"%@\"", s];
    }

    if ([obj isKindOfClass:[NSNumber class]]) {
        NSNumber *n = (NSNumber *)obj;
        // Detect boolean
        const char *t = [n objCType];
        if (strcmp(t, @encode(BOOL)) == 0 || strcmp(t, @encode(signed char)) == 0) {
            return [n boolValue] ? @"true" : @"false";
        }
        return [n stringValue];
    }

    if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *)obj;
        NSMutableArray *parts = [NSMutableArray arrayWithCapacity:[arr count]];
        for (id item in arr) {
            [parts addObject:[self stringify:item]];
        }
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@","]];
    }

    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;
        NSMutableArray *parts = [NSMutableArray arrayWithCapacity:[dict count]];
        for (NSString *key in dict) {
            NSString *escapedKey = [self stringify:key]; // includes quotes
            NSString *val = [self stringify:[dict objectForKey:key]];
            [parts addObject:[NSString stringWithFormat:@"%@:%@", escapedKey, val]];
        }
        return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@","]];
    }

    return @"null";
}

+ (id)parse:(NSString *)jsonString error:(NSError **)outError {
    if (!jsonString) return nil;
    _SJParser *p = [[[_SJParser alloc] initWithString:jsonString] autorelease];
    return [p parseValue:outError];
}

@end
