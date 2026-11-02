#import "CTDOMainViewController.h"
#import <QuartzCore/QuartzCore.h>

// ============================================================================
// 1. Official Zalo Conversation Cell (ref1.png & ref2.png — 74pt height, 2 lines)
// ============================================================================
@interface CTDOThreadCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UIImageView *groupBadgeView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIImageView *statusIconView; // Pin or Muted Bell next to time
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *unreadBadge;
@property (nonatomic, strong) UIView *redDotView;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, copy) NSString *representedThreadId;
- (void)configureWithThread:(NSDictionary *)thread isSelected:(BOOL)isSelected onAvatarLoaded:(void (^)(void))onAvatarLoaded;
@end

@implementation CTDOThreadCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(14, 11, 52, 52)];
        _avatarView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_avatarView];

        _groupBadgeView = [[UIImageView alloc] initWithFrame:CGRectMake(78, 15, 18, 18)];
        _groupBadgeView.image = [CTDOIconRenderer groupPrefixIconWithSize:18.0];
        _groupBadgeView.hidden = YES;
        [self.contentView addSubview:_groupBadgeView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:16.5 weight:UIFontWeightRegular];
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_nameLabel];

        _statusIconView = [[UIImageView alloc] init];
        _statusIconView.contentMode = UIViewContentModeScaleAspectFit;
        _statusIconView.hidden = YES;
        [self.contentView addSubview:_statusIconView];

        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
        _timeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_timeLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightRegular];
        _subtitleLabel.numberOfLines = 1;
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_subtitleLabel];

        _unreadBadge = [[UILabel alloc] init];
        _unreadBadge.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
        _unreadBadge.textColor = [UIColor whiteColor];
        _unreadBadge.textAlignment = NSTextAlignmentCenter;
        _unreadBadge.layer.cornerRadius = 9.5;
        _unreadBadge.layer.masksToBounds = YES;
        _unreadBadge.hidden = YES;
        [self.contentView addSubview:_unreadBadge];

        _redDotView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 9, 9)];
        _redDotView.backgroundColor = [UIColor colorWithRed:0.937 green:0.267 blue:0.267 alpha:1.0];
        _redDotView.layer.cornerRadius = 4.5;
        _redDotView.hidden = YES;
        [self.contentView addSubview:_redDotView];

        _separatorLine = [[UIView alloc] init];
        [self.contentView addSubview:_separatorLine];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;

    _avatarView.frame = CGRectMake(14.0, (h - 52.0) * 0.5, 52.0, 52.0);

    CGSize timeSize = [_timeLabel.text ?: @"" sizeWithAttributes:@{NSFontAttributeName: _timeLabel.font}];
    CGFloat timeW = MIN(72.0, ceil(timeSize.width) + 4.0);
    _timeLabel.frame = CGRectMake(w - 14.0 - timeW, 14.0, timeW, 18.0);

    CGFloat rightEdgeForName = _timeLabel.frame.origin.x - 6.0;
    if (!_statusIconView.hidden) {
        _statusIconView.frame = CGRectMake(_timeLabel.frame.origin.x - 18.0, 16.0, 14.0, 14.0);
        rightEdgeForName = _statusIconView.frame.origin.x - 6.0;
    }

    CGFloat nameX = 78.0;
    if (!_groupBadgeView.hidden) {
        _groupBadgeView.frame = CGRectMake(78.0, 15.0, 19.0, 18.0);
        nameX = 102.0;
    }
    _nameLabel.frame = CGRectMake(nameX, 13.0, MAX(60.0, rightEdgeForName - nameX), 21.0);

    CGFloat badgeRightW = 0.0;
    if (!_unreadBadge.hidden) {
        CGSize bs = [_unreadBadge.text ?: @"1" sizeWithAttributes:@{NSFontAttributeName: _unreadBadge.font}];
        CGFloat bw = MAX(19.0, ceil(bs.width) + 11.0);
        _unreadBadge.frame = CGRectMake(w - 14.0 - bw, 41.0, bw, 19.0);
        badgeRightW = bw + 8.0;
    } else if (!_redDotView.hidden) {
        _redDotView.frame = CGRectMake(w - 23.0, 46.0, 9.0, 9.0);
        badgeRightW = 18.0;
    }

    _subtitleLabel.frame = CGRectMake(78.0, 40.0, MAX(60.0, w - 78.0 - 14.0 - badgeRightW), 20.0);
    _separatorLine.frame = CGRectMake(78.0, h - 0.5, w - 78.0, 0.5);
}

- (void)configureWithThread:(NSDictionary *)thread isSelected:(BOOL)isSelected onAvatarLoaded:(void (^)(void))onAvatarLoaded {
    CTDOTheme *theme = [CTDOTheme shared];
    self.representedThreadId = thread[@"id"] ?: @"";
    self.contentView.backgroundColor = isSelected ? theme.bgElevated : theme.bgSecondary;
    _separatorLine.backgroundColor = theme.borderSubtle;

    BOOL isGroup = [thread[@"is_group"] boolValue];
    BOOL isPinned = [thread[@"is_pinned"] boolValue];
    BOOL isMuted = [thread[@"is_muted"] boolValue];
    NSInteger unread = [thread[@"unread_count"] integerValue];

    _groupBadgeView.hidden = !isGroup;

    NSString *name = thread[@"name"] ?: @"Hội thoại";
    _nameLabel.text = name;
    _nameLabel.textColor = theme.textPrimary;
    _nameLabel.font = (unread > 0)
        ? [UIFont systemFontOfSize:16.5 weight:UIFontWeightSemibold]
        : [UIFont systemFontOfSize:16.5 weight:UIFontWeightRegular];

    NSString *lastMsg = thread[@"last_message"] ?: @"";
    if ([lastMsg isEqualToString:@"Chưa có tin nhắn"]) {
        lastMsg = @"";
    }
    if (lastMsg.length == 0) {
        NSInteger totMem = [thread[@"total_members"] integerValue];
        if (isGroup && totMem > 0) {
            lastMsg = [NSString stringWithFormat:@"Nhóm · %ld thành viên", (long)totMem];
        } else if (isGroup) {
            lastMsg = @"Nhóm trò chuyện";
        } else {
            lastMsg = @"[Tin nhắn thoại]";
        }
    }
    _subtitleLabel.text = lastMsg;
    _subtitleLabel.textColor = (unread > 0 && !isMuted) ? theme.textPrimary : theme.textSecondary;
    _subtitleLabel.font = (unread > 0 && !isMuted)
        ? [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium]
        : [UIFont systemFontOfSize:14.5 weight:UIFontWeightRegular];

    _timeLabel.text = thread[@"last_time_label"] ?: @"";
    _timeLabel.textColor = theme.textSecondary;

    UIColor *iconGray = [UIColor colorWithRed:0.62 green:0.65 blue:0.70 alpha:1.0];
    if (isPinned) {
        _statusIconView.hidden = NO;
        _statusIconView.image = [CTDOIconRenderer pinIconWithSize:14.0 color:iconGray];
    } else if (isMuted) {
        _statusIconView.hidden = NO;
        _statusIconView.image = [CTDOIconRenderer mutedBellIconWithSize:14.0 color:iconGray];
    } else {
        _statusIconView.hidden = YES;
    }

    _unreadBadge.hidden = YES;
    _redDotView.hidden = YES;
    if (unread > 0) {
        _unreadBadge.hidden = NO;
        _unreadBadge.text = (unread > 5) ? @"5+" : [NSString stringWithFormat:@"%ld", (long)unread];
        if (isMuted) {
            _unreadBadge.backgroundColor = [UIColor colorWithRed:0.76 green:0.79 blue:0.84 alpha:1.0];
        } else {
            _unreadBadge.backgroundColor = theme.dangerColor;
        }
    }

    _avatarView.image = [CTDOIconRenderer avatarForThread:thread size:52.0 onCompletion:onAvatarLoaded];
}

@end

// ============================================================================
// 2. Official Zalo Contact Cell (ref3.png — 68pt height with 📞 and 📹 buttons)
// ============================================================================
@interface CTDOContactCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *businessBadge;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *videoButton;
@property (nonatomic, copy) void (^onTapCall)(BOOL isVideo);
- (void)configureWithContact:(NSDictionary *)contact onAvatarLoaded:(void (^)(void))onAvatarLoaded;
@end

@implementation CTDOContactCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 10, 48, 48)];
        _avatarView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:16.5 weight:UIFontWeightRegular];
        [self.contentView addSubview:_nameLabel];

        _businessBadge = [[UILabel alloc] init];
        _businessBadge.text = @"Business";
        _businessBadge.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
        _businessBadge.textColor = [UIColor colorWithRed:0.09 green:0.40 blue:0.75 alpha:1.0];
        _businessBadge.backgroundColor = [UIColor colorWithRed:0.90 green:0.95 blue:1.00 alpha:1.0];
        _businessBadge.textAlignment = NSTextAlignmentCenter;
        _businessBadge.layer.cornerRadius = 4.0;
        _businessBadge.layer.masksToBounds = YES;
        _businessBadge.hidden = YES;
        [self.contentView addSubview:_businessBadge];

        UIColor *iconColor = [UIColor colorWithRed:0.15 green:0.18 blue:0.22 alpha:1.0];
        _callButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _callButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_callButton setImage:[CTDOIconRenderer phoneCallIconWithSize:22.0 color:iconColor] forState:UIControlStateNormal];
        [_callButton addTarget:self action:@selector(handleAudioCall) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_callButton];

        _videoButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _videoButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_videoButton setImage:[CTDOIconRenderer videoCallIconWithSize:22.0 color:iconColor] forState:UIControlStateNormal];
        [_videoButton addTarget:self action:@selector(handleVideoCall) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_videoButton];
    }
    return self;
}

- (void)handleAudioCall {
    if (self.onTapCall) self.onTapCall(NO);
}

- (void)handleVideoCall {
    if (self.onTapCall) self.onTapCall(YES);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    _avatarView.frame = CGRectMake(16.0, (h - 48.0) * 0.5, 48.0, 48.0);
    _videoButton.frame = CGRectMake(w - 58.0, (h - 36.0) * 0.5, 36.0, 36.0);
    _callButton.frame = CGRectMake(w - 104.0, (h - 36.0) * 0.5, 36.0, 36.0);

    if (!_businessBadge.hidden) {
        _nameLabel.frame = CGRectMake(78.0, 12.0, MAX(80.0, w - 190.0), 21.0);
        _businessBadge.frame = CGRectMake(78.0, 36.0, 62.0, 18.0);
    } else {
        _nameLabel.frame = CGRectMake(78.0, (h - 22.0) * 0.5, MAX(80.0, w - 190.0), 22.0);
    }
}

- (void)configureWithContact:(NSDictionary *)contact onAvatarLoaded:(void (^)(void))onAvatarLoaded {
    CTDOTheme *theme = [CTDOTheme shared];
    self.contentView.backgroundColor = theme.bgSecondary;
    _nameLabel.text = contact[@"name"] ?: @"Liên hệ";
    _nameLabel.textColor = theme.textPrimary;
    _businessBadge.hidden = ![contact[@"is_business"] boolValue];
    _avatarView.image = [CTDOIconRenderer avatarForThread:contact size:48.0 onCompletion:onAvatarLoaded];
}

@end

// ============================================================================
// 3. Official Zalo Menu / Settings Cell (ref4.png & ref5.png)
// ============================================================================
@interface CTDOMenuCell : UITableViewCell
@property (nonatomic, strong) UIImageView *leftIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *chevronLabel;
@property (nonatomic, strong) UIView *separatorLine;
- (void)configureWithIcon:(NSString *)iconKey
                    title:(NSString *)title
                 subtitle:(nullable NSString *)subtitle
              showChevron:(BOOL)showChevron;
@end

@implementation CTDOMenuCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _leftIconView = [[UIImageView alloc] initWithFrame:CGRectMake(18, 18, 24, 24)];
        _leftIconView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_leftIconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:16.5 weight:UIFontWeightRegular];
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular];
        [self.contentView addSubview:_subtitleLabel];

        _chevronLabel = [[UILabel alloc] init];
        _chevronLabel.text = @"›";
        _chevronLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightRegular];
        _chevronLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_chevronLabel];

        _separatorLine = [[UIView alloc] init];
        [self.contentView addSubview:_separatorLine];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    _leftIconView.frame = CGRectMake(18.0, (h - 24.0) * 0.5, 24.0, 24.0);
    _chevronLabel.frame = CGRectMake(w - 34.0, (h - 24.0) * 0.5, 18.0, 24.0);

    if (_subtitleLabel.text.length > 0) {
        _titleLabel.frame = CGRectMake(56.0, 12.0, w - 96.0, 21.0);
        _subtitleLabel.frame = CGRectMake(56.0, 35.0, w - 96.0, 18.0);
    } else {
        _titleLabel.frame = CGRectMake(56.0, (h - 22.0) * 0.5, w - 96.0, 22.0);
        _subtitleLabel.frame = CGRectZero;
    }
    _separatorLine.frame = CGRectMake(56.0, h - 0.5, w - 56.0, 0.5);
}

- (void)configureWithIcon:(NSString *)iconKey
                    title:(NSString *)title
                 subtitle:(nullable NSString *)subtitle
              showChevron:(BOOL)showChevron {
    CTDOTheme *theme = [CTDOTheme shared];
    self.contentView.backgroundColor = theme.bgSecondary;
    _leftIconView.image = [CTDOIconRenderer menuRowIconNamed:iconKey color:theme.accentPrimary size:24.0];
    _titleLabel.text = title;
    _titleLabel.textColor = theme.textPrimary;
    _subtitleLabel.text = subtitle ?: @"";
    _subtitleLabel.textColor = theme.textSecondary;
    _chevronLabel.hidden = !showChevron;
    _chevronLabel.textColor = [UIColor colorWithRed:0.65 green:0.68 blue:0.73 alpha:1.0];
    _separatorLine.backgroundColor = theme.borderSubtle;
}

@end

// ============================================================================
// 4. Official Zalo Chat Bubble Cell (Light Blue #D5F1FF Outgoing, White Incoming)
// ============================================================================
@interface CTDOMessageCell : UITableViewCell
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UILabel *senderLabel;
@property (nonatomic, strong) UILabel *quoteLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, copy) NSDictionary *messageData;
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
        _bubbleView.layer.cornerRadius = 12.0;
        _bubbleView.layer.borderWidth = 0.5;
        [self.contentView addSubview:_bubbleView];

        _senderLabel = [[UILabel alloc] init];
        _senderLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        [_bubbleView addSubview:_senderLabel];

        _quoteLabel = [[UILabel alloc] init];
        _quoteLabel.font = [UIFont italicSystemFontOfSize:12.0];
        _quoteLabel.numberOfLines = 2;
        _quoteLabel.layer.cornerRadius = 6.0;
        _quoteLabel.layer.masksToBounds = YES;
        [_bubbleView addSubview:_quoteLabel];

        _bodyLabel = [[UILabel alloc] init];
        _bodyLabel.font = [UIFont systemFontOfSize:15.5];
        _bodyLabel.numberOfLines = 0;
        [_bubbleView addSubview:_bodyLabel];

        _metaLabel = [[UILabel alloc] init];
        _metaLabel.font = [UIFont systemFontOfSize:11.0];
        [_bubbleView addSubview:_metaLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    if (w > 120.0 && _messageData) {
        [self layoutBubbleForWidth:w];
    }
}

+ (CGFloat)heightForMessage:(NSDictionary *)msg maxWidth:(CGFloat)maxWidth {
    if (maxWidth < 200.0) maxWidth = 348.0;
    CGFloat bubbleMaxW = MIN(maxWidth * 0.78, 460.0);
    CGFloat textMaxW = MAX(120.0, bubbleMaxW - 28.0);
    NSString *content = msg[@"content"] ?: @"";
    BOOL isSelf = [msg[@"is_self"] boolValue];
    CGRect bodyRect = [content boundingRectWithSize:CGSizeMake(textMaxW, 2000.0)
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15.5]}
                                            context:nil];
    CGFloat h = ceil(bodyRect.size.height) + (isSelf ? 32.0 : 48.0);
    NSString *quote = msg[@"reply_preview"];
    if ([quote isKindOfClass:[NSString class]] && quote.length > 0) {
        h += 28.0;
    }
    return MAX(54.0, h + 8.0);
}

- (void)configureWithMessage:(NSDictionary *)msg maxWidth:(CGFloat)maxWidth {
    _messageData = [msg copy];
    CGFloat effectiveW = self.contentView.bounds.size.width > 120.0 ? self.contentView.bounds.size.width : (maxWidth > 120.0 ? maxWidth : 348.0);
    [self layoutBubbleForWidth:effectiveW];
}

