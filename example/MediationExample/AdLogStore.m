#import "AdLogStore.h"

NSNotificationName const AdLogStoreDidChangeNotification = @"AdLogStoreDidChangeNotification";
NSString *const AdLogStoreSlotUserInfoKey = @"slot";

NSString *AdLogSlotTitle(AdLogSlot slot) {
  switch (slot) {
    case AdLogSlotAppOpen:
      return @"开屏";
    case AdLogSlotBanner:
      return @"Banner";
    case AdLogSlotInterstitial:
      return @"插屏";
    case AdLogSlotRewarded:
      return @"激励";
    case AdLogSlotRewardedInterstitial:
      return @"激励插屏";
    case AdLogSlotNative:
      return @"Native";
    default:
      return @"未知";
  }
}

@interface AdLogEntry ()
@property(nonatomic, strong) NSDate *date;
@property(nonatomic, copy) NSString *event;
@property(nonatomic, copy) NSString *detail;
@end

@implementation AdLogEntry

- (NSString *)timeString {
  static NSDateFormatter *formatter;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
  });
  return [formatter stringFromDate:self.date];
}

@end

@interface AdLogStore ()
@property(nonatomic, strong) NSMutableArray<NSMutableArray<AdLogEntry *> *> *slotLogs;
@property(nonatomic, strong) dispatch_queue_t queue;
@end

@implementation AdLogStore

+ (instancetype)sharedStore {
  static AdLogStore *store;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    store = [[AdLogStore alloc] init];
  });
  return store;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _queue = dispatch_queue_create("com.menta.adlog", DISPATCH_QUEUE_SERIAL);
    _slotLogs = [NSMutableArray arrayWithCapacity:AdLogSlotCount];
    for (NSInteger i = 0; i < AdLogSlotCount; i++) {
      [_slotLogs addObject:[NSMutableArray array]];
    }
  }
  return self;
}

- (void)logSlot:(AdLogSlot)slot event:(NSString *)event detail:(NSString *)detail {
  if (slot < 0 || slot >= AdLogSlotCount || event.length == 0) {
    return;
  }
  AdLogEntry *entry = [[AdLogEntry alloc] init];
  entry.date = [NSDate date];
  entry.event = event;
  entry.detail = detail ?: @"";

  dispatch_async(self.queue, ^{
    [self.slotLogs[slot] addObject:entry];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
          postNotificationName:AdLogStoreDidChangeNotification
                        object:self
                      userInfo:@{AdLogStoreSlotUserInfoKey : @(slot)}];
    });
  });
}

- (NSArray<AdLogEntry *> *)entriesForSlot:(AdLogSlot)slot {
  if (slot < 0 || slot >= AdLogSlotCount) {
    return @[];
  }
  __block NSArray<AdLogEntry *> *copy;
  dispatch_sync(self.queue, ^{
    copy = [self.slotLogs[slot] copy];
  });
  return copy;
}

- (NSUInteger)countForSlot:(AdLogSlot)slot {
  if (slot < 0 || slot >= AdLogSlotCount) {
    return 0;
  }
  __block NSUInteger count = 0;
  dispatch_sync(self.queue, ^{
    count = self.slotLogs[slot].count;
  });
  return count;
}

- (void)clearSlot:(AdLogSlot)slot {
  if (slot < 0 || slot >= AdLogSlotCount) {
    return;
  }
  dispatch_async(self.queue, ^{
    [self.slotLogs[slot] removeAllObjects];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
          postNotificationName:AdLogStoreDidChangeNotification
                        object:self
                      userInfo:@{AdLogStoreSlotUserInfoKey : @(slot)}];
    });
  });
}

- (void)clearAll {
  dispatch_async(self.queue, ^{
    for (NSMutableArray *logs in self.slotLogs) {
      [logs removeAllObjects];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter] postNotificationName:AdLogStoreDidChangeNotification
                                                          object:self
                                                        userInfo:nil];
    });
  });
}

- (NSString *)plainTextForSlot:(AdLogSlot)slot {
  NSMutableString *text = [NSMutableString string];
  [text appendFormat:@"======= %@ 回调日志 =======\n", AdLogSlotTitle(slot)];
  for (AdLogEntry *entry in [self entriesForSlot:slot]) {
    if (entry.detail.length > 0) {
      [text appendFormat:@"%@  %@  %@\n", entry.timeString, entry.event, entry.detail];
    } else {
      [text appendFormat:@"%@  %@\n", entry.timeString, entry.event];
    }
  }
  return text;
}

@end
