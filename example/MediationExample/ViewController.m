//
// Copyright (C) 2015 Google, Inc.
//
// ViewController.m
// Mediation Example
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "ViewController.h"

#import <GoogleMobileAds/GoogleMobileAds.h>
#import <SampleAdSDK/SampleAdSDK.h>

#import "AdLogStore.h"
#import "AdLogViewController.h"
#import "ExampleNativeAdView.h"

@interface ViewController () <GADFullScreenContentDelegate,
                              GADNativeAdLoaderDelegate,
                              GADBannerViewDelegate,
                              GADNativeAdDelegate>

@property(nonatomic, strong) AdSourceConfig *config;

@property(nonatomic, weak) IBOutlet GADBannerView *bannerAdView;

@property(weak, nonatomic) IBOutlet UIButton *appOpenButton;

@property(nonatomic, weak) IBOutlet UIButton *interstitialButton;

@property(nonatomic, weak) IBOutlet UIButton *rewardedButton;

@property(weak, nonatomic) IBOutlet UIButton *rewardedInterstitialButton;

@property(nonatomic, weak) IBOutlet UIView *nativeAdPlaceholder;

@property(nonatomic, strong) GADAppOpenAd *appOpenAd;

@property(nonatomic, strong) GADInterstitialAd *interstitial;

@property(nonatomic, strong) GADRewardedAd *rewardedAd;

@property(nonatomic, strong) GADRewardedInterstitialAd *rewardedInterstitialAd;

@property(nonatomic, strong) GADNativeAd *nativeAd;

/// You must keep a strong reference to the GADAdLoader during the ad loading process.
@property(nonatomic, strong) GADAdLoader *adLoader;

/// Shows the most recently loaded interstitial ad in response to a button tap.
- (IBAction)showInterstitial:(UIButton *)sender;

/// Shows the most recently loaded rewarded ad in response to a button tap.
- (IBAction)showRewarded:(UIButton *)sender;

/// Shows the most recently loaded rewarded interstitial ad in response to a button tap.
- (IBAction)showRewardedInterstitial:(UIButton *)sender;

@end

static void LogAdEvent(AdLogSlot slot, NSString *event, NSString *detail) {
  [[AdLogStore sharedStore] logSlot:slot event:event detail:detail];
  if (detail.length > 0) {
    NSLog(@"[AdLog][%@] %@ — %@", AdLogSlotTitle(slot), event, detail);
  } else {
    NSLog(@"[AdLog][%@] %@", AdLogSlotTitle(slot), event);
  }
}

@implementation ViewController

+ (instancetype)controllerWithAdSourceConfig:(AdSourceConfig *)adSourceConfig {
  ViewController *controller = [[UIStoryboard storyboardWithName:@"Main" bundle:nil]
      instantiateViewControllerWithIdentifier:@"ViewController"];
  controller.config = adSourceConfig;
  return controller;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = self.config.title;
  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:@"日志"
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(showAdLogs)];

  self.bannerAdView.adUnitID = self.config.bannerAdUnitID;
  self.bannerAdView.rootViewController = self;
  self.bannerAdView.delegate = self;
  LogAdEvent(AdLogSlotBanner, @"开始加载", self.config.bannerAdUnitID);
  [self.bannerAdView loadRequest:[GADRequest request]];

  [self requestAppOpen];
  [self requestInterstitial];
  [self requestRewarded];
  [self requestRewardedInterstitial];
  [self refreshNativeAd:nil];
}

- (void)showAdLogs {
  AdLogViewController *logs = [[AdLogViewController alloc] initWithInitialSlot:AdLogSlotAppOpen];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:logs];
  nav.modalPresentationStyle = UIModalPresentationPageSheet;
  if (@available(iOS 15.0, *)) {
    nav.sheetPresentationController.detents = @[
      [UISheetPresentationControllerDetent mediumDetent],
      [UISheetPresentationControllerDetent largeDetent]
    ];
    nav.sheetPresentationController.prefersGrabberVisible = YES;
    nav.sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = YES;
  }
  [self presentViewController:nav animated:YES completion:nil];
}

