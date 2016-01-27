#import <Foundation/Foundation.h>
#import "ApplicationInsights.h"

#if MSAI_FEATURE_CRASH_REPORTER

@class MSAIEnvelope;
@class MSAIPLCrashReport;

NS_ASSUME_NONNULL_BEGIN
/**
 *  ApplicationInsights Crash Reporter error domain
 */
typedef NS_ENUM (NSInteger, MSAIBinaryImageType) {
  /**
   *  App binary
   */
  MSAIBinaryImageTypeAppBinary,
  /**
   *  App provided framework
   */
  MSAIBinaryImageTypeAppFramework,
  /**
   *  Image not related to the app
   */
  MSAIBinaryImageTypeOther
};


@interface MSAICrashDataProvider : NSObject {
}

+ (MSAIEnvelope *)crashDataForCrashReport:(MSAIPLCrashReport *)report handledException:(nullable NSException *)exception;
+ (MSAIEnvelope *)crashDataForCrashReport:(MSAIPLCrashReport *)report;

+ (MSAIBinaryImageType)imageTypeForImagePath:(NSString *)imagePath processPath:(NSString *)processPath;

@end
NS_ASSUME_NONNULL_END

#endif /* MSAI_FEATURE_CRASH_REPORTER */
