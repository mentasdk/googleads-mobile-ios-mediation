#import "AdMobMentaBannerAdapter.h"

#include <stdatomic.h>

#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

#import "AdMobMentaAdapterUtils.h"

@interface AdMobMentaBannerAdapter () <GADMediationBannerAd, MentaMediationBannerDelegate>
- (void)loadBannerAfterSDKReady:(GADMediationBannerAdConfiguration *)adConfiguration
              completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler;
@end

@implementation AdMobMentaBannerAdapter {
    MentaMediationBanner *_bannerAd;
    UIView *_bannerView;
    GADMediationBannerLoadCompletionHandler _loadCompletionHandler;
    id<GADMediationBannerAdEventDelegate> _adEventDelegate;
}

- (void)loadBannerForAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration
                   completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler {
    __weak typeof(self) weakSelf = self;
    AdMobMentaAdapterInitializeThenLoad(
        adConfiguration,
        ^{
            [weakSelf loadBannerAfterSDKReady:adConfiguration completionHandler:completionHandler];
        },
        ^(NSError *error) {
            completionHandler(nil, error);
        });
}

- (void)loadBannerAfterSDKReady:(GADMediationBannerAdConfiguration *)adConfiguration
              completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationBannerLoadCompletionHandler originalCompletionHandler = [completionHandler copy];
    _loadCompletionHandler = ^id<GADMediationBannerAdEventDelegate>(_Nullable id<GADMediationBannerAd> ad, NSError *_Nullable error) {
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }
        id<GADMediationBannerAdEventDelegate> delegate = nil;
        if (originalCompletionHandler) {
            delegate = originalCompletionHandler(ad, error);
        }
        originalCompletionHandler = nil;
        return delegate;
    };

    NSString *placementID = AdMobMentaAdapterPlacementID(adConfiguration);
    if (!placementID.length) {
        _loadCompletionHandler(nil, AdMobMentaAdapterError(AdMobMentaAdapterErrorInvalidServerParameters, @"Missing Menta placement ID."));
        return;
    }

    _bannerAd = [[MentaMediationBanner alloc] initWithPlacementID:placementID];
    _bannerAd.delegate = self;
    // AdMob publishers own the banner lifecycle; hide Menta's close button.
    // _bannerAd.displayConfig.hideCloseButton = YES;

    NSString *bidResponse = AdMobMentaAdapterBidResponse(adConfiguration);
    if (bidResponse.length) {
        [_bannerAd loadAdWithAdm:bidResponse];
    } else {
        [_bannerAd loadAd];
    }
}

#pragma mark - GADMediationBannerAd

- (UIView *)view {
    return _bannerView ?: _bannerAd.bannerAdView ?: [[UIView alloc] init];
}

#pragma mark - MentaMediationBannerDelegate

- (void)menta_bannerAdDidLoad:(MentaMediationBanner *)banner {
}

- (void)menta_bannerAdLoadFailedWithError:(NSError *)error banner:(MentaMediationBanner *)banner {
    _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta banner failed to load."));
}

- (void)menta_bannerAdRenderSuccess:(MentaMediationBanner *)banner bannerAdView:(UIView *)bannerAdView {
    _bannerView = bannerAdView ?: banner.bannerAdView;
    if (!_bannerView) {
        _adEventDelegate = _loadCompletionHandler(nil, AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta banner rendered without a view."));
        return;
    }
    [_bannerAd sendWinnerNotificationWith:nil];
    _adEventDelegate = _loadCompletionHandler(self, nil);
}

- (void)menta_bannerAdRenderFailureWithError:(NSError *)error banner:(MentaMediationBanner *)banner {
    _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta banner failed to render."));
}

- (void)menta_bannerAdExposed:(MentaMediationBanner *)banner {
    [_adEventDelegate reportImpression];
}

- (void)menta_bannerAdClicked:(MentaMediationBanner *)banner {
    [_adEventDelegate reportClick];
}

- (void)menta_bannerAdClosed:(MentaMediationBanner *)banner {
    [_adEventDelegate willDismissFullScreenView];
    [_adEventDelegate didDismissFullScreenView];
}

@end