- (IBAction)refreshNativeAd:(id)sender {
  GADNativeAdViewAdOptions *adViewOptions = [[GADNativeAdViewAdOptions alloc] init];
  adViewOptions.preferredAdChoicesPosition = GADAdChoicesPositionTopRightCorner;

  self.adLoader = [[GADAdLoader alloc] initWithAdUnitID:self.config.nativeAdUnitID
                                     rootViewController:self
                                                adTypes:@[ GADAdLoaderAdTypeNative ]
                                                options:@[ adViewOptions ]];
  self.adLoader.delegate = self;
  LogAdEvent(AdLogSlotNative, @"开始加载", self.config.nativeAdUnitID);
  [self.adLoader loadRequest:[GADRequest request]];
}

- (void)requestAppOpen {
  LogAdEvent(AdLogSlotAppOpen, @"开始加载", self.config.appOpenAdUnitID);
  [GADAppOpenAd
       loadWithAdUnitID:self.config.appOpenAdUnitID
                request:[GADRequest request]
      completionHandler:^(GADAppOpenAd *_Nullable appOpenAd, NSError *_Nullable error) {
        if (error) {
          LogAdEvent(AdLogSlotAppOpen, @"加载失败", error.localizedDescription);
          return;
        }
        LogAdEvent(AdLogSlotAppOpen, @"加载成功", nil);
        self.appOpenAd = appOpenAd;
        self.appOpenAd.fullScreenContentDelegate = self;
      }];
}

- (IBAction)showAppOpen:(UIButton *)sender {
  if (self.appOpenAd) {
    LogAdEvent(AdLogSlotAppOpen, @"开始展示", nil);
    [self.appOpenAd presentFromRootViewController:self];
  } else {
    LogAdEvent(AdLogSlotAppOpen, @"广告未就绪", @"重新请求");
    [self requestAppOpen];
  }
}

- (void)requestInterstitial {
  LogAdEvent(AdLogSlotInterstitial, @"开始加载", self.config.interstitialAdUnitID);
  [GADInterstitialAd
       loadWithAdUnitID:self.config.interstitialAdUnitID
                request:[GADRequest request]
      completionHandler:^(GADInterstitialAd *ad, NSError *error) {
        if (error) {
          LogAdEvent(AdLogSlotInterstitial, @"加载失败", error.localizedDescription);
          return;
        }
        LogAdEvent(AdLogSlotInterstitial, @"加载成功", nil);
        self.interstitial = ad;
        self.interstitial.fullScreenContentDelegate = self;
      }];
}

- (IBAction)showInterstitial:(UIButton *)sender {
  if (self.interstitial) {
    LogAdEvent(AdLogSlotInterstitial, @"开始展示", nil);
    [self.interstitial presentFromRootViewController:self];
  } else {
    LogAdEvent(AdLogSlotInterstitial, @"广告未就绪", @"重新请求");
    [self requestInterstitial];
  }
}

- (void)requestRewarded {
  LogAdEvent(AdLogSlotRewarded, @"开始加载", self.config.rewardedAdUnitID);
  GADRequest *request = [GADRequest request];
  [GADRewardedAd loadWithAdUnitID:self.config.rewardedAdUnitID
                          request:request
                completionHandler:^(GADRewardedAd *ad, NSError *error) {
                  if (error) {
                    LogAdEvent(AdLogSlotRewarded, @"加载失败", error.localizedDescription);
                    return;
                  }
                  LogAdEvent(AdLogSlotRewarded, @"加载成功", nil);
                  self.rewardedAd = ad;
                  self.rewardedAd.fullScreenContentDelegate = self;
                }];
}

