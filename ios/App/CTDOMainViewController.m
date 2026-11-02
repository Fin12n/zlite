#import "CTDOMainViewController.h"

// ============================================================================
// Custom Reusable Thread TableView Cell (60/120fps, zero Nib overhead, iOS 12+)
// ============================================================================
@interface CTDOThreadCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *tagBadgeLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *unreadBadge;
@property (nonatomic, strong) UIView *separatorLine;
- (void)configureWithThread:(NSDictionary *)thread isSelected:(BOOL)isSelected;
@end

@implementation CTDOThreadCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 12, 46, 46)];
        _avatarView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont boldSystemFontOfSize:15.0];
        [self.contentView addSubview:_nameLabel];

        _tagBadgeLabel = [[UILabel alloc] init];
        _tagBadgeLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        [self.contentView addSubview:_tagBadgeLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:13.0];
        _subtitleLabel.numberOfLines = 1;
        [self.contentView addSubview:_subtitleLabel];

        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont systemFontOfSize:11.5];
        _timeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_timeLabel];

        _unreadBadge = [[UILabel alloc] init];
        _unreadBadge.font = [UIFont boldSystemFontOfSize:11.0];
        _unreadBadge.textColor = [UIColor whiteColor];
        _unreadBadge.backgroundColor = [UIColor colorWithRed:0.94 green:0.27 blue:0.27 alpha:1.0];
        _unreadBadge.textAlignment = NSTextAlignmentCenter;
        _unreadBadge.layer.cornerRadius = 9.0;
        _unreadBadge.layer.masksToBounds = YES;
        [self.contentView addSubview:_unreadBadge];

        _separatorLine = [[UIView alloc] init];
        [self.contentView addSubview:_separatorLine];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    _avatarView.frame = CGRectMake(12, (h - 46) * 0.5, 46, 46);
    _timeLabel.frame = CGRectMake(w - 76, 10, 66, 16);
    _nameLabel.frame = CGRectMake(68, 9, MAX(80, w - 150), 19);
    _tagBadgeLabel.frame = CGRectMake(68, 29, MAX(80, w - 115), 15);
    _subtitleLabel.frame = CGRectMake(68, 45, MAX(80, w - 110), 18);
    _unreadBadge.frame = CGRectMake(w - 34, 42, 22, 18);
    _separatorLine.frame = CGRectMake(68, h - 0.5, w - 68, 0.5);
}

- (void)configureWithThread:(NSDictionary *)thread isSelected:(BOOL)isSelected {
    CTDOTheme *theme = [CTDOTheme shared];
    self.contentView.backgroundColor = isSelected ? theme.bgElevated : theme.bgSecondary;
    _separatorLine.backgroundColor = theme.borderSubtle;

    NSString *name = thread[@"name"] ?: @"Hội thoại";
    BOOL pinned = [thread[@"is_pinned"] boolValue];
    BOOL muted = [thread[@"is_muted"] boolValue];
    NSMutableString *titleStr = [NSMutableString stringWithString:name];
    if (pinned) [titleStr appendString:@" 📌"];
    if (muted) [titleStr appendString:@" 🔕"];
    _nameLabel.text = titleStr;
    _nameLabel.textColor = theme.textPrimary;

    _tagBadgeLabel.text = thread[@"subtitle_tag"] ?: @"";
    _tagBadgeLabel.textColor = theme.accentPrimary;

    _subtitleLabel.text = thread[@"last_message"] ?: @"";
    _subtitleLabel.textColor = theme.textSecondary;

    _timeLabel.text = thread[@"last_time_label"] ?: @"";
    _timeLabel.textColor = theme.textSecondary;

    NSInteger unread = [thread[@"unread_count"] integerValue];
    if (unread > 0) {
        _unreadBadge.hidden = NO;
        _unreadBadge.text = unread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unread];
    } else {
        _unreadBadge.hidden = YES;
    }

    NSString *initials = thread[@"avatar_initials"] ?: @"Z";
    NSString *hex = thread[@"avatar_color_hex"] ?: @"#0068FF";
    BOOL online = [thread[@"is_online"] boolValue];
    _avatarView.image = [CTDOIconRenderer avatarWithInitials:initials colorHex:hex size:46.0 isOnline:online];
}

@end

// ============================================================================
// Custom Reusable Chat Bubble Cell (Supports Quote Reply, Reactions, Metadata)
// ============================================================================
@interface CTDOMessageCell : UITableViewCell
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UILabel *senderLabel;
@property (nonatomic, strong) UILabel *quoteLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UILabel *metaLabel;
- (void)configureWithMessage:(NSDictionary *)msg maxWidth:(CGFloat)maxWidth;
+ (CGFloat)heightForMessage:(NSDictionary *)msg maxWidth:(CGFloat)maxWidth;
@end

@implementation CTDOMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];

        _bubbleView = [[UIView alloc] init];
        _bubbleView.layer.cornerRadius = 14.0;
        _bubbleView.layer.borderWidth = 0.5;
        [self.contentView addSubview:_bubbleView];

        _senderLabel = [[UILabel alloc] init];
        _senderLabel.font = [UIFont boldSystemFontOfSize:11.5];
        [_bubbleView addSubview:_senderLabel];

        _quoteLabel = [[UILabel alloc] init];
        _quoteLabel.font = [UIFont italicSystemFontOfSize:11.5];
        _quoteLabel.numberOfLines = 2;
        _quoteLabel.layer.cornerRadius = 6.0;
        _quoteLabel.layer.masksToBounds = YES;
        [_bubbleView addSubview:_quoteLabel];

        _bodyLabel = [[UILabel alloc] init];
        _bodyLabel.font = [UIFont systemFontOfSize:14.5];
        _bodyLabel.numberOfLines = 0;
        [_bubbleView addSubview:_bodyLabel];

        _metaLabel = [[UILabel alloc] init];
        _metaLabel.font = [UIFont systemFontOfSize:11.0];
        [_bubbleView addSubview:_metaLabel];
    }
    return self;
}

+ (CGFloat)heightForMessage:(NSDictionary *)msg maxWidth:(CGFloat)maxWidth {
    CGFloat bubbleMaxW = MIN(maxWidth * 0.78, 460.0);
    CGFloat textMaxW = MAX(120.0, bubbleMaxW - 24.0);
    NSString *content = msg[@"content"] ?: @"";
    CGRect bodyRect = [content boundingRectWithSize:CGSizeMake(textMaxW, 2000.0)
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14.5]}
                                            context:nil];
    CGFloat h = ceil(bodyRect.size.height) + 46.0;
    NSString *quote = msg[@"reply_preview"];
    if ([quote isKindOfClass:[NSString class]] && quote.length > 0) {
        h += 28.0;
    }
    return MAX(64.0, h + 10.0);
}

- (void)configureWithMessage:(NSDictionary *)msg maxWidth:(CGFloat)maxWidth {
    CTDOTheme *theme = [CTDOTheme shared];
    BOOL isSelf = [msg[@"is_self"] boolValue];
    NSString *sender = msg[@"sender_name"] ?: (isSelf ? @"Tôi" : @"Đối tác");
    NSString *content = msg[@"content"] ?: @"";
    NSString *timeLbl = msg[@"time_label"] ?: @"";
    NSString *quote = [msg[@"reply_preview"] isKindOfClass:[NSString class]] ? msg[@"reply_preview"] : nil;
    NSArray *reactions = [msg[@"reactions"] isKindOfClass:[NSArray class]] ? msg[@"reactions"] : @[];

    CGFloat bubbleMaxW = MIN(maxWidth * 0.78, 460.0);
    CGFloat textMaxW = MAX(120.0, bubbleMaxW - 24.0);
    CGRect bodyRect = [content boundingRectWithSize:CGSizeMake(textMaxW, 2000.0)
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14.5]}
                                            context:nil];

    NSString *reactStr = reactions.count > 0 ? [NSString stringWithFormat:@"  %@", [reactions componentsJoinedByString:@" "]] : @"";
    NSString *metaText = [NSString stringWithFormat:@"%@%@", timeLbl, reactStr];

    CGFloat contentW = MAX(ceil(bodyRect.size.width), 130.0);
    if (quote && quote.length > 0) {
        contentW = MAX(contentW, MIN(textMaxW, 220.0));
    }
    CGFloat bubbleW = MIN(bubbleMaxW, contentW + 24.0);

    CGFloat yCursor = 8.0;
    _senderLabel.text = sender;
    _senderLabel.textColor = isSelf ? [UIColor colorWithRed:0.55 green:0.82 blue:1.0 alpha:1.0] : theme.accentOnline;
    if (theme.mode == CTDOThemeModeZaloLight && isSelf) {
        _senderLabel.textColor = theme.accentPrimary;
    }
    _senderLabel.frame = CGRectMake(12.0, yCursor, bubbleW - 24.0, 15.0);
    yCursor += 17.0;

    if (quote && quote.length > 0) {
        _quoteLabel.hidden = NO;
        _quoteLabel.text = [NSString stringWithFormat:@" ❝ %@", quote];
        _quoteLabel.textColor = theme.textSecondary;
        _quoteLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.15];
        _quoteLabel.frame = CGRectMake(12.0, yCursor, bubbleW - 24.0, 22.0);
        yCursor += 26.0;
    } else {
        _quoteLabel.hidden = YES;
    }

    _bodyLabel.text = content;
    _bodyLabel.textColor = (theme.mode == CTDOThemeModeZaloLight) ? theme.textPrimary : [UIColor whiteColor];
    CGFloat bodyH = ceil(bodyRect.size.height) + 2.0;
    _bodyLabel.frame = CGRectMake(12.0, yCursor, bubbleW - 24.0, bodyH);
    yCursor += bodyH + 4.0;

    _metaLabel.text = metaText;
    _metaLabel.textColor = theme.textSecondary;
    _metaLabel.frame = CGRectMake(12.0, yCursor, bubbleW - 24.0, 14.0);
    yCursor += 18.0;

    CGFloat bubbleX = isSelf ? (maxWidth - bubbleW - 12.0) : 12.0;
    _bubbleView.frame = CGRectMake(bubbleX, 4.0, bubbleW, yCursor);
    _bubbleView.backgroundColor = isSelf ? theme.bubbleSelf : theme.bubblePartner;
    _bubbleView.layer.borderColor = theme.borderSubtle.CGColor;
}

@end

// ============================================================================
// Main View Controller Implementation — Pure Native UIKit + Real Zalo QR Login
// ============================================================================
@interface CTDOMainViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, assign) NSInteger activeSlot; // 0 = Primary Account, 1 = Secondary Account (Duo #2)
@property (nonatomic, assign) NSInteger secondarySlot;
@property (nonatomic, assign) NSInteger filterMode;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, copy) NSString *selectedThreadIdPrimary;
@property (nonatomic, copy) NSString *selectedThreadIdSecondary;
@property (nonatomic, copy, nullable) NSString *replyToMsgIdPrimary;
@property (nonatomic, copy, nullable) NSString *replyPreviewTextPrimary;
@property (nonatomic, assign) BOOL compactShowingChatDetail;
@property (nonatomic, copy) NSString *lastRenderedQrPayload;

