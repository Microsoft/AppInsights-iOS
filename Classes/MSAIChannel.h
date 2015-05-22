#import <Foundation/Foundation.h>
#import "ApplicationInsights.h"

MSAI_ASSUME_NONNULL_BEGIN
/**
 *  Prepares telemetry data and forwards it to the persistence layer. Once data has been persisted it will be sent by the sender automatically.
 */
@interface MSAIChannel : NSObject

/**
 *  Manually trigger the MSAIChannel to persist all items currently in its dataItemsQueue
 */
- (void)persistDataItemQueue;

@end
MSAI_ASSUME_NONNULL_END
