#import "AdMobMentaAdapterUtils.h"

#import <MentaBaseGlobal/MentaAdSDK.h>
#import <UIKit/UIKit.h>

#import "AdMobMentaAdapterConstants.h"

static NSMutableArray<void (^)(NSError *)> *gAdMobMentaPendingInitCallbacks;
static BOOL gAdMobMentaSDKStarting;

NSError *AdMobMentaAdapterError(AdMobMentaAdapterErrorCode code, NSString *description) {
    return [NSError errorWithDomain:AdMobMentaAdapterErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description,
                                      NSLocalizedFailureReasonErrorKey: description}];
}

NSString *AdMobMentaAdapterStringValue(id value) {
    if ([value isKindOfClass:NSString.class]) {
        NSString *string = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return string.length ? string : nil;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return nil;
}

static NSDictionary *AdMobMentaAdapterJSONDictionary(NSString *string) {
    if (![string hasPrefix:@"{"]) {
        return nil;
    }
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return nil;
    }
    id JSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [JSON isKindOfClass:NSDictionary.class] ? JSON : nil;
}

static NSString *AdMobMentaAdapterValueForKeys(NSDictionary<NSString *, id> *settings, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        NSString *value = AdMobMentaAdapterStringValue(settings[key]);
        if (value.length) {
            return value;
        }
    }
    return nil;
}

static NSDictionary<NSString *, id> *AdMobMentaAdapterFlattenedSettings(NSDictionary<NSString *, id> *settings) {
    NSMutableDictionary<NSString *, id> *flattened = [NSMutableDictionary dictionaryWithDictionary:settings ?: @{}];
    NSString *parameter = AdMobMentaAdapterStringValue(settings[AdMobMentaAdapterParameterKey]);
    NSDictionary *JSON = AdMobMentaAdapterJSONDictionary(parameter);
    if (JSON.count) {
        [flattened addEntriesFromDictionary:JSON];
    }
    return flattened;
}

NSString *AdMobMentaAdapterPlacementID(GADMediationAdConfiguration *config) {
    if ([config.extras isKindOfClass:AdMobMentaAdapterExtras.class]) {
        NSString *extrasPlacement = ((AdMobMentaAdapterExtras *)config.extras).placementId;
        if (extrasPlacement.length) {
            return extrasPlacement;
        }
    }

    NSDictionary<NSString *, id> *settings = AdMobMentaAdapterFlattenedSettings(config.credentials.settings);
    NSString *placement = AdMobMentaAdapterValueForKeys(settings,
                                                        @[AdMobMentaAdapterPlacementIDKey,
                                                          @"slot_id",
                                                          @"slotId",
                                                          @"slotID",
                                                          AdMobMentaAdapterParameterKey]);
    // If the parameter was JSON, the raw string is not a placement ID.
    if (AdMobMentaAdapterJSONDictionary(placement)) {
        return nil;
    }
    return placement;
}

NSString *AdMobMentaAdapterBidResponse(GADMediationAdConfiguration *config) {
    return AdMobMentaAdapterStringValue(config.bidResponse);
}

void AdMobMentaAdapterExtractAppCredentials(NSArray<NSDictionary<NSString *, id> *> *settingsList,
                                            id<GADAdNetworkExtras> extras, NSString **appId, NSString **appKey) {
    NSString *resolvedAppId = nil;
    NSString *resolvedAppKey = nil;

    if ([extras isKindOfClass:AdMobMentaAdapterExtras.class]) {
        AdMobMentaAdapterExtras *mentaExtras = (AdMobMentaAdapterExtras *)extras;
        resolvedAppId = AdMobMentaAdapterStringValue(mentaExtras.appId);
        resolvedAppKey = AdMobMentaAdapterStringValue(mentaExtras.appKey);
    }

    for (NSDictionary<NSString *, id> *rawSettings in settingsList) {
        NSDictionary<NSString *, id> *settings = AdMobMentaAdapterFlattenedSettings(rawSettings);
        if (!resolvedAppId.length) {
            resolvedAppId = AdMobMentaAdapterValueForKeys(settings, @[AdMobMentaAdapterAppIDKey, @"app_id", @"appID"]);
        }
        if (!resolvedAppKey.length) {
            resolvedAppKey = AdMobMentaAdapterValueForKeys(settings, @[AdMobMentaAdapterAppKeyKey, @"app_key", @"appKEY"]);
        }
        if (resolvedAppId.length && resolvedAppKey.length) {
            break;
        }
    }

    if (appId) {
        *appId = resolvedAppId;
    }
    if (appKey) {
        *appKey = resolvedAppKey;
    }
}

static dispatch_queue_t AdMobMentaAdapterInitQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.advlion.adapter.admob.init", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

