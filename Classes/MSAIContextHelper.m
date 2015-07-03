#import "ApplicationInsightsPrivate.h"
#import "MSAIContextHelper.h"
#import "MSAIContextHelperPrivate.h"
#import "MSAIPersistencePrivate.h"
#import "MSAIUser.h"
#import "MSAISession.h"
#import "MSAISessionStateData.h"

#import "MSAITelemetryManagerPrivate.h"

#import "MSAIHelper.h"

NSString *const kMSAIMetaDataSessionInfo = @"MSAIMetaDataSessionInfo";
NSString *const kMSAIMetaDataSessionCrashHandled = @"MetaDataSessionCrashHandled";

NSString *const kMSAISessionFileName = @"MSAISessions";
NSString *const kMSAISessionFileType = @"plist";
char *const MSAISessionOperationsQueue = "com.microsoft.ApplicationInsights.sessionQueue";

NSUInteger const defaultSessionExpirationTime = 20;
NSString *const kMSAIApplicationDidEnterBackgroundTime = @"MSAIApplicationDidEnterBackgroundTime";
NSString *const kMSAIApplicationWasLaunched = @"MSAIApplicationWasLaunched";

NSString *const MSAIUserChangedNotification = @"MSAIUserChangedNotification";
NSString *const kMSAIUserInfo = @"MSAIUserInfo";

NSString *const MSAISessionStartedNotification = @"MSAISessionStartedNotification";
NSString *const MSAISessionEndedNotification = @"MSAISessionEndedNotification";
NSString *const kMSAISessionInfo = @"MSAISessionInfo";

@implementation MSAIContextHelper {
  id _appWillEnterForegroundObserver;
  id _appDidEnterBackgroundObserver;
  id _appWillTerminateObserver;
}

#pragma mark - Initialize

+ (instancetype)sharedInstance {
  static MSAIContextHelper *sharedInstance = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [self new];
  });
  
  return sharedInstance;
}

- (instancetype)init {
  if (self = [super init]) {
    _operationsQueue = dispatch_queue_create(MSAISessionOperationsQueue, DISPATCH_QUEUE_SERIAL);
    
    _autoSessionManagementDisabled = NO;
    _appBackgroundTimeBeforeSessionExpires = defaultSessionExpirationTime;
    
    NSMutableDictionary *restoredMetaData = [[[MSAIPersistence sharedInstance] metaData] mutableCopy];
    _metaData = restoredMetaData ?: @{}.mutableCopy;
    _metaData[@"sessions"] = restoredMetaData[@"sessions"] ?: @{}.mutableCopy;
    _metaData[@"users"] = restoredMetaData[@"users"] ?: @{}.mutableCopy;
    [self registerObservers];
  }
  return self;
}

#pragma mark - Users
#pragma mark Create New Users

- (MSAIUser *)newUser {
  return ({
    MSAIUser *user = [MSAIUser new];
    user.userId = msai_appAnonID();
    user;
  });
}

#pragma mark Manual User ID Management
  
- (void)setCurrentUserId:(NSString *)userId {
  [self setUserWithConfigurationBlock:^(MSAIUser * __nonnull user) {
    user.userId = userId;
  }];
}

- (void)setUserWithConfigurationBlock:(void (^)(MSAIUser *user))userConfigurationBlock {
  MSAIUser *__block currentUser = [self userForDate:[NSDate date]];
  
  if (!currentUser) {
    currentUser = [self newUser];
  }
  
  userConfigurationBlock(currentUser);
  
  if (!currentUser) {
    return;
  }
  
  [self setCurrentUser:currentUser];
}

- (void)setCurrentUser:(nonnull MSAIUser *)user {
  [self addUser:user forDate:[NSDate date]];
  [self sendUserChangedNotificationWithUserInfo:@{kMSAIUserInfo : user}];
}

- (void)addUser:(MSAIUser *)user forDate:(NSDate *)date {
  NSString *timestamp = [self unixTimestampFromDate:date ?: [NSDate date]];
  
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.operationsQueue, ^{
    typeof(self) strongSelf = weakSelf;
    NSMutableDictionary *users = strongSelf.metaData[@"users"];
    users[timestamp] = user;
    [[MSAIPersistence sharedInstance] persistMetaData:strongSelf.metaData];
  });
}

- (MSAIUser *)userForDate:(NSDate *)date {
  NSString *timestamp = [self unixTimestampFromDate:date];
  NSMutableDictionary *users = self.metaData[@"users"];
  
  __block MSAIUser *user = nil;
  
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.operationsQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    NSString *userKey = [strongSelf keyForTimestamp:timestamp inDictionary:users];
    user = users[userKey];
  });
  
  return user;
}