- (void)layoutBubbleForWidth:(CGFloat)maxWidth {
    NSDictionary *msg = _messageData;
    if (!msg) return;
    CTDOTheme *theme = [CTDOTheme shared];
    BOOL isSelf = [msg[@"is_self"] boolValue];
    NSString *sender = msg[@"sender_name"] ?: (isSelf ? @"Tôi" : @"Đối tác");
    NSString *content = msg[@"content"] ?: @"";
    NSString *timeLbl = msg[@"time_label"] ?: @"";
    NSString *quote = [msg[@"reply_preview"] isKindOfClass:[NSString class]] ? msg[@"reply_preview"] : nil;
    NSArray *reactions = [msg[@"reactions"] isKindOfClass:[NSArray class]] ? msg[@"reactions"] : @[];

    CGFloat bubbleMaxW = MIN(maxWidth * 0.78, 460.0);
    CGFloat textMaxW = MAX(120.0, bubbleMaxW - 28.0);
    CGRect bodyRect = [content boundingRectWithSize:CGSizeMake(textMaxW, 2000.0)
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15.5]}
                                            context:nil];

    NSString *reactStr = reactions.count > 0 ? [NSString stringWithFormat:@"  %@", [reactions componentsJoinedByString:@" "]] : @"";
    NSString *metaText = [NSString stringWithFormat:@"%@%@", timeLbl, reactStr];

    CGFloat contentW = MAX(ceil(bodyRect.size.width), 112.0);
    if (!isSelf) {
        CGSize sSize = [sender sizeWithAttributes:@{NSFontAttributeName: _senderLabel.font}];
        contentW = MAX(contentW, MIN(textMaxW, ceil(sSize.width)));
    }
    if (quote && quote.length > 0) {
        contentW = MAX(contentW, MIN(textMaxW, 220.0));
    }
    CGFloat bubbleW = MIN(bubbleMaxW, contentW + 28.0);

    CGFloat yCursor = 9.0;
    if (!isSelf) {
        _senderLabel.hidden = NO;
        _senderLabel.text = sender;
        _senderLabel.textColor = [UIColor colorWithRed:0.35 green:0.42 blue:0.52 alpha:1.0];
        _senderLabel.frame = CGRectMake(14.0, yCursor, bubbleW - 28.0, 15.0);
        yCursor += 17.0;
    } else {
        _senderLabel.hidden = YES;
    }

    if (quote && quote.length > 0) {
        _quoteLabel.hidden = NO;
        _quoteLabel.text = [NSString stringWithFormat:@" ▍ %@", quote];
        _quoteLabel.textColor = theme.textSecondary;
        _quoteLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.06];
        _quoteLabel.frame = CGRectMake(14.0, yCursor, bubbleW - 28.0, 22.0);
        yCursor += 26.0;
    } else {
        _quoteLabel.hidden = YES;
    }

    _bodyLabel.text = content;
    _bodyLabel.textColor = theme.textPrimary;
    CGFloat bodyH = ceil(bodyRect.size.height) + 2.0;
    _bodyLabel.frame = CGRectMake(14.0, yCursor, bubbleW - 28.0, bodyH);
    yCursor += bodyH + 3.0;

    _metaLabel.text = metaText;
    _metaLabel.textColor = theme.textSecondary;
    _metaLabel.textAlignment = isSelf ? NSTextAlignmentRight : NSTextAlignmentLeft;
    _metaLabel.frame = CGRectMake(14.0, yCursor, bubbleW - 28.0, 14.0);
    yCursor += 17.0;

    CGFloat bubbleX = isSelf ? (maxWidth - bubbleW - 12.0) : 12.0;
    _bubbleView.frame = CGRectMake(bubbleX, 4.0, bubbleW, yCursor);
    _bubbleView.backgroundColor = isSelf ? theme.bubbleSelf : theme.bubblePartner;
    if (theme.mode == CTDOThemeModeZaloLight) {
        _bubbleView.layer.borderColor = isSelf
            ? [UIColor colorWithRed:0.70 green:0.86 blue:0.98 alpha:1.0].CGColor
            : [UIColor colorWithRed:0.86 green:0.88 blue:0.91 alpha:1.0].CGColor;
    } else {
        _bubbleView.layer.borderColor = theme.borderSubtle.CGColor;
    }
}

@end


#pragma mark - CTDOMainViewController Implementation

@interface CTDOMainViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, assign) NSInteger activeSlot;
@property (nonatomic, assign) NSInteger activeBottomTab; // 0: Tin nhắn, 1: Danh bạ, 2: Khám phá, 3: Tường nhà, 4: Cá nhân
@property (nonatomic, assign) NSInteger activeFilterMode; // 0: Ưu tiên, 1: Khác
@property (nonatomic, assign) NSInteger contactFilterType; // 0: Bạn bè, 1: Nhóm, 2: OA
@property (nonatomic, assign) BOOL showingSettingsSubscreen; // ref5.png
@property (nonatomic, assign) BOOL compactShowingChatDetail;
@property (nonatomic, assign) BOOL dualChatEnabled;
@property (nonatomic, assign) NSInteger secondaryPaneMode; // 0: Chat song song (Slot 0), 1: Tài khoản 2 / Màn 2 (Slot 1)
@property (nonatomic, assign) NSInteger loginAuthTab; // 0: Quét mã QR, 1: SĐT & Mật khẩu
@property (nonatomic, assign) NSInteger secondaryLoginAuthTab; // 0: Quét mã QR, 1: SĐT & Mật khẩu
@property (nonatomic, assign) BOOL isPhoneSyncRunning;
@property (nonatomic, assign) CTDODeviceClass currentDeviceClass;

@property (nonatomic, copy) NSString *primaryThreadId;
@property (nonatomic, copy) NSString *secondaryThreadId;
@property (nonatomic, copy) NSString *slot1ThreadId;
@property (nonatomic, copy, nullable) NSString *replyTargetMsgId;
@property (nonatomic, copy, nullable) NSString *replyTargetPreview;

@property (nonatomic, strong) NSArray<NSDictionary *> *threads;
@property (nonatomic, strong) NSArray<NSDictionary *> *contacts;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSDictionary *> *> *contactSections;
@property (nonatomic, strong) NSArray<NSString *> *contactSectionTitles;
@property (nonatomic, strong) NSArray<NSDictionary *> *primaryMessages;
@property (nonatomic, strong) NSArray<NSDictionary *> *secondaryMessages;
@property (nonatomic, strong, nullable) NSDictionary *latestReleaseInfo;
@property (nonatomic, strong, nullable) NSTimer *scheduleTimer;
@property (nonatomic, strong, nullable) NSTimer *qrPollTimer;

// Left / Primary Column (Zalo Main Shell)
@property (nonatomic, strong) UIView *leftMasterContainer;
@property (nonatomic, strong) UIView *topHeaderView;
@property (nonatomic, strong) CAGradientLayer *topHeaderGradient;
@property (nonatomic, strong) UIButton *headerBackBtn;
@property (nonatomic, strong) UIImageView *headerSearchIcon;
@property (nonatomic, strong) UITextField *headerSearchField;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UIButton *headerRightBtn1; // QR / AddFriend / Gear / Search
@property (nonatomic, strong) UIButton *headerRightBtn2; // Plus (+)

// Sub-header for Tin nhắn (Ưu tiên | Khác)
@property (nonatomic, strong) UIView *msgSubHeaderView;
@property (nonatomic, strong) UIButton *uuTienTabBtn;
@property (nonatomic, strong) UIButton *khacTabBtn;
@property (nonatomic, strong) UIView *khacRedDot;
@property (nonatomic, strong) UIView *subHeaderIndicator;
@property (nonatomic, strong) UIView *subHeaderBottomLine;

// Phone Message Sync Bar ("Đồng bộ tin nhắn từ điện thoại")
@property (nonatomic, strong) UIView *phoneSyncBannerView;
@property (nonatomic, strong) UIImageView *phoneSyncIconView;
@property (nonatomic, strong) UILabel *phoneSyncTitleLabel;
@property (nonatomic, strong) UILabel *phoneSyncSubLabel;
@property (nonatomic, strong) UIButton *phoneSyncActionBtn;
@property (nonatomic, strong) UIProgressView *phoneSyncProgressView;
@property (nonatomic, strong) UIView *phoneSyncBottomLine;

// Sub-header for Danh bạ (Bạn bè | Nhóm | OA)
@property (nonatomic, strong) UIView *contactSubHeaderView;
@property (nonatomic, strong) UIButton *contactSubBtn0;
@property (nonatomic, strong) UIButton *contactSubBtn1;
@property (nonatomic, strong) UIButton *contactSubBtn2;
@property (nonatomic, strong) UIView *contactSubIndicator;

// Main TableViews inside Left Master Column
@property (nonatomic, strong) UITableView *threadTableView;
@property (nonatomic, strong) UIRefreshControl *threadRefreshControl;
@property (nonatomic, strong) UITableView *contactTableView;
@property (nonatomic, strong) UITableView *profileTableView;

// Bottom 5-Tab Bar
@property (nonatomic, strong) UIView *bottomTabBar;
@property (nonatomic, strong) UIView *bottomTabTopLine;
@property (nonatomic, strong) NSMutableArray<UIButton *> *bottomTabButtons;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *bottomTabIcons;
@property (nonatomic, strong) NSMutableArray<UILabel *> *bottomTabLabels;
@property (nonatomic, strong) UILabel *msgTabBadge;
@property (nonatomic, strong) UIView *timelineTabDot;

// Chat Detail Column (Primary)
@property (nonatomic, strong) UIView *primaryChatContainer;
@property (nonatomic, strong) UIView *primaryChatHeader;
@property (nonatomic, strong) CAGradientLayer *primaryChatHeaderGradient;
@property (nonatomic, strong) UIButton *chatBackBtn;
@property (nonatomic, strong) UILabel *chatTitleLabel;
@property (nonatomic, strong) UILabel *chatSubtitleLabel;
@property (nonatomic, strong) UIButton *chatPhoneBtn;
@property (nonatomic, strong) UIButton *chatVideoBtn;
@property (nonatomic, strong) UIButton *chatMenuBtn;
@property (nonatomic, strong) UITableView *primaryChatTableView;

// Reply banner + Composer Bar
@property (nonatomic, strong) UIView *replyBannerView;
@property (nonatomic, strong) UILabel *replyBannerLabel;
@property (nonatomic, strong) UIButton *replyBannerCloseBtn;
@property (nonatomic, strong) UIView *composerBar;
@property (nonatomic, strong) UIButton *composerStickerBtn;
@property (nonatomic, strong) UITextField *composerTextField;
@property (nonatomic, strong) UIButton *composerScheduleBtn;
@property (nonatomic, strong) UIButton *composerSendBtn;

// Secondary Dual-Chat / Màn 2 Column (for iPhone Duo & iPad Pro)
@property (nonatomic, strong) UIView *secondaryChatContainer;
@property (nonatomic, strong) UIView *secondaryChatHeader;
@property (nonatomic, strong) CAGradientLayer *secondaryChatHeaderGradient;
@property (nonatomic, strong) UILabel *secondaryChatTitleLabel;
@property (nonatomic, strong) UILabel *secondaryChatSubtitleLabel;
@property (nonatomic, strong) UISegmentedControl *secondaryPaneModeSegment;
@property (nonatomic, strong) UITableView *secondaryChatTableView;
@property (nonatomic, strong) UIView *secondaryComposerBar;
@property (nonatomic, strong) UITextField *secondaryComposerField;
@property (nonatomic, strong) UIButton *secondaryComposerSendBtn;

// Embedded Màn 2 Login View (inside _secondaryChatContainer when secondaryPaneMode == 1 and Slot 1 unauthed)
@property (nonatomic, strong) UIView *secondaryLoginContainer;
@property (nonatomic, strong) UIView *secondaryLoginCard;
@property (nonatomic, strong) UILabel *secondaryLoginBadgeLabel;
@property (nonatomic, strong) UILabel *secondaryLoginTitleLabel;
@property (nonatomic, strong) UILabel *secondaryLoginSubLabel;
@property (nonatomic, strong) UISegmentedControl *secondaryLoginTabSegment;
@property (nonatomic, strong) UIImageView *secondaryQrImageView;
@property (nonatomic, strong) UITextField *secondaryPhoneField;
@property (nonatomic, strong) UITextField *secondaryPassField;
@property (nonatomic, strong) UILabel *secondaryQrStatusLabel;
@property (nonatomic, strong) UIButton *secondaryQrActionBtn;
@property (nonatomic, strong) UIButton *secondaryBackToDualBtn;

// QR / Password Login Overlay (Shown when activeSlot is not authenticated)
@property (nonatomic, strong) UIView *loginOverlay;
@property (nonatomic, strong) UIView *loginCard;
@property (nonatomic, strong) UILabel *loginSlotBadgeLabel;
@property (nonatomic, strong) UIImageView *loginLogoView;
@property (nonatomic, strong) UILabel *loginTitleLabel;
@property (nonatomic, strong) UILabel *loginSubtitleLabel;
@property (nonatomic, strong) UISegmentedControl *loginModeSegment;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, strong) UITextField *loginPhoneField;
@property (nonatomic, strong) UITextField *loginPasswordField;
@property (nonatomic, strong) UILabel *qrStatusLabel;
@property (nonatomic, strong) UIButton *qrReloadBtn;
@property (nonatomic, strong) UIButton *loginBackToSlot0Btn;

@end

@implementation CTDOMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _activeSlot = 0;
    _activeBottomTab = 0;
    _activeFilterMode = 0;
    _contactFilterType = 0;
    _showingSettingsSubscreen = NO;
    _compactShowingChatDetail = NO;
    _dualChatEnabled = YES;
    _secondaryPaneMode = 0;
    _loginAuthTab = 0;
    _secondaryLoginAuthTab = 0;
    _isPhoneSyncRunning = NO;
    _primaryThreadId = @"";
    _secondaryThreadId = @"";
    _slot1ThreadId = @"";

    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    if ([args containsObject:@"--tab-contacts"]) {
        _activeBottomTab = 1;
    } else if ([args containsObject:@"--tab-profile"]) {
        _activeBottomTab = 4;
    } else if ([args containsObject:@"--tab-settings"]) {
        _activeBottomTab = 4;
        _showingSettingsSubscreen = YES;
    } else if ([args containsObject:@"--open-chat"]) {
        _compactShowingChatDetail = YES;
    }

    [self setupUI];
    [self reloadAllData];
    [self applyTheme];
    [self refreshAuthOverlayState];

    if ([args containsObject:@"--show-login2"]) {
        CGSize winSize = [UIScreen mainScreen].bounds.size;
        CTDODeviceClass dc = [[CTDOCoreBridge shared] hardwareDeviceClassForWindowSize:winSize];
        if (dc == CTDODeviceClassiPhone) {
            _activeSlot = 1;
            [self reloadAllData];
            [self refreshAuthOverlayState];
            [self onTapStartQRLogin];
        } else {
            _secondaryPaneMode = 1;
            _secondaryPaneModeSegment.selectedSegmentIndex = 1;
            [self onSecondaryPaneModeChanged:_secondaryPaneModeSegment];
        }
    }

    NSDictionary *auth = [[CTDOCoreBridge shared] authStateForSlot:_activeSlot];
    if ([auth[@"authenticated"] boolValue]) {
        [self triggerBackgroundSyncForCurrentSlot];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onThreadsDidUpdateNotification:)
                                                 name:@"CTDOThreadsDidUpdateNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAuthDidUpdateNotification:)
                                                 name:@"CTDOAuthDidUpdateNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSyncProgressNotification:)
                                                 name:@"CTDOSyncProgressNotification"
                                               object:nil];

    _scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                      target:self
                                                    selector:@selector(onScheduleTimerTick)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)onThreadsDidUpdateNotification:(__unused NSNotification *)note {
    [self reloadAllData];
}

- (void)onAuthDidUpdateNotification:(__unused NSNotification *)note {
    [self refreshAuthOverlayState];
    [self refreshSecondaryPaneState];
    [self reloadAllData];
}

- (void)onSyncProgressNotification:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    if (!info) return;
    double pct = [info[@"progress"] doubleValue];
    NSString *txt = info[@"text"] ?: @"";
    _phoneSyncProgressView.hidden = NO;
    [_phoneSyncProgressView setProgress:(float)pct animated:YES];
    if (txt.length > 0) {
        _phoneSyncSubLabel.text = txt;
    }
    if (pct >= 1.0) {
        _isPhoneSyncRunning = NO;
        [_phoneSyncActionBtn setTitle:@"Đồng bộ" forState:UIControlStateNormal];
        _phoneSyncActionBtn.enabled = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.isPhoneSyncRunning) {
                self.phoneSyncProgressView.hidden = YES;
            }
        });
    }
}

- (void)refreshAllData {
    [self reloadAllData];
}