- (IBAction)showRewarded:(UIButton *)sender {
  if (self.rewardedAd) {
    LogAdEvent(AdLogSlotRewarded, @"开始展示", nil);
    [self.rewardedAd presentFromRootViewController:self
                          userDidEarnRewardHandler:^{
                            GADAdReward *reward = self.rewardedAd.adReward;
                            NSString *rewardMessage = [NSString
                                stringWithFormat:@"currency=%@ amount=%@", reward.type,
                                                 reward.amount];
                            LogAdEvent(AdLogSlotRewarded, @"获得激励", rewardMessage);
                          }];
  } else {
    LogAdEvent(AdLogSlotRewarded, @"广告未就绪", @"重新请求");
    [self requestRewarded];
  }
}

- (void)requestRewardedInterstitial {
  LogAdEvent(AdLogSlotRewardedInterstitial, @"开始加载",
             self.config.rewardedInterstitialAdUnitID);
  GADRequest *request = [GADRequest request];
  [GADRewardedInterstitialAd
       loadWithAdUnitID:self.config.rewardedInterstitialAdUnitID
                request:request
      completionHandler:^(GADRewardedInterstitialAd *_Nullable rewardedInterstitialAd,
                          NSError *_Nullable error) {
        if (error) {
          LogAdEvent(AdLogSlotRewardedInterstitial, @"加载失败", error.localizedDescription);
          return;
        }
        LogAdEvent(AdLogSlotRewardedInterstitial, @"加载成功", nil);
        self.rewardedInterstitialAd = rewardedInterstitialAd;
        self.rewardedInterstitialAd.fullScreenContentDelegate = self;
      }];
}

- (IBAction)showRewardedInterstitial:(UIButton *)sender {
  if (self.rewardedInterstitialAd) {
    LogAdEvent(AdLogSlotRewardedInterstitial, @"开始展示", nil);
    [self.rewardedInterstitialAd
        presentFromRootViewController:self
             userDidEarnRewardHandler:^{
               GADAdReward *reward = self.rewardedInterstitialAd.adReward;
               NSString *rewardMessage =
                   [NSString stringWithFormat:@"currency=%@ amount=%@", reward.type, reward.amount];
               LogAdEvent(AdLogSlotRewardedInterstitial, @"获得激励", rewardMessage);
             }];
  } else {
    LogAdEvent(AdLogSlotRewardedInterstitial, @"广告未就绪", @"重新请求");
    [self requestRewardedInterstitial];
  }
}

- (void)replaceNativeAdView:(UIView *)nativeAdView inPlaceholder:(UIView *)placeholder {
  // Remove anything currently in the placeholder.
  NSArray *currentSubviews = [placeholder.subviews copy];
  for (UIView *subview in currentSubviews) {
    [subview removeFromSuperview];
  }

  if (!nativeAdView) {
    return;
  }

  // Add new ad view and set constraints to fill its container.
  [placeholder addSubview:nativeAdView];
  nativeAdView.translatesAutoresizingMaskIntoConstraints = NO;

  NSDictionary *viewDictionary = NSDictionaryOfVariableBindings(nativeAdView);
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[nativeAdView]|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:viewDictionary]];
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[nativeAdView]|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:viewDictionary]];
}

- (AdLogSlot)slotForFullScreenAd:(id<GADFullScreenPresentingAd>)ad {
  if (ad == self.appOpenAd || [ad isKindOfClass:[GADAppOpenAd class]]) {
    return AdLogSlotAppOpen;
  }
  if (ad == self.rewardedInterstitialAd || [ad isKindOfClass:[GADRewardedInterstitialAd class]]) {
    return AdLogSlotRewardedInterstitial;
  }
  if (ad == self.rewardedAd || [ad isKindOfClass:[GADRewardedAd class]]) {
    return AdLogSlotRewarded;
  }
  if (ad == self.interstitial || [ad isKindOfClass:[GADInterstitialAd class]]) {
    return AdLogSlotInterstitial;
  }
  return AdLogSlotInterstitial;
}

#pragma mark GADFullScreenContentDelegate implementation

