#import "AdMobMentaInterstitialAdapter.h"

#include <stdatomic.h>

#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

#import "AdMobMentaAdapterUtils.h"

@interface AdMobMentaInterstitialAdapter () <GADMediationInterstitialAd, MentaMediationInterstitialDelegate>
- (void)loadInterstitialAfterSDKReady:(GADMediationInterstitialAdConfiguration *)adConfiguration
                    completionHandler:(GADMediationInterstitialLoadCompletionHandler)completionHandler;
@end

@implementation AdMobMentaInterstitialAdapter {
    MentaMediationInterstitial *_interstitialAd;
    NSString *_bidResponse;
    GADMediationInterstitialLoadCompletionHandler _loadCompletionHandler;
    id<GADMediationInterstitialAdEventDelegate> _adEventDelegate;
}

- (void)loadInterstitialForAdConfiguration:(GADMediationInterstitialAdConfiguration *)adConfiguration
                         completionHandler:(GADMediationInterstitialLoadCompletionHandler)completionHandler {
    __weak typeof(self) weakSelf = self;
    AdMobMentaAdapterInitializeThenLoad(
        adConfiguration,
        ^{
            [weakSelf loadInterstitialAfterSDKReady:adConfiguration completionHandler:completionHandler];
        },
        ^(NSError *error) {
            completionHandler(nil, error);
        });
}

- (void)loadInterstitialAfterSDKReady:(GADMediationInterstitialAdConfiguration *)adConfiguration
                    completionHandler:(GADMediationInterstitialLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationInterstitialLoadCompletionHandler originalCompletionHandler = [completionHandler copy];
    _loadCompletionHandler = ^id<GADMediationInterstitialAdEventDelegate>(_Nullable id<GADMediationInterstitialAd> ad,
                                                                          NSError *_Nullable error) {
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }
        id<GADMediationInterstitialAdEventDelegate> delegate = nil;
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

    _bidResponse = AdMobMentaAdapterBidResponse(adConfiguration);
    _interstitialAd = [[MentaMediationInterstitial alloc] initWithPlacementID:placementID];
    _interstitialAd.delegate = self;

    if (_bidResponse.length) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
        return;
    }

    [_interstitialAd loadAd];
}

#pragma mark - GADMediationInterstitialAd

- (void)presentFromViewController:(UIViewController *)viewController {
    if (_bidResponse.length) {
        [_interstitialAd sendWinnerNotificationWith:nil];
        [_interstitialAd showAdFromRootViewController:viewController adm:_bidResponse];
        return;
    }

    if (![_interstitialAd isAdReady]) {
        [_adEventDelegate didFailToPresentWithError:AdMobMentaAdapterError(AdMobMentaAdapterErrorAdNotReady,
                                                                           @"Menta interstitial ad is not ready.")];
        return;
    }

    [_interstitialAd sendWinnerNotificationWith:nil];
    [_interstitialAd showAdFromRootViewController:viewController];
}

#pragma mark - MentaMediationInterstitialDelegate

- (void)menta_interstitialDidLoad:(MentaMediationInterstitial *)interstitial {
}

- (void)menta_interstitialLoadFailedWithError:(NSError *)error interstitial:(MentaMediationInterstitial *)interstitial {
    _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta interstitial failed to load."));
}

- (void)menta_interstitialRenderSuccess:(MentaMediationInterstitial *)interstitial {
    if (!_adEventDelegate) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
    }
}

- (void)menta_interstitialRenderFailureWithError:(NSError *)error
                                    interstitial:(MentaMediationInterstitial *)interstitial {
    if (!_adEventDelegate) {
        _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta interstitial failed to render."));
        return;
    }
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)menta_interstitialWillPresent:(MentaMediationInterstitial *)interstitial {
    [_adEventDelegate willPresentFullScreenView];
}

- (void)menta_interstitialShowFailWithError:(NSError *)error interstitial:(MentaMediationInterstitial *)interstitial {
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)menta_interstitialExposed:(MentaMediationInterstitial *)interstitial {
    [_adEventDelegate reportImpression];
}

- (void)menta_interstitialClicked:(MentaMediationInterstitial *)interstitial {
    [_adEventDelegate reportClick];
}

- (void)menta_interstitialPlayCompleted:(MentaMediationInterstitial *)interstitial {
}

- (void)menta_interstitialClosed:(MentaMediationInterstitial *)interstitial {
    [_adEventDelegate willDismissFullScreenView];
    [_adEventDelegate didDismissFullScreenView];
}

@end
