#import "AdMobMentaBaseAdapter.h"

#import <MentaBaseGlobal/MentaAdSDK.h>

#import "AdMobMentaAdapter.h"
#import "AdMobMentaAdapterConstants.h"
#import "AdMobMentaAdapterUtils.h"

@implementation AdMobMentaBaseAdapter

+ (GADVersionNumber)adSDKVersion {
    return AdMobMentaAdapterVersionFromString(MentaAdSDK.shared.sdkVersion, NO);
}

+ (GADVersionNumber)adapterVersion {
    return AdMobMentaAdapterVersionFromString(AdMobMentaAdapterVersion, YES);
}

+ (nullable Class<GADAdNetworkExtras>)networkExtrasClass {
    return AdMobMentaAdapterExtras.class;
}

+ (void)setUpWithConfiguration:(GADMediationServerConfiguration *)configuration
             completionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
    AdMobMentaAdapterInitializeSDKWithServerConfiguration(configuration, completionHandler);
}

@end
