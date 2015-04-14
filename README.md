## Application Insights for iOS (1.0-beta.1)

**Release Notes**

- Performance improvements
- Expose configuarations:
	- Set serverURL programmatically
	- Automatic page view tracking
	- Set instrumentation key programmatically
- Bug fixes
	- Use session id of previous session for crashes
	- Session context for page views
	- Prevent SDK from crashing if too many events are tracked
- Add user context to payload
- Breaking change: Rename MSAITelemetryManager to MSAITelemetryManager

## Introduction

This article describes how to integrate Application Insights into your iOS apps. The SDK  allows to send application metrics (events, traces, metrics, and pageviews) to the server. 

This document contains the following sections:

- [Requirements](#requirements)
- [Download & Extract](#download)
- [Set up Xcode](#xcode) 
- [Modify Code](#modify)
- [Endpoints](#endpoints)
- [iOS 8 Extensions](#extension)
- [Additional Options](#options)
- [Contact](#contact)

<a id="requirements"></a> 
## Requirements

The SDK runs on devices with iOS 6.0 or higher.

<a id="download"></a> 
## Download & Extract

1. Download the latest [Application Insights for iOS](https://github.com/Microsoft/AppInsights-iOS/releases) framework.

2. Unzip the file. A new folder `ApplicationInsights` is created.

3. Move the folder into your project directory. We usually put 3rd-party code into a subdirectory named `Vendor`, so we move the directory into it.

<a id="xcode"></a> 
## Set up Xcode

1. Drag & drop `ApplicationInsights.framework` from your project directory to your Xcode project.
2. Similar to above, our projects have a group `Vendor`, so we drop it there.
3. Select `Create groups for any added folders` and set the checkmark for your target. Then click `Finish`.
4. Select your project in the `Project Navigator` (⌘+1).
5. Select your app target.
6. Select the tab `Build Phases`.
7. Expand `Link Binary With Libraries`.
8. Add the following system frameworks, if they are missing:
	- `UIKit`
	- `Foundation`
	- `SystemConfiguration`
	- `Security`
	- `CoreTelephony`(only required if iOS > 7.0)
9. Open the info.plist of your app target and add a new field of type *String*. Name it `MSAIInstrumentationKey` and set your Application Insights instrumentation key as its value.

<a id="modify"></a> 
## Modify Code 

### Objective-C

2. Open your `AppDelegate.m` file.
3. Add the following line at the top of the file below your own #import statements:

	```objectivec
	#import <ApplicationInsights/ApplicationInsights.h>
	```
4. Search for the method `application:didFinishLaunchingWithOptions:`
5. Add the following lines to setup and start the Application Insights SDK:

	```objectivec
	[[MSAIApplicationInsights sharedInstance] setup];
	// Do some additional configuration if needed here
	...
	[[MSAIApplicationInsights sharedInstance] start];
	```

	You can also use the following shortcut:

	```objectivec
	[MSAIApplicationInsights setup];
	[MSAIApplicationInsights start];
	```

6. Send some data to the server:

	```objectivec	
	// Send an event with custom properties and measuremnts data
	[MSAITelemetryManager trackEventWithName:@"Hello World event!"
								  properties:@{@"Test property 1":@"Some value",
											 @"Test property 2":@"Some other value"}
							     measurements:@{@"Test measurement 1":@(4.8),
											 @"Test measurement 2":@(15.16),
		                                	 @"Test measurement 3":@(23.42)}];

	// Send a message
	[MSAITelemetryManager trackTraceWithMessage:@"Test message"];

	// Manually send pageviews (note: this will also be done automatically)
	[MSAITelemetryManager trackPageView:@"MyViewController"
							   duration:300
					 	     properties:@{@"Test measurement 1":@(4.8)}];

	// Send custom metrics
	[MSAITelemetryManager trackMetricWithName:@"Test metric" 
									    value:42.2];
	```

*Note:* The SDK is optimized to defer everything possible to a later time while making sure e.g. crashes on startup can also be caught and each module executes other code with a delay some seconds. This ensures that applicationDidFinishLaunching will process as fast as possible and the SDK will not block the startup sequence resulting in a possible kill by the watchdog process.

### Swift

2. Open your `AppDelegate.swift` file.
3. Add the following line at the top of the file below your own #import statements:
	
	```swift	
	#import ApplicationInsights
	```
4. Search for the method 
	
	```swift	
	application(application: UIApplication, didFinishLaunchingWithOptions launchOptions:[NSObject: AnyObject]?) -> Bool`
	```
5. Add the following lines to setup and start the Application Insights SDK:
	
	```swift
	MSAIApplicationInsights.sharedInstance().setup();
   MSAIApplicationInsights.sharedInstance().start();
	```
	
	You can also use the following shortcut:

	```swift
	MSAIApplicationInsights.setup();
   MSAIApplicationInsights.start();
	```
5. Send some data to the server:
	
	```swift
	// Send an event with custom properties and measuremnts data
	MSAITelemetryManager.trackEventWithName(name:"Hello World event!", 
									  properties:@{"Test property 1":"Some value",
												  "Test property 2":"Some other value"},
								    measurements:@{"Test measurement 1":@(4.8),
												  "Test measurement 2":@(15.16),
 											      "Test measurement 3":@(23.42)});

	// Send a message
	MSAITelemetryManager.trackTraceWithMessage(message:"Test message");

	// Manually send pageviews
	MSAITelemetryManager.trackPageView(pageView:"MyViewController",
									   duration:300,
								     properties:@{"Test measurement 1":@(4.8)});

	// Send a message
	MSAITelemetryManager.trackMetricWithName(name:"Test metric",
										    value:42.2);
	```

<a id="endpoints"></a> 
## Endpoint 

By default the following server URL is used to work with the [Azure portal](https://portal.azure.com):

* `https://dc.services.visualstudio.com`

To change the URL, setup Application Insights like this:

```objectivec
	[[MSAIApplicationInsights sharedInstance] setup];
	[[MSAIApplicationInsights sharedInstance] setServerURL:{your server url}];
	[[MSAIApplicationInsights sharedInstance] start];
```
	

<a id="extensions"></a>
## iOS 8 Extensions

The following points need to be considered to use the Application Insights SDK with iOS 8 Extensions:

1. Each extension is required to use the same values for version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`) as the main app uses. (This is required only if you are using the same `MSAIInstrumentationKey` for your app and extensions).
2. You need to make sure the SDK setup code is only invoked once. Since there is no `applicationDidFinishLaunching:` equivalent and `viewDidLoad` can run multiple times, you need to use a setup like the following example:

	```objectivec	
	@interface TodayViewController () <NCWidgetProviding>
	@property (nonatomic, assign) BOOL didSetupApplicationInsightsSDK;
	@end

	@implementation TodayViewController

	- (void)viewDidLoad {
		[super viewDidLoad];
		if (!self.didSetupApplicationInsightsSDK) {
			[MSAIApplicationInsights setup];
			[MSAIApplicationInsights start];
          self.didSetupApplicationInsightsSDK = YES;
       }
    }
    ```
 
<a id="options"></a> 
## Additional Options

### Set up with xcconfig

Instead of manually adding the missing frameworks, you can also use our bundled xcconfig file.

1. Select your project in the `Project Navigator` (⌘+1).

2. Select your project.

3. Select the tab `Info`.

4. Expand `Configurations`.

5. Select `ApplicationInsights.xcconfig` for all your configurations (if you don't already use a `.xcconfig` file)

	**Note:** You can also add the required frameworks manually to your targets `Build Phases` and continue with step `7.` instead.

6. If you are already using a `.xcconfig` file, simply add the following line to it

	`#include "../Vendor/ApplicationInsights/Support/ApplicationInsights.xcconfig"`

	(Adjust the path depending where the `Project.xcconfig` file is located related to the Xcode project package)

	**Important note:** Check if you overwrite any of the build settings and add a missing `$(inherited)` entry on the projects build settings level, so the `ApplicationInsights.xcconfig` settings will be passed through successfully.

7. If you are getting build warnings, then the `.xcconfig` setting wasn't included successfully or its settings in `Other Linker Flags` get ignored because `$(inherited)` is missing on project or target level. Either add `$(inherited)` or link the following frameworks manually in `Link Binary With Libraries` under `Build Phases`:
	- `UIKit`
	- `Foundation`
	- `SystemConfiguration`
	- `Security`
	- `CoreTelephony`(only required if iOS > 7.0)

### Setup with CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like ApplicationInsights in your projects. To learn how to setup cocoapods for your project, visit the [official cocoapods website](http://cocoapods.org/).

**[NOTE]**
When adding Application Insights to your podfile **without** specifying the version, `pod install` will throw an error because using a pre-release version of a pod has to be specified **explicitly**.
As soon as Application Insights 1.0 is available, the version doesn't have to be specified in your podfile anymore. 

#### Podfile

```ruby
platform :ios, '8.0'
pod "ApplicationInsights", '1.0-beta.1'
```

<a id="contact"></a>
## Contact

If you have further questions or are running into trouble that cannot be resolved by any of the steps here, feel free to contact us at [AppInsights-iOS@microsoft.com](mailto:AppInsights-ios@microsoft.com)
