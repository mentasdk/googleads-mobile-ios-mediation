#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AdLogSlot) {
  AdLogSlotAppOpen = 0,
  AdLogSlotBanner,
  AdLogSlotInterstitial,
  AdLogSlotRewarded,
  AdLogSlotRewardedInterstitial,
  AdLogSlotNative,
  AdLogSlotCount
};

FOUNDATION_EXPORT NSNotificationName const AdLogStoreDidChangeNotification;
FOUNDATION_EXPORT NSString *const AdLogStoreSlotUserInfoKey;

NSString *AdLogSlotTitle(AdLogSlot slot);

@interface AdLogEntry : NSObject

@property(nonatomic, readonly) NSDate *date;
@property(nonatomic, readonly, copy) NSString *event;
@property(nonatomic, readonly, copy) NSString *detail;
@property(nonatomic, readonly, copy) NSString *timeString;

@end

@interface AdLogStore : NSObject

+ (instancetype)sharedStore;

- (void)logSlot:(AdLogSlot)slot event:(NSString *)event detail:(NSString *_Nullable)detail;
- (NSArray<AdLogEntry *> *)entriesForSlot:(AdLogSlot)slot;
- (NSUInteger)countForSlot:(AdLogSlot)slot;
- (void)clearSlot:(AdLogSlot)slot;
- (void)clearAll;
- (NSString *)plainTextForSlot:(AdLogSlot)slot;

@end
