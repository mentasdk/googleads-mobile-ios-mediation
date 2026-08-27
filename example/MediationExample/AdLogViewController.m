#import "AdLogViewController.h"

@interface AdLogViewController () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, assign) AdLogSlot selectedSlot;
@property(nonatomic, copy) NSArray<AdLogEntry *> *entries;
@property(nonatomic, strong) UIScrollView *tabScrollView;
@property(nonatomic, strong) UIStackView *tabStack;
@property(nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UILabel *emptyLabel;

@end

@implementation AdLogViewController

- (instancetype)init {
  return [self initWithInitialSlot:AdLogSlotAppOpen];
}

- (instancetype)initWithInitialSlot:(AdLogSlot)slot {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _selectedSlot = slot;
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = @"广告回调日志";
  if (@available(iOS 13.0, *)) {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
  } else {
    self.view.backgroundColor = [UIColor whiteColor];
  }

  self.navigationItem.leftBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(closeTapped)];
  self.navigationItem.rightBarButtonItems = @[
    [[UIBarButtonItem alloc] initWithTitle:@"清空"
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(clearTapped)],
    [[UIBarButtonItem alloc] initWithTitle:@"复制"
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(copyTapped)]
  ];

  [self setupTabs];
  [self setupTable];
  [self setupEmptyLabel];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(logsDidChange:)
                                               name:AdLogStoreDidChangeNotification
                                             object:nil];
  [self reloadEntries];
}