- (void)triggerGitHubUpdateCheck:(BOOL)simulateOldVersion {
    [[CTDOCoreBridge shared] checkGitHubLatestReleaseWithSimulateOldVersion:simulateOldVersion
                                                                 completion:^(NSDictionary *releaseInfo) {
        self.latestReleaseInfo = releaseInfo;
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_scheduleTimer invalidate];
    [_qrPollTimer invalidate];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - UI Construction

- (void)setupUI {
    // 1. Left Master Container (Holds Header, SubHeader, Lists, Bottom TabBar)
    _leftMasterContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _leftMasterContainer.clipsToBounds = YES;
    [self.view addSubview:_leftMasterContainer];

    // Zalo Signature Top Gradient Header (#0068FF -> #0091FF)
    _topHeaderView = [[UIView alloc] initWithFrame:CGRectZero];
    _topHeaderGradient = [CAGradientLayer layer];
    _topHeaderGradient.startPoint = CGPointMake(0.0, 0.5);
    _topHeaderGradient.endPoint = CGPointMake(1.0, 0.5);
    _topHeaderGradient.colors = @[
        (id)[CTDOTheme colorFromHex:@"#0068FF"].CGColor,
        (id)[CTDOTheme colorFromHex:@"#0091FF"].CGColor
    ];
    [_topHeaderView.layer insertSublayer:_topHeaderGradient atIndex:0];
    [_leftMasterContainer addSubview:_topHeaderView];

    _headerBackBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _headerBackBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_headerBackBtn setImage:[CTDOIconRenderer backChevronIconWithSize:22.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
    [_headerBackBtn addTarget:self action:@selector(onTapHeaderBack) forControlEvents:UIControlEventTouchUpInside];
    _headerBackBtn.hidden = YES;
    [_topHeaderView addSubview:_headerBackBtn];

    _headerSearchIcon = [[UIImageView alloc] initWithImage:[CTDOIconRenderer searchIconWithSize:20.0 color:[UIColor whiteColor]]];
    _headerSearchIcon.contentMode = UIViewContentModeScaleAspectFit;
    [_topHeaderView addSubview:_headerSearchIcon];

    _headerSearchField = [[UITextField alloc] initWithFrame:CGRectZero];
    _headerSearchField.delegate = self;
    _headerSearchField.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    _headerSearchField.textColor = [UIColor whiteColor];
    _headerSearchField.tintColor = [UIColor whiteColor];
    _headerSearchField.returnKeyType = UIReturnKeySearch;
    _headerSearchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _headerSearchField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"Tìm kiếm"
            attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.88]}];
    [_headerSearchField addTarget:self action:@selector(onSearchFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [_topHeaderView addSubview:_headerSearchField];

    _headerTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _headerTitleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _headerTitleLabel.textColor = [UIColor whiteColor];
    _headerTitleLabel.text = @"Cài đặt";
    _headerTitleLabel.hidden = YES;
    [_topHeaderView addSubview:_headerTitleLabel];

    _headerRightBtn1 = [UIButton buttonWithType:UIButtonTypeCustom];
    _headerRightBtn1.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_headerRightBtn1 addTarget:self action:@selector(onTapHeaderRight1) forControlEvents:UIControlEventTouchUpInside];
    [_topHeaderView addSubview:_headerRightBtn1];

    _headerRightBtn2 = [UIButton buttonWithType:UIButtonTypeCustom];
    _headerRightBtn2.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_headerRightBtn2 setImage:[CTDOIconRenderer plusIconWithSize:22.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
    [_headerRightBtn2 addTarget:self action:@selector(onTapHeaderRight2) forControlEvents:UIControlEventTouchUpInside];
    [_topHeaderView addSubview:_headerRightBtn2];

    // 2. Sub-Header for Tab 0 (Tin nhắn: Ưu tiên | Khác)
    _msgSubHeaderView = [[UIView alloc] initWithFrame:CGRectZero];
    [_leftMasterContainer addSubview:_msgSubHeaderView];

    _uuTienTabBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_uuTienTabBtn setTitle:@"Ưu tiên" forState:UIControlStateNormal];
    [_uuTienTabBtn addTarget:self action:@selector(onTapUuTienTab) forControlEvents:UIControlEventTouchUpInside];
    [_msgSubHeaderView addSubview:_uuTienTabBtn];

    _khacTabBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_khacTabBtn setTitle:@"Khác" forState:UIControlStateNormal];
    [_khacTabBtn addTarget:self action:@selector(onTapKhacTab) forControlEvents:UIControlEventTouchUpInside];
    [_msgSubHeaderView addSubview:_khacTabBtn];

    _khacRedDot = [[UIView alloc] initWithFrame:CGRectZero];
    _khacRedDot.backgroundColor = [CTDOTheme colorFromHex:@"#EF4444"];
    _khacRedDot.layer.cornerRadius = 3.5;
    [_msgSubHeaderView addSubview:_khacRedDot];

    _subHeaderBottomLine = [[UIView alloc] initWithFrame:CGRectZero];
    [_msgSubHeaderView addSubview:_subHeaderBottomLine];

    _subHeaderIndicator = [[UIView alloc] initWithFrame:CGRectZero];
    _subHeaderIndicator.layer.cornerRadius = 1.25;
    [_msgSubHeaderView addSubview:_subHeaderIndicator];

    // 2b. Phone Message Sync Bar ("Đồng bộ tin nhắn với điện thoại")
    _phoneSyncBannerView = [[UIView alloc] initWithFrame:CGRectZero];
    [_leftMasterContainer addSubview:_phoneSyncBannerView];

    _phoneSyncIconView = [[UIImageView alloc] initWithImage:[CTDOIconRenderer phoneSyncIconWithSize:20.0 color:[CTDOTheme colorFromHex:@"#0068FF"]]];
    _phoneSyncIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_phoneSyncBannerView addSubview:_phoneSyncIconView];

    _phoneSyncTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _phoneSyncTitleLabel.text = @"Đồng bộ tin nhắn từ điện thoại";
    _phoneSyncTitleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [_phoneSyncBannerView addSubview:_phoneSyncTitleLabel];

    _phoneSyncSubLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _phoneSyncSubLabel.text = @"Gửi yêu cầu lên điện thoại & tải lịch sử chat mới nhất";
    _phoneSyncSubLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
    _phoneSyncSubLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_phoneSyncBannerView addSubview:_phoneSyncSubLabel];

    _phoneSyncActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_phoneSyncActionBtn setTitle:@"Đồng bộ" forState:UIControlStateNormal];
    _phoneSyncActionBtn.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    _phoneSyncActionBtn.backgroundColor = [CTDOTheme colorFromHex:@"#0068FF"];
    [_phoneSyncActionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _phoneSyncActionBtn.layer.cornerRadius = 13.0;
    [_phoneSyncActionBtn addTarget:self action:@selector(onTapSyncPhoneMessages) forControlEvents:UIControlEventTouchUpInside];
    [_phoneSyncBannerView addSubview:_phoneSyncActionBtn];

    _phoneSyncProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    _phoneSyncProgressView.progressTintColor = [CTDOTheme colorFromHex:@"#0068FF"];
    _phoneSyncProgressView.trackTintColor = [UIColor colorWithWhite:0.85 alpha:0.6];
    _phoneSyncProgressView.hidden = YES;
    [_phoneSyncBannerView addSubview:_phoneSyncProgressView];

    _phoneSyncBottomLine = [[UIView alloc] initWithFrame:CGRectZero];
    [_phoneSyncBannerView addSubview:_phoneSyncBottomLine];

    // 3. Sub-Header for Tab 1 (Danh bạ: Bạn bè | Nhóm | OA)
    _contactSubHeaderView = [[UIView alloc] initWithFrame:CGRectZero];
    _contactSubHeaderView.hidden = YES;
    [_leftMasterContainer addSubview:_contactSubHeaderView];

    _contactSubBtn0 = [UIButton buttonWithType:UIButtonTypeCustom];
    [_contactSubBtn0 setTitle:@"Bạn bè" forState:UIControlStateNormal];
    _contactSubBtn0.tag = 0;
    [_contactSubBtn0 addTarget:self action:@selector(onTapContactSubTab:) forControlEvents:UIControlEventTouchUpInside];
    [_contactSubHeaderView addSubview:_contactSubBtn0];

    _contactSubBtn1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [_contactSubBtn1 setTitle:@"Nhóm" forState:UIControlStateNormal];
    _contactSubBtn1.tag = 1;
    [_contactSubBtn1 addTarget:self action:@selector(onTapContactSubTab:) forControlEvents:UIControlEventTouchUpInside];
    [_contactSubHeaderView addSubview:_contactSubBtn1];

    _contactSubBtn2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [_contactSubBtn2 setTitle:@"OA" forState:UIControlStateNormal];
    _contactSubBtn2.tag = 2;
    [_contactSubBtn2 addTarget:self action:@selector(onTapContactSubTab:) forControlEvents:UIControlEventTouchUpInside];
    [_contactSubHeaderView addSubview:_contactSubBtn2];

    _contactSubIndicator = [[UIView alloc] initWithFrame:CGRectZero];
    _contactSubIndicator.layer.cornerRadius = 1.25;
    [_contactSubHeaderView addSubview:_contactSubIndicator];

    // 4. TableViews (Threads, Contacts, Profile/Settings)
    _threadTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _threadTableView.dataSource = self;
    _threadTableView.delegate = self;
    _threadTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _threadTableView.showsVerticalScrollIndicator = YES;
    [_threadTableView registerClass:[CTDOThreadCell class] forCellReuseIdentifier:@"CTDOThreadCell"];

    _threadRefreshControl = [[UIRefreshControl alloc] init];
    [_threadRefreshControl addTarget:self action:@selector(onPullToRefreshThreads) forControlEvents:UIControlEventValueChanged];
    _threadTableView.refreshControl = _threadRefreshControl;
    [_leftMasterContainer addSubview:_threadTableView];

    _contactTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _contactTableView.dataSource = self;
    _contactTableView.delegate = self;
    _contactTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _contactTableView.sectionIndexColor = [UIColor colorWithRed:0.35 green:0.40 blue:0.46 alpha:1.0];
    _contactTableView.sectionIndexBackgroundColor = [UIColor clearColor];
    _contactTableView.hidden = YES;
    [_contactTableView registerClass:[CTDOContactCell class] forCellReuseIdentifier:@"CTDOContactCell"];
    [_contactTableView registerClass:[CTDOMenuCell class] forCellReuseIdentifier:@"CTDOMenuCell"];
    [_leftMasterContainer addSubview:_contactTableView];

    _profileTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _profileTableView.dataSource = self;
    _profileTableView.delegate = self;
    _profileTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _profileTableView.hidden = YES;
    [_profileTableView registerClass:[CTDOMenuCell class] forCellReuseIdentifier:@"CTDOMenuCell"];
    [_leftMasterContainer addSubview:_profileTableView];

    // 5. Bottom 5-Tab Bar (Tin nhắn | Danh bạ | Khám phá | Tường nhà | Cá nhân)
    _bottomTabBar = [[UIView alloc] initWithFrame:CGRectZero];
    [_leftMasterContainer addSubview:_bottomTabBar];

    _bottomTabTopLine = [[UIView alloc] initWithFrame:CGRectZero];
    [_bottomTabBar addSubview:_bottomTabTopLine];

    NSArray<NSString *> *tabTitles = @[@"Tin nhắn", @"Danh bạ", @"Khám phá", @"Tường nhà", @"Cá nhân"];
    _bottomTabButtons = [NSMutableArray arrayWithCapacity:5];
    _bottomTabIcons = [NSMutableArray arrayWithCapacity:5];
    _bottomTabLabels = [NSMutableArray arrayWithCapacity:5];

    for (NSInteger i = 0; i < 5; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        [btn addTarget:self action:@selector(onTapBottomTab:) forControlEvents:UIControlEventTouchUpInside];
        [_bottomTabBar addSubview:btn];
        [_bottomTabButtons addObject:btn];

        UIImageView *iv = [[UIImageView alloc] initWithImage:[CTDOIconRenderer tabIconForIndex:i selected:(i == 0)]];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.userInteractionEnabled = NO;
        [btn addSubview:iv];
        [_bottomTabIcons addObject:iv];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectZero];
        lbl.text = tabTitles[i];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont systemFontOfSize:10.5 weight:(i == 0 ? UIFontWeightSemibold : UIFontWeightRegular)];
        lbl.userInteractionEnabled = NO;
        [btn addSubview:lbl];
        [_bottomTabLabels addObject:lbl];

        if (i == 0) {
            _msgTabBadge = [[UILabel alloc] initWithFrame:CGRectZero];
            _msgTabBadge.backgroundColor = [CTDOTheme colorFromHex:@"#EF4444"];
            _msgTabBadge.textColor = [UIColor whiteColor];
            _msgTabBadge.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold];
            _msgTabBadge.textAlignment = NSTextAlignmentCenter;
            _msgTabBadge.layer.cornerRadius = 8.0;
            _msgTabBadge.layer.masksToBounds = YES;
            _msgTabBadge.layer.borderWidth = 1.5;
            _msgTabBadge.layer.borderColor = [UIColor whiteColor].CGColor;
            [btn addSubview:_msgTabBadge];
        } else if (i == 3) {
            _timelineTabDot = [[UIView alloc] initWithFrame:CGRectZero];
            _timelineTabDot.backgroundColor = [CTDOTheme colorFromHex:@"#EF4444"];
            _timelineTabDot.layer.cornerRadius = 3.5;
            [btn addSubview:_timelineTabDot];
        }
    }

    // 6. Primary Chat Detail Column
    _primaryChatContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _primaryChatContainer.clipsToBounds = YES;
    [self.view addSubview:_primaryChatContainer];

    _primaryChatHeader = [[UIView alloc] initWithFrame:CGRectZero];
    _primaryChatHeaderGradient = [CAGradientLayer layer];
    _primaryChatHeaderGradient.startPoint = CGPointMake(0.0, 0.5);
    _primaryChatHeaderGradient.endPoint = CGPointMake(1.0, 0.5);
    _primaryChatHeaderGradient.colors = @[
        (id)[CTDOTheme colorFromHex:@"#0068FF"].CGColor,
        (id)[CTDOTheme colorFromHex:@"#0091FF"].CGColor
    ];
    [_primaryChatHeader.layer insertSublayer:_primaryChatHeaderGradient atIndex:0];
    [_primaryChatContainer addSubview:_primaryChatHeader];

    _chatBackBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _chatBackBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_chatBackBtn setImage:[CTDOIconRenderer backChevronIconWithSize:22.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
    [_chatBackBtn addTarget:self action:@selector(onTapChatBack) forControlEvents:UIControlEventTouchUpInside];
    [_primaryChatHeader addSubview:_chatBackBtn];

    _chatTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _chatTitleLabel.font = [UIFont systemFontOfSize:16.5 weight:UIFontWeightSemibold];
    _chatTitleLabel.textColor = [UIColor whiteColor];
    [_primaryChatHeader addSubview:_chatTitleLabel];

    _chatSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _chatSubtitleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightRegular];
    _chatSubtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    [_primaryChatHeader addSubview:_chatSubtitleLabel];

    _chatPhoneBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _chatPhoneBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_chatPhoneBtn setImage:[CTDOIconRenderer phoneCallIconWithSize:20.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
    [_chatPhoneBtn addTarget:self action:@selector(onTapVoiceCall) forControlEvents:UIControlEventTouchUpInside];
    [_primaryChatHeader addSubview:_chatPhoneBtn];

    _chatVideoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _chatVideoBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_chatVideoBtn setImage:[CTDOIconRenderer videoCallIconWithSize:20.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
    [_chatVideoBtn addTarget:self action:@selector(onTapVideoCall) forControlEvents:UIControlEventTouchUpInside];
    [_primaryChatHeader addSubview:_chatVideoBtn];

    _chatMenuBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_chatMenuBtn setTitle:@"☰" forState:UIControlStateNormal];
    [_chatMenuBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _chatMenuBtn.titleLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    [_chatMenuBtn addTarget:self action:@selector(onTapChatMenu) forControlEvents:UIControlEventTouchUpInside];
    [_primaryChatHeader addSubview:_chatMenuBtn];

    _primaryChatTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _primaryChatTableView.dataSource = self;
    _primaryChatTableView.delegate = self;
    _primaryChatTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_primaryChatTableView registerClass:[CTDOMessageCell class] forCellReuseIdentifier:@"CTDOMessageCell"];
    [_primaryChatContainer addSubview:_primaryChatTableView];

    // Reply Banner + Composer Bar
    _replyBannerView = [[UIView alloc] initWithFrame:CGRectZero];
    _replyBannerView.hidden = YES;
    [_primaryChatContainer addSubview:_replyBannerView];

    _replyBannerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _replyBannerLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    [_replyBannerView addSubview:_replyBannerLabel];

    _replyBannerCloseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_replyBannerCloseBtn setTitle:@"✕" forState:UIControlStateNormal];
    [_replyBannerCloseBtn addTarget:self action:@selector(onCancelReply) forControlEvents:UIControlEventTouchUpInside];
    [_replyBannerView addSubview:_replyBannerCloseBtn];

    _composerBar = [[UIView alloc] initWithFrame:CGRectZero];
    [_primaryChatContainer addSubview:_composerBar];

    _composerStickerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_composerStickerBtn setTitle:@"😊" forState:UIControlStateNormal];
    _composerStickerBtn.titleLabel.font = [UIFont systemFontOfSize:21.0];
    [_composerBar addSubview:_composerStickerBtn];

    _composerTextField = [[UITextField alloc] initWithFrame:CGRectZero];
    _composerTextField.delegate = self;
    _composerTextField.font = [UIFont systemFontOfSize:15.5];
    _composerTextField.placeholder = @"Tin nhắn";
    _composerTextField.returnKeyType = UIReturnKeySend;
    [_composerBar addSubview:_composerTextField];

    _composerScheduleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_composerScheduleBtn setTitle:@"⏰" forState:UIControlStateNormal];
    _composerScheduleBtn.titleLabel.font = [UIFont systemFontOfSize:18.0];
    [_composerScheduleBtn addTarget:self action:@selector(onTapScheduleQuickMessage) forControlEvents:UIControlEventTouchUpInside];
    [_composerBar addSubview:_composerScheduleBtn];

    _composerSendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_composerSendBtn setTitle:@"Gửi" forState:UIControlStateNormal];
    _composerSendBtn.titleLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightBold];
    _composerSendBtn.layer.cornerRadius = 17.0;
    [_composerSendBtn addTarget:self action:@selector(onSendPrimaryMessage) forControlEvents:UIControlEventTouchUpInside];
    [_composerBar addSubview:_composerSendBtn];

    // 7. Secondary Dual-Chat / Màn 2 Column (iPhone Duo & iPad Pro)
    _secondaryChatContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _secondaryChatContainer.clipsToBounds = YES;
    [self.view addSubview:_secondaryChatContainer];

    _secondaryChatHeader = [[UIView alloc] initWithFrame:CGRectZero];
    _secondaryChatHeaderGradient = [CAGradientLayer layer];
    _secondaryChatHeaderGradient.startPoint = CGPointMake(0.0, 0.5);
    _secondaryChatHeaderGradient.endPoint = CGPointMake(1.0, 0.5);
    _secondaryChatHeaderGradient.colors = @[
        (id)[CTDOTheme colorFromHex:@"#0068FF"].CGColor,
        (id)[CTDOTheme colorFromHex:@"#0091FF"].CGColor
    ];
    [_secondaryChatHeader.layer insertSublayer:_secondaryChatHeaderGradient atIndex:0];
    [_secondaryChatContainer addSubview:_secondaryChatHeader];

    _secondaryChatTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondaryChatTitleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _secondaryChatTitleLabel.textColor = [UIColor whiteColor];
    [_secondaryChatHeader addSubview:_secondaryChatTitleLabel];

    _secondaryChatSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondaryChatSubtitleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
    _secondaryChatSubtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    [_secondaryChatHeader addSubview:_secondaryChatSubtitleLabel];

    _secondaryPaneModeSegment = [[UISegmentedControl alloc] initWithItems:@[@"Chat song song", @"Tài khoản 2 (Màn 2)"]];
    _secondaryPaneModeSegment.selectedSegmentIndex = 0;
    if (@available(iOS 13.0, *)) {
        _secondaryPaneModeSegment.selectedSegmentTintColor = [UIColor whiteColor];
        [_secondaryPaneModeSegment setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.92],
            NSFontAttributeName: [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium]
        } forState:UIControlStateNormal];
        [_secondaryPaneModeSegment setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [CTDOTheme colorFromHex:@"#0068FF"],
            NSFontAttributeName: [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold]
        } forState:UIControlStateSelected];
    }
    [_secondaryPaneModeSegment addTarget:self action:@selector(onSecondaryPaneModeChanged:) forControlEvents:UIControlEventValueChanged];
    [_secondaryChatHeader addSubview:_secondaryPaneModeSegment];

    _secondaryChatTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _secondaryChatTableView.dataSource = self;
    _secondaryChatTableView.delegate = self;
    _secondaryChatTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_secondaryChatTableView registerClass:[CTDOMessageCell class] forCellReuseIdentifier:@"CTDOMessageCell2"];
    [_secondaryChatContainer addSubview:_secondaryChatTableView];

    _secondaryComposerBar = [[UIView alloc] initWithFrame:CGRectZero];
    [_secondaryChatContainer addSubview:_secondaryComposerBar];

    _secondaryComposerField = [[UITextField alloc] initWithFrame:CGRectZero];
    _secondaryComposerField.delegate = self;
    _secondaryComposerField.font = [UIFont systemFontOfSize:14.5];
    _secondaryComposerField.placeholder = @"Tin nhắn song song (Dual-Chat)...";
    _secondaryComposerField.returnKeyType = UIReturnKeySend;
    [_secondaryComposerBar addSubview:_secondaryComposerField];

    _secondaryComposerSendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_secondaryComposerSendBtn setTitle:@"Gửi" forState:UIControlStateNormal];
    _secondaryComposerSendBtn.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    _secondaryComposerSendBtn.layer.cornerRadius = 15.0;
    [_secondaryComposerSendBtn addTarget:self action:@selector(onSendSecondaryMessage) forControlEvents:UIControlEventTouchUpInside];
    [_secondaryComposerBar addSubview:_secondaryComposerSendBtn];

    // Embedded Login Màn 2 Card (inside _secondaryChatContainer)
    [self setupSecondaryLoginPane];

    // 8. QR Login Overlay
    [self setupLoginOverlay];
}

