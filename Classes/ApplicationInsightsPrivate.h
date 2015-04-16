#import <Foundation/Foundation.h>
#import "MSAIApplicationInsights.h"

#ifndef MSAI_Private_h
#define MSAI_Private_h

extern NSString *const kMSAIName;
extern NSString *const kMSAIIdentifier;
extern NSString *const kMSAICrashSettings;
extern NSString *const kMSAICrashAnalyzer;

#if MSAI_FEATURE_TELEMETRY

extern NSString *const __unused kMSAITelemetryCachesSessions;
extern NSString *const __unused kMSAITelemetryTempSessionData;
extern NSString *const __unused kMSAITelemetryLastAppVersion;

#endif

extern NSString *const kMSAIIntegrationflowTimestamp;

extern NSString *const kMSAITelemetryPath;

#define MSAILog(fmt, ...) do { if([MSAIApplicationInsights sharedInstance].isDebugLogEnabled && ![MSAIApplicationInsights sharedInstance].isAppStoreEnvironment) { NSLog((@"[MSAI] %s/%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); }} while(0)

#ifndef __IPHONE_8_0
#define __IPHONE_8_0     80000
#endif

#endif //MSAI_Private_h