@property (nonatomic, strong) NSArray<NSDictionary *> *threadsPrimary;
@property (nonatomic, strong) NSArray<NSDictionary *> *messagesPrimary;
@property (nonatomic, strong) NSArray<NSDictionary *> *messagesSecondary;
@property (nonatomic, strong, nullable) NSDictionary *githubReleaseInfo;
@property (nonatomic, assign) BOOL updateBannerDismissed;

// Top Navigation & Hardware Badge (Zero fake mode-switcher buttons)
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIButton *accountButton;
@property (nonatomic, strong) UILabel *hardwareBadgeLabel;
@property (nonatomic, strong) UIButton *qrButton;
@property (nonatomic, strong) UIButton *scheduleButton;
@property (nonatomic, strong) UIButton *autoReplyButton;
@property (nonatomic, strong) UIButton *themeButton;
@property (nonatomic, strong) UIButton *updateCheckButton;

// GitHub Update Banner
@property (nonatomic, strong) UIView *updateBanner;
@property (nonatomic, strong) UILabel *updateBannerLabel;
@property (nonatomic, strong) UIButton *updateBannerDetailBtn;
@property (nonatomic, strong) UIButton *updateBannerCloseBtn;

// Workspace Containers
@property (nonatomic, strong) UIView *leftPane;
@property (nonatomic, strong) UIView *centerPane;
@property (nonatomic, strong) UIView *hingeBar;
@property (nonatomic, strong) UILabel *hingeLabel;
@property (nonatomic, strong) UIButton *hingeToggleBtn;
@property (nonatomic, strong) UIView *rightPane;

// Real Zalo QR Login Card (Rendered inside Center Pane when slot is not authenticated)
@property (nonatomic, strong) UIView *qrAuthOverlay;
@property (nonatomic, strong) UIView *qrCardView;
@property (nonatomic, strong) UILabel *qrTitleLabel;
@property (nonatomic, strong) UILabel *qrSubtitleLabel;
@property (nonatomic, strong) UIView *qrWhiteFrame;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, strong) UILabel *qrTokenLabel;
@property (nonatomic, strong) UILabel *qrStatusLabel;
@property (nonatomic, strong) UIButton *qrRefreshBtn;
@property (nonatomic, strong) UIButton *qrPasswordLoginBtn;

// Left Pane Views
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) UITableView *threadsTableView;
@property (nonatomic, strong) UILabel *emptyThreadsLabel;

// Primary Chat Views
@property (nonatomic, strong) UIView *chatHeaderPrimary;
@property (nonatomic, strong) UIButton *backButtonCompact;
@property (nonatomic, strong) UILabel *chatTitlePrimary;
@property (nonatomic, strong) UILabel *chatSubPrimary;
@property (nonatomic, strong) UIButton *syncRefreshBtn;
@property (nonatomic, strong) UIButton *callBtnPrimary;
@property (nonatomic, strong) UIButton *duoSendToRightBtn;
@property (nonatomic, strong) UITableView *messagesTablePrimary;
@property (nonatomic, strong) UIView *replyBarPrimary;
@property (nonatomic, strong) UILabel *replyBarLabelPrimary;
@property (nonatomic, strong) UIButton *replyBarCancelPrimary;
@property (nonatomic, strong) UIView *composerPrimary;
@property (nonatomic, strong) UIButton *stickerBtnPrimary;
@property (nonatomic, strong) UIButton *schedQuickBtnPrimary;
@property (nonatomic, strong) UITextField *inputFieldPrimary;
@property (nonatomic, strong) UIButton *sendBtnPrimary;

// Secondary Chat Views (iPhone Duo Right Screen & iPad 3rd Column)
@property (nonatomic, strong) UIView *chatHeaderSecondary;
@property (nonatomic, strong) UILabel *chatTitleSecondary;
@property (nonatomic, strong) UILabel *chatSubSecondary;
@property (nonatomic, strong) UIButton *switchSecondaryThreadBtn;
@property (nonatomic, strong) UIButton *switchSecondarySlotBtn;
@property (nonatomic, strong) UITableView *messagesTableSecondary;
@property (nonatomic, strong) UIView *composerSecondary;
@property (nonatomic, strong) UITextField *inputFieldSecondary;
@property (nonatomic, strong) UIButton *sendBtnSecondary;

// Background Timers
@property (nonatomic, strong, nullable) NSTimer *schedulerTimer;

@end

@implementation CTDOMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.activeSlot = 0;
    self.secondarySlot = 0;
    self.filterMode = 0;
    self.searchQuery = @"";
    self.selectedThreadIdPrimary = @"";
    self.selectedThreadIdSecondary = @"";
    self.duoDualChatMode = NO;
    self.lastRenderedQrPayload = @"";

    [self buildUI];
    [self applyTheme];

    // If not authenticated on Slot 0, immediately start real Zalo QR login from wpa.zaloapp.com
    NSDictionary *auth0 = [[CTDOCoreBridge shared] authStateForSlot:0];
    if (![auth0[@"status"] isEqualToString:@"authenticated"]) {
        [[CTDOCoreBridge shared] startQRLoginForSlot:0];
    }

    [self refreshAllData];

    // 1.2s timer to poll QR scan status, incoming messages, and scheduled messages
    self.schedulerTimer = [NSTimer scheduledTimerWithTimeInterval:1.2
                                                           target:self
                                                         selector:@selector(onPeriodicTick)
                                                         userInfo:nil
                                                          repeats:YES];

    [self triggerGitHubUpdateCheck:NO];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return ([CTDOTheme shared].mode == CTDOThemeModeZaloLight)
        ? UIStatusBarStyleDefault
        : UIStatusBarStyleLightContent;
}

