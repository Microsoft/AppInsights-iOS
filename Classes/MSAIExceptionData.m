#import "MSAIExceptionData.h"
/// Data contract class for type ExceptionData.
@implementation MSAIExceptionData
@synthesize envelopeTypeName = _envelopeTypeName;
@synthesize dataTypeName = _dataTypeName;

/// Initializes a new instance of the class.
- (instancetype)init {
    if (self = [super init]) {
        _envelopeTypeName = @"Microsoft.ApplicationInsights.Exception";
        _dataTypeName = @"ExceptionData";
        self.version = [NSNumber numberWithInt:2];
    }
    return self;
}

///
/// Adds all members of this class to a dictionary
/// @param dictionary to which the members of this class will be added.
///
- (NSMutableDictionary *)serializeToDictionary {
    NSMutableDictionary * dict = [super serializeToDictionary];
    if (self.handledAt != nil) {
        [dict setObject:self.handledAt forKey:@"handledAt"];
    }
    if (self.exceptions != nil) {
        [dict setObject:self.exceptions forKey:@"exceptions"];
    }
    [dict setObject:[NSNumber numberWithInt:(int)self.severityLevel] forKey:@"severityLevel"];
    if (self.measurements != nil) {
        [dict setObject:self.measurements forKey:@"measurements"];
    }
    return dict;
}

///
/// Serializes the object to a string in json format.
/// @param writer The writer to serialize this object to.
///
- (NSString *)serializeToString {
    NSMutableDictionary *dict = [self serializeToDictionary];
    NSMutableString  *jsonString;
    NSError *error = nil;
    NSData *json;
    json = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    jsonString = [[NSMutableString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    return jsonString;
}

@end