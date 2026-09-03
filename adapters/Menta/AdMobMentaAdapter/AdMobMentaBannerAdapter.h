#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "AdMobMentaBaseAdapter.h"

@interface AdMobMentaBannerAdapter : AdMobMentaBaseAdapter

- (void)loadBannerForAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration
                   completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler;

@end
