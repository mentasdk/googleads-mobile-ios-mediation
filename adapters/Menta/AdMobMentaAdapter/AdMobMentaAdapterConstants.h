#import <Foundation/Foundation.h>

/// Adapter version. Follows {Menta SDK version}.{adapter revision}.
static NSString *const AdMobMentaAdapterVersion = @"1.0.34";

/// Error domain reported to Google Mobile Ads.
static NSString *const AdMobMentaAdapterErrorDomain = @"com.advlion.adapter.admob";

/// AdMob mapping / extras keys.
static NSString *const AdMobMentaAdapterAppIDKey = @"appId";
static NSString *const AdMobMentaAdapterAppKeyKey = @"appKey";
static NSString *const AdMobMentaAdapterPlacementIDKey = @"placementId";
static NSString *const AdMobMentaAdapterParameterKey = @"parameter";

/// Extra native assets forwarded to publishers.
static NSString *const AdMobMentaAdapterExtraECPMKey = @"eCPM";
static NSString *const AdMobMentaAdapterExtraPlatformNameKey = @"platformName";
