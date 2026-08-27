#import "AdMobMentaAdapter.h"

#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

#import "AdMobMentaAdapterUtils.h"
#import "AdMobMentaBannerAdapter.h"
#import "AdMobMentaInterstitialAdapter.h"
#import "AdMobMentaNativeAdapter.h"
#import "AdMobMentaRewardedAdapter.h"
#import "AdMobMentaSplashAdapter.h"

@implementation AdMobMentaAdapterExtras
@end

@implementation AdMobMentaAdapter {
    AdMobMentaSplashAdapter *_splashAd;
    AdMobMentaBannerAdapter *_bannerAd;
    AdMobMentaInterstitialAdapter *_interstitialAd;
    AdMobMentaRewardedAdapter *_rewardedAd;
    AdMobMentaNativeAdapter *_nativeAd;
    MentaMediationBanner *_signalCollector;
}

#pragma mark - GADMediationAdapter

- (void)loadAppOpenAdForAdConfiguration:(GADMediationAppOpenAdConfiguration *)adConfiguration
                      completionHandler:(GADMediationAppOpenLoadCompletionHandler)completionHandler {
    __weak AdMobMentaAdapter *weakSelf = self;
    AdMobMentaAdapterInitializeSDK(adConfiguration.credentials.settings, adConfiguration.extras, ^(NSError *_Nullable error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        AdMobMentaAdapter *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf->_splashAd = [[AdMobMentaSplashAdapter alloc] init];
        [strongSelf->_splashAd loadAppOpenAdForAdConfiguration:adConfiguration completionHandler:completionHandler];
    });
}

- (void)loadBannerForAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration
                   completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler {
    __weak AdMobMentaAdapter *weakSelf = self;
    AdMobMentaAdapterInitializeSDK(adConfiguration.credentials.settings, adConfiguration.extras, ^(NSError *_Nullable error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        AdMobMentaAdapter *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf->_bannerAd = [[AdMobMentaBannerAdapter alloc] init];
        [strongSelf->_bannerAd loadBannerForAdConfiguration:adConfiguration completionHandler:completionHandler];
    });
}

- (void)loadInterstitialForAdConfiguration:(GADMediationInterstitialAdConfiguration *)adConfiguration
                         completionHandler:(GADMediationInterstitialLoadCompletionHandler)completionHandler {
    __weak AdMobMentaAdapter *weakSelf = self;
    AdMobMentaAdapterInitializeSDK(adConfiguration.credentials.settings, adConfiguration.extras, ^(NSError *_Nullable error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        AdMobMentaAdapter *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf->_interstitialAd = [[AdMobMentaInterstitialAdapter alloc] init];
        [strongSelf->_interstitialAd loadInterstitialForAdConfiguration:adConfiguration completionHandler:completionHandler];
    });
}

- (void)loadRewardedAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                       completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {
    __weak AdMobMentaAdapter *weakSelf = self;
    AdMobMentaAdapterInitializeSDK(adConfiguration.credentials.settings, adConfiguration.extras, ^(NSError *_Nullable error) {
       if (error) {
           completionHandler(nil, error);
           return;
       }
       AdMobMentaAdapter *strongSelf = weakSelf;
       if (!strongSelf) {
           return;
       }
       strongSelf->_rewardedAd = [[AdMobMentaRewardedAdapter alloc] init];
       [strongSelf->_rewardedAd loadRewardedAdForAdConfiguration:adConfiguration completionHandler:completionHandler];
   });
}

- (void)loadRewardedInterstitialAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                                   completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {
    [self loadRewardedAdForAdConfiguration:adConfiguration completionHandler:completionHandler];
}

- (void)loadNativeAdForAdConfiguration:(GADMediationNativeAdConfiguration *)adConfiguration
                     completionHandler:(GADMediationNativeLoadCompletionHandler)completionHandler {
    __weak AdMobMentaAdapter *weakSelf = self;
    AdMobMentaAdapterInitializeSDK(adConfiguration.credentials.settings, adConfiguration.extras, ^(NSError *_Nullable error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        AdMobMentaAdapter *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf->_nativeAd = [[AdMobMentaNativeAdapter alloc] init];
        [strongSelf->_nativeAd loadNativeAdForAdConfiguration:adConfiguration completionHandler:completionHandler];
    });
}

#pragma mark - GADRTBAdapter

- (void)collectSignalsForRequestParameters:(GADRTBRequestParameters *)params
                         completionHandler:(GADRTBSignalCompletionHandler)completionHandler {
    GADMediationCredentials *credentials = params.configuration.credentials.firstObject;
    NSString *placementID = nil;
    if (credentials) {
        // Build a temporary configuration-like lookup from credentials + extras.
        NSDictionary<NSString *, id> *settings = credentials.settings;
        placementID = settings[@"placementId"] ?: settings[@"placementID"] ?: settings[@"parameter"] ?: settings[@"slotId"];
        if ([placementID isKindOfClass:NSString.class]) {
            placementID = [placementID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        } else {
            placementID = nil;
        }
    }
    if ([params.extras isKindOfClass:AdMobMentaAdapterExtras.class]) {
        NSString *extrasPlacement = ((AdMobMentaAdapterExtras *)params.extras).placementId;
        if (extrasPlacement.length) {
            placementID = extrasPlacement;
        }
    }

    if (!placementID.length) {
        completionHandler(nil, AdMobMentaAdapterError(AdMobMentaAdapterErrorInvalidServerParameters,
                                                      @"Missing Menta placement ID for signal collection."));
        return;
    }

    __weak AdMobMentaAdapter *weakSelf = self;
    AdMobMentaAdapterInitializeSDK(credentials.settings ?: @{}, params.extras, ^(NSError *_Nullable error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }

        AdMobMentaAdapter *strongSelf = weakSelf;
        if (!strongSelf) {
            completionHandler(nil, AdMobMentaAdapterError(AdMobMentaAdapterErrorSignalCollectionFailure,
                                                          @"Adapter was deallocated during signal collection."));
            return;
        }

        strongSelf->_signalCollector = [[MentaMediationBanner alloc] initWithPlacementID:placementID];
        [strongSelf->_signalCollector fetchS2SSDKInfo:^(NSString *_Nullable info, NSError *_Nullable fetchError) {
            if (fetchError || !info.length) {
                completionHandler(nil, fetchError ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorSignalCollectionFailure,
                                                                            @"Menta failed to collect bidding signals."));
                return;
            }
            completionHandler(info, nil);
        }];
    });
}

@end