- (void)setupTabs {
  self.tabScrollView = [[UIScrollView alloc] init];
  self.tabScrollView.translatesAutoresizingMaskIntoConstraints = NO;
  self.tabScrollView.showsHorizontalScrollIndicator = NO;
  self.tabScrollView.alwaysBounceHorizontal = YES;
  self.tabScrollView.clipsToBounds = YES;
  if (@available(iOS 11.0, *)) {
    self.tabScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
  }
  // 右侧多留一点，避免最后一个 Tab 被 page sheet 圆角裁掉。
  self.tabScrollView.contentInset = UIEdgeInsetsMake(0, 12, 0, 24);
  [self.view addSubview:self.tabScrollView];

  self.tabStack = [[UIStackView alloc] init];
  self.tabStack.translatesAutoresizingMaskIntoConstraints = NO;
  self.tabStack.axis = UILayoutConstraintAxisHorizontal;
  self.tabStack.alignment = UIStackViewAlignmentFill;
  self.tabStack.spacing = 8;
  [self.tabScrollView addSubview:self.tabStack];

  self.tabButtons = [NSMutableArray array];
  for (AdLogSlot slot = 0; slot < AdLogSlotCount; slot++) {
    UIButton *button = [self tabButtonWithTitle:AdLogSlotTitle(slot) slot:slot];
    [self.tabButtons addObject:button];
    [self.tabStack addArrangedSubview:button];
  }
  [self updateTabAppearance];

  UILayoutGuide *content = self.tabScrollView.contentLayoutGuide;
  UILayoutGuide *frame = self.tabScrollView.frameLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [self.tabScrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [self.tabScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [self.tabScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.tabScrollView.heightAnchor constraintEqualToConstant:48],
    [self.tabStack.topAnchor constraintEqualToAnchor:content.topAnchor constant:8],
    [self.tabStack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-8],
    [self.tabStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [self.tabStack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [self.tabStack.heightAnchor constraintEqualToAnchor:frame.heightAnchor constant:-16]
  ]];
}

- (UIButton *)tabButtonWithTitle:(NSString *)title slot:(AdLogSlot)slot {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
  [button setTitle:title forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
  button.titleLabel.lineBreakMode = NSLineBreakByClipping;
  button.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
  button.layer.cornerRadius = 8;
  button.clipsToBounds = YES;
  button.tag = slot;
  [button setContentCompressionResistancePriority:UILayoutPriorityRequired
                                          forAxis:UILayoutConstraintAxisHorizontal];
  [button setContentHuggingPriority:UILayoutPriorityRequired
                            forAxis:UILayoutConstraintAxisHorizontal];
  [button addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  return button;
}

- (void)updateTabAppearance {
  for (UIButton *button in self.tabButtons) {
    BOOL selected = button.tag == self.selectedSlot;
    if (selected) {
      [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
      button.backgroundColor = [UIColor systemBlueColor];
    } else if (@available(iOS 13.0, *)) {
      [button setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
      button.backgroundColor = [UIColor secondarySystemFillColor];
    } else {
      [button setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
      button.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1];
    }
  }
}

- (void)setupTable {
  self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 64;
  self.tableView.tableFooterView = [[UIView alloc] init];
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"log"];
  [self.view addSubview:self.tableView];

  [NSLayoutConstraint activateConstraints:@[
    [self.tableView.topAnchor constraintEqualToAnchor:self.tabScrollView.bottomAnchor],
    [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
  ]];
}

- (void)setupEmptyLabel {
  self.emptyLabel = [[UILabel alloc] init];
  self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.emptyLabel.text = @"暂无日志\n请先在广告页操作，回调会按广告位记录在这里";
  self.emptyLabel.textAlignment = NSTextAlignmentCenter;
  self.emptyLabel.numberOfLines = 0;
  if (@available(iOS 13.0, *)) {
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
  } else {
    self.emptyLabel.textColor = [UIColor darkGrayColor];
  }
  self.emptyLabel.font = [UIFont systemFontOfSize:15];
  [self.view addSubview:self.emptyLabel];
  [NSLayoutConstraint activateConstraints:@[
    [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
    [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor],
    [self.emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
    [self.emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24]
  ]];
}

- (void)tabButtonTapped:(UIButton *)button {
  self.selectedSlot = (AdLogSlot)button.tag;
  [self updateTabAppearance];
  [self reloadEntries];
  [self.tabScrollView scrollRectToVisible:CGRectInset(button.frame, -16, 0) animated:YES];
}

- (void)logsDidChange:(NSNotification *)notification {
  NSNumber *slotNumber = notification.userInfo[AdLogStoreSlotUserInfoKey];
  if (slotNumber && slotNumber.integerValue != self.selectedSlot) {
    return;
  }
  [self reloadEntries];
}

- (void)reloadEntries {
  self.entries = [[AdLogStore sharedStore] entriesForSlot:self.selectedSlot];
  self.emptyLabel.hidden = self.entries.count > 0;
  [self.tableView reloadData];
  if (self.entries.count > 0) {
    NSIndexPath *last = [NSIndexPath indexPathForRow:(NSInteger)self.entries.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom
                                  animated:NO];
  }
}

- (void)closeTapped {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearTapped {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:nil
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  NSString *currentTitle =
      [NSString stringWithFormat:@"清空「%@」", AdLogSlotTitle(self.selectedSlot)];
  [alert addAction:[UIAlertAction actionWithTitle:currentTitle
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *_Nonnull action) {
                                            [[AdLogStore sharedStore] clearSlot:self.selectedSlot];
                                          }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"清空全部广告位"
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *_Nonnull action) {
                                            [[AdLogStore sharedStore] clearAll];
                                          }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)copyTapped {
  UIPasteboard.generalPasteboard.string =
      [[AdLogStore sharedStore] plainTextForSlot:self.selectedSlot];
  self.navigationItem.prompt = @"已复制当前广告位日志";
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   self.navigationItem.prompt = nil;
                 });
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return (NSInteger)self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"log" forIndexPath:indexPath];
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  cell.textLabel.numberOfLines = 0;
  cell.textLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightRegular];

  AdLogEntry *entry = self.entries[indexPath.row];
  NSString *line = entry.detail.length > 0
                       ? [NSString stringWithFormat:@"%@  %@\n%@", entry.timeString, entry.event,
                                                    entry.detail]
                       : [NSString stringWithFormat:@"%@  %@", entry.timeString, entry.event];
  cell.textLabel.text = line;
  cell.textLabel.textColor = [self colorForEvent:entry.event];
  return cell;
}

- (UIColor *)colorForEvent:(NSString *)event {
  if ([event containsString:@"失败"]) {
    return [UIColor systemRedColor];
  }
  if ([event containsString:@"成功"] || [event containsString:@"曝光"] ||
      [event containsString:@"激励"]) {
    return [UIColor systemGreenColor];
  }
  if ([event containsString:@"点击"]) {
    return [UIColor systemBlueColor];
  }
  if ([event containsString:@"关闭"]) {
    return [UIColor systemOrangeColor];
  }
  if (@available(iOS 13.0, *)) {
    return [UIColor labelColor];
  }
  return [UIColor darkTextColor];
}

@end