- (void)setupSecondaryLoginPane {
    _secondaryLoginContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _secondaryLoginContainer.hidden = YES;
    [_secondaryChatContainer addSubview:_secondaryLoginContainer];

    _secondaryLoginCard = [[UIView alloc] initWithFrame:CGRectZero];
    _secondaryLoginCard.backgroundColor = [UIColor whiteColor];
    _secondaryLoginCard.layer.cornerRadius = 18.0;
    _secondaryLoginCard.layer.borderWidth = 1.0;
    _secondaryLoginCard.layer.borderColor = [CTDOTheme colorFromHex:@"#E2E8F0"].CGColor;
    _secondaryLoginCard.layer.masksToBounds = YES;
    [_secondaryLoginContainer addSubview:_secondaryLoginCard];

    _secondaryLoginBadgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondaryLoginBadgeLabel.text = @"MÀN 2 ĐỘC LẬP • TÀI KHOẢN ZALO 2";
    _secondaryLoginBadgeLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    _secondaryLoginBadgeLabel.textAlignment = NSTextAlignmentCenter;
    _secondaryLoginBadgeLabel.adjustsFontSizeToFitWidth = YES;
    _secondaryLoginBadgeLabel.minimumScaleFactor = 0.85;
    _secondaryLoginBadgeLabel.textColor = [CTDOTheme colorFromHex:@"#0068FF"];
    _secondaryLoginBadgeLabel.backgroundColor = [CTDOTheme colorFromHex:@"#EBF3FF"];
    _secondaryLoginBadgeLabel.layer.cornerRadius = 11.0;
    _secondaryLoginBadgeLabel.layer.masksToBounds = YES;
    [_secondaryLoginCard addSubview:_secondaryLoginBadgeLabel];

    _secondaryLoginTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondaryLoginTitleLabel.text = @"Đăng nhập Zalo trên Màn 2";
    _secondaryLoginTitleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
    _secondaryLoginTitleLabel.textAlignment = NSTextAlignmentCenter;
    _secondaryLoginTitleLabel.textColor = [CTDOTheme colorFromHex:@"#141415"];
    [_secondaryLoginCard addSubview:_secondaryLoginTitleLabel];

    _secondaryLoginSubLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondaryLoginSubLabel.text = @"Chạy song song 2 tài khoản Zalo độc lập trên iPhone Duo / iPad Pro & đồng bộ tin nhắn.";
    _secondaryLoginSubLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    _secondaryLoginSubLabel.textAlignment = NSTextAlignmentCenter;
    _secondaryLoginSubLabel.numberOfLines = 2;
    _secondaryLoginSubLabel.textColor = [CTDOTheme colorFromHex:@"#64748B"];
    [_secondaryLoginCard addSubview:_secondaryLoginSubLabel];

    _secondaryLoginTabSegment = [[UISegmentedControl alloc] initWithItems:@[@"Quét mã QR", @"SĐT & Mật khẩu"]];
    _secondaryLoginTabSegment.selectedSegmentIndex = 0;
    [_secondaryLoginTabSegment addTarget:self action:@selector(onSecondaryLoginTabChanged:) forControlEvents:UIControlEventValueChanged];
    [_secondaryLoginCard addSubview:_secondaryLoginTabSegment];

    _secondaryQrImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _secondaryQrImageView.backgroundColor = [UIColor whiteColor];
    _secondaryQrImageView.contentMode = UIViewContentModeScaleAspectFit;
    _secondaryQrImageView.layer.cornerRadius = 12.0;
    _secondaryQrImageView.layer.borderWidth = 1.5;
    _secondaryQrImageView.layer.borderColor = [CTDOTheme colorFromHex:@"#0068FF"].CGColor;
    _secondaryQrImageView.layer.masksToBounds = YES;
    [_secondaryLoginCard addSubview:_secondaryQrImageView];

    _secondaryPhoneField = [[UITextField alloc] initWithFrame:CGRectZero];
    _secondaryPhoneField.placeholder = @"Số điện thoại Zalo (VD: 0912345678)";
    _secondaryPhoneField.font = [UIFont systemFontOfSize:14.0];
    _secondaryPhoneField.borderStyle = UITextBorderStyleRoundedRect;
    _secondaryPhoneField.keyboardType = UIKeyboardTypePhonePad;
    _secondaryPhoneField.hidden = YES;
    [_secondaryLoginCard addSubview:_secondaryPhoneField];

    _secondaryPassField = [[UITextField alloc] initWithFrame:CGRectZero];
    _secondaryPassField.placeholder = @"Mật khẩu Zalo";
    _secondaryPassField.font = [UIFont systemFontOfSize:14.0];
    _secondaryPassField.borderStyle = UITextBorderStyleRoundedRect;
    _secondaryPassField.secureTextEntry = YES;
    _secondaryPassField.hidden = YES;
    [_secondaryLoginCard addSubview:_secondaryPassField];

    _secondaryQrStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondaryQrStatusLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _secondaryQrStatusLabel.textAlignment = NSTextAlignmentCenter;
    _secondaryQrStatusLabel.numberOfLines = 2;
    _secondaryQrStatusLabel.textColor = [CTDOTheme colorFromHex:@"#0068FF"];
    [_secondaryLoginCard addSubview:_secondaryQrStatusLabel];

    _secondaryQrActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_secondaryQrActionBtn setTitle:@"Làm mới mã QR Màn 2" forState:UIControlStateNormal];
    _secondaryQrActionBtn.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _secondaryQrActionBtn.backgroundColor = [CTDOTheme colorFromHex:@"#0068FF"];
    [_secondaryQrActionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _secondaryQrActionBtn.layer.cornerRadius = 10.0;
    [_secondaryQrActionBtn addTarget:self action:@selector(onTapSecondaryLoginAction) forControlEvents:UIControlEventTouchUpInside];
    [_secondaryLoginCard addSubview:_secondaryQrActionBtn];

    _secondaryBackToDualBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_secondaryBackToDualBtn setTitle:@"← Quay về Chat song song (Tài khoản 1)" forState:UIControlStateNormal];
    _secondaryBackToDualBtn.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
    _secondaryBackToDualBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    _secondaryBackToDualBtn.titleLabel.minimumScaleFactor = 0.85;
    [_secondaryBackToDualBtn setTitleColor:[CTDOTheme colorFromHex:@"#475569"] forState:UIControlStateNormal];
    [_secondaryBackToDualBtn addTarget:self action:@selector(onTapSecondaryBackToDual) forControlEvents:UIControlEventTouchUpInside];
    [_secondaryLoginCard addSubview:_secondaryBackToDualBtn];
}

- (void)setupLoginOverlay {
    _loginOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    _loginOverlay.backgroundColor = [UIColor colorWithRed:0.02 green:0.06 blue:0.14 alpha:0.90];
    _loginOverlay.hidden = YES;
    [self.view addSubview:_loginOverlay];

    _loginCard = [[UIView alloc] initWithFrame:CGRectZero];
    _loginCard.backgroundColor = [UIColor whiteColor];
    _loginCard.layer.cornerRadius = 20.0;
    _loginCard.layer.masksToBounds = YES;
    [_loginOverlay addSubview:_loginCard];

    _loginSlotBadgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _loginSlotBadgeLabel.text = @"MÀN 2 • ĐĂNG NHẬP TÀI KHOẢN ZALO THỨ 2";
    _loginSlotBadgeLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    _loginSlotBadgeLabel.textAlignment = NSTextAlignmentCenter;
    _loginSlotBadgeLabel.textColor = [CTDOTheme colorFromHex:@"#0068FF"];
    _loginSlotBadgeLabel.backgroundColor = [CTDOTheme colorFromHex:@"#EBF3FF"];
    _loginSlotBadgeLabel.layer.cornerRadius = 11.0;
    _loginSlotBadgeLabel.layer.masksToBounds = YES;
    [_loginCard addSubview:_loginSlotBadgeLabel];

    _loginLogoView = [[UIImageView alloc] initWithImage:[CTDOIconRenderer appLogoWithSize:48.0]];
    _loginLogoView.contentMode = UIViewContentModeScaleAspectFit;
    [_loginCard addSubview:_loginLogoView];

    _loginTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _loginTitleLabel.text = @"Đăng nhập Zalo & Đồng bộ điện thoại";
    _loginTitleLabel.font = [UIFont systemFontOfSize:17.5 weight:UIFontWeightBold];
    _loginTitleLabel.textAlignment = NSTextAlignmentCenter;
    _loginTitleLabel.textColor = [CTDOTheme colorFromHex:@"#141415"];
    [_loginCard addSubview:_loginTitleLabel];

    _loginSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _loginSubtitleLabel.text = @"Mở Zalo trên điện thoại → Quét mã QR để đăng nhập và tự động đồng bộ tin nhắn.";
    _loginSubtitleLabel.font = [UIFont systemFontOfSize:12.5];
    _loginSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    _loginSubtitleLabel.numberOfLines = 2;
    _loginSubtitleLabel.textColor = [CTDOTheme colorFromHex:@"#64748B"];
    [_loginCard addSubview:_loginSubtitleLabel];

    _loginModeSegment = [[UISegmentedControl alloc] initWithItems:@[@"Quét mã QR", @"SĐT & Mật khẩu"]];
    _loginModeSegment.selectedSegmentIndex = 0;
    [_loginModeSegment addTarget:self action:@selector(onLoginModeTabChanged:) forControlEvents:UIControlEventValueChanged];
    [_loginCard addSubview:_loginModeSegment];

    _qrImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _qrImageView.backgroundColor = [UIColor whiteColor];
    _qrImageView.contentMode = UIViewContentModeScaleAspectFit;
    _qrImageView.layer.cornerRadius = 12.0;
    _qrImageView.layer.borderWidth = 1.5;
    _qrImageView.layer.borderColor = [CTDOTheme colorFromHex:@"#0068FF"].CGColor;
    _qrImageView.layer.masksToBounds = YES;
    [_loginCard addSubview:_qrImageView];

    _loginPhoneField = [[UITextField alloc] initWithFrame:CGRectZero];
    _loginPhoneField.placeholder = @"Số điện thoại Zalo (VD: 0912345678)";
    _loginPhoneField.font = [UIFont systemFontOfSize:14.5];
    _loginPhoneField.borderStyle = UITextBorderStyleRoundedRect;
    _loginPhoneField.keyboardType = UIKeyboardTypePhonePad;
    _loginPhoneField.hidden = YES;
    [_loginCard addSubview:_loginPhoneField];

    _loginPasswordField = [[UITextField alloc] initWithFrame:CGRectZero];
    _loginPasswordField.placeholder = @"Mật khẩu Zalo";
    _loginPasswordField.font = [UIFont systemFontOfSize:14.5];
    _loginPasswordField.borderStyle = UITextBorderStyleRoundedRect;
    _loginPasswordField.secureTextEntry = YES;
    _loginPasswordField.hidden = YES;
    [_loginCard addSubview:_loginPasswordField];

    _qrStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _qrStatusLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    _qrStatusLabel.textAlignment = NSTextAlignmentCenter;
    _qrStatusLabel.numberOfLines = 2;
    _qrStatusLabel.textColor = [CTDOTheme colorFromHex:@"#0068FF"];
    [_loginCard addSubview:_qrStatusLabel];

    _qrReloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_qrReloadBtn setTitle:@"Lấy mã QR mới" forState:UIControlStateNormal];
    _qrReloadBtn.titleLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold];
    _qrReloadBtn.backgroundColor = [CTDOTheme colorFromHex:@"#0068FF"];
    [_qrReloadBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _qrReloadBtn.layer.cornerRadius = 10.0;
    [_qrReloadBtn addTarget:self action:@selector(onTapPrimaryLoginAction) forControlEvents:UIControlEventTouchUpInside];
    [_loginCard addSubview:_qrReloadBtn];

    _loginBackToSlot0Btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_loginBackToSlot0Btn setTitle:@"← Quay lại Tài khoản 1 (Đang đăng nhập)" forState:UIControlStateNormal];
    _loginBackToSlot0Btn.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [_loginBackToSlot0Btn setTitleColor:[CTDOTheme colorFromHex:@"#334155"] forState:UIControlStateNormal];
    _loginBackToSlot0Btn.backgroundColor = [CTDOTheme colorFromHex:@"#F1F5F9"];
    _loginBackToSlot0Btn.layer.cornerRadius = 10.0;
    [_loginBackToSlot0Btn addTarget:self action:@selector(onTapBackToAccount1) forControlEvents:UIControlEventTouchUpInside];
    [_loginCard addSubview:_loginBackToSlot0Btn];
}

