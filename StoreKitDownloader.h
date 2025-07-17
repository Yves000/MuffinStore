#import <Foundation/Foundation.h>

@interface StoreKitDownloader : NSObject

+ (instancetype)sharedInstance;
- (void)downloadAppWithAppId:(long long)appId versionId:(long long)versionId;

@end