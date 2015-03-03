#import <Foundation/Foundation.h>

/**
* A simple class that handles serialisation and deserialisation of bundles of data.
*/

@interface MSAIPersistence : NSObject

/**
* Notification that will be send on the main thread to notifiy observers of a successfully saved bundle.
* This is typically used to trigger sending to the server.
*/
FOUNDATION_EXPORT NSString *const kMSAIPersistenceSuccessNotification;
FOUNDATION_EXPORT NSString *const kUserInfoFilePath;


/**
* The MSAIPersistenceType determines the way how a bundle is saved.
* Bundles of type MSAIPersistenceTypeHighPriority will be loaded before all bundles if type MSAIPersistenceTypeRegular.
*/

typedef NS_ENUM(NSInteger, MSAIPersistenceType) {
  MSAIPersistenceTypeHighPriority = 0,
  MSAIPersistenceTypeRegular = 1,
  MSAIPersistenceTypeFakeCrash = 2
};

///-----------------------------------------------------------------------------
/// @name Save/delete bundle of data
///-----------------------------------------------------------------------------

/**
* Saves the bundle and sends out a kMSAIPersistenceSuccessNotification in case of success
* for all types except MSAIPersistenceTypeFakeCrash
* @param bundle a bundle of tracked events (telemetry, crashes, ...) that will be serialized and saved.
* @param type The type of the bundle we want to save.
* @param completionBlock An optional block that will be executed after we have tried to save the bundle.
*
* @warning: The data within the array needs to implement NSCoding.
*/
+ (void)persistBundle:(NSArray *)bundle ofType:(MSAIPersistenceType)type withCompletionBlock:(void (^)(BOOL success))completionBlock;

/**
 *  Deletes the file for the given path.
 *
 *  @param path the path of the file, which should be deleted
 */
+ (void)deleteBundleAtPath:(NSString *)path ;

/**
 *  Determines whether the persistence layer is able to write more files to disk.
 *
 *  @return YES if the maxFileCount has not been reached, yet (otherwise NO).
 */
+ (BOOL)isFreeSpaceAvailable;

/**
 *  Set the count of files, that can be written to disk by the SDK.
 *
 *  @param maxFileCount number of files that can be on disk
 */
+ (void)setMaxFileCount:(NSUInteger)maxFileCount;

///-----------------------------------------------------------------------------
/// @name Get a bundle of saved data
///-----------------------------------------------------------------------------

/**
* Get a bundle of previously saved data from disk and deletes it using dispatch_sync.
*
* @warning Make sure nextBundle is not called from the main thread.
*
* It will return bundles of MSAIPersistenceType first.
* Between bundles of the same MSAIPersistenceType, the order is arbitrary.
* Returns 'nil' if no bundle is available
*
* @return a bundle of AppInsightsData that's ready to be sent to the server
*/

/**
 *  Returns the path for the next item to send.
 *
 *  @return the path of the item, which should be sent next
 */
+ (NSString *)nextPath;

/**
 *  Return the bundle for a given path.
 *
 *  @param path the path of the bundle.
 *
 *  @return an array with all envelope objects.
 */
+ (NSArray *)bundleAtPath:(NSString *)path;

///-----------------------------------------------------------------------------
/// @name Handling of a "fake" CrashReport
///-----------------------------------------------------------------------------

/**
* Persist a "fake" crash report.
*
* @param bundle The bundle of application insights data
*/
+ (void)persistFakeReportBundle:(NSArray *)bundle;

/**
* Get the first of all saved fake crash reports (an arbitrary one in case we have several fake reports)
*
* @return a fake crash report, wrapped as a bundle
*/
+ (NSArray *)fakeReportBundle;

@end
