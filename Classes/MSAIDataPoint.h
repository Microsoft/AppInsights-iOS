#import "MSAIDataPointType.h"
#import "MSAIObject.h"
#import "MSAITelemetryData.h"
#import "MSAIDomain.h"

@interface MSAIDataPoint : MSAIObject <NSCoding>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) MSAIDataPointType kind;
@property (nonatomic, strong) NSNumber *value;
@property (nonatomic, strong) NSNumber *count;
@property (nonatomic, strong) NSNumber *min;
@property (nonatomic, strong) NSNumber *max;
@property (nonatomic, strong) NSNumber *stdDev;

@end
