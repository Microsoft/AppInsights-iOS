#import "MSAITelemetryContext.h"
#import "MSAIApplication.h"
#import "MSAIDevice.h"
#import "MSAIOperation.h"
#import "MSAIInternal.h"
#import "MSAIUser.h"
#import "MSAISession.h"
#import "MSAILocation.h"
#import "MSAIContext.h"
#import "MSAIContextPrivate.h"

@interface MSAITelemetryContext()

///-----------------------------------------------------------------------------
/// @name Initialisation
///-----------------------------------------------------------------------------

/**
 *  The path to the telemetry endpoint.
 */
@property(nonatomic, strong, readonly) NSString *endpointPath;

/**
 *  The instrumentation key of the app.
 */
@property(nonatomic, strong, readonly) NSString *instrumentationKey;


/**
 *  The application context.
 */
@property(nonatomic, strong, readonly) MSAIApplication *application;

/**
 *  The device context.
 */
@property (nonatomic, strong, readonly)MSAIDevice *device;

/**
 *  The location context.
 */
@property (nonatomic, strong, readonly)MSAILocation *location;

/**
 *  The session context.
 */
@property (nonatomic, strong, readonly)MSAISession *session;

/**
 *  The user context.
 */
@property (nonatomic, strong, readonly)MSAIUser *user;

/**
 *  The internal context.
 */
@property (nonatomic, strong, readonly)MSAIInternal *internal;

/**
 *  The operation context.
 */
@property (nonatomic, strong, readonly)MSAIOperation *operation;

/**
 *  Initializes a telemetry context.
 *
 *  @param appContext         the context of the app, which contains several meta infos
 *  @param endpointPath       the path to the telemetry endpoint
 *  @param sessionId          the id of the first session
 *
 *  @return the telemetry context
 */
- (instancetype)initWithAppContext:(MSAIContext *)appContext
                      endpointPath:(NSString *)endpointPath;

///-----------------------------------------------------------------------------
/// @name Session
///-----------------------------------------------------------------------------

/**
 *  A reference to the userDefaults being used to store values
 */
@property(nonatomic, weak) NSUserDefaults *userDefaults;

///-----------------------------------------------------------------------------
/// @name Network status
///-----------------------------------------------------------------------------

/**
 *  Get current network type and register for updates.
 */
- (void)configureNetworkStatusTracking;

///-----------------------------------------------------------------------------
/// @name Helper
///-----------------------------------------------------------------------------

/**
 *  A dictionary which holds static tag fields for the purpose of caching
 */
@property (nonatomic, strong)MSAIOrderedDictionary *tags;

/**
 *  Returns context objects as dictionary.
 *
 *  @return a dictionary containing all context fields
 */
- (MSAIOrderedDictionary *)contextDictionary;

@end
