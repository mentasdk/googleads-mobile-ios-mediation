#import "AdMobMentaNativeAdapter.h"

#include <stdatomic.h>

#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

#import "AdMobMentaAdapterConstants.h"
#import "AdMobMentaAdapterUtils.h"

@interface AdMobMentaNativeAdapter () <GADMediationNativeAd, MentaNativeSelfRenderDelegate>
- (void)loadNativeAdAfterSDKReady:(GADMediationNativeAdConfiguration *)adConfiguration
                completionHandler:(GADMediationNativeLoadCompletionHandler)completionHandler;
@end

@implementation AdMobMentaNativeAdapter {
    MentaMediationNativeSelfRender *_nativeAd;
    MentaMediationNativeSelfRenderModel *_nativeModel;
    UIView<MentaMediationNativeSelfRenderViewProtocol> *_renderView;
    GADNativeAdImage *_icon;
    NSArray<GADNativeAdImage *> *_images;
    BOOL _disableImageLoading;
    GADMediationNativeLoadCompletionHandler _loadCompletionHandler;
    id<GADMediationNativeAdEventDelegate> _adEventDelegate;
}

- (void)loadNativeAdForAdConfiguration:(GADMediationNativeAdConfiguration *)adConfiguration
                     completionHandler:(GADMediationNativeLoadCompletionHandler)completionHandler {
    __weak typeof(self) weakSelf = self;
    AdMobMentaAdapterInitializeThenLoad(
        adConfiguration,
        ^{
            [weakSelf loadNativeAdAfterSDKReady:adConfiguration completionHandler:completionHandler];
        },
        ^(NSError *error) {
            completionHandler(nil, error);
        });
}

- (void)loadNativeAdAfterSDKReady:(GADMediationNativeAdConfiguration *)adConfiguration
                completionHandler:(GADMediationNativeLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationNativeLoadCompletionHandler originalCompletionHandler = [completionHandler copy];
    _loadCompletionHandler =
        ^id<GADMediationNativeAdEventDelegate>(_Nullable id<GADMediationNativeAd> ad, NSError *_Nullable error) {
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }
        id<GADMediationNativeAdEventDelegate> delegate = nil;
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

    for (GADAdLoaderOptions *options in adConfiguration.options) {
        if ([options isKindOfClass:GADNativeAdImageAdLoaderOptions.class]) {
            _disableImageLoading = ((GADNativeAdImageAdLoaderOptions *)options).disableImageLoading;
        }
    }

    _nativeAd = [[MentaMediationNativeSelfRender alloc] initWithPlacementID:placementID];
    _nativeAd.delegate = self;

    NSString *bidResponse = AdMobMentaAdapterBidResponse(adConfiguration);
    if (bidResponse.length) {
        [_nativeAd loadAdWithAdm:bidResponse];
    } else {
        [_nativeAd loadAd];
    }
}

#pragma mark - GADMediationNativeAd / GADMediatedUnifiedNativeAd

- (NSString *)headline {
    return _nativeModel.title;
}

- (NSString *)body {
    return _nativeModel.des;
}

- (NSString *)callToAction {
    id CTA = _nativeModel.extroInfo[@"call_to_action"] ?: _nativeModel.extroInfo[@"cta"];
    return AdMobMentaAdapterStringValue(CTA);
}

- (NSArray<GADNativeAdImage *> *)images {
    return _images;
}

- (GADNativeAdImage *)icon {
    return _icon;
}

- (NSString *)advertiser {
    return _nativeModel.platformName;
}

- (NSDecimalNumber *)starRating {
    return nil;
}

- (NSString *)store {
    return nil;
}

- (NSString *)price {
    return _nativeModel.eCPM;
}

- (NSDictionary<NSString *, id> *)extraAssets {
    NSMutableDictionary<NSString *, id> *extras = [[NSMutableDictionary alloc] init];
    if (_nativeModel.eCPM.length) {
        extras[AdMobMentaAdapterExtraECPMKey] = _nativeModel.eCPM;
    }
    if (_nativeModel.platformName.length) {
        extras[AdMobMentaAdapterExtraPlatformNameKey] = _nativeModel.platformName;
    }
    return extras.count ? extras : nil;
}

- (UIView *)adChoicesView {
    return _nativeModel.adLogo;
}

- (UIView *)mediaView {
    return _renderView.mediaView;
}

- (BOOL)hasVideoContent {
    return _nativeModel.isVideo;
}