- (void)buildUI {
    // 1. Top Bar (Native hardware badge — NO fake UI switcher buttons)
    _topBar = [[UIView alloc] init];
    [self.view addSubview:_topBar];

    _accountButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _accountButton.titleLabel.font = [UIFont boldSystemFontOfSize:12.5];
    _accountButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    _accountButton.titleLabel.minimumScaleFactor = 0.8;
    _accountButton.layer.cornerRadius = 8.0;
    _accountButton.contentEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 8);
    [_accountButton addTarget:self action:@selector(onTapAccountSwitch) forControlEvents:UIControlEventTouchUpInside];
    [_topBar addSubview:_accountButton];

    _hardwareBadgeLabel = [[UILabel alloc] init];
    _hardwareBadgeLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    _hardwareBadgeLabel.textAlignment = NSTextAlignmentCenter;
    _hardwareBadgeLabel.layer.cornerRadius = 7.0;
    _hardwareBadgeLabel.layer.masksToBounds = YES;
    [_topBar addSubview:_hardwareBadgeLabel];

    _qrButton = [self makeTopActionButton:@"📱 QR Login" action:@selector(onTapQRModal)];
    _scheduleButton = [self makeTopActionButton:@"🕒 Hẹn giờ" action:@selector(onTapScheduleModal)];
    _autoReplyButton = [self makeTopActionButton:@"🤖 Bot" action:@selector(onTapAutoReplyModal)];
    _themeButton = [self makeTopActionButton:@"🎨 Giao diện" action:@selector(onTapThemeCycle)];
    _updateCheckButton = [self makeTopActionButton:@"🚀 v0.0.5" action:@selector(onTapUpdateModal)];

    [_topBar addSubview:_qrButton];
    [_topBar addSubview:_scheduleButton];
    [_topBar addSubview:_autoReplyButton];
    [_topBar addSubview:_themeButton];
    [_topBar addSubview:_updateCheckButton];

    // 2. GitHub Releases API Update Banner
    _updateBanner = [[UIView alloc] init];
    _updateBanner.hidden = YES;
    [self.view addSubview:_updateBanner];

    _updateBannerLabel = [[UILabel alloc] init];
    _updateBannerLabel.font = [UIFont boldSystemFontOfSize:12.0];
    [_updateBanner addSubview:_updateBannerLabel];

    _updateBannerDetailBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_updateBannerDetailBtn setTitle:@"Chi tiết Update" forState:UIControlStateNormal];
    _updateBannerDetailBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11.5];
    _updateBannerDetailBtn.layer.cornerRadius = 6.0;
    [_updateBannerDetailBtn addTarget:self action:@selector(onTapUpdateModal) forControlEvents:UIControlEventTouchUpInside];
    [_updateBanner addSubview:_updateBannerDetailBtn];

    _updateBannerCloseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_updateBannerCloseBtn setTitle:@"✕" forState:UIControlStateNormal];
    _updateBannerCloseBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    [_updateBannerCloseBtn addTarget:self action:@selector(onDismissUpdateBanner) forControlEvents:UIControlEventTouchUpInside];
    [_updateBanner addSubview:_updateBannerCloseBtn];

    // 3. Workspace Panes
    _leftPane = [[UIView alloc] init];
    _centerPane = [[UIView alloc] init];
    _hingeBar = [[UIView alloc] init];
    _rightPane = [[UIView alloc] init];
    [self.view addSubview:_leftPane];
    [self.view addSubview:_centerPane];
    [self.view addSubview:_hingeBar];
    [self.view addSubview:_rightPane];

    // Hinge Bar (Only visible on iPhone Duo hardware or iPad 3-column divider)
    _hingeLabel = [[UILabel alloc] init];
    _hingeLabel.font = [UIFont boldSystemFontOfSize:10.0];
    _hingeLabel.textAlignment = NSTextAlignmentCenter;
    _hingeLabel.text = @"•\nD\nU\nO\n•";
    _hingeLabel.numberOfLines = 5;
    [_hingeBar addSubview:_hingeLabel];

    _hingeToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_hingeToggleBtn setTitle:@"⇄" forState:UIControlStateNormal];
    _hingeToggleBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    _hingeToggleBtn.layer.cornerRadius = 10.0;
    [_hingeToggleBtn addTarget:self action:@selector(onToggleDuoDualChatMode) forControlEvents:UIControlEventTouchUpInside];
    [_hingeBar addSubview:_hingeToggleBtn];

    // 4. Left Pane (Search + Filter + Threads Table + Empty State)
    _searchField = [[UITextField alloc] init];
    _searchField.placeholder = @"🔍 Tìm bạn bè, nhóm Zalo, UID...";
    _searchField.font = [UIFont systemFontOfSize:13.5];
    _searchField.layer.cornerRadius = 8.0;
    _searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    _searchField.leftViewMode = UITextFieldViewModeAlways;
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.delegate = self;
    [_searchField addTarget:self action:@selector(onSearchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [_leftPane addSubview:_searchField];

    _filterControl = [[UISegmentedControl alloc] initWithItems:@[@"Tất cả", @"Chưa đọc", @"Đã ghim", @"Nhóm", @"Đã ẩn"]];
    _filterControl.selectedSegmentIndex = 0;
    [_filterControl addTarget:self action:@selector(onFilterChanged:) forControlEvents:UIControlEventValueChanged];
    [_leftPane addSubview:_filterControl];

    _threadsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _threadsTableView.dataSource = self;
    _threadsTableView.delegate = self;
    _threadsTableView.rowHeight = 72.0;
    _threadsTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_threadsTableView registerClass:[CTDOThreadCell class] forCellReuseIdentifier:@"ThreadCell"];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressThread:)];
    [_threadsTableView addGestureRecognizer:lp];
    [_leftPane addSubview:_threadsTableView];

    _emptyThreadsLabel = [[UILabel alloc] init];
    _emptyThreadsLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _emptyThreadsLabel.textAlignment = NSTextAlignmentCenter;
    _emptyThreadsLabel.numberOfLines = 0;
    _emptyThreadsLabel.text = @"Chưa đăng nhập Zalo.\nQuét mã QR Zalo thực tế để đồng bộ\ndanh bạ, nhóm và tin nhắn của bạn.";
    [_leftPane addSubview:_emptyThreadsLabel];

    // 5. Primary Chat Pane
    _chatHeaderPrimary = [[UIView alloc] init];
    [_centerPane addSubview:_chatHeaderPrimary];

    _backButtonCompact = [UIButton buttonWithType:UIButtonTypeCustom];
    [_backButtonCompact setTitle:@"‹ Danh bạ" forState:UIControlStateNormal];
    _backButtonCompact.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [_backButtonCompact addTarget:self action:@selector(onTapCompactBack) forControlEvents:UIControlEventTouchUpInside];
    [_chatHeaderPrimary addSubview:_backButtonCompact];

    _chatTitlePrimary = [[UILabel alloc] init];
    _chatTitlePrimary.font = [UIFont boldSystemFontOfSize:15.5];
    [_chatHeaderPrimary addSubview:_chatTitlePrimary];

    _chatSubPrimary = [[UILabel alloc] init];
    _chatSubPrimary.font = [UIFont systemFontOfSize:11.5];
    [_chatHeaderPrimary addSubview:_chatSubPrimary];

    _syncRefreshBtn = [self makeSmallHeaderButton:@"🔄 Đồng bộ" action:@selector(onTapRefreshRealZalo)];
    _callBtnPrimary = [self makeSmallHeaderButton:@"📞 Gọi" action:@selector(onTapVoiceCall)];
    _duoSendToRightBtn = [self makeSmallHeaderButton:@"⫸ Màn #2" action:@selector(onTapOpenInRightScreen)];
    [_chatHeaderPrimary addSubview:_syncRefreshBtn];
    [_chatHeaderPrimary addSubview:_callBtnPrimary];
    [_chatHeaderPrimary addSubview:_duoSendToRightBtn];

    _messagesTablePrimary = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _messagesTablePrimary.dataSource = self;
    _messagesTablePrimary.delegate = self;
    _messagesTablePrimary.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_messagesTablePrimary registerClass:[CTDOMessageCell class] forCellReuseIdentifier:@"MsgCellPrimary"];
    [_centerPane addSubview:_messagesTablePrimary];

    _replyBarPrimary = [[UIView alloc] init];
    _replyBarPrimary.hidden = YES;
    [_centerPane addSubview:_replyBarPrimary];

    _replyBarLabelPrimary = [[UILabel alloc] init];
    _replyBarLabelPrimary.font = [UIFont italicSystemFontOfSize:12.0];
    [_replyBarPrimary addSubview:_replyBarLabelPrimary];

    _replyBarCancelPrimary = [UIButton buttonWithType:UIButtonTypeCustom];
    [_replyBarCancelPrimary setTitle:@"✕" forState:UIControlStateNormal];
    [_replyBarCancelPrimary addTarget:self action:@selector(onCancelReplyPrimary) forControlEvents:UIControlEventTouchUpInside];
    [_replyBarPrimary addSubview:_replyBarCancelPrimary];

    _composerPrimary = [[UIView alloc] init];
    [_centerPane addSubview:_composerPrimary];

    _stickerBtnPrimary = [self makeSmallHeaderButton:@"🎉" action:@selector(onTapStickerPicker)];
    _schedQuickBtnPrimary = [self makeSmallHeaderButton:@"🕒" action:@selector(onTapQuickSchedulePrimary)];
    [_composerPrimary addSubview:_stickerBtnPrimary];
    [_composerPrimary addSubview:_schedQuickBtnPrimary];

    _inputFieldPrimary = [[UITextField alloc] init];
    _inputFieldPrimary.placeholder = @"Nhập tin nhắn Zalo thực tế (Enter để gửi)...";
    _inputFieldPrimary.font = [UIFont systemFontOfSize:14.0];
    _inputFieldPrimary.layer.cornerRadius = 17.0;
    _inputFieldPrimary.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 10)];
    _inputFieldPrimary.leftViewMode = UITextFieldViewModeAlways;
    _inputFieldPrimary.returnKeyType = UIReturnKeySend;
    _inputFieldPrimary.delegate = self;
    [_composerPrimary addSubview:_inputFieldPrimary];

    _sendBtnPrimary = [UIButton buttonWithType:UIButtonTypeCustom];
    [_sendBtnPrimary setTitle:@"Gửi" forState:UIControlStateNormal];
    _sendBtnPrimary.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
    _sendBtnPrimary.layer.cornerRadius = 17.0;
    [_sendBtnPrimary addTarget:self action:@selector(onSendPrimary) forControlEvents:UIControlEventTouchUpInside];
    [_composerPrimary addSubview:_sendBtnPrimary];

    // 5b. Real Zalo QR Login Overlay (Shown when not authenticated — Zero Fake Data)
    _qrAuthOverlay = [[UIView alloc] init];
    [_centerPane addSubview:_qrAuthOverlay];

    _qrCardView = [[UIView alloc] init];
    _qrCardView.layer.cornerRadius = 16.0;
    _qrCardView.layer.borderWidth = 1.0;
    [_qrAuthOverlay addSubview:_qrCardView];

    _qrTitleLabel = [[UILabel alloc] init];
    _qrTitleLabel.font = [UIFont boldSystemFontOfSize:17.0];
    _qrTitleLabel.textAlignment = NSTextAlignmentCenter;
    _qrTitleLabel.text = @"Đăng nhập Zalo bằng Mã QR";
    [_qrCardView addSubview:_qrTitleLabel];

    _qrSubtitleLabel = [[UILabel alloc] init];
    _qrSubtitleLabel.font = [UIFont systemFontOfSize:12.0];
    _qrSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    _qrSubtitleLabel.numberOfLines = 2;
    _qrSubtitleLabel.text = @"Kết nối trực tiếp tới wpa.zaloapp.com/api/login/reqqr · Không dùng dữ liệu giả";
    [_qrCardView addSubview:_qrSubtitleLabel];

    _qrWhiteFrame = [[UIView alloc] init];
    _qrWhiteFrame.backgroundColor = [UIColor whiteColor];
    _qrWhiteFrame.layer.cornerRadius = 12.0;
    [_qrCardView addSubview:_qrWhiteFrame];

    _qrImageView = [[UIImageView alloc] init];
    _qrImageView.contentMode = UIViewContentModeScaleAspectFit;
    [_qrWhiteFrame addSubview:_qrImageView];

    _qrTokenLabel = [[UILabel alloc] init];
    _qrTokenLabel.font = [UIFont fontWithName:@"Menlo" size:10.5] ?: [UIFont systemFontOfSize:10.5];
    _qrTokenLabel.textAlignment = NSTextAlignmentCenter;
    _qrTokenLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_qrCardView addSubview:_qrTokenLabel];

    _qrStatusLabel = [[UILabel alloc] init];
    _qrStatusLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
    _qrStatusLabel.textAlignment = NSTextAlignmentCenter;
    _qrStatusLabel.numberOfLines = 3;
    [_qrCardView addSubview:_qrStatusLabel];

    _qrRefreshBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_qrRefreshBtn setTitle:@"🔄 Lấy mã QR mới" forState:UIControlStateNormal];
    _qrRefreshBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    _qrRefreshBtn.layer.cornerRadius = 10.0;
    [_qrRefreshBtn addTarget:self action:@selector(onTapRefreshQR) forControlEvents:UIControlEventTouchUpInside];
    [_qrCardView addSubview:_qrRefreshBtn];

    _qrPasswordLoginBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_qrPasswordLoginBtn setTitle:@"🔑 Đăng nhập SĐT / MK" forState:UIControlStateNormal];
    _qrPasswordLoginBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    _qrPasswordLoginBtn.layer.cornerRadius = 10.0;
    [_qrPasswordLoginBtn addTarget:self action:@selector(onTapPasswordLoginModal) forControlEvents:UIControlEventTouchUpInside];
    [_qrCardView addSubview:_qrPasswordLoginBtn];

    // 6. Secondary Chat Pane (iPhone Duo Right Screen & iPad 3rd Column)
    _chatHeaderSecondary = [[UIView alloc] init];
    [_rightPane addSubview:_chatHeaderSecondary];

    _chatTitleSecondary = [[UILabel alloc] init];
    _chatTitleSecondary.font = [UIFont boldSystemFontOfSize:14.5];
    [_chatHeaderSecondary addSubview:_chatTitleSecondary];

    _chatSubSecondary = [[UILabel alloc] init];
    _chatSubSecondary.font = [UIFont systemFontOfSize:11.0];
    [_chatHeaderSecondary addSubview:_chatSubSecondary];

    _switchSecondaryThreadBtn = [self makeSmallHeaderButton:@"🔄 Đổi Chat" action:@selector(onTapSwitchSecondaryThread)];
    _switchSecondarySlotBtn = [self makeSmallHeaderButton:@"👥 TK1/2" action:@selector(onTapToggleSecondarySlot)];
    [_chatHeaderSecondary addSubview:_switchSecondaryThreadBtn];
    [_chatHeaderSecondary addSubview:_switchSecondarySlotBtn];

    _messagesTableSecondary = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _messagesTableSecondary.dataSource = self;
    _messagesTableSecondary.delegate = self;
    _messagesTableSecondary.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_messagesTableSecondary registerClass:[CTDOMessageCell class] forCellReuseIdentifier:@"MsgCellSecondary"];
    [_rightPane addSubview:_messagesTableSecondary];

    _composerSecondary = [[UIView alloc] init];
    [_rightPane addSubview:_composerSecondary];

    _inputFieldSecondary = [[UITextField alloc] init];
    _inputFieldSecondary.placeholder = @"Nhắn ở màn hình Phải (iPhone Duo / iPad)...";
    _inputFieldSecondary.font = [UIFont systemFontOfSize:13.5];
    _inputFieldSecondary.layer.cornerRadius = 16.0;
    _inputFieldSecondary.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    _inputFieldSecondary.leftViewMode = UITextFieldViewModeAlways;
    _inputFieldSecondary.returnKeyType = UIReturnKeySend;
    _inputFieldSecondary.delegate = self;
    [_composerSecondary addSubview:_inputFieldSecondary];

    _sendBtnSecondary = [UIButton buttonWithType:UIButtonTypeCustom];
    [_sendBtnSecondary setTitle:@"Gửi #2" forState:UIControlStateNormal];
    _sendBtnSecondary.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    _sendBtnSecondary.layer.cornerRadius = 16.0;
    [_sendBtnSecondary addTarget:self action:@selector(onSendSecondary) forControlEvents:UIControlEventTouchUpInside];
    [_composerSecondary addSubview:_sendBtnSecondary];
}

