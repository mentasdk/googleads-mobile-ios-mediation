#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "AdMobMentaBaseAdapter.h"

typedef NS_ENUM(NSInteger, AdMobMentaAdapterErrorCode) {
    /// Missing or invalid AdMob mapping parameters.
    AdMobMentaAdapterErrorInvalidServerParameters = 101,
    /// Menta SDK failed to initialize.
    AdMobMentaAdapterErrorInitializationFailure = 102,
    /// The ad is not ready to present.
    AdMobMentaAdapterErrorAdNotReady = 103,
    /// Menta returned a load / render failure.
    AdMobMentaAdapterErrorAdLoadFailure = 104,
    /// Signal collection failed.
    AdMobMentaAdapterErrorSignalCollectionFailure = 105
};

/// Optional extras publishers can attach via GADRequest.registerAdNetworkExtras:.
@interface AdMobMentaAdapterExtras : NSObject <GADAdNetworkExtras>
@property(nonatomic, copy, nullable) NSString *appId;
@property(nonatomic, copy, nullable) NSString *appKey;
@property(nonatomic, copy, nullable) NSString *placementId;
@end

/// AdMob mediation adapter entry point. Register this class name, or a format class such as
/// AdMobMentaInterstitialAdapter, in the AdMob UI.
@interface AdMobMentaAdapter : AdMobMentaBaseAdapter <GADRTBAdapter>
@end