- (BOOL)removeUserId:(NSString *)userId {
  BOOL __block success = NO;
  
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.operationsQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    NSMutableDictionary *users = self.metaData[@"users"];
    [users enumerateKeysAndObjectsUsingBlock:^(NSString *blockTimestamp, MSAIUser *blockUser, BOOL *stop) {
      if ([blockUser.userId isEqualToString:userId]) {
        [users removeObjectForKey:blockTimestamp];
        success = YES;
        *stop = YES;
      }
    }];
    [[MSAIPersistence sharedInstance] persistMetaData:strongSelf.metaData];
  });
  return success;
}

#pragma mark - Sessions
#pragma mark Session Creation

- (MSAISession *)newSession {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  return [self newSessionWithId:nil];
#pragma clang diagnostic pop
}

- (MSAISession *)newSessionWithId:(NSString *)sessionId {
  MSAISession *session = [MSAISession new];
  session.sessionId = sessionId ?: msai_UUID();
  session.isNew = @"false";
  
  if (![[NSUserDefaults standardUserDefaults] boolForKey:kMSAIApplicationWasLaunched]) {
    session.isFirst = @"true";
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kMSAIApplicationWasLaunched];
    [[NSUserDefaults standardUserDefaults] synchronize];
  } else {
    session.isFirst = @"false";
  }
  return session;
}

#pragma mark Automatic Session Management

- (void)registerObservers {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  
  __weak typeof(self) weakSelf = self;

  if (nil == _appDidEnterBackgroundObserver) {
    _appDidEnterBackgroundObserver = [nc addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                     object:nil
                                                      queue:NSOperationQueue.mainQueue
                                                 usingBlock:^(NSNotification *note) {
                                                   typeof(self) strongSelf = weakSelf;
                                                   [strongSelf updateDidEnterBackgroundTime];
                                                 }];
  }
  if (nil == _appWillEnterForegroundObserver) {
    _appWillEnterForegroundObserver = [nc addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification *note) {
                                                    typeof(self) strongSelf = weakSelf;
                                                    [strongSelf startNewSessionIfNeeded];
                                                  }];
  }
  if (nil == _appWillTerminateObserver) {
    _appWillTerminateObserver = [nc addObserverForName:UIApplicationWillTerminateNotification
                                                object:nil
                                                 queue:NSOperationQueue.mainQueue
                                            usingBlock:^(NSNotification *note) {
                                              typeof(self) strongSelf = weakSelf;
                                              [strongSelf endSession];
                                            }];
  }
}

- (void)unregisterObservers {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  _appDidEnterBackgroundObserver = nil;
  _appWillEnterForegroundObserver = nil;
  _appWillTerminateObserver = nil;
}

- (void)updateDidEnterBackgroundTime {
  if (self.autoSessionManagementDisabled) {
    return;
  }
  [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:kMSAIApplicationDidEnterBackgroundTime];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)startNewSessionIfNeeded {
  if (self.autoSessionManagementDisabled) {
    return;
  }
  
  if (self.appBackgroundTimeBeforeSessionExpires == 0) {
    [self startNewSession];
    return;
  }
  
  double appDidEnterBackgroundTime = [[NSUserDefaults standardUserDefaults] doubleForKey:kMSAIApplicationDidEnterBackgroundTime];
  double timeSinceLastBackground = [[NSDate date] timeIntervalSince1970] - appDidEnterBackgroundTime;
  if (timeSinceLastBackground > self.appBackgroundTimeBeforeSessionExpires) {
    [self startNewSession];
  }
}

#pragma mark Manual Session Management

- (void)renewSessionWithId:(NSString *)sessionId {
  MSAISession *session = [self newSessionWithId:sessionId];
  [self addSession:session withDate:[NSDate date]];

  NSDictionary *userInfo = @{kMSAISessionInfo: session};
  [self sendSessionStartedNotificationWithUserInfo:userInfo];
}

- (void)addSession:(MSAISession *)session withDate:(NSDate *)date {
  NSString *timestamp = [self unixTimestampFromDate:date];
  
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.operationsQueue, ^{
    typeof(self) strongSelf = weakSelf;
    NSMutableDictionary *sessions = strongSelf.metaData[@"sessions"];
    
    NSDictionary *sessionDict = [NSDictionary dictionaryWithObjectsAndKeys:session, kMSAIMetaDataSessionInfo, @(NO), kMSAIMetaDataSessionCrashHandled, nil];
    sessions[timestamp][kMSAIMetaDataSessionInfo] = session;
    sessions[timestamp][kMSAIMetaDataSessionCrashHandled] = @(NO);
    sessions[timestamp] = sessionDict;
    strongSelf.metaData[@"sessions"] = sessions;
    [[MSAIPersistence sharedInstance] persistMetaData:strongSelf.metaData];
  });
}