- (UIButton *)makeTopActionButton:(NSString *)title action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    btn.titleLabel.adjustsFontSizeToFitWidth = YES;
    btn.titleLabel.minimumScaleFactor = 0.75;
    btn.layer.cornerRadius = 7.0;
    btn.contentEdgeInsets = UIEdgeInsetsMake(4, 6, 4, 6);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UIButton *)makeSmallHeaderButton:(NSString *)title action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    btn.titleLabel.adjustsFontSizeToFitWidth = YES;
    btn.titleLabel.minimumScaleFactor = 0.75;
    btn.layer.cornerRadius = 6.0;
    btn.contentEdgeInsets = UIEdgeInsetsMake(4, 6, 4, 6);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

// ============================================================================
// Hardware-Truth Responsive Layout Engine (iPhone vs iPhone Duo vs iPad)
// ============================================================================
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UIEdgeInsets safe = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safe = self.view.safeAreaInsets;
    }
    CGFloat fullW = self.view.bounds.size.width;
    CGFloat fullH = self.view.bounds.size.height;
    CGFloat topY = safe.top;
    CGFloat bottomH = safe.bottom;

    CTDODeviceClass devClass = [[CTDOCoreBridge shared] hardwareDeviceClassForWindowSize:self.view.bounds.size];
    NSString *hwName = [[CTDOCoreBridge shared] deviceHardwareName];
    if (devClass == CTDODeviceClassiPhoneDuo) {
        _hardwareBadgeLabel.text = [NSString stringWithFormat:@"📖 %@ · Dual-Screen", hwName];
    } else if (devClass == CTDODeviceClassiPad) {
        _hardwareBadgeLabel.text = [NSString stringWithFormat:@"🖥 %@ · 3-Column", hwName];
    } else {
        _hardwareBadgeLabel.text = [NSString stringWithFormat:@"📱 %@", hwName];
    }

    BOOL isNarrow = (fullW < 680.0);
    CGFloat topBarH = isNarrow ? 76.0 : 46.0;
    _topBar.frame = CGRectMake(0, topY, fullW, topBarH);

    if (isNarrow) {
        _accountButton.frame = CGRectMake(10, 6, 138, 28);
        _hardwareBadgeLabel.frame = CGRectMake(154, 6, fullW - 164, 28);
        CGFloat btnW = (fullW - 20 - 16) / 5.0;
        NSArray<UIButton *> *btns = @[_qrButton, _scheduleButton, _autoReplyButton, _themeButton, _updateCheckButton];
        for (NSUInteger i = 0; i < btns.count; i++) {
            btns[i].frame = CGRectMake(10 + i * (btnW + 4.0), 40, btnW, 30);
        }
    } else {
        _accountButton.frame = CGRectMake(12, 8, 160, 30);
        _hardwareBadgeLabel.frame = CGRectMake(180, 8, 250, 30);
        CGFloat rightX = fullW - 12;
        NSArray<UIButton *> *btns = @[_updateCheckButton, _themeButton, _autoReplyButton, _scheduleButton, _qrButton];
        for (UIButton *b in btns) {
            CGFloat bw = [b.titleLabel.text sizeWithAttributes:@{NSFontAttributeName: b.titleLabel.font}].width + 20.0;
            rightX -= bw;
            b.frame = CGRectMake(rightX, 8, bw, 30);
            rightX -= 6.0;
        }
    }

    CGFloat contentY = topY + topBarH;
    BOOL showBanner = (!_updateBanner.hidden && !_updateBannerDismissed);
    if (showBanner) {
        _updateBanner.frame = CGRectMake(0, contentY, fullW, 32.0);
        _updateBannerCloseBtn.frame = CGRectMake(fullW - 32, 1, 26, 30);
        _updateBannerDetailBtn.frame = CGRectMake(fullW - 150, 3, 114, 26);
        _updateBannerLabel.frame = CGRectMake(12, 1, MAX(100, fullW - 168), 30);
        contentY += 32.0;
    }

    CGFloat workspaceH = MAX(100.0, fullH - contentY - bottomH);
    NSDictionary *auth = [[CTDOCoreBridge shared] authStateForSlot:self.activeSlot];
    BOOL isAuthed = [auth[@"status"] isEqualToString:@"authenticated"];

    if (devClass == CTDODeviceClassiPhone) {
        _hingeBar.hidden = YES;
        _rightPane.hidden = YES;
        _backButtonCompact.hidden = !isAuthed;
        _duoSendToRightBtn.hidden = YES;
        if (!isAuthed || self.compactShowingChatDetail) {
            _leftPane.hidden = YES;
            _centerPane.hidden = NO;
            _centerPane.frame = CGRectMake(0, contentY, fullW, workspaceH);
        } else {
            _leftPane.hidden = NO;
            _centerPane.hidden = YES;
            _leftPane.frame = CGRectMake(0, contentY, fullW, workspaceH);
        }
    } else if (devClass == CTDODeviceClassiPhoneDuo) {
        // Native iPhone Duo (iPhone19,4) Dual-Pane Hinge-Aware Layout
        _backButtonCompact.hidden = !self.duoDualChatMode;
        _duoSendToRightBtn.hidden = NO;
        _hingeBar.hidden = NO;

        CGFloat hingeW = 16.0;
        CGFloat leftW = floor((fullW - hingeW) * 0.42);
        if (self.duoDualChatMode) {
            leftW = floor((fullW - hingeW) * 0.50);
        }
        _hingeBar.frame = CGRectMake(leftW, contentY, hingeW, workspaceH);
        _hingeToggleBtn.frame = CGRectMake(1, 10, hingeW - 2, 28);
        _hingeLabel.frame = CGRectMake(0, 44, hingeW, 90);

        if (self.duoDualChatMode) {
            _leftPane.hidden = YES;
            _centerPane.hidden = NO;
            _rightPane.hidden = NO;
            _centerPane.frame = CGRectMake(0, contentY, leftW, workspaceH);
            _rightPane.frame = CGRectMake(leftW + hingeW, contentY, fullW - leftW - hingeW, workspaceH);
        } else {
            _leftPane.hidden = NO;
            _centerPane.hidden = NO;
            _rightPane.hidden = YES;
            _leftPane.frame = CGRectMake(0, contentY, leftW, workspaceH);
            _centerPane.frame = CGRectMake(leftW + hingeW, contentY, fullW - leftW - hingeW, workspaceH);
        }
    } else {
        // Native iPad 3-Column Split-View Layout
        _backButtonCompact.hidden = YES;
        _duoSendToRightBtn.hidden = NO;
        _leftPane.hidden = NO;
        _centerPane.hidden = NO;
        _hingeBar.hidden = NO;
        _rightPane.hidden = NO;

        CGFloat leftW = 265.0;
        CGFloat hingeW = 12.0;
        CGFloat rightW = MIN(310.0, floor(fullW * 0.29));
        CGFloat centerW = MAX(300.0, fullW - leftW - hingeW - rightW);

        _leftPane.frame = CGRectMake(0, contentY, leftW, workspaceH);
        _centerPane.frame = CGRectMake(leftW, contentY, centerW, workspaceH);
        _hingeBar.frame = CGRectMake(leftW + centerW, contentY, hingeW, workspaceH);
        _hingeToggleBtn.frame = CGRectMake(0, 10, hingeW, 28);
        _hingeLabel.frame = CGRectMake(0, 44, hingeW, 90);
        _rightPane.frame = CGRectMake(leftW + centerW + hingeW, contentY, rightW, workspaceH);
    }

    [self layoutLeftPane];
    [self layoutPrimaryChatPane];
    [self layoutSecondaryChatPane];
}

- (void)layoutLeftPane {
    if (_leftPane.hidden) return;
    CGFloat w = _leftPane.bounds.size.width;
    CGFloat h = _leftPane.bounds.size.height;
    _searchField.frame = CGRectMake(8, 8, w - 16, 34);
    _filterControl.frame = CGRectMake(8, 48, w - 16, 28);
    _threadsTableView.frame = CGRectMake(0, 82, w, MAX(40, h - 82));
    _emptyThreadsLabel.frame = CGRectMake(14, 120, MAX(80, w - 28), 110);
}