#pragma mark - Adaptive Layout (iPhone vs iPhone Duo vs iPad Pro)

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize winSize = self.view.bounds.size;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    _currentDeviceClass = [[CTDOCoreBridge shared] hardwareDeviceClassForWindowSize:winSize];

    BOOL isCompact = (_currentDeviceClass == CTDODeviceClassiPhone);
    BOOL isWideMultiPane = !isCompact;

    if (isCompact) {
        _secondaryChatContainer.hidden = YES;
        if (_compactShowingChatDetail) {
            _leftMasterContainer.hidden = YES;
            _primaryChatContainer.hidden = NO;
            _primaryChatContainer.frame = self.view.bounds;
        } else {
            _leftMasterContainer.hidden = NO;
            _primaryChatContainer.hidden = YES;
            _leftMasterContainer.frame = self.view.bounds;
        }
    } else {
        _leftMasterContainer.hidden = NO;
        _primaryChatContainer.hidden = NO;

        CGFloat leftW = (_currentDeviceClass == CTDODeviceClassiPhoneDuo) ? 336.0 : 352.0;
        _leftMasterContainer.frame = CGRectMake(0, 0, leftW, winSize.height);

        CGFloat remW = winSize.width - leftW;
        BOOL showSecondary = _dualChatEnabled && (remW >= 600.0) && (_secondaryThreadId.length > 0 || _secondaryPaneMode == 1);
        if (showSecondary) {
            CGFloat primaryW = floor(remW * 0.50);
            _primaryChatContainer.frame = CGRectMake(leftW, 0, primaryW, winSize.height);
            _secondaryChatContainer.hidden = NO;
            _secondaryChatContainer.frame = CGRectMake(leftW + primaryW, 0, remW - primaryW, winSize.height);
        } else {
            _primaryChatContainer.frame = CGRectMake(leftW, 0, remW, winSize.height);
            _secondaryChatContainer.hidden = YES;
        }
    }

    // Layout Left Master Container
    [self layoutLeftMasterWithSafeInsets:safe];

    // Layout Primary Chat Container
    if (!_primaryChatContainer.hidden) {
        [self layoutPrimaryChatWithSafeInsets:safe isCompact:isCompact];
    }

    // Layout Secondary Chat / Màn 2 Container
    if (!_secondaryChatContainer.hidden && isWideMultiPane) {
        [self layoutSecondaryChatWithSafeInsets:safe];
    }

    // Layout QR / Password Login Overlay
    if (!_loginOverlay.hidden) {
        _loginOverlay.frame = self.view.bounds;
        NSDictionary *slot0Auth = [[CTDOCoreBridge shared] authStateForSlot:0];
        BOOL canReturnToSlot0 = (_activeSlot != 0 && [slot0Auth[@"authenticated"] boolValue]);
        _loginBackToSlot0Btn.hidden = !canReturnToSlot0;

        CGFloat cardW = MIN(winSize.width - 28.0, 392.0);
        CGFloat cardH = canReturnToSlot0 ? 528.0 : 480.0;
        _loginCard.frame = CGRectMake((winSize.width - cardW) * 0.5, (winSize.height - cardH) * 0.5, cardW, cardH);

        _loginSlotBadgeLabel.frame = CGRectMake((cardW - 260.0) * 0.5, 14.0, 260.0, 22.0);
        _loginLogoView.frame = CGRectMake((cardW - 44.0) * 0.5, 42.0, 44.0, 44.0);
        _loginTitleLabel.frame = CGRectMake(16.0, 92.0, cardW - 32.0, 22.0);
        _loginSubtitleLabel.frame = CGRectMake(18.0, 116.0, cardW - 36.0, 32.0);
        _loginModeSegment.frame = CGRectMake(24.0, 154.0, cardW - 48.0, 30.0);

        if (_loginAuthTab == 0) {
            _qrImageView.hidden = NO;
            _loginPhoneField.hidden = YES;
            _loginPasswordField.hidden = YES;
            _qrImageView.frame = CGRectMake((cardW - 196.0) * 0.5, 194.0, 196.0, 196.0);
        } else {
            _qrImageView.hidden = YES;
            _loginPhoneField.hidden = NO;
            _loginPasswordField.hidden = NO;
            _loginPhoneField.frame = CGRectMake(28.0, 220.0, cardW - 56.0, 40.0);
            _loginPasswordField.frame = CGRectMake(28.0, 272.0, cardW - 56.0, 40.0);
        }

        _qrStatusLabel.frame = CGRectMake(16.0, 396.0, cardW - 32.0, 32.0);
        _qrReloadBtn.frame = CGRectMake(28.0, 432.0, cardW - 56.0, 38.0);
        if (canReturnToSlot0) {
            _loginBackToSlot0Btn.frame = CGRectMake(28.0, 478.0, cardW - 56.0, 36.0);
        }
    }
}

