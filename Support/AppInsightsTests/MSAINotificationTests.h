#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

@interface MSAINotificationTests : XCTestCase

- (void)setMockNotificationCenter:(NSNotificationCenter *)notificationCenter;
- (NSNotificationCenter *)mockNotificationCenter;

@end