- (CGFloat)mediaContentAspectRatio {
    CGFloat width = _nativeModel.isVideo ? _nativeModel.videoCoverWidth : _nativeModel.materialWidth;
    CGFloat height = _nativeModel.isVideo ? _nativeModel.videoCoverHeight : _nativeModel.materialHeight;
    if (width <= 0 || height <= 0) {
        return 0;
    }
    return width / height;
}

- (BOOL)handlesUserClicks {
    return YES;
}

- (BOOL)handlesUserImpressions {
    return YES;
}

- (void)didRenderInView:(UIView *)view
       clickableAssetViews:(NSDictionary<GADNativeAssetIdentifier, UIView *> *)clickableAssetViews
    nonclickableAssetViews:(NSDictionary<GADNativeAssetIdentifier, UIView *> *)nonclickableAssetViews
            viewController:(UIViewController *)viewController {
    [_renderView inMediation:YES];
    [_nativeAd sendWinnerNotificationWith:nil];
    [_renderView menta_registerClickableViews:clickableAssetViews.allValues closeableViews:nil];
}

- (void)didUntrackView:(UIView *)view {
    [_renderView inMediation:NO];
}

#pragma mark - MentaNativeSelfRenderDelegate

- (void)menta_nativeSelfRenderLoadSuccess:(NSArray<MentaMediationNativeSelfRenderModel *> *)nativeSelfRenderAds
                         nativeSelfRender:(MentaMediationNativeSelfRender *)nativeSelfRender {
    _nativeModel = nativeSelfRenderAds.firstObject;
    _renderView = _nativeModel.selfRenderView;
    if (!_nativeModel || !_renderView) {
        _adEventDelegate = _loadCompletionHandler(nil, AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta returned no native ad."));
        return;
    }

    [self loadImagesThenComplete];
}

- (void)menta_nativeSelfRenderLoadFailure:(NSError *)error
                         nativeSelfRender:(MentaMediationNativeSelfRender *)nativeSelfRender {
    _adEventDelegate = _loadCompletionHandler(nil, error ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorAdLoadFailure, @"Menta native ad failed to load."));
}

- (void)menta_nativeSelfRenderViewExposed {
    [_adEventDelegate reportImpression];
}

- (void)menta_nativeSelfRenderViewClicked {
    [_adEventDelegate reportClick];
}

- (void)menta_nativeSelfRenderViewClosed {
    [_adEventDelegate willDismissFullScreenView];
    [_adEventDelegate didDismissFullScreenView];
}

#pragma mark - Images

- (void)loadImagesThenComplete {
    NSURL *iconURL = [self URLFromString:_nativeModel.iconURL];
    NSString *material = _nativeModel.isVideo ? _nativeModel.videoCover : _nativeModel.materialURL;
    NSURL *imageURL = [self URLFromString:material];

    if (_disableImageLoading) {
        if (iconURL) {
            _icon = [[GADNativeAdImage alloc] initWithURL:iconURL scale:1.0];
        }
        if (imageURL) {
            _images = @[ [[GADNativeAdImage alloc] initWithURL:imageURL scale:1.0] ];
        }
        _adEventDelegate = _loadCompletionHandler(self, nil);
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    __block UIImage *iconImage = nil;
    __block UIImage *mainImage = nil;

    if (iconURL) {
        dispatch_group_enter(group);
        [self downloadImageFromURL:iconURL
                        completion:^(UIImage *image) {
                            iconImage = image;
                            dispatch_group_leave(group);
                        }];
    }
    if (imageURL) {
        dispatch_group_enter(group);
        [self downloadImageFromURL:imageURL
                        completion:^(UIImage *image) {
                            mainImage = image;
                            dispatch_group_leave(group);
                        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (iconImage) {
            self->_icon = [[GADNativeAdImage alloc] initWithImage:iconImage];
        } else if (iconURL) {
            self->_icon = [[GADNativeAdImage alloc] initWithURL:iconURL scale:1.0];
        }
        if (mainImage) {
            self->_images = @[ [[GADNativeAdImage alloc] initWithImage:mainImage] ];
        } else if (imageURL) {
            self->_images = @[ [[GADNativeAdImage alloc] initWithURL:imageURL scale:1.0] ];
        }
        self->_adEventDelegate = self->_loadCompletionHandler(self, nil);
    });
}

- (NSURL *)URLFromString:(NSString *)string {
    if (!string.length) {
        return nil;
    }
    return [NSURL URLWithString:string];
}

- (void)downloadImageFromURL:(NSURL *)URL completion:(void (^)(UIImage *_Nullable image))completion {
    [[[NSURLSession sharedSession]
          dataTaskWithURL:URL
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            UIImage *image = data ? [UIImage imageWithData:data] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(image);
            });
        }] resume];
}

@end