- (void)layoutPrimaryChatPane {
    if (_centerPane.hidden) return;
    CGFloat w = _centerPane.bounds.size.width;
    CGFloat h = _centerPane.bounds.size.height;

    _chatHeaderPrimary.frame = CGRectMake(0, 0, w, 54);
    CGFloat titleX = 12.0;
    if (!_backButtonCompact.hidden) {
        _backButtonCompact.frame = CGRectMake(8, 12, 82, 30);
        titleX = 94.0;
    }

    CGFloat btnRight = w - 8.0;
    if (!_duoSendToRightBtn.hidden && w >= 420.0) {
        _duoSendToRightBtn.frame = CGRectMake(btnRight - 86, 13, 86, 28);
        btnRight -= 92.0;
    } else {
        _duoSendToRightBtn.frame = CGRectZero;
    }
    _callBtnPrimary.frame = CGRectMake(btnRight - 56, 13, 56, 28);
    btnRight -= 62.0;
    _syncRefreshBtn.frame = CGRectMake(btnRight - 84, 13, 84, 28);
    btnRight -= 90.0;

    CGFloat availTitleW = MAX(70.0, btnRight - titleX);
    _chatTitlePrimary.frame = CGRectMake(titleX, 8, availTitleW, 20);
    _chatSubPrimary.frame = CGRectMake(titleX, 29, availTitleW, 16);

    CGFloat composerH = 50.0;
    CGFloat replyH = _replyBarPrimary.hidden ? 0.0 : 28.0;
    _composerPrimary.frame = CGRectMake(0, h - composerH, w, composerH);
    if (replyH > 0.0) {
        _replyBarPrimary.frame = CGRectMake(0, h - composerH - replyH, w, replyH);
        _replyBarLabelPrimary.frame = CGRectMake(12, 4, w - 44, 20);
        _replyBarCancelPrimary.frame = CGRectMake(w - 32, 2, 26, 24);
    }
    _messagesTablePrimary.frame = CGRectMake(0, 54, w, MAX(40, h - 54 - composerH - replyH));

    _stickerBtnPrimary.frame = CGRectMake(8, 8, 34, 34);
    _schedQuickBtnPrimary.frame = CGRectMake(46, 8, 34, 34);
    _sendBtnPrimary.frame = CGRectMake(w - 64, 8, 56, 34);
    _inputFieldPrimary.frame = CGRectMake(86, 8, MAX(80, w - 156), 34);

    // Layout QR Auth Overlay
    _qrAuthOverlay.frame = CGRectMake(0, 0, w, h);
    CGFloat cardW = MIN(w - 16.0, 380.0);
    CGFloat cardH = MIN(h - 16.0, 440.0);
    _qrCardView.frame = CGRectMake((w - cardW) * 0.5, (h - cardH) * 0.5, cardW, cardH);

    _qrTitleLabel.frame = CGRectMake(12, 12, cardW - 24, 22);
    _qrSubtitleLabel.frame = CGRectMake(12, 34, cardW - 24, 30);

    CGFloat qrSide = MIN(cardW - 44.0, MAX(150.0, cardH - 196.0));
    _qrWhiteFrame.frame = CGRectMake((cardW - qrSide) * 0.5, 68, qrSide, qrSide);
    _qrImageView.frame = CGRectMake(10, 10, qrSide - 20, qrSide - 20);

    CGFloat afterQrY = 68 + qrSide + 8;
    _qrTokenLabel.frame = CGRectMake(12, afterQrY, cardW - 24, 16);
    _qrStatusLabel.frame = CGRectMake(12, afterQrY + 18, cardW - 24, 46);

    CGFloat btnW = (cardW - 32) * 0.5;
    _qrRefreshBtn.frame = CGRectMake(12, cardH - 46, btnW, 34);
    _qrPasswordLoginBtn.frame = CGRectMake(20 + btnW, cardH - 46, btnW, 34);
}

- (void)layoutSecondaryChatPane {
    if (_rightPane.hidden) return;
    CGFloat w = _rightPane.bounds.size.width;
    CGFloat h = _rightPane.bounds.size.height;

    _chatHeaderSecondary.frame = CGRectMake(0, 0, w, 54);
    _switchSecondarySlotBtn.frame = CGRectMake(w - 76, 13, 68, 28);
    _switchSecondaryThreadBtn.frame = CGRectMake(w - 168, 13, 86, 28);
    _chatTitleSecondary.frame = CGRectMake(10, 8, MAX(60, w - 174), 20);
    _chatSubSecondary.frame = CGRectMake(10, 29, MAX(60, w - 174), 16);

    CGFloat composerH = 50.0;
    _composerSecondary.frame = CGRectMake(0, h - composerH, w, composerH);
    _messagesTableSecondary.frame = CGRectMake(0, 54, w, MAX(40, h - 54 - composerH));

    _sendBtnSecondary.frame = CGRectMake(w - 66, 8, 58, 34);
    _inputFieldSecondary.frame = CGRectMake(10, 8, MAX(60, w - 82), 34);
}