- (void)ad:(id<GADFullScreenPresentingAd>)ad
    didFailToPresentFullScreenContentWithError:(NSError *)error {
  LogAdEvent([self slotForFullScreenAd:ad], @"曝光失败", error.localizedDescription);
}

- (void)adWillPresentFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
  LogAdEvent([self slotForFullScreenAd:ad], @"展示成功", nil);
}

- (void)adDidRecordImpression:(id<GADFullScreenPresentingAd>)ad {
  LogAdEvent([self slotForFullScreenAd:ad], @"曝光成功", nil);
}

- (void)adDidRecordClick:(id<GADFullScreenPresentingAd>)ad {
  LogAdEvent([self slotForFullScreenAd:ad], @"点击", nil);
}

- (void)adWillDismissFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
  LogAdEvent([self slotForFullScreenAd:ad], @"即将关闭", nil);
}

- (void)adDidDismissFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
  AdLogSlot slot = [self slotForFullScreenAd:ad];
  LogAdEvent(slot, @"关闭", nil);
  switch (slot) {
    case AdLogSlotAppOpen:
      self.appOpenAd = nil;
      break;
    case AdLogSlotInterstitial:
      self.interstitial = nil;
      break;
    case AdLogSlotRewarded:
      self.rewardedAd = nil;
      break;
    case AdLogSlotRewardedInterstitial:
      self.rewardedInterstitialAd = nil;
      break;
    default:
      break;
  }
}

#pragma mark GADBannerViewDelegate implementation

- (void)bannerViewDidReceiveAd:(GADBannerView *)bannerView {
  LogAdEvent(AdLogSlotBanner, @"加载成功", nil);
}

- (void)bannerView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(NSError *)error {
  LogAdEvent(AdLogSlotBanner, @"加载失败", error.localizedDescription);
}

- (void)bannerViewDidRecordImpression:(GADBannerView *)bannerView {
  LogAdEvent(AdLogSlotBanner, @"曝光成功", nil);
}

- (void)bannerViewDidRecordClick:(GADBannerView *)bannerView {
  LogAdEvent(AdLogSlotBanner, @"点击", nil);
}

- (void)bannerViewWillPresentScreen:(GADBannerView *)bannerView {
  LogAdEvent(AdLogSlotBanner, @"即将打开落地页", nil);
}

- (void)bannerViewWillDismissScreen:(GADBannerView *)bannerView {
  LogAdEvent(AdLogSlotBanner, @"即将关闭落地页", nil);
}

- (void)bannerViewDidDismissScreen:(GADBannerView *)bannerView {
  LogAdEvent(AdLogSlotBanner, @"关闭", nil);
}

#pragma mark GADAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader didFailToReceiveAdWithError:(NSError *)error {
  LogAdEvent(AdLogSlotNative, @"加载失败", error.localizedDescription);
}

#pragma mark Utility Method

/// Gets an image representing the number of stars. Returns nil if rating is less than 3.5 stars.
- (UIImage *)imageForStars:(NSDecimalNumber *)numberOfStars {
  double starRating = numberOfStars.doubleValue;
  if (starRating >= 5) {
    return [UIImage imageNamed:@"stars_5"];
  } else if (starRating >= 4.5) {
    return [UIImage imageNamed:@"stars_4_5"];
  } else if (starRating >= 4) {
    return [UIImage imageNamed:@"stars_4"];
  } else if (starRating >= 3.5) {
    return [UIImage imageNamed:@"stars_3_5"];
  } else {
    return nil;
  }
}

