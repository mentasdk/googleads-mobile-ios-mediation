#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "AdMobMentaAdapter.h"

NS_ASSUME_NONNULL_BEGIN

/// Builds an adapter NSError.
NSError *_Nonnull AdMobMentaAdapterError(AdMobMentaAdapterErrorCode code, NSString *_Nonnull description);

/// Returns a trimmed string or nil.
NSString *_Nullable AdMobMentaAdapterStringValue(id _Nullable value);

/// Placement ID from AdMob credentials / extras / JSON parameter.
NSString *_Nullable AdMobMentaAdapterPlacementID(GADMediationAdConfiguration *_Nonnull config);

/// Bid response (S2S adm) from the GMA ad configuration.
NSString *_Nullable AdMobMentaAdapterBidResponse(GADMediationAdConfiguration *_Nonnull config);

/// Reads appId / appKey from extras, then from the given settings dictionaries.
void AdMobMentaAdapterExtractAppCredentials(NSArray<NSDictionary<NSString *, id> *> *_Nullable settingsList,
                                            id<GADAdNetworkExtras> _Nullable extras,
                                            NSString *_Nullable *_Nonnull appId, NSString *_Nullable *_Nonnull appKey);

/// Initializes MentaAdSDK once. Completion is always invoked on the main queue.
void AdMobMentaAdapterInitializeSDK(NSDictionary<NSString *, id> *_Nullable settings,
                                    id<GADAdNetworkExtras> _Nullable extras,
                                    void (^_Nonnull completion)(NSError *_Nullable error));

/// Initializes from an AdMob server configuration (all mapping credentials).
void AdMobMentaAdapterInitializeSDKWithServerConfiguration(GADMediationServerConfiguration *_Nonnull configuration,
                                                           void (^_Nonnull completion)(NSError *_Nullable error));

/// Initializes Menta, then runs loadBlock. failBlock is called on the main queue if init fails.
void AdMobMentaAdapterInitializeThenLoad(GADMediationAdConfiguration *_Nonnull config,
                                         void (^_Nonnull loadBlock)(void),
                                         void (^_Nonnull failBlock)(NSError *_Nonnull error));

/// Parses a dotted version string into a GADVersionNumber.
GADVersionNumber AdMobMentaAdapterVersionFromString(NSString *_Nullable versionString, BOOL adapterVersion);

/// Key window used to present splash ads.
UIWindow *_Nullable AdMobMentaAdapterKeyWindow(UIViewController *_Nullable viewController);

NS_ASSUME_NONNULL_END