- (void)layoutLeftMasterWithSafeInsets:(UIEdgeInsets)safe {
    CGFloat w = _leftMasterContainer.bounds.size.width;
    CGFloat h = _leftMasterContainer.bounds.size.height;
    CGFloat topBarContentH = 46.0;
    CGFloat topBarH = safe.top + topBarContentH;

    _topHeaderView.frame = CGRectMake(0, 0, w, topBarH);
    _topHeaderGradient.frame = _topHeaderView.bounds;

    BOOL inSettings = (_activeBottomTab == 4 && _showingSettingsSubscreen);
    if (inSettings) {
        _headerBackBtn.hidden = NO;
        _headerTitleLabel.hidden = NO;
        _headerSearchIcon.hidden = YES;
        _headerSearchField.hidden = YES;
        _headerRightBtn2.hidden = YES;

        _headerBackBtn.frame = CGRectMake(8.0, safe.top + 5.0, 36.0, 36.0);
        _headerTitleLabel.frame = CGRectMake(48.0, safe.top + 5.0, w - 104.0, 36.0);
        _headerRightBtn1.frame = CGRectMake(w - 44.0, safe.top + 5.0, 36.0, 36.0);
        [_headerRightBtn1 setImage:[CTDOIconRenderer searchIconWithSize:20.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
    } else {
        _headerBackBtn.hidden = YES;
        _headerTitleLabel.hidden = YES;
        _headerSearchIcon.hidden = NO;
        _headerSearchField.hidden = NO;

        _headerSearchIcon.frame = CGRectMake(16.0, safe.top + 13.0, 20.0, 20.0);

        if (_activeBottomTab == 0) {
            // Tin nhắn: [QR] and [+]
            _headerRightBtn2.hidden = NO;
            _headerRightBtn2.frame = CGRectMake(w - 44.0, safe.top + 5.0, 36.0, 36.0);
            _headerRightBtn1.frame = CGRectMake(w - 86.0, safe.top + 5.0, 36.0, 36.0);
            [_headerRightBtn1 setImage:[CTDOIconRenderer qrScanIconWithSize:21.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
            _headerSearchField.frame = CGRectMake(46.0, safe.top + 6.0, w - 140.0, 34.0);
        } else if (_activeBottomTab == 1) {
            // Danh bạ: [👤+]
            _headerRightBtn2.hidden = YES;
            _headerRightBtn1.frame = CGRectMake(w - 46.0, safe.top + 5.0, 36.0, 36.0);
            [_headerRightBtn1 setImage:[CTDOIconRenderer addFriendIconWithSize:22.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
            _headerSearchField.frame = CGRectMake(46.0, safe.top + 6.0, w - 100.0, 34.0);
        } else {
            // Cá nhân / Khám phá / Tường nhà: [⚙️]
            _headerRightBtn2.hidden = YES;
            _headerRightBtn1.frame = CGRectMake(w - 46.0, safe.top + 5.0, 36.0, 36.0);
            [_headerRightBtn1 setImage:[CTDOIconRenderer gearIconWithSize:21.0 color:[UIColor whiteColor]] forState:UIControlStateNormal];
            _headerSearchField.frame = CGRectMake(46.0, safe.top + 6.0, w - 100.0, 34.0);
        }
    }

    // Bottom TabBar (hidden when inside Cài đặt on compact iPhone, matching ref5.png)
    CGFloat tabBarH = inSettings ? 0.0 : (54.0 + safe.bottom);
    _bottomTabBar.hidden = inSettings;
    _bottomTabBar.frame = CGRectMake(0, h - tabBarH, w, tabBarH);
    _bottomTabTopLine.frame = CGRectMake(0, 0, w, 0.6);

    if (!inSettings) {
        CGFloat tabW = w / 5.0;
        for (NSInteger i = 0; i < 5; i++) {
            UIButton *btn = _bottomTabButtons[i];
            btn.frame = CGRectMake(i * tabW, 0, tabW, 54.0);
            UIImageView *iv = _bottomTabIcons[i];
            iv.frame = CGRectMake((tabW - 24.0) * 0.5, 6.0, 24.0, 24.0);
            UILabel *lbl = _bottomTabLabels[i];
            lbl.frame = CGRectMake(2.0, 32.0, tabW - 4.0, 15.0);

            if (i == 0 && !_msgTabBadge.hidden) {
                _msgTabBadge.frame = CGRectMake(tabW * 0.5 + 4.0, 3.0, 24.0, 16.0);
            }
            if (i == 3) {
                _timelineTabDot.frame = CGRectMake(tabW * 0.5 + 10.0, 5.0, 7.0, 7.0);
            }
        }
    }

    // Sub-header, Phone Sync Bar, and Active TableView
    CGFloat listY = topBarH;
    if (_activeBottomTab == 0) {
        _msgSubHeaderView.hidden = NO;
        _phoneSyncBannerView.hidden = NO;
        _contactSubHeaderView.hidden = YES;
        _threadTableView.hidden = NO;
        _contactTableView.hidden = YES;
        _profileTableView.hidden = YES;

        CGFloat subH = 38.0;
        _msgSubHeaderView.frame = CGRectMake(0, topBarH, w, subH);
        _uuTienTabBtn.frame = CGRectMake(16.0, 0, 68.0, subH);
        _khacTabBtn.frame = CGRectMake(96.0, 0, 52.0, subH);
        _khacRedDot.frame = CGRectMake(144.0, 9.0, 7.0, 7.0);
        _subHeaderBottomLine.frame = CGRectMake(0, subH - 0.6, w, 0.6);

        if (_activeFilterMode == 0) {
            _subHeaderIndicator.frame = CGRectMake(18.0, subH - 2.5, 64.0, 2.5);
        } else {
            _subHeaderIndicator.frame = CGRectMake(98.0, subH - 2.5, 48.0, 2.5);
        }
        listY += subH;

        CGFloat syncH = 44.0;
        _phoneSyncBannerView.frame = CGRectMake(0, listY, w, syncH);
        _phoneSyncIconView.frame = CGRectMake(14.0, 11.0, 22.0, 22.0);
        CGFloat btnW = 74.0;
        _phoneSyncActionBtn.frame = CGRectMake(w - btnW - 12.0, 9.0, btnW, 26.0);
        CGFloat textW = MAX(80.0, w - 44.0 - btnW - 20.0);
        _phoneSyncTitleLabel.frame = CGRectMake(42.0, 5.0, textW, 17.0);
        _phoneSyncSubLabel.frame = CGRectMake(42.0, 22.0, textW, 15.0);
        _phoneSyncProgressView.frame = CGRectMake(0, syncH - 2.5, w, 2.0);
        _phoneSyncBottomLine.frame = CGRectMake(0, syncH - 0.5, w, 0.5);
        listY += syncH;

        _threadTableView.frame = CGRectMake(0, listY, w, h - listY - tabBarH);
    } else if (_activeBottomTab == 1) {
        _msgSubHeaderView.hidden = YES;
        _phoneSyncBannerView.hidden = YES;
        _contactSubHeaderView.hidden = NO;
        _threadTableView.hidden = YES;
        _contactTableView.hidden = NO;
        _profileTableView.hidden = YES;

        CGFloat subH = 42.0;
        _contactSubHeaderView.frame = CGRectMake(0, topBarH, w, subH);
        CGFloat colW = w / 3.0;
        _contactSubBtn0.frame = CGRectMake(0, 0, colW, subH);
        _contactSubBtn1.frame = CGRectMake(colW, 0, colW, subH);
        _contactSubBtn2.frame = CGRectMake(colW * 2.0, 0, colW, subH);
        CGFloat indW = 64.0;
        _contactSubIndicator.frame = CGRectMake(_contactFilterType * colW + (colW - indW) * 0.5, subH - 2.5, indW, 2.5);

        listY += subH;
        _contactTableView.frame = CGRectMake(0, listY, w, h - listY - tabBarH);
    } else {
        _msgSubHeaderView.hidden = YES;
        _phoneSyncBannerView.hidden = YES;
        _contactSubHeaderView.hidden = YES;
        _threadTableView.hidden = YES;
        _contactTableView.hidden = YES;
        _profileTableView.hidden = NO;
        _profileTableView.frame = CGRectMake(0, listY, w, h - listY - tabBarH);
    }
}

- (void)layoutPrimaryChatWithSafeInsets:(UIEdgeInsets)safe isCompact:(BOOL)isCompact {
    CGFloat w = _primaryChatContainer.bounds.size.width;
    CGFloat h = _primaryChatContainer.bounds.size.height;
    CGFloat topBarH = safe.top + 46.0;

    _primaryChatHeader.frame = CGRectMake(0, 0, w, topBarH);
    _primaryChatHeaderGradient.frame = _primaryChatHeader.bounds;

    CGFloat titleX = 14.0;
    if (isCompact) {
        _chatBackBtn.hidden = NO;
        _chatBackBtn.frame = CGRectMake(6.0, safe.top + 5.0, 36.0, 36.0);
        titleX = 44.0;
    } else {
        _chatBackBtn.hidden = YES;
    }

    _chatMenuBtn.frame = CGRectMake(w - 42.0, safe.top + 5.0, 34.0, 36.0);
    _chatVideoBtn.frame = CGRectMake(w - 82.0, safe.top + 5.0, 34.0, 36.0);
    _chatPhoneBtn.frame = CGRectMake(w - 122.0, safe.top + 5.0, 34.0, 36.0);

    CGFloat maxTitleW = MAX(80.0, w - titleX - 130.0);
    _chatTitleLabel.frame = CGRectMake(titleX, safe.top + 5.0, maxTitleW, 20.0);
    _chatSubtitleLabel.frame = CGRectMake(titleX, safe.top + 25.0, maxTitleW, 15.0);

    CGFloat compH = 52.0 + safe.bottom;
    _composerBar.frame = CGRectMake(0, h - compH, w, compH);
    _composerStickerBtn.frame = CGRectMake(8.0, 7.0, 36.0, 36.0);
    _composerSendBtn.frame = CGRectMake(w - 64.0, 8.0, 54.0, 34.0);
    _composerScheduleBtn.frame = CGRectMake(w - 104.0, 8.0, 34.0, 34.0);
    _composerTextField.frame = CGRectMake(48.0, 8.0, w - 158.0, 34.0);

    CGFloat replyH = _replyBannerView.hidden ? 0.0 : 32.0;
    if (!_replyBannerView.hidden) {
        _replyBannerView.frame = CGRectMake(0, h - compH - replyH, w, replyH);
        _replyBannerLabel.frame = CGRectMake(14.0, 4.0, w - 52.0, 24.0);
        _replyBannerCloseBtn.frame = CGRectMake(w - 36.0, 2.0, 28.0, 28.0);
    }

    _primaryChatTableView.frame = CGRectMake(0, topBarH, w, h - topBarH - compH - replyH);
}

- (void)layoutSecondaryChatWithSafeInsets:(UIEdgeInsets)safe {
    CGFloat w = _secondaryChatContainer.bounds.size.width;
    CGFloat h = _secondaryChatContainer.bounds.size.height;
    CGFloat topBarH = safe.top + 76.0;

    _secondaryChatHeader.frame = CGRectMake(0, 0, w, topBarH);
    _secondaryChatHeaderGradient.frame = _secondaryChatHeader.bounds;
    _secondaryChatTitleLabel.frame = CGRectMake(12.0, safe.top + 4.0, w - 24.0, 19.0);
    _secondaryChatSubtitleLabel.frame = CGRectMake(12.0, safe.top + 23.0, w - 24.0, 14.0);
    _secondaryPaneModeSegment.frame = CGRectMake(12.0, safe.top + 41.0, w - 24.0, 28.0);

    NSDictionary *slot1Auth = [[CTDOCoreBridge shared] authStateForSlot:1];
    BOOL slot1Authed = [slot1Auth[@"authenticated"] boolValue];
    BOOL showingLoginCard = (_secondaryPaneMode == 1 && !slot1Authed);

    if (showingLoginCard) {
        _secondaryChatTableView.hidden = YES;
        _secondaryComposerBar.hidden = YES;
        _secondaryLoginContainer.hidden = NO;
        _secondaryLoginContainer.frame = CGRectMake(0, topBarH, w, h - topBarH);

        CGFloat availH = h - topBarH - safe.bottom;
        CGFloat cardW = MIN(w - 20.0, 356.0);
        CGFloat cardH = MIN(availH - 16.0, 446.0);
        _secondaryLoginCard.frame = CGRectMake((w - cardW) * 0.5, MAX(8.0, (availH - cardH) * 0.5), cardW, cardH);

        _secondaryLoginBadgeLabel.frame = CGRectMake(16.0, 12.0, cardW - 32.0, 22.0);
        _secondaryLoginTitleLabel.frame = CGRectMake(14.0, 40.0, cardW - 28.0, 22.0);
        _secondaryLoginSubLabel.frame = CGRectMake(14.0, 64.0, cardW - 28.0, 32.0);
        _secondaryLoginTabSegment.frame = CGRectMake(18.0, 102.0, cardW - 36.0, 28.0);

        CGFloat qrBoxSize = MIN(172.0, MAX(136.0, cardH - 252.0));
        if (_secondaryLoginAuthTab == 0) {
            _secondaryQrImageView.hidden = NO;
            _secondaryPhoneField.hidden = YES;
            _secondaryPassField.hidden = YES;
            _secondaryQrImageView.frame = CGRectMake((cardW - qrBoxSize) * 0.5, 138.0, qrBoxSize, qrBoxSize);
        } else {
            _secondaryQrImageView.hidden = YES;
            _secondaryPhoneField.hidden = NO;
            _secondaryPassField.hidden = NO;
            _secondaryPhoneField.frame = CGRectMake(20.0, 154.0, cardW - 40.0, 38.0);
            _secondaryPassField.frame = CGRectMake(20.0, 202.0, cardW - 40.0, 38.0);
        }

        CGFloat bottomBase = 138.0 + qrBoxSize + 8.0;
        _secondaryQrStatusLabel.frame = CGRectMake(12.0, bottomBase, cardW - 24.0, 32.0);
        _secondaryQrActionBtn.frame = CGRectMake(20.0, bottomBase + 36.0, cardW - 40.0, 36.0);
        _secondaryBackToDualBtn.frame = CGRectMake(12.0, bottomBase + 76.0, cardW - 24.0, 26.0);
    } else {
        _secondaryLoginContainer.hidden = YES;
        _secondaryChatTableView.hidden = NO;
        _secondaryComposerBar.hidden = NO;

        CGFloat compH = 52.0 + safe.bottom;
        _secondaryComposerBar.frame = CGRectMake(0, h - compH, w, compH);
        _secondaryComposerSendBtn.frame = CGRectMake(w - 62.0, 8.0, 52.0, 34.0);
        _secondaryComposerField.frame = CGRectMake(12.0, 8.0, w - 82.0, 34.0);

        _secondaryChatTableView.frame = CGRectMake(0, topBarH, w, h - topBarH - compH);
    }
}

#pragma mark - Data Loading & Sync

- (void)reloadAllData {
    NSString *query = _headerSearchField.text;
    _threads = [[CTDOCoreBridge shared] listThreadsForSlot:_activeSlot
                                                filterMode:_activeFilterMode
                                               searchQuery:query];

    // Update unread badge on Tin nhắn tab
    NSArray<NSDictionary *> *allThreads = [[CTDOCoreBridge shared] listThreadsForSlot:_activeSlot
                                                                           filterMode:0
                                                                          searchQuery:nil];
    NSInteger totalUnread = 0;
    for (NSDictionary *t in allThreads) {
        totalUnread += [t[@"unread_count"] integerValue];
    }
    if (totalUnread > 0) {
        _msgTabBadge.hidden = NO;
        _msgTabBadge.text = (totalUnread > 5) ? @"5+" : [NSString stringWithFormat:@"%ld", (long)totalUnread];
    } else {
        _msgTabBadge.hidden = YES;
    }

    if (_primaryThreadId.length == 0 && _threads.count > 0) {
        _primaryThreadId = _threads[0][@"id"] ?: @"";
    }
    if (_secondaryThreadId.length == 0 && _threads.count > 1) {
        _secondaryThreadId = _threads[1][@"id"] ?: @"";
    } else if (_secondaryThreadId.length == 0 && _threads.count == 1) {
        _secondaryThreadId = _threads[0][@"id"] ?: @"";
    }

    // Contacts & Alphabetical grouping for Danh bạ
    _contacts = [[CTDOCoreBridge shared] listContactsForSlot:_activeSlot
                                                  filterType:_contactFilterType
                                                 searchQuery:query];
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *grouped = [NSMutableDictionary dictionary];
    for (NSDictionary *c in _contacts) {
        NSString *letter = c[@"section_letter"] ?: @"#";
        if (!grouped[letter]) {
            grouped[letter] = [NSMutableArray array];
        }
        [grouped[letter] addObject:c];
    }
    _contactSections = grouped;
    _contactSectionTitles = [[grouped allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    // Primary & Secondary Chat Messages
    if (_primaryThreadId.length > 0) {
        _primaryMessages = [[CTDOCoreBridge shared] getMessagesForSlot:_activeSlot threadId:_primaryThreadId];
        NSDictionary *t = [self threadById:_primaryThreadId];
        _chatTitleLabel.text = t[@"name"] ?: @"Trò chuyện";
        BOOL isGroup = [t[@"is_group"] boolValue];
        NSInteger mCount = [t[@"total_members"] integerValue];
        if (isGroup && mCount > 0) {
            _chatSubtitleLabel.text = [NSString stringWithFormat:@"%ld thành viên", (long)mCount];
        } else if ([t[@"is_cloud"] boolValue] || [t[@"name"] isEqualToString:@"My Documents"]) {
            _chatSubtitleLabel.text = @"Lưu trữ các tin nhắn quan trọng";
        } else {
            _chatSubtitleLabel.text = @"Truy cập vừa xong";
        }
    } else {
        _primaryMessages = @[];
        _chatTitleLabel.text = @"Zalo";
        _chatSubtitleLabel.text = @"Chọn cuộc trò chuyện để bắt đầu";
    }

    if (_secondaryPaneMode == 1) {
        NSDictionary *slot1Auth = [[CTDOCoreBridge shared] authStateForSlot:1];
        if ([slot1Auth[@"authenticated"] boolValue]) {
            NSArray<NSDictionary *> *slot1Threads = [[CTDOCoreBridge shared] listThreadsForSlot:1 filterMode:0 searchQuery:nil];
            if (_slot1ThreadId.length == 0 && slot1Threads.count > 0) {
                _slot1ThreadId = slot1Threads[0][@"id"] ?: @"";
            }
            _secondaryMessages = (_slot1ThreadId.length > 0)
                ? [[CTDOCoreBridge shared] getMessagesForSlot:1 threadId:_slot1ThreadId]
                : @[];
            NSString *s1Name = slot1Auth[@"display_name"] ?: @"Tài khoản 2";
            _secondaryChatTitleLabel.text = [NSString stringWithFormat:@"Màn 2 • %@", s1Name];
            _secondaryChatSubtitleLabel.text = @"Tài khoản Zalo thứ 2 đang hoạt động độc lập";
        } else {
            _secondaryMessages = @[];
            _secondaryChatTitleLabel.text = @"Màn 2 • Tài khoản Zalo thứ 2";
            _secondaryChatSubtitleLabel.text = @"Quét mã QR hoặc nhập SĐT để đăng nhập song song";
        }
    } else if (_secondaryThreadId.length > 0) {
        _secondaryMessages = [[CTDOCoreBridge shared] getMessagesForSlot:_activeSlot threadId:_secondaryThreadId];
        NSDictionary *t2 = [self threadById:_secondaryThreadId];
        _secondaryChatTitleLabel.text = t2[@"name"] ?: @"Dual-Chat";
        _secondaryChatSubtitleLabel.text = @"Khung chat song song • iPhone Duo / iPad";
    } else {
        _secondaryMessages = @[];
    }

    [self refreshSecondaryPaneState];
    [_threadTableView reloadData];
    [_contactTableView reloadData];
    [_profileTableView reloadData];
    [_primaryChatTableView reloadData];
    [_secondaryChatTableView reloadData];
}

- (nullable NSDictionary *)threadById:(NSString *)threadId {
    for (NSDictionary *t in _threads) {
        if ([t[@"id"] isEqualToString:threadId]) return t;
    }
    NSArray<NSDictionary *> *all = [[CTDOCoreBridge shared] listThreadsForSlot:_activeSlot filterMode:0 searchQuery:nil];
    for (NSDictionary *t in all) {
        if ([t[@"id"] isEqualToString:threadId]) return t;
    }
    return nil;
}

- (void)triggerBackgroundSyncForCurrentSlot {
    NSInteger slot = _activeSlot;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[CTDOCoreBridge shared] refreshThreadsForSlot:slot];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.threadRefreshControl endRefreshing];
            [self reloadAllData];
        });
    });
}

- (void)onTapSyncPhoneMessages {
    if (_isPhoneSyncRunning) return;
    _isPhoneSyncRunning = YES;
    _phoneSyncProgressView.hidden = NO;
    [_phoneSyncProgressView setProgress:0.10f animated:YES];
    [_phoneSyncActionBtn setTitle:@"Đang tải" forState:UIControlStateNormal];
    _phoneSyncActionBtn.enabled = NO;
    _phoneSyncSubLabel.text = @"Đang gửi yêu cầu đồng bộ lên điện thoại & tải lịch sử...";

    [[CTDOCoreBridge shared] requestPhoneMessageSyncForSlot:_activeSlot
                                                 completion:^(__unused NSInteger syncedCount, NSString *statusText) {
        self.isPhoneSyncRunning = NO;
        [self.phoneSyncActionBtn setTitle:@"Đồng bộ" forState:UIControlStateNormal];
        self.phoneSyncActionBtn.enabled = YES;
        if (statusText.length > 0) {
            self.phoneSyncSubLabel.text = statusText;
        }
        [self reloadAllData];
    }];
}

- (void)onPullToRefreshThreads {
    [self onTapSyncPhoneMessages];
    [self.threadRefreshControl endRefreshing];
}

#pragma mark - Theme Application

- (void)applyTheme {
    CTDOTheme *theme = [CTDOTheme shared];
    self.view.backgroundColor = theme.bgPrimary;
    _leftMasterContainer.backgroundColor = theme.bgSecondary;
    _primaryChatContainer.backgroundColor = theme.bgChatCanvas;
    _secondaryChatContainer.backgroundColor = theme.bgChatCanvas;
    _secondaryLoginContainer.backgroundColor = theme.bgChatCanvas;

    _leftMasterContainer.layer.borderWidth = 0.5;
    _leftMasterContainer.layer.borderColor = theme.borderSubtle.CGColor;
    _secondaryChatContainer.layer.borderWidth = 0.5;
    _secondaryChatContainer.layer.borderColor = theme.borderSubtle.CGColor;

    // Sub-Header (Ưu tiên | Khác)
    _msgSubHeaderView.backgroundColor = theme.bgSecondary;
    _subHeaderBottomLine.backgroundColor = theme.borderSubtle;
    UIColor *activeTabColor = (theme.mode == CTDOThemeModeZaloLight) ? [CTDOTheme colorFromHex:@"#141415"] : theme.textPrimary;
    _subHeaderIndicator.backgroundColor = activeTabColor;

    [_uuTienTabBtn setTitleColor:(_activeFilterMode == 0 ? activeTabColor : theme.textSecondary) forState:UIControlStateNormal];
    _uuTienTabBtn.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:(_activeFilterMode == 0 ? UIFontWeightBold : UIFontWeightMedium)];

    [_khacTabBtn setTitleColor:(_activeFilterMode == 1 ? activeTabColor : theme.textSecondary) forState:UIControlStateNormal];
    _khacTabBtn.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:(_activeFilterMode == 1 ? UIFontWeightBold : UIFontWeightMedium)];

    // Phone Sync Bar
    _phoneSyncBannerView.backgroundColor = (theme.mode == CTDOThemeModeZaloLight)
        ? [CTDOTheme colorFromHex:@"#F0F7FF"]
        : theme.bgElevated;
    _phoneSyncTitleLabel.textColor = theme.textPrimary;
    _phoneSyncSubLabel.textColor = theme.textSecondary;
    _phoneSyncBottomLine.backgroundColor = theme.borderSubtle;
    _phoneSyncIconView.image = [CTDOIconRenderer phoneSyncIconWithSize:20.0 color:theme.accentPrimary];

    // Contact Sub-Header (Bạn bè | Nhóm | OA)
    _contactSubHeaderView.backgroundColor = theme.bgSecondary;
    _contactSubIndicator.backgroundColor = activeTabColor;
    NSArray<UIButton *> *cBtns = @[_contactSubBtn0, _contactSubBtn1, _contactSubBtn2];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *b = cBtns[i];
        BOOL sel = (i == _contactFilterType);
        [b setTitleColor:(sel ? activeTabColor : theme.textSecondary) forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:(sel ? UIFontWeightBold : UIFontWeightMedium)];
    }

    // TableViews
    _threadTableView.backgroundColor = theme.bgSecondary;
    _contactTableView.backgroundColor = theme.bgSecondary;
    _profileTableView.backgroundColor = theme.bgPrimary;
    _primaryChatTableView.backgroundColor = theme.bgChatCanvas;
    _secondaryChatTableView.backgroundColor = theme.bgChatCanvas;

    // Bottom TabBar
    _bottomTabBar.backgroundColor = theme.bgSecondary;
    _bottomTabTopLine.backgroundColor = theme.borderSubtle;
    UIColor *tabSelColor = [CTDOTheme colorFromHex:@"#0068FF"];
    UIColor *tabNormalColor = theme.textSecondary;
    for (NSInteger i = 0; i < 5; i++) {
        BOOL sel = (i == _activeBottomTab);
        _bottomTabIcons[i].image = [CTDOIconRenderer tabIconForIndex:i selected:sel];
        _bottomTabLabels[i].textColor = sel ? tabSelColor : tabNormalColor;
        _bottomTabLabels[i].font = [UIFont systemFontOfSize:10.5 weight:(sel ? UIFontWeightSemibold : UIFontWeightRegular)];
    }

    // Composer Bars
    _composerBar.backgroundColor = theme.bgSecondary;
    _composerBar.layer.borderWidth = 0.5;
    _composerBar.layer.borderColor = theme.borderSubtle.CGColor;
    _composerTextField.textColor = theme.textPrimary;
    _composerSendBtn.backgroundColor = theme.accentPrimary;
    [_composerSendBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    _secondaryComposerBar.backgroundColor = theme.bgSecondary;
    _secondaryComposerBar.layer.borderWidth = 0.5;
    _secondaryComposerBar.layer.borderColor = theme.borderSubtle.CGColor;
    _secondaryComposerField.textColor = theme.textPrimary;
    _secondaryComposerSendBtn.backgroundColor = theme.accentPrimary;
    [_secondaryComposerSendBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    _replyBannerView.backgroundColor = theme.bgElevated;
    _replyBannerLabel.textColor = theme.textSecondary;

    [_threadTableView reloadData];
    [_contactTableView reloadData];
    [_profileTableView reloadData];
    [_primaryChatTableView reloadData];
    [_secondaryChatTableView reloadData];
    [self.view setNeedsLayout];
}

#pragma mark - Navigation & Header Actions

- (void)onTapBottomTab:(UIButton *)sender {
    _activeBottomTab = sender.tag;
    _showingSettingsSubscreen = NO;
    [self applyTheme];
    [self.view setNeedsLayout];
}

- (void)onTapUuTienTab {
    _activeFilterMode = 0;
    [self reloadAllData];
    [self applyTheme];
}

- (void)onTapKhacTab {
    _activeFilterMode = 1;
    [self reloadAllData];
    [self applyTheme];
}

- (void)onTapContactSubTab:(UIButton *)sender {
    _contactFilterType = sender.tag;
    [self reloadAllData];
    [self applyTheme];
}

- (void)onTapHeaderBack {
    if (_showingSettingsSubscreen) {
        _showingSettingsSubscreen = NO;
        [self applyTheme];
        [self.view setNeedsLayout];
    }
}

- (void)onTapHeaderRight1 {
    if (_activeBottomTab == 4 && !_showingSettingsSubscreen) {
        // Gear icon on Cá nhân -> Open Cài đặt (ref5.png)
        _showingSettingsSubscreen = YES;
        [self applyTheme];
        [self.view setNeedsLayout];
        return;
    }
    if (_activeBottomTab == 0) {
        // QR / Sync button on Tin nhắn
        [self onTapSyncPhoneMessages];
    }
}

- (void)onTapHeaderRight2 {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"📲 Đồng bộ tin nhắn từ điện thoại"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [self onTapSyncPhoneMessages];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"👤 Đăng nhập / Mở Tài khoản 2 (Màn 2)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [self switchToSecondAccountFlow];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"📁 Mở My Documents (Lưu trữ đám mây)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSDictionary *auth = [[CTDOCoreBridge shared] authStateForSlot:self.activeSlot];
        NSString *s2m = auth[@"send2me_id"];
        [self openThreadId:(s2m.length > 0 ? s2m : @"cloud_self")];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🎨 Đổi giao diện (Sáng / Tối / OLED)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [[CTDOTheme shared] cycleTheme];
        [self applyTheme];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = _headerRightBtn2;
    sheet.popoverPresentationController.sourceRect = _headerRightBtn2.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openThreadId:(NSString *)threadId {
    if (threadId.length == 0) return;
    _primaryThreadId = [threadId copy];
    if (_currentDeviceClass == CTDODeviceClassiPhone) {
        _compactShowingChatDetail = YES;
    }
    [self reloadAllData];
    [self.view setNeedsLayout];
    [self scrollToBottomOfTableView:_primaryChatTableView];
}

- (void)onTapChatBack {
    _compactShowingChatDetail = NO;
    [self.view setNeedsLayout];
}

- (void)onTapVoiceCall {
    NSDictionary *t = [self threadById:_primaryThreadId];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Cuộc gọi thoại Zalo"
                                                                message:[NSString stringWithFormat:@"Đang kết nối cuộc gọi thoại tới %@...", t[@"name"] ?: @"đối tác"]
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kết thúc" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)onTapVideoCall {
    NSDictionary *t = [self threadById:_primaryThreadId];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Cuộc gọi Video Zalo"
                                                                message:[NSString stringWithFormat:@"Đang kết nối cuộc gọi video tới %@...", t[@"name"] ?: @"đối tác"]
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kết thúc" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)onTapChatMenu {
    NSDictionary *t = [self threadById:_primaryThreadId];
    if (!t) return;
    BOOL pinned = [t[@"is_pinned"] boolValue];
    BOOL muted = [t[@"is_muted"] boolValue];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:t[@"name"]
                                                                   message:@"Tùy chọn cuộc trò chuyện"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:(pinned ? @"Bỏ ghim hội thoại" : @"Ghim hội thoại")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:self.primaryThreadId action:1];
        [self reloadAllData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:(muted ? @"Bật thông báo" : @"Tắt thông báo")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [[CTDOCoreBridge shared] performThreadActionForSlot:self.activeSlot threadId:self.primaryThreadId action:2];
        [self reloadAllData];
    }]];
    if (_currentDeviceClass != CTDODeviceClassiPhone) {
        [sheet addAction:[UIAlertAction actionWithTitle:(_dualChatEnabled ? @"Tắt khung chat song song (Dual-Chat)" : @"Bật khung chat song song (Dual-Chat)")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            self.dualChatEnabled = !self.dualChatEnabled;
            [self.view setNeedsLayout];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = _chatMenuBtn;
    sheet.popoverPresentationController.sourceRect = _chatMenuBtn.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)onSearchFieldChanged:(__unused UITextField *)sender {
    [self reloadAllData];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _headerSearchField) {
        [textField resignFirstResponder];
        [self reloadAllData];
        return YES;
    }
    if (textField == _composerTextField) {
        [self onSendPrimaryMessage];
        return YES;
    }
    if (textField == _secondaryComposerField) {
        [self onSendSecondaryMessage];
        return YES;
    }
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Messaging & Scheduling

- (void)onSendPrimaryMessage {
    NSString *text = [_composerTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0 || _primaryThreadId.length == 0) return;

    _primaryMessages = [[CTDOCoreBridge shared] sendMessageForSlot:_activeSlot
                                                          threadId:_primaryThreadId
                                                           content:text
                                                      replyToMsgId:_replyTargetMsgId];
    _composerTextField.text = @"";
    [self onCancelReply];
    [self reloadAllData];
    [self scrollToBottomOfTableView:_primaryChatTableView];
}

- (void)onSendSecondaryMessage {
    NSString *text = [_secondaryComposerField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    NSInteger targetSlot = (_secondaryPaneMode == 1) ? 1 : _activeSlot;
    NSString *targetTid = (_secondaryPaneMode == 1) ? _slot1ThreadId : _secondaryThreadId;
    if (targetTid.length == 0) return;

    _secondaryMessages = [[CTDOCoreBridge shared] sendMessageForSlot:targetSlot
                                                            threadId:targetTid
                                                             content:text
                                                        replyToMsgId:nil];
    _secondaryComposerField.text = @"";
    [self reloadAllData];
    [self scrollToBottomOfTableView:_secondaryChatTableView];
}

- (void)onCancelReply {
    _replyTargetMsgId = nil;
    _replyTargetPreview = nil;
    _replyBannerView.hidden = YES;
    [self.view setNeedsLayout];
}

- (void)onTapScheduleQuickMessage {
    if (_primaryThreadId.length == 0) return;
    NSString *draft = [_composerTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *msgContent = draft.length > 0 ? draft : @"[Hẹn giờ tự động] Nhắc lịch họp từ Zalo iOS Native";
    int64_t deliverAt = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000.0) + 10000;
    [[CTDOCoreBridge shared] scheduleMessageForSlot:_activeSlot
                                           threadId:_primaryThreadId
                                            content:msgContent
                                        deliverAtMs:deliverAt];
    _composerTextField.text = @"";

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Đã hẹn giờ gửi tin nhắn"
                                                                message:@"Tin nhắn sẽ tự động gửi sau 10 giây."
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)onScheduleTimerTick {
    NSArray *fired = [[CTDOCoreBridge shared] pollDueScheduledMessages];
    if (fired.count > 0) {
        [self reloadAllData];
    }
}

- (void)scrollToBottomOfTableView:(UITableView *)tv {
    NSInteger rows = [tv numberOfRowsInSection:0];
    if (rows > 0) {
        [tv scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:rows - 1 inSection:0]
                  atScrollPosition:UITableViewScrollPositionBottom
                          animated:YES];
    }
}

#pragma mark - QR & Password Authentication Flow (Màn 1 & Màn 2)

- (void)switchToSecondAccountFlow {
    if (_currentDeviceClass != CTDODeviceClassiPhone) {
        _dualChatEnabled = YES;
        _secondaryPaneMode = 1;
        _secondaryPaneModeSegment.selectedSegmentIndex = 1;
        [self onSecondaryPaneModeChanged:_secondaryPaneModeSegment];
    } else {
        _activeSlot = (_activeSlot == 0) ? 1 : 0;
        [self reloadAllData];
        [self refreshAuthOverlayState];
        NSDictionary *auth = [[CTDOCoreBridge shared] authStateForSlot:_activeSlot];
        if (![auth[@"authenticated"] boolValue]) {
            [self onTapStartQRLogin];
        }
    }
}

- (void)onSecondaryPaneModeChanged:(UISegmentedControl *)sender {
    _secondaryPaneMode = sender.selectedSegmentIndex;
    if (_secondaryPaneMode == 1) {
        NSDictionary *auth1 = [[CTDOCoreBridge shared] authStateForSlot:1];
        if (![auth1[@"authenticated"] boolValue]) {
            NSString *qrB64 = auth1[@"qr_image_base64"];
            if (![qrB64 isKindOfClass:[NSString class]] || qrB64.length == 0) {
                [[CTDOCoreBridge shared] startQRLoginForSlot:1];
            }
            [self ensureQRPollTimerRunning];
        }
    }
    [self refreshSecondaryPaneState];
    [self reloadAllData];
    [self.view setNeedsLayout];
}

- (void)onSecondaryLoginTabChanged:(UISegmentedControl *)sender {
    _secondaryLoginAuthTab = sender.selectedSegmentIndex;
    if (_secondaryLoginAuthTab == 0) {
        [_secondaryQrActionBtn setTitle:@"Làm mới mã QR Màn 2" forState:UIControlStateNormal];
    } else {
        [_secondaryQrActionBtn setTitle:@"Đăng nhập Màn 2 bằng mật khẩu" forState:UIControlStateNormal];
    }
    [self.view setNeedsLayout];
}

- (void)onTapSecondaryLoginAction {
    if (_secondaryLoginAuthTab == 0) {
        NSDictionary *st = [[CTDOCoreBridge shared] startQRLoginForSlot:1];
        _secondaryQrStatusLabel.text = st[@"status_text"] ?: @"Đang lấy mã QR Màn 2...";
        [self ensureQRPollTimerRunning];
    } else {
        NSString *ph = _secondaryPhoneField.text ?: @"";
        NSString *pw = _secondaryPassField.text ?: @"";
        if (ph.length == 0 || pw.length == 0) {
            _secondaryQrStatusLabel.text = @"Vui lòng nhập đầy đủ SĐT và Mật khẩu Zalo cho Màn 2.";
            return;
        }
        [_secondaryPhoneField resignFirstResponder];
        [_secondaryPassField resignFirstResponder];
        NSDictionary *st = [[CTDOCoreBridge shared] loginPasswordForSlot:1 phone:ph password:pw];
        _secondaryQrStatusLabel.text = st[@"status_text"] ?: @"Đang xác thực SĐT & Mật khẩu...";
        [self ensureQRPollTimerRunning];
    }
}

- (void)onTapSecondaryBackToDual {
    _secondaryPaneMode = 0;
    _secondaryPaneModeSegment.selectedSegmentIndex = 0;
    [self reloadAllData];
    [self.view setNeedsLayout];
}

- (void)refreshSecondaryPaneState {
    NSDictionary *auth1 = [[CTDOCoreBridge shared] authStateForSlot:1];
    NSString *qrB64 = auth1[@"qr_image_base64"];
    if ([qrB64 isKindOfClass:[NSString class]] && qrB64.length > 0) {
        UIImage *img = [CTDOIconRenderer imageFromBase64String:qrB64];
        if (img) _secondaryQrImageView.image = img;
    } else {
        NSString *qrPayload = auth1[@"qr_payload"];
        if ([qrPayload isKindOfClass:[NSString class]] && qrPayload.length > 0) {
            _secondaryQrImageView.image = [CTDOIconRenderer qrCodeImageForString:qrPayload size:360.0];
        }
    }
    _secondaryQrStatusLabel.text = auth1[@"status_text"] ?: @"Mở Zalo trên điện thoại → Quét mã QR để đăng nhập Màn 2.";
}

- (void)onLoginModeTabChanged:(UISegmentedControl *)sender {
    _loginAuthTab = sender.selectedSegmentIndex;
    if (_loginAuthTab == 0) {
        [_qrReloadBtn setTitle:@"Lấy mã QR mới" forState:UIControlStateNormal];
    } else {
        [_qrReloadBtn setTitle:@"Đăng nhập bằng SĐT & Mật khẩu" forState:UIControlStateNormal];
    }
    [self.view setNeedsLayout];
}

- (void)onTapPrimaryLoginAction {
    if (_loginAuthTab == 0) {
        [self onTapStartQRLogin];
    } else {
        NSString *ph = _loginPhoneField.text ?: @"";
        NSString *pw = _loginPasswordField.text ?: @"";
        if (ph.length == 0 || pw.length == 0) {
            _qrStatusLabel.text = @"Vui lòng nhập đầy đủ Số điện thoại và Mật khẩu Zalo.";
            return;
        }
        [_loginPhoneField resignFirstResponder];
        [_loginPasswordField resignFirstResponder];
        NSDictionary *state = [[CTDOCoreBridge shared] loginPasswordForSlot:_activeSlot phone:ph password:pw];
        _qrStatusLabel.text = state[@"status_text"] ?: @"Đang xác thực SĐT & Mật khẩu...";
        [self ensureQRPollTimerRunning];
    }
}

- (void)onTapBackToAccount1 {
    _activeSlot = 0;
    [self reloadAllData];
    [self refreshAuthOverlayState];
}

- (void)refreshAuthOverlayState {
    NSDictionary *auth = [[CTDOCoreBridge shared] authStateForSlot:_activeSlot];
    BOOL isAuthed = [auth[@"authenticated"] boolValue];
    _loginOverlay.hidden = isAuthed;

    NSDictionary *slot0Auth = [[CTDOCoreBridge shared] authStateForSlot:0];
    NSString *s0Name = slot0Auth[@"display_name"] ?: @"Tài khoản 1";
    [_loginBackToSlot0Btn setTitle:[NSString stringWithFormat:@"← Quay lại Tài khoản 1 (%@)", s0Name] forState:UIControlStateNormal];

    if (_activeSlot == 1) {
        _loginSlotBadgeLabel.text = @"MÀN 2 • ĐĂNG NHẬP TÀI KHOẢN ZALO THỨ 2";
        _loginTitleLabel.text = @"Đăng nhập Tài khoản Zalo 2";
    } else {
        _loginSlotBadgeLabel.text = @"ZALO NATIVE iOS • ĐỒNG BỘ ĐIỆN THOẠI";
        _loginTitleLabel.text = @"Đăng nhập Zalo qua mã QR";
    }

    if (!isAuthed) {
        NSString *qrB64 = auth[@"qr_image_base64"];
        if ([qrB64 isKindOfClass:[NSString class]] && qrB64.length > 0) {
            UIImage *img = [CTDOIconRenderer imageFromBase64String:qrB64];
            if (img) _qrImageView.image = img;
        } else {
            NSString *qrPayload = auth[@"qr_payload"];
            if ([qrPayload isKindOfClass:[NSString class]] && qrPayload.length > 0) {
                _qrImageView.image = [CTDOIconRenderer qrCodeImageForString:qrPayload size:380.0];
            }
        }
        _qrStatusLabel.text = auth[@"status_text"] ?: @"Đang lấy mã QR thực tế từ máy chủ Zalo...";
    }
    [self.view setNeedsLayout];
}

- (void)ensureQRPollTimerRunning {
    [_qrPollTimer invalidate];
    _qrPollTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                    target:self
                                                  selector:@selector(onQRPollTimerTick)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)onTapStartQRLogin {
    NSDictionary *state = [[CTDOCoreBridge shared] startQRLoginForSlot:_activeSlot];
    _qrStatusLabel.text = state[@"status_text"] ?: @"Đang kết nối tới máy chủ Zalo...";
    [self ensureQRPollTimerRunning];
}

- (void)onQRPollTimerTick {
    [self refreshAuthOverlayState];
    [self refreshSecondaryPaneState];

    NSDictionary *authActive = [[CTDOCoreBridge shared] authStateForSlot:_activeSlot];
    NSDictionary *auth1 = [[CTDOCoreBridge shared] authStateForSlot:1];
    BOOL activeAuthed = [authActive[@"authenticated"] boolValue];
    BOOL slot1Authed = [auth1[@"authenticated"] boolValue];

    if (activeAuthed && (_secondaryPaneMode == 0 || slot1Authed)) {
        [_qrPollTimer invalidate];
        _qrPollTimer = nil;
        _loginOverlay.hidden = YES;
        [self reloadAllData];
        [self.view setNeedsLayout];
    }
}

- (void)onTapLogoutButton {
    [[CTDOCoreBridge shared] logoutSlot:_activeSlot];
    _showingSettingsSubscreen = NO;
    [self reloadAllData];
    [self refreshAuthOverlayState];
    [self onTapStartQRLogin];
}

#pragma mark - Profile & Settings Data Model (ref4.png & ref5.png)

- (NSArray<NSArray<NSDictionary *> *> *)profileMenuSections {
    if (_activeBottomTab == 2) {
        // Khám phá
        return @[
            @[
                @{@"icon": @"game", @"color": @"#0068FF", @"title": @"Mini Apps", @"subtitle": @"Tiện ích Zalo trên iPhone & iPad"},
                @{@"icon": @"video", @"color": @"#F97316", @"title": @"Zalo Video", @"subtitle": @"Video ngắn xu hướng"},
                @{@"icon": @"qr_wallet", @"color": @"#10B981", @"title": @"Quét mã QR", @"subtitle": @"Đăng nhập và thanh toán nhanh"},
            ]
        ];
    }
    if (_activeBottomTab == 3) {
        // Tường nhà
        return @[
            @[
                @{@"icon": @"journal", @"color": @"#0068FF", @"title": @"Nhật ký bạn bè", @"subtitle": @"Cập nhật khoảnh khắc mới nhất"},
                @{@"icon": @"style", @"color": @"#EC4899", @"title": @"Khoảnh khắc", @"subtitle": @"Chia sẻ câu chuyện 24 giờ"},
            ]
        ];
    }
    if (_showingSettingsSubscreen) {
        // Cài đặt screen matching ref5.png
        return @[
            @[
                @{@"icon": @"security", @"color": @"#0068FF", @"title": @"Tài khoản và bảo mật", @"action": @"security"},
                @{@"icon": @"privacy", @"color": @"#0068FF", @"title": @"Quyền riêng tư", @"action": @"privacy"},
            ],
            @[
                @{@"icon": @"storage", @"color": @"#0068FF", @"title": @"Dữ liệu trên máy", @"action": @"storage"},
                @{@"icon": @"backup", @"color": @"#0068FF", @"title": @"Sao lưu và khôi phục", @"action": @"backup"},
            ],
            @[
                @{@"icon": @"notif", @"color": @"#0068FF", @"title": @"Thông báo", @"action": @"notif"},
                @{@"icon": @"msg", @"color": @"#0068FF", @"title": @"Tin nhắn", @"action": @"msg"},
                @{@"icon": @"call", @"color": @"#0068FF", @"title": @"Cuộc gọi", @"action": @"call"},
                @{@"icon": @"journal", @"color": @"#0068FF", @"title": @"Nhật ký", @"action": @"journal"},
                @{@"icon": @"contacts", @"color": @"#0068FF", @"title": @"Danh bạ", @"action": @"contacts"},
                @{@"icon": @"theme", @"color": @"#0068FF", @"title": @"Giao diện và ngôn ngữ", @"action": @"theme"},
            ],
            @[
                @{@"icon": @"info", @"color": @"#0068FF", @"title": @"Thông tin về Zalo", @"action": @"github_update"},
                @{@"icon": @"help", @"color": @"#0068FF", @"title": @"Liên hệ hỗ trợ", @"action": @"help"},
                @{@"icon": @"switch_acc", @"color": @"#0068FF", @"title": @"Chuyển tài khoản (Màn 2)", @"action": @"switch_acc"},
            ]
        ];
    }

    // Cá nhân screen matching ref4.png + Đồng bộ tin nhắn từ điện thoại
    return @[
        @[
            @{@"icon": @"cloud", @"color": @"#0068FF", @"title": @"zCloud", @"subtitle": @"Không gian lưu trữ dữ liệu trên đám mây", @"action": @"cloud"},
            @{@"icon": @"sync_phone", @"color": @"#0068FF", @"title": @"Đồng bộ tin nhắn từ điện thoại", @"subtitle": @"Gửi yêu cầu đồng bộ & tải lịch sử chat mới nhất", @"action": @"sync_phone"},
            @{@"icon": @"style", @"color": @"#0068FF", @"title": @"zStyle – Nổi bật trên Zalo", @"subtitle": @"Hình nền và nhạc cho cuộc gọi Zalo", @"action": @"style"},
        ],
        @[
            @{@"icon": @"mydocs", @"color": @"#0068FF", @"title": @"My Documents", @"subtitle": @"Lưu trữ các tin nhắn quan trọng", @"action": @"open_mydocs"},
            @{@"icon": @"storage", @"color": @"#0068FF", @"title": @"Dữ liệu trên máy", @"subtitle": @"Quản lý dữ liệu Zalo của bạn", @"action": @"storage"},
            @{@"icon": @"qr_wallet", @"color": @"#0068FF", @"title": @"Ví QR", @"subtitle": @"Lưu trữ và xuất trình các mã QR quan trọng", @"action": @"qr_wallet"},
        ],
        @[
            @{@"icon": @"security", @"color": @"#0068FF", @"title": @"Tài khoản và bảo mật", @"action": @"security"},
            @{@"icon": @"privacy", @"color": @"#0068FF", @"title": @"Quyền riêng tư", @"action": @"privacy"},
            @{@"icon": @"switch_acc", @"color": @"#0068FF", @"title": @"Đăng nhập / Chuyển Tài khoản 2 (Màn 2)", @"action": @"switch_acc"},
        ]
    ];
}

#pragma mark - UITableViewDataSource & UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == _threadTableView) return 1;
    if (tableView == _primaryChatTableView || tableView == _secondaryChatTableView) return 1;
    if (tableView == _contactTableView) {
        if (_contactFilterType == 0) {
            // Section 0: Lời mời kết bạn + Danh bạ máy shortcuts; Sections 1..N: Alphabetical
            return 1 + _contactSectionTitles.count;
        }
        return 1;
    }
    if (tableView == _profileTableView) {
        NSArray *menuSecs = [self profileMenuSections];
        if (_activeBottomTab == 4 && !_showingSettingsSubscreen) {
            return 1 + menuSecs.count; // Section 0 = User Profile Card
        }
        if (_activeBottomTab == 4 && _showingSettingsSubscreen) {
            return menuSecs.count + 1; // Last Section = Logout Pill Button
        }
        return menuSecs.count;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == _threadTableView) {
        return _threads.count;
    }
    if (tableView == _primaryChatTableView) {
        return _primaryMessages.count;
    }
    if (tableView == _secondaryChatTableView) {
        return _secondaryMessages.count;
    }
    if (tableView == _contactTableView) {
        if (_contactFilterType == 0) {
            if (section == 0) return 2; // Lời mời kết bạn + Danh bạ máy
            NSString *letter = _contactSectionTitles[section - 1];
            return [_contactSections[letter] count];
        }
        return _contacts.count;
    }
    if (tableView == _profileTableView) {
        NSArray *menuSecs = [self profileMenuSections];
        if (_activeBottomTab == 4 && !_showingSettingsSubscreen) {
            if (section == 0) return 1; // User Profile Card
            return [menuSecs[section - 1] count];
        }
        if (_activeBottomTab == 4 && _showingSettingsSubscreen) {
            if (section == (NSInteger)menuSecs.count) return 1; // Logout Row
            return [menuSecs[section] count];
        }
        return [menuSecs[section] count];
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == _threadTableView) {
        return 74.0;
    }
    if (tableView == _primaryChatTableView) {
        NSDictionary *msg = _primaryMessages[indexPath.row];
        return [CTDOMessageCell heightForMessage:msg maxWidth:tableView.bounds.size.width];
    }
    if (tableView == _secondaryChatTableView) {
        NSDictionary *msg = _secondaryMessages[indexPath.row];
        return [CTDOMessageCell heightForMessage:msg maxWidth:tableView.bounds.size.width];
    }
    if (tableView == _contactTableView) {
        if (_contactFilterType == 0 && indexPath.section == 0) return 60.0;
        return 66.0;
    }
    if (tableView == _profileTableView) {
        if (_activeBottomTab == 4 && !_showingSettingsSubscreen && indexPath.section == 0) {
            return 84.0; // Profile header row (ref4.png)
        }
        if (_activeBottomTab == 4 && _showingSettingsSubscreen && indexPath.section == (NSInteger)[[self profileMenuSections] count]) {
            return 72.0; // Logout button row (ref5.png)
        }
        NSArray *menuSecs = [self profileMenuSections];
        NSInteger secIdx = (_activeBottomTab == 4 && !_showingSettingsSubscreen) ? (indexPath.section - 1) : indexPath.section;
        NSDictionary *item = menuSecs[secIdx][indexPath.row];
        NSString *sub = item[@"subtitle"];
        return (sub.length > 0) ? 68.0 : 54.0;
    }
    return 56.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (tableView == _contactTableView && _contactFilterType == 0 && section > 0) {
        return 28.0;
    }
    if (tableView == _profileTableView && section > 0) {
        return 8.0;
    }
    return 0.0;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    CTDOTheme *theme = [CTDOTheme shared];
    if (tableView == _contactTableView && _contactFilterType == 0 && section > 0) {
        UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 28.0)];
        hdr.backgroundColor = theme.bgSecondary;
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 4.0, 100.0, 20.0)];
        lbl.text = _contactSectionTitles[section - 1];
        lbl.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
        lbl.textColor = theme.textPrimary;
        [hdr addSubview:lbl];
        return hdr;
    }
    if (tableView == _profileTableView && section > 0) {
        UIView *spacer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 8.0)];
        spacer.backgroundColor = theme.bgPrimary;
        return spacer;
    }
    return nil;
}