// ============================================================================
// Theme Styling
// ============================================================================
- (void)applyTheme {
    CTDOTheme *theme = [CTDOTheme shared];
    self.view.backgroundColor = theme.bgPrimary;
    _topBar.backgroundColor = theme.bgHeader;

    _accountButton.backgroundColor = theme.bgElevated;
    [_accountButton setTitleColor:theme.textPrimary forState:UIControlStateNormal];

    _hardwareBadgeLabel.backgroundColor = theme.bgElevated;
    _hardwareBadgeLabel.textColor = theme.accentOnline;

    NSArray<UIButton *> *topBtns = @[_qrButton, _scheduleButton, _autoReplyButton, _themeButton, _updateCheckButton];
    for (UIButton *b in topBtns) {
        b.backgroundColor = theme.bgElevated;
        [b setTitleColor:theme.textPrimary forState:UIControlStateNormal];
    }
    _qrButton.backgroundColor = theme.accentPrimary;
    [_qrButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _updateCheckButton.backgroundColor = [UIColor colorWithRed:0.06 green:0.48 blue:0.36 alpha:1.0];
    [_updateCheckButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    _updateBanner.backgroundColor = [UIColor colorWithRed:0.04 green:0.28 blue:0.22 alpha:1.0];
    _updateBannerLabel.textColor = [UIColor colorWithRed:0.45 green:0.95 blue:0.75 alpha:1.0];
    _updateBannerDetailBtn.backgroundColor = theme.accentOnline;
    [_updateBannerDetailBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_updateBannerCloseBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    _leftPane.backgroundColor = theme.bgSecondary;
    _leftPane.layer.borderColor = theme.borderSubtle.CGColor;
    _leftPane.layer.borderWidth = 0.5;

    _searchField.backgroundColor = theme.bgElevated;
    _searchField.textColor = theme.textPrimary;
    _searchField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"🔍 Tìm bạn bè, nhóm Zalo, UID..."
            attributes:@{NSForegroundColorAttributeName: theme.textSecondary}];
    _threadsTableView.backgroundColor = theme.bgSecondary;
    _emptyThreadsLabel.textColor = theme.textSecondary;

    NSDictionary *segNormal = @{
        NSForegroundColorAttributeName: theme.textSecondary,
        NSFontAttributeName: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold]
    };
    NSDictionary *segSelected = @{
        NSForegroundColorAttributeName: (theme.mode == CTDOThemeModeZaloLight) ? [UIColor blackColor] : [UIColor whiteColor],
        NSFontAttributeName: [UIFont boldSystemFontOfSize:11.0]
    };
    [_filterControl setTitleTextAttributes:segNormal forState:UIControlStateNormal];
    [_filterControl setTitleTextAttributes:segSelected forState:UIControlStateSelected];
    if (@available(iOS 13.0, *)) {
        _filterControl.selectedSegmentTintColor = theme.accentPrimary;
    }

    _centerPane.backgroundColor = theme.bgPrimary;
    _chatHeaderPrimary.backgroundColor = theme.bgSecondary;
    _chatTitlePrimary.textColor = theme.textPrimary;
    _chatSubPrimary.textColor = theme.textSecondary;
    [_backButtonCompact setTitleColor:theme.accentPrimary forState:UIControlStateNormal];

    for (UIButton *b in @[_syncRefreshBtn, _callBtnPrimary, _duoSendToRightBtn, _stickerBtnPrimary, _schedQuickBtnPrimary]) {
        b.backgroundColor = theme.bgElevated;
        [b setTitleColor:theme.textPrimary forState:UIControlStateNormal];
    }

    _messagesTablePrimary.backgroundColor = theme.bgPrimary;
    _replyBarPrimary.backgroundColor = theme.bgElevated;
    _replyBarLabelPrimary.textColor = theme.textSecondary;
    [_replyBarCancelPrimary setTitleColor:theme.textPrimary forState:UIControlStateNormal];

    _composerPrimary.backgroundColor = theme.bgSecondary;
    _inputFieldPrimary.backgroundColor = theme.bgElevated;
    _inputFieldPrimary.textColor = theme.textPrimary;
    _inputFieldPrimary.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"Nhập tin nhắn Zalo thực tế (Enter để gửi)..."
            attributes:@{NSForegroundColorAttributeName: theme.textSecondary}];
    _sendBtnPrimary.backgroundColor = theme.accentPrimary;
    [_sendBtnPrimary setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    // QR Auth Overlay styling
    _qrAuthOverlay.backgroundColor = theme.bgPrimary;
    _qrCardView.backgroundColor = theme.bgSecondary;
    _qrCardView.layer.borderColor = theme.borderSubtle.CGColor;
    _qrTitleLabel.textColor = theme.textPrimary;
    _qrSubtitleLabel.textColor = theme.textSecondary;
    _qrTokenLabel.textColor = theme.accentPrimary;
    _qrStatusLabel.textColor = theme.accentOnline;
    _qrRefreshBtn.backgroundColor = theme.accentPrimary;
    [_qrRefreshBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _qrPasswordLoginBtn.backgroundColor = theme.bgElevated;
    [_qrPasswordLoginBtn setTitleColor:theme.textPrimary forState:UIControlStateNormal];

    _hingeBar.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.06 alpha:1.0];
    _hingeLabel.textColor = theme.accentPrimary;
    _hingeToggleBtn.backgroundColor = theme.accentPrimary;
    [_hingeToggleBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    _rightPane.backgroundColor = theme.bgPrimary;
    _chatHeaderSecondary.backgroundColor = theme.bgSecondary;
    _chatTitleSecondary.textColor = theme.textPrimary;
    _chatSubSecondary.textColor = theme.accentOnline;
    for (UIButton *b in @[_switchSecondaryThreadBtn, _switchSecondarySlotBtn]) {
        b.backgroundColor = theme.bgElevated;
        [b setTitleColor:theme.textPrimary forState:UIControlStateNormal];
    }
    _messagesTableSecondary.backgroundColor = theme.bgPrimary;
    _composerSecondary.backgroundColor = theme.bgSecondary;
    _inputFieldSecondary.backgroundColor = theme.bgElevated;
    _inputFieldSecondary.textColor = theme.textPrimary;
    _inputFieldSecondary.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"Nhắn ở màn hình Phải (iPhone Duo / iPad)..."
            attributes:@{NSForegroundColorAttributeName: theme.textSecondary}];
    _sendBtnSecondary.backgroundColor = theme.accentOnline;
    [_sendBtnSecondary setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    [self setNeedsStatusBarAppearanceUpdate];
}

// ============================================================================
// Data Loading & Live QR Status Sync
// ============================================================================
- (void)refreshAllData {
    CTDOCoreBridge *core = [CTDOCoreBridge shared];
    NSDictionary *auth = [core authStateForSlot:self.activeSlot];
    NSString *status = auth[@"status"] ?: @"unauthenticated";
    BOOL isAuthed = [status isEqualToString:@"authenticated"];

    NSString *accTitle = (self.activeSlot == 0)
        ? (isAuthed ? [NSString stringWithFormat:@"👤 TK1: %@", auth[@"display_name"]] : @"👤 TK1 (Chưa ĐN)")
        : (isAuthed ? [NSString stringWithFormat:@"👥 TK2: %@", auth[@"display_name"]] : @"👥 TK2 (Chưa ĐN)");
    [_accountButton setTitle:accTitle forState:UIControlStateNormal];

    if (!isAuthed) {
        _qrAuthOverlay.hidden = NO;
        _qrStatusLabel.text = auth[@"status_message"] ?: @"Đang lấy mã QR từ máy chủ Zalo...";
        NSString *tokenId = auth[@"qr_token_id"] ?: @"";
        _qrTokenLabel.text = tokenId.length > 0 ? [NSString stringWithFormat:@"Token: %@", tokenId] : @"Đang kết nối wpa.zaloapp.com...";

        NSString *qrPayload = auth[@"qr_payload"] ?: @"";
        NSString *qrB64 = auth[@"qr_image_b64"] ?: @"";
        if (qrPayload.length > 0 && ![qrPayload isEqualToString:self.lastRenderedQrPayload]) {
            self.lastRenderedQrPayload = qrPayload;
            _qrImageView.image = [CTDOIconRenderer qrCodeImageForString:qrPayload size:240.0];
        } else if (qrPayload.length == 0 && qrB64.length > 0 && ![qrB64 isEqualToString:self.lastRenderedQrPayload]) {
            self.lastRenderedQrPayload = qrB64;
            _qrImageView.image = [CTDOIconRenderer imageFromBase64String:qrB64];
        } else if (qrPayload.length == 0 && qrB64.length == 0) {
            _qrImageView.image = [CTDOIconRenderer appLogoWithSize:120.0];
        }
    } else {
        _qrAuthOverlay.hidden = YES;
    }

    self.threadsPrimary = [core listThreadsForSlot:self.activeSlot
                                        filterMode:self.filterMode
                                       searchQuery:self.searchQuery];
    _emptyThreadsLabel.hidden = (self.threadsPrimary.count > 0);
    if (isAuthed && self.threadsPrimary.count == 0) {
        _emptyThreadsLabel.text = @"Đang đồng bộ danh bạ & tin nhắn từ Zalo...\nBấm '🔄 Đồng bộ' nếu chưa thấy hội thoại.";
    } else if (!isAuthed) {
        _emptyThreadsLabel.text = @"Chưa đăng nhập Zalo.\nHãy dùng điện thoại quét mã QR bên phải\nđể tải danh bạ & tin nhắn thực tế.";
    }

    BOOL foundPrimary = NO;
    NSDictionary *primaryThreadObj = nil;
    for (NSDictionary *t in self.threadsPrimary) {
        if ([t[@"id"] isEqualToString:self.selectedThreadIdPrimary]) {
            foundPrimary = YES;
            primaryThreadObj = t;
            break;
        }
    }
    if (!foundPrimary && self.threadsPrimary.count > 0) {
        primaryThreadObj = self.threadsPrimary.firstObject;
        self.selectedThreadIdPrimary = primaryThreadObj[@"id"] ?: @"";
    }

    if (primaryThreadObj) {
        _chatTitlePrimary.text = primaryThreadObj[@"name"] ?: @"Hội thoại";
        _chatSubPrimary.text = [NSString stringWithFormat:@"[%@] %@",
                                primaryThreadObj[@"id"] ?: @"",
                                primaryThreadObj[@"subtitle_tag"] ?: @""];
    } else {
        _chatTitlePrimary.text = isAuthed ? @"Chọn một hội thoại Zalo" : @"Đăng nhập Zalo QR";
        _chatSubPrimary.text = isAuthed ? @"Đã kết nối phiên Zalo thực tế" : @"Quét mã QR để bắt đầu trò chuyện";
    }

    self.messagesPrimary = [core getMessagesForSlot:self.activeSlot
                                           threadId:self.selectedThreadIdPrimary];

    // Secondary Pane (iPhone Duo Right Screen / iPad 3rd Column)
    NSDictionary *authSec = [core authStateForSlot:self.secondarySlot];
    BOOL secAuthed = [authSec[@"status"] isEqualToString:@"authenticated"];
    NSArray<NSDictionary *> *secThreads = [core listThreadsForSlot:self.secondarySlot
                                                        filterMode:0
                                                       searchQuery:@""];
    NSDictionary *secThreadObj = nil;
    for (NSDictionary *t in secThreads) {
        if ([t[@"id"] isEqualToString:self.selectedThreadIdSecondary]) {
            secThreadObj = t;
            break;
        }
    }
    if (!secThreadObj && secThreads.count > 0) {
        secThreadObj = (secThreads.count > 1) ? secThreads[1] : secThreads[0];
        self.selectedThreadIdSecondary = secThreadObj[@"id"] ?: @"";
    }
    if (secThreadObj) {
        _chatTitleSecondary.text = [NSString stringWithFormat:@"Màn #2 (TK%ld): %@",
                                    (long)(self.secondarySlot + 1),
                                    secThreadObj[@"name"] ?: @"Hội thoại"];
        _chatSubSecondary.text = [NSString stringWithFormat:@"ID: %@ · %@",
                                  secThreadObj[@"id"] ?: @"",
                                  secThreadObj[@"subtitle_tag"] ?: @""];
    } else {
        _chatTitleSecondary.text = [NSString stringWithFormat:@"Màn #2 (TK%ld)", (long)(self.secondarySlot + 1)];
        _chatSubSecondary.text = secAuthed ? @"Chọn hội thoại để mở song song" : @"Chờ đăng nhập QR Zalo";
    }
    self.messagesSecondary = [core getMessagesForSlot:self.secondarySlot
                                             threadId:self.selectedThreadIdSecondary];

    [_threadsTableView reloadData];
    [_messagesTablePrimary reloadData];
    [_messagesTableSecondary reloadData];
    [self scrollTableToBottom:_messagesTablePrimary count:self.messagesPrimary.count];
    [self scrollTableToBottom:_messagesTableSecondary count:self.messagesSecondary.count];
    [self.view setNeedsLayout];
}

- (void)scrollTableToBottom:(UITableView *)table count:(NSUInteger)count {
    if (count == 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:(NSInteger)(count - 1) inSection:0];
    [table scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}

- (void)onPeriodicTick {
    [[CTDOCoreBridge shared] pollDueScheduledMessages];
    [self refreshAllData];
}

// ============================================================================
// UITableViewDataSource & UITableViewDelegate
// ============================================================================
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == _threadsTableView) {
        return (NSInteger)self.threadsPrimary.count;
    }
    if (tableView == _messagesTablePrimary) {
        return (NSInteger)self.messagesPrimary.count;
    }
    return (NSInteger)self.messagesSecondary.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == _threadsTableView) {
        return 72.0;
    }
    if (tableView == _messagesTablePrimary) {
        NSDictionary *msg = self.messagesPrimary[indexPath.row];
        return [CTDOMessageCell heightForMessage:msg maxWidth:MAX(260.0, tableView.bounds.size.width)];
    }
    NSDictionary *msg = self.messagesSecondary[indexPath.row];
    return [CTDOMessageCell heightForMessage:msg maxWidth:MAX(240.0, tableView.bounds.size.width)];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == _threadsTableView) {
        CTDOThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ThreadCell" forIndexPath:indexPath];
        NSDictionary *thread = self.threadsPrimary[indexPath.row];
        BOOL selected = [thread[@"id"] isEqualToString:self.selectedThreadIdPrimary];
        [cell configureWithThread:thread isSelected:selected];
        return cell;
    }
    if (tableView == _messagesTablePrimary) {
        CTDOMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MsgCellPrimary" forIndexPath:indexPath];
        NSDictionary *msg = self.messagesPrimary[indexPath.row];
        [cell configureWithMessage:msg maxWidth:MAX(260.0, tableView.bounds.size.width)];
        return cell;
    }
    CTDOMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MsgCellSecondary" forIndexPath:indexPath];
    NSDictionary *msg = self.messagesSecondary[indexPath.row];
    [cell configureWithMessage:msg maxWidth:MAX(240.0, tableView.bounds.size.width)];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == _threadsTableView) {
        NSDictionary *thread = self.threadsPrimary[indexPath.row];
        self.selectedThreadIdPrimary = thread[@"id"] ?: @"";
        self.compactShowingChatDetail = YES;
        [self refreshAllData];
        return;
    }

    BOOL isPrimary = (tableView == _messagesTablePrimary);
    NSArray<NSDictionary *> *list = isPrimary ? self.messagesPrimary : self.messagesSecondary;
    if (indexPath.row >= (NSInteger)list.count) return;
    NSDictionary *msg = list[indexPath.row];
    NSString *mid = msg[@"id"] ?: @"";
    NSString *tid = isPrimary ? self.selectedThreadIdPrimary : self.selectedThreadIdSecondary;
    NSInteger slot = isPrimary ? self.activeSlot : self.secondarySlot;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:msg[@"sender_name"]
                                                                   message:msg[@"content"]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *emoji in @[@"❤️", @"👍", @"😆", @"😮", @"🔥"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Thả biểu cảm %@", emoji]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            [[CTDOCoreBridge shared] reactMessageForSlot:slot threadId:tid msgId:mid emoji:emoji];
            [self refreshAllData];
        }]];
    }
    if (isPrimary) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"↩️ Trả lời (Quote Reply) tin nhắn này"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            self.replyToMsgIdPrimary = mid;
            self.replyPreviewTextPrimary = [NSString stringWithFormat:@"Đang trả lời %@: %@", msg[@"sender_name"], msg[@"content"]];
            self.replyBarLabelPrimary.text = self.replyPreviewTextPrimary;
            self.replyBarPrimary.hidden = NO;
            [self.view setNeedsLayout];
            [self.inputFieldPrimary becomeFirstResponder];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentPopoverOrSheet:sheet sourceView:tableView];
}

// iOS 12+ Swipe Actions on Threads (#5, #24)
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != _threadsTableView) return nil;
    NSDictionary *thread = self.threadsPrimary[indexPath.row];
    NSString *tid = thread[@"id"] ?: @"";
    BOOL pinned = [thread[@"is_pinned"] boolValue];

    UIContextualAction *pinAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:(pinned ? @"Bỏ ghim" : @"📌 Ghim")
                                                                       handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:tid action:1];
        [self refreshAllData];
        completionHandler(YES);
    }];
    pinAct.backgroundColor = [CTDOTheme shared].accentPrimary;

    UIContextualAction *duoAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:@"📱 Màn #2"
                                                                       handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        self.secondarySlot = self.activeSlot;
        self.selectedThreadIdSecondary = tid;
        self.duoDualChatMode = YES;
        [self refreshAllData];
        completionHandler(YES);
    }];
    duoAct.backgroundColor = [CTDOTheme shared].accentOnline;

    return [UISwipeActionsConfiguration configurationWithActions:@[pinAct, duoAct]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != _threadsTableView) return nil;
    NSDictionary *thread = self.threadsPrimary[indexPath.row];
    NSString *tid = thread[@"id"] ?: @"";
    BOOL muted = [thread[@"is_muted"] boolValue];
    BOOL hidden = [thread[@"is_hidden"] boolValue];

    UIContextualAction *muteAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:(muted ? @"🔔 Bật TB" : @"🔕 Tắt TB")
                                                                        handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:tid action:2];
        [self refreshAllData];
        completionHandler(YES);
    }];
    muteAct.backgroundColor = [CTDOTheme shared].warningColor;

    UIContextualAction *hideAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:(hidden ? @"👁 Hiện" : @"🙈 Ẩn")
                                                                        handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:tid action:3];
        [self refreshAllData];
        completionHandler(YES);
    }];
    hideAct.backgroundColor = [UIColor darkGrayColor];

    UIContextualAction *delAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                         title:@"🗑 Xoá"
                                                                       handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:tid action:4];
        [self refreshAllData];
        completionHandler(YES);
    }];

    return [UISwipeActionsConfiguration configurationWithActions:@[delAct, hideAct, muteAct]];
}

