#import "MSAISender.h"
#import "MSAIAppClient.h"
#import "MSAISenderPrivate.h"
#import "MSAIPersistence.h"
#import "MSAIPersistencePrivate.h"
#import "MSAIGZIP.h"
#import "MSAIEnvelope.h"
#import "ApplicationInsights.h"
#import "ApplicationInsightsPrivate.h"
#import "MSAIApplicationInsights.h"

static char const *kPersistenceQueueString = "com.microsoft.ApplicationInsights.senderQueue";
static NSUInteger const defaultRequestLimit = 10;

@interface MSAISender ()

@end

@implementation MSAISender

@synthesize runningRequestsCount = _runningRequestsCount;

#pragma mark - Initialize & configure shared instance

+ (instancetype)sharedSender {
  static MSAISender *sharedInstance = nil;
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    sharedInstance = [MSAISender new];
  });
  return sharedInstance;
}

- (instancetype)init {
  if ((self = [super init])) {
    _senderQueue = dispatch_queue_create(kPersistenceQueueString, DISPATCH_QUEUE_CONCURRENT);
  }
  return self;
}

#pragma mark - Network status

- (void)configureWithAppClient:(MSAIAppClient *)appClient {
  [self configureWithAppClient:appClient delegate:nil];
}

- (void)configureWithAppClient:(MSAIAppClient *)appClient delegate:(id)delegate {
  self.appClient = appClient;
  self.maxRequestCount = defaultRequestLimit;
  self.delegate = delegate;
  [self registerObservers];
}

#pragma mark - Handle persistence events

- (void)registerObservers{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  __weak typeof(self) weakSelf = self;
  [center addObserverForName:MSAIPersistenceSuccessNotification
                      object:nil
                       queue:nil
                  usingBlock:^(NSNotification *notification) {
                    typeof(self) strongSelf = weakSelf;
                    
                    [strongSelf sendSavedData];
                    
                  }];
}

#pragma mark - Sending

- (void)sendSavedData{
  
  @synchronized(self){
    if(_runningRequestsCount < _maxRequestCount){
      _runningRequestsCount++;
    }else{
      return;
    }
  }
  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    typeof(self) strongSelf = weakSelf;
    NSString *path = [[MSAIPersistence sharedInstance] requestNextPath];
    NSData *data = [[MSAIPersistence sharedInstance] dataAtPath:path];
    NSData *gzippedData = [data gzippedData];
    [strongSelf sendData:gzippedData withPath:path];
  });
}

- (void)sendData:(NSData *)data withPath:(NSString *)path{
  
  if(data) {
    NSURLRequest *request = [self requestForData:data];
    [self sendRequest:request path:path];
    
  }else{
    self.runningRequestsCount -= 1;
  }
}

- (void)sendRequest:(NSURLRequest *)request path:(NSString *)path{
  if(!path || !request) return;
  
  // Inform delegate
  NSArray *bundle;
  MSAIPersistenceType type = [[MSAIPersistence sharedInstance] persistenceTypeForPath:path];
  if(self.delegate && type == MSAIPersistenceTypeHighPriority && [self.delegate respondsToSelector:@selector(appInsightsWillSendCrashDict:)]){
    bundle = [[MSAIPersistence sharedInstance] bundleAtPath:path withPersistenceType:type];
    NSDictionary *crashDict = bundle.count > 0 ? bundle[0] : nil;
    [self.delegate appInsightsWillSendCrashDict:crashDict];
  }
  
  __weak typeof(self) weakSelf = self;
  MSAIHTTPOperation *operation = [self.appClient operationWithURLRequest:request queue:self.senderQueue completion:^(MSAIHTTPOperation *operation, NSData *responseData, NSError *error) {
    typeof(self) strongSelf = weakSelf;
    
    strongSelf.runningRequestsCount -= 1;
    NSInteger statusCode = [operation.response statusCode];

    if(responseData && [self shouldDeleteDataWithStatusCode:statusCode]) {
      //we delete data that was either sent successfully or if we have a non-recoverable error
      MSAILog(@"Sent data with status code: %ld", (long) statusCode);
      if (responseData) {
        MSAILog(@"Response data:\n%@", [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil]);
      }
      [[MSAIPersistence sharedInstance] deleteFileAtPath:path];
      [strongSelf sendSavedData];
    } else {
      MSAILog(@"Sending MSAIApplicationInsights data failed");
      MSAILog(@"Error description: %@", error.localizedDescription);
      [[MSAIPersistence sharedInstance] giveBackRequestedPath:path];
    }
    
    // Inform delegate
    if(statusCode >= 200 && statusCode <= 202){
      if(strongSelf.delegate && type == MSAIPersistenceTypeHighPriority && [strongSelf.delegate respondsToSelector:@selector(appInsightsDidFinishSendingCrashDict:)]){
        NSDictionary *crashDict = bundle.count > 0 ? bundle[0] : nil;
        [strongSelf.delegate appInsightsDidFinishSendingCrashDict:crashDict];
      }
    }else{
      if(strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(appInsightsDidFailWithError:)]){
        [strongSelf.delegate appInsightsDidFailWithError:error];
      }
    }
  }];
  
  [self.appClient enqeueHTTPOperation:operation];
}

#pragma mark - Helper

- (NSURLRequest *)requestForData:(NSData *)data {
  NSMutableURLRequest *request = [self.appClient requestWithMethod:@"POST"
                                                              path:self.endpointPath
                                                        parameters:nil];
  
  request.HTTPBody = data;
  request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
  
  NSDictionary *headers = @{@"Charset": @"UTF-8",
                            @"Content-Encoding": @"gzip",
                            @"Content-Type": @"application/json",
                            @"Accept-Encoding": @"gzip"};
  [request setAllHTTPHeaderFields:headers];
  
  return request;
}

//some status codes represent recoverable error codes
//we try sending again some point later
- (BOOL)shouldDeleteDataWithStatusCode:(NSInteger)statusCode {
  NSArray *recoverableStatusCodes = @[@429, @408, @500, @503, @511];

  return ![recoverableStatusCodes containsObject:@(statusCode)];
}

#pragma mark - Getter/Setter

- (NSUInteger)runningRequestsCount {
  @synchronized(self) {
    return _runningRequestsCount;
  }
}

- (void)setRunningRequestsCount:(NSUInteger)runningRequestsCount {
  @synchronized(self) {
    _runningRequestsCount = runningRequestsCount;
  }
}

@end