#pragma mark GADNativeAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader didReceiveNativeAd:(GADNativeAd *)nativeAd {
  LogAdEvent(AdLogSlotNative, @"加载成功", nativeAd.headline);
  self.nativeAd = nativeAd;
  nativeAd.delegate = self;

  // Create and place ad in view hierarchy.
  ExampleNativeAdView *nativeAdView =
      [[NSBundle mainBundle] loadNibNamed:@"ExampleNativeAdView" owner:nil options:nil].firstObject;

  nativeAdView.nativeAd = nativeAd;
  UIView *placeholder = self.nativeAdPlaceholder;
  NSString *awesomenessKey = self.config.awesomenessKey;

  [self replaceNativeAdView:nativeAdView inPlaceholder:placeholder];

  nativeAdView.mediaView.contentMode = UIViewContentModeScaleAspectFit;
  nativeAdView.mediaView.hidden = NO;
  [nativeAdView.mediaView setMediaContent:nativeAd.mediaContent];
  // Populate the native ad view with the native ad assets.
  // Some assets are guaranteed to be present in every native ad.
  ((UILabel *)nativeAdView.headlineView).text = nativeAd.headline;
  ((UILabel *)nativeAdView.bodyView).text = nativeAd.body;
  [((UIButton *)nativeAdView.callToActionView) setTitle:nativeAd.callToAction
                                               forState:UIControlStateNormal];

  // These assets are not guaranteed to be present, and should be checked first.
  ((UIImageView *)nativeAdView.iconView).image = nativeAd.icon.image;
  if (nativeAd.icon != nil) {
    nativeAdView.iconView.hidden = NO;
  } else {
    nativeAdView.iconView.hidden = YES;
  }
  ((UIImageView *)nativeAdView.starRatingView).image = [self imageForStars:nativeAd.starRating];
  if (nativeAd.starRating) {
    nativeAdView.starRatingView.hidden = NO;
  } else {
    nativeAdView.starRatingView.hidden = YES;
  }

  ((UILabel *)nativeAdView.storeView).text = nativeAd.store;
  if (nativeAd.store) {
    nativeAdView.storeView.hidden = NO;
  } else {
    nativeAdView.storeView.hidden = YES;
  }

  ((UILabel *)nativeAdView.priceView).text = nativeAd.price;
  if (nativeAd.price) {
    nativeAdView.priceView.hidden = NO;
  } else {
    nativeAdView.priceView.hidden = YES;
  }

  ((UILabel *)nativeAdView.advertiserView).text = nativeAd.advertiser;
  if (nativeAd.advertiser) {
    nativeAdView.advertiserView.hidden = NO;
  } else {
    nativeAdView.advertiserView.hidden = YES;
  }

  // If the ad came from the Sample SDK, it should contain an extra asset, which is retrieved here.
  NSString *degreeOfAwesomeness = nativeAd.extraAssets[awesomenessKey];

  if (degreeOfAwesomeness) {
    nativeAdView.degreeOfAwesomenessView.text = degreeOfAwesomeness;
    nativeAdView.degreeOfAwesomenessView.hidden = NO;
  } else {
    nativeAdView.degreeOfAwesomenessView.hidden = YES;
  }

  // In order for the SDK to process touch events properly, user interaction should be disabled.
  nativeAdView.callToActionView.userInteractionEnabled = NO;
}

#pragma mark GADNativeAdDelegate implementation

- (void)nativeAdDidRecordImpression:(GADNativeAd *)nativeAd {
  LogAdEvent(AdLogSlotNative, @"曝光成功", nil);
}

- (void)nativeAdDidRecordClick:(GADNativeAd *)nativeAd {
  LogAdEvent(AdLogSlotNative, @"点击", nil);
}

- (void)nativeAdDidRecordSwipeGestureClick:(GADNativeAd *)nativeAd {
  LogAdEvent(AdLogSlotNative, @"点击", @"滑动手势");
}

- (void)nativeAdWillPresentScreen:(GADNativeAd *)nativeAd {
  LogAdEvent(AdLogSlotNative, @"即将打开落地页", nil);
}

- (void)nativeAdWillDismissScreen:(GADNativeAd *)nativeAd {
  LogAdEvent(AdLogSlotNative, @"即将关闭落地页", nil);
}

- (void)nativeAdDidDismissScreen:(GADNativeAd *)nativeAd {
  LogAdEvent(AdLogSlotNative, @"关闭", nil);
}

@end