// ============================================================================
// User Actions & Modals
// ============================================================================
- (void)presentPopoverOrSheet:(UIAlertController *)alert sourceView:(UIView *)sourceView {
    UIPopoverPresentationController *pop = alert.popoverPresentationController;
    if (pop) {
        pop.sourceView = sourceView;
        pop.sourceRect = CGRectMake(sourceView.bounds.size.width * 0.5, sourceView.bounds.size.height * 0.5, 1, 1);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onTapRefreshQR {
    self.lastRenderedQrPayload = @"";
    [[CTDOCoreBridge shared] startQRLoginForSlot:self.activeSlot];
    [self refreshAllData];
}

- (void)onTapPasswordLoginModal {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔑 Đăng nhập Zalo bằng SĐT & Mật khẩu"
                                                                   message:@"Giao thức ParamCipher v2 (loginByPasswv2). Khuyên dùng quét mã QR Zalo để không bị hỏi Captcha."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Số điện thoại (ví dụ: 0912345678)";
        tf.keyboardType = UIKeyboardTypePhonePad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Mật khẩu Zalo";
        tf.secureTextEntry = YES;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đăng nhập" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *phone = alert.textFields[0].text ?: @"";
        NSString *pwd = alert.textFields[1].text ?: @"";
        [[CTDOCoreBridge shared] loginPasswordForSlot:self.activeSlot phone:phone password:pwd];
        [self refreshAllData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onTapRefreshRealZalo {
    [[CTDOCoreBridge shared] refreshThreadsForSlot:self.activeSlot];
    [self refreshAllData];
}

- (void)onLongPressThread:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint pt = [gesture locationInView:_threadsTableView];
    NSIndexPath *idx = [_threadsTableView indexPathForRowAtPoint:pt];
    if (!idx || idx.row >= (NSInteger)self.threadsPrimary.count) return;

    NSDictionary *thread = self.threadsPrimary[idx.row];
    NSString *tid = thread[@"id"] ?: @"";
    NSString *tname = thread[@"name"] ?: @"Hội thoại";

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:tname
                                                                  message:[NSString stringWithFormat:@"Thread ID: %@ (#5, #24, #63)", tid]
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"📌 Ghim / Bỏ ghim hội thoại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:tid action:1];
        [self refreshAllData];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"🔕 Tắt / Bật thông báo" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:tid action:2];
        [self refreshAllData];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"📱 Mở ở Màn hình Phải (iPhone Duo / iPad)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.secondarySlot = self.activeSlot;
        self.selectedThreadIdSecondary = tid;
        self.duoDualChatMode = YES;
        [self refreshAllData];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"🕒 Hẹn giờ gửi tin nhắn vào hội thoại này (#38)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.selectedThreadIdPrimary = tid;
        [self onTapQuickSchedulePrimary];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"🙈 Ẩn / Hiện hội thoại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:tid action:3];
        [self refreshAllData];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"🗑 Xoá lịch sử cuộc trò chuyện" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:tid action:4];
        [self refreshAllData];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentPopoverOrSheet:menu sourceView:_threadsTableView];
}

