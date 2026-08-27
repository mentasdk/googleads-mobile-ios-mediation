#import "AdMobMentaSplashAdapter.h"

#include <stdatomic.h>

#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

#import "AdMobMentaAdapterUtils.h"

@interface AdMobMentaSplashAdapter () <GADMediationAppOpenAd, MentaMediationSplashDelegate>
- (void)loadAppOpenAdAfterSDKReady:(GADMediationAppOpenAdConfiguration *)adConfiguration
                 completionHandler:(GADMediationAppOpenLoadCompletionHandler)completionHandler;
@end

@implementation AdMobMentaSplashAdapter {
    MentaMediationSplash *_splashAd;
    NSString *_bidResponse;
    GADMediationAppOpenLoadCompletionHandler _loadCompletionHandler;
    id<GADMediationAppOpenAdEventDelegate> _adEventDelegate;
}

- (void)loadAppOpenAdForAdConfiguration:(GADMediationAppOpenAdConfiguration *)adConfiguration
                      completionHandler:(GADMediationAppOpenLoadCompletionHandler)completionHandler {
    __weak typeof(self) weakSelf = self;
    AdMobMentaAdapterInitializeThenLoad(
        adConfiguration,
        ^{
            [weakSelf loadAppOpenAdAfterSDKReady:adConfiguration completionHandler:completionHandler];
        },
        ^(NSError *error) {
            completionHandler(nil, error);
        });
}

- (void)loadAppOpenAdAfterSDKReady:(GADMediationAppOpenAdConfiguration *)adConfiguration
                 completionHandler:(GADMediationAppOpenLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationAppOpenLoadCompletionHandler originalCompletionHandler = [completionHandler copy];
    _loadCompletionHandler =
        ^id<GADMediationAppOpenAdEventDelegate>(_Nullable id<GADMediationAppOpenAd> ad, NSError *_Nullable error) {
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }
        id<GADMediationAppOpenAdEventDelegate> delegate = nil;
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
    _splashAd = [[MentaMediationSplash alloc] initWithPlacementID:placementID];
    _splashAd.delegate = self;

    // S2S / RTB: adm is rendered at show time.
    if (_bidResponse.length) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
        return;
    }

    [_splashAd loadSplashAd];
}

#pragma mark - GADMediationAppOpenAd

- (void)presentFromViewController:(UIViewController *)viewController {
    UIWindow *window = AdMobMentaAdapterKeyWindow(viewController);
    if (!window) {
        [_adEventDelegate didFailToPresentWithError:AdMobMentaAdapterError(AdMobMentaAdapterErrorAdNotReady,
                                                                           @"Unable to find a window to present splash.")];
        return;
    }

    if (_bidResponse.length) {
        [_splashAd sendWinnerNotificationWith:nil];
        [_splashAd showAdInWindow:window adm:_bidResponse];
        return;
    }

    if (![_splashAd isAdReady]) {
        [_adEventDelegate didFailToPresentWithError:AdMobMentaAdapterError(AdMobMentaAdapterErrorAdNotReady,
                                                                           @"Menta splash ad is not ready.")];
        return;
    }

    [_splashAd sendWinnerNotificationWith:nil];
    [_splashAd showAdInWindow:window];
}

#pragma mark - MentaMediationSplashDelegate

- (void)menta_splashAdDidLoad:(MentaMediationSplash *)splash {
}

- (void)menta_splashAdLoadFailedWithError:(NSError *)error splash:(MentaMediationSplash *)splash {
    _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta splash failed to load."));
}

- (void)menta_splashAdRenderSuccess:(MentaMediationSplash *)splash {
    if (!_adEventDelegate) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
    }
}

- (void)menta_splashAdRenderFailureWithError:(NSError *)error splash:(MentaMediationSplash *)splash {
    if (!_adEventDelegate) {
        _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta splash failed to render."));
        return;
    }
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)menta_splashAdWillPresent:(MentaMediationSplash *)splash {
    [_adEventDelegate willPresentFullScreenView];
}

- (void)menta_splashAdShowFailWithError:(NSError *)error splash:(MentaMediationSplash *)splash {
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)menta_splashAdExposed:(MentaMediationSplash *)splash {
    [_adEventDelegate reportImpression];
}

- (void)menta_splashAdClicked:(MentaMediationSplash *)splash {
    [_adEventDelegate reportClick];
}

- (void)menta_splashAdClosed:(MentaMediationSplash *)splash {
    [_adEventDelegate willDismissFullScreenView];
    [_adEventDelegate didDismissFullScreenView];
}

@end