void AdMobMentaAdapterInitializeSDK(NSDictionary<NSString *, id> *settings, id<GADAdNetworkExtras> extras,
                                    void (^completion)(NSError *error)) {
    NSArray<NSDictionary<NSString *, id> *> *settingsList = settings ? @[ settings ] : @[];
    NSString *appId = nil;
    NSString *appKey = nil;
    AdMobMentaAdapterExtractAppCredentials(settingsList, extras, &appId, &appKey);

    dispatch_async(AdMobMentaAdapterInitQueue(), ^{
        if (MentaAdSDK.shared.isInitialized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
            return;
        }

        if (!gAdMobMentaPendingInitCallbacks) {
            gAdMobMentaPendingInitCallbacks = [[NSMutableArray alloc] init];
        }
        [gAdMobMentaPendingInitCallbacks addObject:[completion copy]];
        if (gAdMobMentaSDKStarting) {
            return;
        }

        if (!appId.length || !appKey.length) {
            NSArray<void (^)(NSError *)> *callbacks = [gAdMobMentaPendingInitCallbacks copy];
            [gAdMobMentaPendingInitCallbacks removeAllObjects];
            NSError *error =
                AdMobMentaAdapterError(AdMobMentaAdapterErrorInvalidServerParameters,
                                       @"Menta requires appId and appKey. Set them in the AdMob adapter mapping or "
                                       @"AdMobMentaAdapterExtras.");
            dispatch_async(dispatch_get_main_queue(), ^{
                for (void (^callback)(NSError *) in callbacks) {
                    callback(error);
                }
            });
            return;
        }

        gAdMobMentaSDKStarting = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [MentaAdSDK.shared startWithAppID:appId
                                       appKey:appKey
                                  finishBlock:^(BOOL success, NSError *_Nullable error) {
               dispatch_async(AdMobMentaAdapterInitQueue(), ^{
                   gAdMobMentaSDKStarting = NO;
                   NSArray<void (^)(NSError *)> *callbacks = [gAdMobMentaPendingInitCallbacks copy];
                   [gAdMobMentaPendingInitCallbacks removeAllObjects];
                   NSError *initError = nil;
                   if (!success) {
                       initError = error
                                       ?: AdMobMentaAdapterError(AdMobMentaAdapterErrorInitializationFailure,
                                                                 @"Menta SDK initialization failed.");
                   }
                   dispatch_async(dispatch_get_main_queue(), ^{
                       for (void (^callback)(NSError *) in callbacks) {
                           callback(initError);
                       }
                   });
               });
            }];
        });
    });
}

void AdMobMentaAdapterInitializeSDKWithServerConfiguration(GADMediationServerConfiguration *configuration,
                                                           void (^completion)(NSError *error)) {
    NSMutableArray<NSDictionary<NSString *, id> *> *settingsList = [[NSMutableArray alloc] init];
    for (GADMediationCredentials *credentials in configuration.credentials) {
        if (credentials.settings) {
            [settingsList addObject:credentials.settings];
        }
    }

    NSString *appId = nil;
    NSString *appKey = nil;
    AdMobMentaAdapterExtractAppCredentials(settingsList, nil, &appId, &appKey);

    NSMutableDictionary<NSString *, id> *merged = [[NSMutableDictionary alloc] init];
    if (appId.length) {
        merged[AdMobMentaAdapterAppIDKey] = appId;
    }
    if (appKey.length) {
        merged[AdMobMentaAdapterAppKeyKey] = appKey;
    }
    AdMobMentaAdapterInitializeSDK(merged, nil, completion);
}

void AdMobMentaAdapterInitializeThenLoad(GADMediationAdConfiguration *config, void (^loadBlock)(void),
                                         void (^failBlock)(NSError *error)) {
    AdMobMentaAdapterInitializeSDK(config.credentials.settings, config.extras, ^(NSError *_Nullable error) {
        if (error) {
            failBlock(error);
            return;
        }
        loadBlock();
    });
}

GADVersionNumber AdMobMentaAdapterVersionFromString(NSString *versionString, BOOL adapterVersion) {
    GADVersionNumber version = {0};
    NSArray<NSString *> *components = [versionString componentsSeparatedByString:@"."];
    if (adapterVersion) {
        if (components.count >= 4) {
            version.majorVersion = components[0].integerValue;
            version.minorVersion = components[1].integerValue;
            version.patchVersion = components[2].integerValue * 100 + components[3].integerValue;
        } else if (components.count == 3) {
            version.majorVersion = components[0].integerValue;
            version.minorVersion = components[1].integerValue;
            version.patchVersion = components[2].integerValue * 100;
        }
    } else if (components.count >= 3) {
        version.majorVersion = components[0].integerValue;
        version.minorVersion = components[1].integerValue;
        version.patchVersion = components[2].integerValue;
    }
    return version;
}

UIWindow *AdMobMentaAdapterKeyWindow(UIViewController *viewController) {
    if (viewController.view.window) {
        return viewController.view.window;
    }
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}