- (void)onTapAccountSwitch {
    NSDictionary *a0 = [[CTDOCoreBridge shared] authStateForSlot:0];
    NSDictionary *a1 = [[CTDOCoreBridge shared] authStateForSlot:1];
    NSString *lbl0 = [a0[@"status"] isEqualToString:@"authenticated"]
        ? [NSString stringWithFormat:@"👤 Tài khoản 1: %@ (%@)", a0[@"display_name"], a0[@"uid"]]
        : @"👤 Tài khoản 1 (Quét mã QR để đăng nhập)";
    NSString *lbl1 = [a1[@"status"] isEqualToString:@"authenticated"]
        ? [NSString stringWithFormat:@"👥 Tài khoản 2: %@ (%@)", a1[@"display_name"], a1[@"uid"]]
        : @"👥 Tài khoản 2 · Duo #2 (Quét mã QR để đăng nhập)";

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Quản lý Tài khoản Zalo Thực tế"
                                                                   message:@"Hỗ trợ đăng nhập QR độc lập cho 2 tài khoản Zalo trên iPhone / iPad / iPhone Duo"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:lbl0 style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.activeSlot = 0;
        self.lastRenderedQrPayload = @"";
        if (![[[CTDOCoreBridge shared] authStateForSlot:0][@"status"] isEqualToString:@"authenticated"]) {
            [[CTDOCoreBridge shared] startQRLoginForSlot:0];
        }
        [self refreshAllData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:lbl1 style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.activeSlot = 1;
        self.lastRenderedQrPayload = @"";
        if (![[[CTDOCoreBridge shared] authStateForSlot:1][@"status"] isEqualToString:@"authenticated"]) {
            [[CTDOCoreBridge shared] startQRLoginForSlot:1];
        }
        [self refreshAllData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🔄 Làm mới mã QR / Đồng bộ danh bạ Zalo" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSDictionary *cur = [[CTDOCoreBridge shared] authStateForSlot:self.activeSlot];
        if ([cur[@"status"] isEqualToString:@"authenticated"]) {
            [[CTDOCoreBridge shared] refreshThreadsForSlot:self.activeSlot];
        } else {
            self.lastRenderedQrPayload = @"";
            [[CTDOCoreBridge shared] startQRLoginForSlot:self.activeSlot];
        }
        [self refreshAllData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"📦 Xuất / Nhập (Migrate) lịch sử tin nhắn (#9)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showHistoryMigrationModal];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🚪 Đăng xuất tài khoản hiện tại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        self.lastRenderedQrPayload = @"";
        [[CTDOCoreBridge shared] logoutSlot:self.activeSlot];
        [self refreshAllData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentPopoverOrSheet:sheet sourceView:_accountButton];
}

- (void)onToggleDuoDualChatMode {
    self.duoDualChatMode = !self.duoDualChatMode;
    [self.view setNeedsLayout];
    [self refreshAllData];
}

- (void)onTapCompactBack {
    CTDODeviceClass devClass = [[CTDOCoreBridge shared] hardwareDeviceClassForWindowSize:self.view.bounds.size];
    if (devClass == CTDODeviceClassiPhoneDuo && self.duoDualChatMode) {
        self.duoDualChatMode = NO;
    } else {
        self.compactShowingChatDetail = NO;
    }
    [self.view setNeedsLayout];
}

- (void)onSearchTextChanged:(UITextField *)tf {
    self.searchQuery = tf.text ?: @"";
    [self refreshAllData];
}

- (void)onFilterChanged:(UISegmentedControl *)seg {
    self.filterMode = seg.selectedSegmentIndex;
    [self refreshAllData];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _inputFieldPrimary) {
        [self onSendPrimary];
        return NO;
    }
    if (textField == _inputFieldSecondary) {
        [self onSendSecondary];
        return NO;
    }
    [textField resignFirstResponder];
    return YES;
}

- (void)onSendPrimary {
    NSString *txt = [_inputFieldPrimary.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (txt.length == 0 || self.selectedThreadIdPrimary.length == 0) return;
    [[CTDOCoreBridge shared] sendMessageForSlot:self.activeSlot
                                       threadId:self.selectedThreadIdPrimary
                                        content:txt
                                   replyToMsgId:self.replyToMsgIdPrimary];
    _inputFieldPrimary.text = @"";
    [self onCancelReplyPrimary];
    [self refreshAllData];
}

- (void)onSendSecondary {
    NSString *txt = [_inputFieldSecondary.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (txt.length == 0 || self.selectedThreadIdSecondary.length == 0) return;
    [[CTDOCoreBridge shared] sendMessageForSlot:self.secondarySlot
                                       threadId:self.selectedThreadIdSecondary
                                        content:txt
                                   replyToMsgId:nil];
    _inputFieldSecondary.text = @"";
    [self refreshAllData];
}

- (void)onCancelReplyPrimary {
    self.replyToMsgIdPrimary = nil;
    self.replyPreviewTextPrimary = nil;
    self.replyBarPrimary.hidden = YES;
    [self.view setNeedsLayout];
}

- (void)onTapVoiceCall {
    NSDictionary *signedDiag = [[CTDOCoreBridge shared] buildSignedRequestForService:@"chat"
                                                                              method:@"voip_call_init"
                                                                          jsonParams:[NSString stringWithFormat:@"{\"callee\":\"%@\"}", self.selectedThreadIdPrimary ?: @""]];
    NSString *msg = [NSString stringWithFormat:@"Kết nối VoIP tới [%@]...\n\n• Giao thức: ParamCipher v2 (zpw_ver=694)\n• Signkey: %@\n• Endpoint: %@",
                     self.selectedThreadIdPrimary ?: @"",
                     signedDiag[@"signkey"] ?: @"",
                     signedDiag[@"endpoint"] ?: @""];
    UIAlertController *callAlert = [UIAlertController alertControllerWithTitle:@"📞 Cuộc gọi Thoại / Video Zalo"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
    [callAlert addAction:[UIAlertAction actionWithTitle:@"Kết thúc" style:UIAlertActionStyleDestructive handler:nil]];
    [self presentViewController:callAlert animated:YES completion:nil];
}

- (void)onTapOpenInRightScreen {
    self.secondarySlot = self.activeSlot;
    self.selectedThreadIdSecondary = self.selectedThreadIdPrimary;
    self.duoDualChatMode = YES;
    [self refreshAllData];
}

- (void)onTapSwitchSecondaryThread {
    NSArray<NSDictionary *> *threads = [[CTDOCoreBridge shared] listThreadsForSlot:self.secondarySlot filterMode:0 searchQuery:@""];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Chọn hội thoại cho Màn hình Phải (#2)"
                                                                   message:@"Hiển thị song song 2 cuộc trò chuyện thực tế trên iPhone Duo / iPad"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *t in threads) {
        NSString *tid = t[@"id"] ?: @"";
        NSString *label = [NSString stringWithFormat:@"%@ (%@)", t[@"name"], t[@"subtitle_tag"]];
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.selectedThreadIdSecondary = tid;
            [self refreshAllData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentPopoverOrSheet:sheet sourceView:_switchSecondaryThreadBtn];
}

- (void)onTapToggleSecondarySlot {
    self.secondarySlot = (self.secondarySlot == 0) ? 1 : 0;
    [self refreshAllData];
}

- (void)onTapStickerPicker {
    if (self.selectedThreadIdPrimary.length == 0) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"🎉 Bộ Nhãn dán Zalo (#7)"
                                                                   message:@"Chọn nhãn dán để gửi"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSString *> *stickers = @[
        @"[Sticker] 🐱 Mèo Meng Meng: Xin chào!",
        @"[Sticker] 🚀 Tên lửa ctdozlite",
        @"[Sticker] ❤️ Thả tim!",
        @"[Sticker] ☕ Mời cà phê!"
    ];
    for (NSString *st in stickers) {
        [sheet addAction:[UIAlertAction actionWithTitle:st style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[CTDOCoreBridge shared] sendMessageForSlot:self.activeSlot
                                               threadId:self.selectedThreadIdPrimary
                                                content:st
                                           replyToMsgId:self.replyToMsgIdPrimary];
            [self onCancelReplyPrimary];
            [self refreshAllData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentPopoverOrSheet:sheet sourceView:_stickerBtnPrimary];
}

- (void)onTapQuickSchedulePrimary {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🕒 Hẹn giờ gửi tin nhắn (#38, #24)"
                                                                   message:[NSString stringWithFormat:@"Hội thoại đích: %@", self.selectedThreadIdPrimary ?: @"(Chưa chọn)"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Nhập nội dung tin nhắn hẹn giờ...";
    }];
    int64_t nowMs = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000.0);
    [alert addAction:[UIAlertAction actionWithTitle:@"⚡ Gửi sau 3 giây" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *txt = alert.textFields.firstObject.text ?: @"";
        if (txt.length > 0 && self.selectedThreadIdPrimary.length > 0) {
            [[CTDOCoreBridge shared] scheduleMessageForSlot:self.activeSlot threadId:self.selectedThreadIdPrimary content:txt deliverAtMs:(nowMs + 3000)];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"🕒 Sau 15 phút (+15m)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *txt = alert.textFields.firstObject.text ?: @"";
        if (txt.length > 0 && self.selectedThreadIdPrimary.length > 0) {
            [[CTDOCoreBridge shared] scheduleMessageForSlot:self.activeSlot threadId:self.selectedThreadIdPrimary content:txt deliverAtMs:(nowMs + 15 * 60 * 1000)];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onTapScheduleModal {
    NSArray<NSDictionary *> *items = [[CTDOCoreBridge shared] listScheduledForSlot:self.activeSlot];
    NSMutableString *desc = [NSMutableString stringWithFormat:@"Đang có %lu tin nhắn chờ gửi tự động:\n\n", (unsigned long)items.count];
    for (NSDictionary *it in items) {
        [desc appendFormat:@"• [#%@] %@ (%@): %@\n",
         it[@"id"], it[@"thread_name"], it[@"deliver_time_label"], it[@"content"]];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🕒 Quản lý Tin nhắn Hẹn giờ (#38, #24)"
                                                                   message:desc
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"➕ Thêm tin hẹn giờ mới" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self onTapQuickSchedulePrimary];
    }]];
    if (items.count > 0) {
        int64_t firstId = [items.firstObject[@"id"] longLongValue];
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"🗑 Huỷ tin hẹn giờ #%lld", firstId]
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *action) {
            [[CTDOCoreBridge shared] cancelScheduledForSlot:self.activeSlot schedId:firstId];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onTapAutoReplyModal {
    NSArray<NSDictionary *> *rules = [[CTDOCoreBridge shared] listAutoReplyRules];
    NSMutableString *desc = [NSMutableString stringWithString:@"Danh sách quy tắc tự động trả lời (#35):\n\n"];
    if (rules.count == 0) {
        [desc appendString:@"(Chưa có quy tắc nào. Hãy thêm từ khoá bên dưới)"];
    }
    for (NSDictionary *r in rules) {
        BOOL en = [r[@"enabled"] boolValue];
        [desc appendFormat:@"%@ Từ khoá \"%@\" → \"%@\"\n\n",
         en ? @"✅ [BẬT]" : @"⏸ [TẮT]", r[@"pattern"], r[@"response"]];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🤖 Cấu hình Auto-Reply Bot (#35)"
                                                                   message:desc
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Từ khoá kích hoạt (ví dụ: xin chào)";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Nội dung tự động trả lời...";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"➕ Thêm quy tắc mới" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *pat = alert.textFields[0].text ?: @"";
        NSString *resp = alert.textFields[1].text ?: @"";
        if (pat.length > 0 && resp.length > 0) {
            [[CTDOCoreBridge shared] mutateAutoReplyOp:1 patternOrId:pat response:resp matchMode:@"contains"];
        }
    }]];
    if (rules.count > 0) {
        NSString *firstId = rules.firstObject[@"id"] ?: @"rule_1";
        [alert addAction:[UIAlertAction actionWithTitle:@"🔄 Bật/Tắt quy tắc đầu tiên" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[CTDOCoreBridge shared] mutateAutoReplyOp:2 patternOrId:firstId response:@"" matchMode:@"contains"];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onTapThemeCycle {
    [[CTDOTheme shared] cycleTheme];
    [self applyTheme];
    [self refreshAllData];
}

- (void)onTapQRModal {
    NSDictionary *auth = [[CTDOCoreBridge shared] authStateForSlot:self.activeSlot];
    NSString *info = [NSString stringWithFormat:
                      @"• Thiết bị thực tế: %@\n"
                      @"• Tài khoản đang chọn: Slot #%ld (%@)\n"
                      @"• Trạng thái: %@\n"
                      @"• Token QR: %@\n"
                      @"• IMEI: %@",
                      [[CTDOCoreBridge shared] deviceHardwareName],
                      (long)(self.activeSlot + 1),
                      auth[@"status"] ?: @"",
                      auth[@"status_message"] ?: @"",
                      auth[@"qr_token_id"] ?: @"(Chưa tạo)",
                      auth[@"imei"] ?: @""];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📱 Trạng thái Đăng nhập QR Zalo"
                                                                   message:info
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"🔄 Lấy mã QR Zalo mới (wpa.zaloapp.com)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self onTapRefreshQR];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"🔑 Đăng nhập bằng SĐT / Mật khẩu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self onTapPasswordLoginModal];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showHistoryMigrationModal {
    NSString *exported = [[CTDOCoreBridge shared] exportHistoryJSONForSlot:self.activeSlot];
    NSDictionary *importResult = [[CTDOCoreBridge shared] importHistoryJSON:exported forSlot:self.activeSlot];
    NSString *msg = [NSString stringWithFormat:
                     @"Đã kiểm tra đồng bộ & gộp lịch sử idempotent (#9):\n\n"
                     @"• Dung lượng JSON sao lưu: %lu bytes\n"
                     @"• Hội thoại mới thêm: %@\n"
                     @"• Tin nhắn mới thêm: %@\n"
                     @"• Bản ghi trùng lặp đã bỏ qua: %@",
                     (unsigned long)exported.length,
                     importResult[@"imported_threads"] ?: @0,
                     importResult[@"imported_messages"] ?: @0,
                     importResult[@"skipped_duplicates"] ?: @0];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📦 Nhập / Xuất Lịch sử Tin nhắn (#9)"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Sao chép JSON vào Clipboard" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = exported;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// ============================================================================
// GitHub Releases API Auto-Update Notification
// ============================================================================
- (void)triggerGitHubUpdateCheck:(BOOL)simulateOldVersion {
    [[CTDOCoreBridge shared] checkGitHubLatestReleaseWithSimulateOldVersion:simulateOldVersion
                                                                 completion:^(NSDictionary *releaseInfo) {
        self.githubReleaseInfo = releaseInfo;
        BOOL hasUpdate = [releaseInfo[@"has_update"] boolValue];
        NSString *latestVer = releaseInfo[@"latest_version"] ?: @"0.0.5";
        NSString *curVer = releaseInfo[@"current_version"] ?: @"0.0.5";

        if (hasUpdate) {
            self.updateBannerDismissed = NO;
            self.updateBanner.hidden = NO;
            self.updateBannerLabel.text = [NSString stringWithFormat:@"🚀 Bản cập nhật mới ctdozlite v%@ trên GitHub API (hiện tại v%@)!", latestVer, curVer];
        } else {
            self.updateBanner.hidden = NO;
            self.updateBannerLabel.text = [NSString stringWithFormat:@"✅ Đang chạy bản mới nhất ctdozlite v%@ (Pure Objective-C · Real Zalo QR)", latestVer];
        }
        [self.view setNeedsLayout];
    }];
}

- (void)onDismissUpdateBanner {
    self.updateBannerDismissed = YES;
    self.updateBanner.hidden = YES;
    [self.view setNeedsLayout];
}

- (void)onTapUpdateModal {
    if (!self.githubReleaseInfo) {
        [self triggerGitHubUpdateCheck:NO];
        return;
    }
    NSDictionary *info = self.githubReleaseInfo;
    BOOL hasUpdate = [info[@"has_update"] boolValue];
    NSString *latestVer = info[@"latest_version"] ?: @"0.0.5";
    NSString *curVer = info[@"current_version"] ?: @"0.0.5";
    NSString *title = info[@"title"] ?: @"ctdozlite v0.0.5";
    NSArray *bullets = [info[@"bullets"] isKindOfClass:[NSArray class]] ? info[@"bullets"] : @[];

    NSMutableString *bodyText = [NSMutableString stringWithFormat:
                                 @"Nguồn: api.github.com/repos/ctdoteam1110/ctdozlite/releases/latest\n"
                                 @"Trạng thái: %@\n"
                                 @"Tiêu đề: %@\n\n"
                                 @"📋 Chi tiết Sửa lỗi & Cập nhật:\n",
                                 hasUpdate
                                    ? [NSString stringWithFormat:@"🚀 Có bản mới v%@ (đang dùng v%@)", latestVer, curVer]
                                    : [NSString stringWithFormat:@"✅ Đã ở bản mới nhất v%@", latestVer],
                                 title];

    for (NSString *b in bullets) {
        [bodyText appendFormat:@"\n• %@", b];
    }

    UIAlertController *modal = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"🚀 GitHub Releases API — v%@", latestVer]
                                                                   message:bodyText
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [modal addAction:[UIAlertAction actionWithTitle:@"🔔 Giả lập đang ở v0.0.4 để test báo Update v0.0.5"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self triggerGitHubUpdateCheck:YES];
    }]];
    [modal addAction:[UIAlertAction actionWithTitle:@"🔄 Kiểm tra lại từ GitHub API (v0.0.5)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self triggerGitHubUpdateCheck:NO];
    }]];
    [modal addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:modal animated:YES completion:nil];
}

@end
