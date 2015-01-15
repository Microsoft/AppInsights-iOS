#import "MSAIClientContext.h"

@implementation MSAIClientContext

- (instancetype)initWithInstrumentationKey:(NSString *)instrumentationKey endpointPath:(NSString *)endpointPath{
  if ((self = [self init])) {
    self.instrumentationKey = instrumentationKey;
    self.endpointPath = endpointPath;
  }
  return self;
}

@end