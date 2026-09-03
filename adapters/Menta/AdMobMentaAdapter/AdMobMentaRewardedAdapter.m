#import "AdMobMentaRewardedAdapter.h"

#include <stdatomic.h>

#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

#import "AdMobMentaAdapterUtils.h"

@interface AdMobMentaRewardedAdapter () <GADMediationRewardedAd, MentaMediationRewardVideoDelegate>
- (void)loadRewardedAdAfterSDKReady:(GADMediationRewardedAdConfiguration *)adConfiguration
                  completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler;
@end

@implementation AdMobMentaRewardedAdapter {
    MentaMediationRewardVideo *_rewardedAd;
    NSString *_bidResponse;
    GADMediationRewardedLoadCompletionHandler _loadCompletionHandler;
    id<GADMediationRewardedAdEventDelegate> _adEventDelegate;
}

- (void)loadRewardedAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                       completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {
    __weak typeof(self) weakSelf = self;
    AdMobMentaAdapterInitializeThenLoad(
        adConfiguration,
        ^{
            [weakSelf loadRewardedAdAfterSDKReady:adConfiguration completionHandler:completionHandler];
        },
        ^(NSError *error) {
            completionHandler(nil, error);
        });
}

- (void)loadRewardedInterstitialAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                                   completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {
    [self loadRewardedAdForAdConfiguration:adConfiguration completionHandler:completionHandler];
}

- (void)loadRewardedAdAfterSDKReady:(GADMediationRewardedAdConfiguration *)adConfiguration
                  completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationRewardedLoadCompletionHandler originalCompletionHandler = [completionHandler copy];
    _loadCompletionHandler =
        ^id<GADMediationRewardedAdEventDelegate>(_Nullable id<GADMediationRewardedAd> ad, NSError *_Nullable error) {
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }
        id<GADMediationRewardedAdEventDelegate> delegate = nil;
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
    _rewardedAd = [[MentaMediationRewardVideo alloc] initWithPlacementID:placementID];
    _rewardedAd.delegate = self;

    if (_bidResponse.length) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
        return;
    }

    [_rewardedAd loadAd];
}

#pragma mark - GADMediationRewardedAd

- (void)presentFromViewController:(UIViewController *)viewController {
    if (_bidResponse.length) {
        [_rewardedAd sendWinnerNotificationWith:nil];
        [_rewardedAd showAdFromRootViewController:viewController adm:_bidResponse];
        return;
    }

    if (![_rewardedAd isAdReady]) {
        [_adEventDelegate didFailToPresentWithError:AdMobMentaAdapterError(AdMobMentaAdapterErrorAdNotReady,
                                                                           @"Menta rewarded ad is not ready.")];
        return;
    }

    [_rewardedAd sendWinnerNotificationWith:nil];
    [_rewardedAd showAdFromRootViewController:viewController];
}

#pragma mark - MentaMediationRewardVideoDelegate

- (void)menta_rewardVideoDidLoad:(MentaMediationRewardVideo *)rewardVideo {
}

- (void)menta_rewardVideoLoadFailedWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta rewarded ad failed to load."));
}

- (void)menta_rewardVideoRenderSuccess:(MentaMediationRewardVideo *)rewardVideo {
    if (!_adEventDelegate) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
    }
}

- (void)menta_rewardVideoRenderFailureWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    if (!_adEventDelegate) {
        _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta rewarded ad failed to render."));
        return;
    }
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)menta_rewardVideoWillPresent:(MentaMediationRewardVideo *)rewardVideo {
    [_adEventDelegate willPresentFullScreenView];
    [_adEventDelegate didStartVideo];
}

- (void)menta_rewardVideoShowFailWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)menta_rewardVideoExposed:(MentaMediationRewardVideo *)rewardVideo {
    [_adEventDelegate reportImpression];
}

- (void)menta_rewardVideoClicked:(MentaMediationRewardVideo *)rewardVideo {
    [_adEventDelegate reportClick];
}

- (void)menta_rewardVideoSkiped:(MentaMediationRewardVideo *)rewardVideo {
}

- (void)menta_rewardVideoDidEarnReward:(MentaMediationRewardVideo *)rewardVideo {
    [_adEventDelegate didRewardUser];
}

- (void)menta_rewardVideoPlayCompleted:(MentaMediationRewardVideo *)rewardVideo {
    [_adEventDelegate didEndVideo];
}

- (void)menta_rewardVideoClosed:(MentaMediationRewardVideo *)rewardVideo {
    [_adEventDelegate willDismissFullScreenView];
    [_adEventDelegate didDismissFullScreenView];
}

@end