- (MSAISession *)sessionForDate:(NSDate *)date {
  NSString *timestamp = [self unixTimestampFromDate:date];
  NSMutableDictionary *sessions = self.metaData[@"sessions"];
  
  __block MSAISession *session = nil;
  
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.operationsQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    NSString *sessionKey = [strongSelf keyForTimestamp:timestamp inDictionary:sessions];
    session = sessions[sessionKey][kMSAIMetaDataSessionInfo];
  });
  
  return session;
}

#if MSAI_FEATURE_XAMARIN

- (void)ignoreCrashForSessionWithDate:(NSDate *)date {
  
  NSString *timestamp = [self unixTimestampFromDate:date];
  NSMutableDictionary *sessions = self.metaData[@"sessions"];
  
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.operationsQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    NSString *sessionKey = [strongSelf keyForTimestamp:timestamp inDictionary:sessions];
    NSMutableDictionary *sessionDict = [[sessions valueForKey:sessionKey] mutableCopy];
    if(sessionDict){
      sessionDict[kMSAIMetaDataSessionCrashHandled] = @(YES);
      sessions[sessionKey] = sessionDict;
      strongSelf.metaData[@"sessions"] = sessions;
      [[MSAIPersistence sharedInstance] persistMetaData:self.metaData];
    }
  });
}

- (BOOL)shouldIgnoreCrashForSessionWithDate:(NSDate *)date {
  
  NSString *timestamp = [self unixTimestampFromDate:date];
  NSMutableDictionary *sessions = self.metaData[@"sessions"];
  
  __block BOOL ignoreCrash = NO;
  
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.operationsQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    NSString *sessionKey = [strongSelf keyForTimestamp:timestamp inDictionary:sessions];
    NSMutableDictionary *sessionDict = [sessions valueForKey:sessionKey];
    if(sessionDict && sessionDict[kMSAIMetaDataSessionCrashHandled]){
      NSNumber *crashHandled = sessionDict[kMSAIMetaDataSessionCrashHandled];
      ignoreCrash = [crashHandled boolValue];
    }
  });
  
  return ignoreCrash;
}

#endif /* MSAI_FEATURE_XAMARIN */


#pragma mark Session Lifecycle

- (void)startNewSession {
  [self renewSessionWithId:msai_appAnonID()];
}

- (void)endSession {
  [self sendSessionEndedNotification];
}

#pragma mark - Notifications

- (void)sendUserChangedNotificationWithUserInfo:(NSDictionary *)userInfo {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:MSAIUserChangedNotification
                                                        object:self
                                                      userInfo:userInfo];
  });
}

- (void)sendSessionStartedNotificationWithUserInfo:(NSDictionary *)userInfo {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:MSAISessionStartedNotification
                                                        object:self
                                                      userInfo:userInfo];
  });
}

- (void)sendSessionEndedNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:MSAISessionEndedNotification
                                                        object:self
                                                      userInfo:nil];
  });
}

#pragma mark - Cleanup Meta Data

- (void)cleanUpMetaData {
  __weak typeof(self) weakSelf = self;
  
  dispatch_sync(self.operationsQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    NSMutableDictionary *sessions = strongSelf.metaData[@"sessions"];
    NSMutableDictionary *users = strongSelf.metaData[@"users"];
    
    if (sessions.count > 1) {
      // Get most recent session
      NSArray *sortedKeys = [strongSelf sortedKeysOfDictionay:sessions];
      NSString *recentSessionKey = sortedKeys.firstObject;
      
      // Clear list and add most recent session
      NSDictionary *lastSession = sessions[recentSessionKey];
      [sessions removeAllObjects];
      sessions[recentSessionKey] = lastSession;
    }
    if (users.count > 1) {
      // Get most recent session
      NSArray *sortedKeys = [strongSelf sortedKeysOfDictionay:users];
      NSString *recentUserKey = sortedKeys.firstObject;
      
      // Clear list and add most recent session
      MSAIUser *lastuser= users[recentUserKey];
      [users removeAllObjects];
      users[recentUserKey] = lastuser;
    }
    [[MSAIPersistence sharedInstance] persistMetaData:strongSelf.metaData];
  });
}

#pragma mark - Helper

- (NSString *)unixTimestampFromDate:(NSDate *)date {
    return [NSString stringWithFormat:@"%ld", (time_t)[date timeIntervalSince1970]];
}

- (NSString *)keyForTimestamp:(NSString *)timestamp inDictionary:(NSDictionary *)dict {
  for (NSString *key in [self sortedKeysOfDictionay:dict]){
    if([timestamp doubleValue] >= [key doubleValue]){
      return key;
    }
  }
  return nil;
}

- (NSArray *)sortedKeysOfDictionay:(NSDictionary *)dict {
  NSMutableArray *keys = [[dict allKeys] mutableCopy];
  NSArray *sortedArray = [keys sortedArrayUsingComparator:^(id a, id b) {
    return [b compare:a options:NSNumericSearch];
  }];
  return sortedArray;
}

@end