- (nullable NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (tableView == _contactTableView && _contactFilterType == 0) {
        return _contactSectionTitles;
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if (tableView == _contactTableView && _contactFilterType == 0) {
        return index + 1;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CTDOTheme *theme = [CTDOTheme shared];

    // 1. Thread List (ref1.png & ref2.png)
    if (tableView == _threadTableView) {
        CTDOThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CTDOThreadCell" forIndexPath:indexPath];
        NSDictionary *thread = _threads[indexPath.row];
        BOOL isSelected = (_currentDeviceClass != CTDODeviceClassiPhone) && [thread[@"id"] isEqualToString:_primaryThreadId];
        __weak typeof(tableView) weakTV = tableView;
        [cell configureWithThread:thread isSelected:isSelected onAvatarLoaded:^{
            [weakTV reloadData];
        }];
        return cell;
    }

    // 2. Primary Chat Messages
    if (tableView == _primaryChatTableView) {
        CTDOMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CTDOMessageCell" forIndexPath:indexPath];
        NSDictionary *msg = _primaryMessages[indexPath.row];
        [cell configureWithMessage:msg maxWidth:tableView.bounds.size.width];
        return cell;
    }

    // 3. Secondary Dual-Chat Messages
    if (tableView == _secondaryChatTableView) {
        CTDOMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CTDOMessageCell2" forIndexPath:indexPath];
        NSDictionary *msg = _secondaryMessages[indexPath.row];
        [cell configureWithMessage:msg maxWidth:tableView.bounds.size.width];
        return cell;
    }

    // 4. Contacts Tab (ref3.png)
    if (tableView == _contactTableView) {
        if (_contactFilterType == 0 && indexPath.section == 0) {
            CTDOMenuCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CTDOMenuCell" forIndexPath:indexPath];
            if (indexPath.row == 0) {
                [cell configureWithIcon:@"switch_user" title:[NSString stringWithFormat:@"Lời mời kết bạn (%lu)", (unsigned long)MIN((NSUInteger)17, _contacts.count)] subtitle:nil showChevron:NO];
            } else {
                [cell configureWithIcon:@"folder" title:@"Danh bạ máy" subtitle:@"Các liên hệ có dùng Zalo" showChevron:NO];
            }
            return cell;
        }

        CTDOContactCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CTDOContactCell" forIndexPath:indexPath];
        NSDictionary *contact = nil;
        if (_contactFilterType == 0) {
            NSString *letter = _contactSectionTitles[indexPath.section - 1];
            contact = _contactSections[letter][indexPath.row];
        } else {
            contact = _contacts[indexPath.row];
        }
        __weak typeof(tableView) weakTV = tableView;
        [cell configureWithContact:contact onAvatarLoaded:^{
            [weakTV reloadData];
        }];
        return cell;
    }

    // 5. Profile & Settings Tab (ref4.png & ref5.png)
    if (tableView == _profileTableView) {
        // User Profile Card at top of Cá nhân (ref4.png)
        if (_activeBottomTab == 4 && !_showingSettingsSubscreen && indexPath.section == 0) {
            UITableViewCell *cardCell = [tableView dequeueReusableCellWithIdentifier:@"ProfileHeaderCell"];
            if (!cardCell) {
                cardCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ProfileHeaderCell"];
                cardCell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            for (UIView *sub in cardCell.contentView.subviews) [sub removeFromSuperview];
            cardCell.backgroundColor = theme.bgSecondary;
            cardCell.contentView.backgroundColor = theme.bgSecondary;

            NSDictionary *auth = [[CTDOCoreBridge shared] authStateForSlot:_activeSlot];
            NSString *userName = auth[@"display_name"] ?: @"Đỗ Trung Thành";
            NSString *avatarUrl = auth[@"avatar_url"];

            UIImageView *av = [[UIImageView alloc] initWithFrame:CGRectMake(16.0, 14.0, 56.0, 56.0)];
            av.layer.cornerRadius = 28.0;
            av.layer.masksToBounds = YES;
            __weak typeof(tableView) weakTV = tableView;
            av.image = [CTDOIconRenderer avatarForURL:avatarUrl
                                         fallbackName:userName
                                             colorHex:@"#0068FF"
                                                 size:56.0
                                         onCompletion:^{
                [weakTV reloadData];
            }];
            [cardCell.contentView addSubview:av];

            CGFloat w = cardCell.contentView.bounds.size.width > 120.0 ? cardCell.contentView.bounds.size.width : (tableView.bounds.size.width > 120.0 ? tableView.bounds.size.width : 390.0);
            UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(86.0, 30.0, w - 212.0, 24.0)];
            nameLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            nameLbl.text = [NSString stringWithFormat:@"%@  ›", userName];
            nameLbl.font = [UIFont systemFontOfSize:17.5 weight:UIFontWeightSemibold];
            nameLbl.textColor = theme.textPrimary;
            [cardCell.contentView addSubview:nameLbl];

            UILabel *statusPill = [[UILabel alloc] initWithFrame:CGRectMake(w - 118.0, 26.0, 102.0, 32.0)];
            statusPill.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            statusPill.text = @"✏️ Trạng thái...";
            statusPill.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
            statusPill.textAlignment = NSTextAlignmentCenter;
            statusPill.textColor = theme.textSecondary;
            statusPill.backgroundColor = theme.bgSecondary;
            statusPill.layer.cornerRadius = 16.0;
            statusPill.layer.borderWidth = 1.0;
            statusPill.layer.borderColor = theme.borderSubtle.CGColor;
            statusPill.layer.masksToBounds = YES;
            [cardCell.contentView addSubview:statusPill];

            return cardCell;
        }

        // Logout Pill Button at bottom of Cài đặt (ref5.png)
        NSArray *menuSecs = [self profileMenuSections];
        if (_activeBottomTab == 4 && _showingSettingsSubscreen && indexPath.section == (NSInteger)menuSecs.count) {
            UITableViewCell *logoutCell = [tableView dequeueReusableCellWithIdentifier:@"LogoutCell"];
            if (!logoutCell) {
                logoutCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LogoutCell"];
                logoutCell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            for (UIView *sub in logoutCell.contentView.subviews) [sub removeFromSuperview];
            logoutCell.backgroundColor = theme.bgPrimary;
            logoutCell.contentView.backgroundColor = theme.bgPrimary;

            CGFloat w = logoutCell.contentView.bounds.size.width > 120.0 ? logoutCell.contentView.bounds.size.width : (tableView.bounds.size.width > 120.0 ? tableView.bounds.size.width : 390.0);
            UIButton *logoutBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            logoutBtn.frame = CGRectMake(16.0, 12.0, w - 32.0, 48.0);
            logoutBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            logoutBtn.backgroundColor = (theme.mode == CTDOThemeModeZaloLight)
                ? [CTDOTheme colorFromHex:@"#E9EBED"]
                : theme.bgElevated;
            [logoutBtn setTitle:@"↪   Đăng xuất" forState:UIControlStateNormal];
            [logoutBtn setTitleColor:theme.textPrimary forState:UIControlStateNormal];
            logoutBtn.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
            logoutBtn.layer.cornerRadius = 24.0;
            [logoutBtn addTarget:self action:@selector(onTapLogoutButton) forControlEvents:UIControlEventTouchUpInside];
            [logoutCell.contentView addSubview:logoutBtn];
            return logoutCell;
        }

        CTDOMenuCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CTDOMenuCell" forIndexPath:indexPath];
        NSInteger secIdx = (_activeBottomTab == 4 && !_showingSettingsSubscreen) ? (indexPath.section - 1) : indexPath.section;
        NSDictionary *item = menuSecs[secIdx][indexPath.row];
        [cell configureWithIcon:(item[@"icon"] ?: @"info") title:item[@"title"] subtitle:item[@"subtitle"] showChevron:YES];
        return cell;
    }

    return [[UITableViewCell alloc] init];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (tableView == _threadTableView) {
        NSDictionary *thread = _threads[indexPath.row];
        NSString *tid = thread[@"id"] ?: @"";
        if (_currentDeviceClass != CTDODeviceClassiPhone && _dualChatEnabled && ![tid isEqualToString:_primaryThreadId]) {
            _secondaryThreadId = [_primaryThreadId copy];
        }
        [self openThreadId:tid];
        return;
    }

    if (tableView == _contactTableView) {
        if (_contactFilterType == 0 && indexPath.section == 0) return;
        NSDictionary *contact = nil;
        if (_contactFilterType == 0) {
            NSString *letter = _contactSectionTitles[indexPath.section - 1];
            contact = _contactSections[letter][indexPath.row];
        } else {
            contact = _contacts[indexPath.row];
        }
        NSString *cid = contact[@"id"] ?: @"";
        if (cid.length > 0) {
            _activeBottomTab = 0;
            [self openThreadId:cid];
            [self applyTheme];
        }
        return;
    }

    if (tableView == _profileTableView) {
        if (_activeBottomTab == 4 && !_showingSettingsSubscreen && indexPath.section == 0) return;
        NSArray *menuSecs = [self profileMenuSections];
        if (_activeBottomTab == 4 && _showingSettingsSubscreen && indexPath.section == (NSInteger)menuSecs.count) return;

        NSInteger secIdx = (_activeBottomTab == 4 && !_showingSettingsSubscreen) ? (indexPath.section - 1) : indexPath.section;
        NSDictionary *item = menuSecs[secIdx][indexPath.row];
        NSString *action = item[@"action"] ?: @"";

        if ([action isEqualToString:@"open_mydocs"]) {
            _activeBottomTab = 0;
            NSDictionary *auth = [[CTDOCoreBridge shared] authStateForSlot:_activeSlot];
            NSString *s2m = auth[@"send2me_id"];
            [self openThreadId:(s2m.length > 0 ? s2m : @"cloud_self")];
            [self applyTheme];
        } else if ([action isEqualToString:@"sync_phone"] || [action isEqualToString:@"backup"] || [action isEqualToString:@"cloud"]) {
            _activeBottomTab = 0;
            _showingSettingsSubscreen = NO;
            [self applyTheme];
            [self onTapSyncPhoneMessages];
        } else if ([action isEqualToString:@"theme"]) {
            [[CTDOTheme shared] cycleTheme];
            [self applyTheme];
        } else if ([action isEqualToString:@"github_update"]) {
            [[CTDOCoreBridge shared] checkGitHubLatestReleaseWithSimulateOldVersion:NO completion:^(NSDictionary *releaseInfo) {
                NSString *tag = releaseInfo[@"tag_name"] ?: @"v0.2.3";
                NSString *body = releaseInfo[@"body"] ?: @"Phiên bản mới nhất từ GitHub Releases.";
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Zalo iOS Native • %@", tag]
                                                                            message:body
                                                                     preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:ac animated:YES completion:nil];
            }];
        } else if ([action isEqualToString:@"switch_acc"]) {
            [self switchToSecondAccountFlow];
        }
        return;
    }

    if (tableView == _primaryChatTableView) {
        NSDictionary *msg = _primaryMessages[indexPath.row];
        NSString *mid = msg[@"id"] ?: @"";
        NSString *content = msg[@"content"] ?: @"";
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Tác vụ tin nhắn"
                                                                       message:content
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSString *emoji in @[@"❤️", @"👍", @"😆", @"😮", @"😢", @"😡"]) {
            [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Thả biểu cảm %@", emoji]
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(__unused UIAlertAction *a) {
                [[CTDOCoreBridge shared] reactMessageForSlot:self.activeSlot threadId:self.primaryThreadId msgId:mid emoji:emoji];
                [self reloadAllData];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Trả lời (Trích dẫn)"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *a) {
            self.replyTargetMsgId = mid;
            self.replyTargetPreview = content;
            self.replyBannerLabel.text = [NSString stringWithFormat:@"Đang trả lời: %@", content];
            self.replyBannerView.hidden = NO;
            [self.view setNeedsLayout];
            [self.composerTextField becomeFirstResponder];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        sheet.popoverPresentationController.sourceView = cell ?: tableView;
        sheet.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(0, 0, 100, 44);
        [self presentViewController:sheet animated:YES completion:nil];
    }
}

@end
