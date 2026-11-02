#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CTDOThemeMode) {
    CTDOThemeModeZaloDark = 0,
    CTDOThemeModeZaloLight = 1,
    CTDOThemeModeOLEDMidnight = 2
};

typedef NS_ENUM(NSInteger, CTDODeviceClass) {
    CTDODeviceClassiPhone = 0,
    CTDODeviceClassiPhoneDuo = 1,
    CTDODeviceClassiPad = 2
};

@interface CTDOTheme : NSObject
@property (nonatomic, assign) CTDOThemeMode mode;
@property (nonatomic, strong, readonly) UIColor *bgPrimary;
@property (nonatomic, strong, readonly) UIColor *bgSecondary;
@property (nonatomic, strong, readonly) UIColor *bgElevated;
@property (nonatomic, strong, readonly) UIColor *bgHeader;
@property (nonatomic, strong, readonly) UIColor *textPrimary;
@property (nonatomic, strong, readonly) UIColor *textSecondary;
@property (nonatomic, strong, readonly) UIColor *accentPrimary;
@property (nonatomic, strong, readonly) UIColor *accentOnline;
@property (nonatomic, strong, readonly) UIColor *bubbleSelf;
@property (nonatomic, strong, readonly) UIColor *bubblePartner;
@property (nonatomic, strong, readonly) UIColor *borderSubtle;
@property (nonatomic, strong, readonly) UIColor *dangerColor;
@property (nonatomic, strong, readonly) UIColor *warningColor;

+ (instancetype)shared;
- (void)cycleTheme;
- (NSString *)themeName;
- (NSString *)exportThemeJSON;
+ (UIColor *)colorFromHex:(NSString *)hexString;
@end

@interface CTDOIconRenderer : NSObject
+ (UIImage *)avatarWithInitials:(NSString *)initials
                       colorHex:(NSString *)colorHex
                           size:(CGFloat)size
                       isOnline:(BOOL)isOnline;
+ (UIImage *)qrCodeImageForString:(NSString *)content size:(CGFloat)size;
+ (nullable UIImage *)imageFromBase64String:(NSString *)base64String;
+ (UIImage *)appLogoWithSize:(CGFloat)size;
@end

@interface CTDOCoreBridge : NSObject
+ (instancetype)shared;
- (NSString *)versionString;

/// Hardware-truth device classification (iPhone vs iPhone Duo vs iPad).
- (CTDODeviceClass)hardwareDeviceClassForWindowSize:(CGSize)windowSize;
- (BOOL)isiPhoneDuoHardwareOrGeometry:(CGSize)windowSize;
- (NSString *)deviceHardwareName;

/// Real Zalo Authentication & QR Login (Zero fake data).
- (NSDictionary *)authStateForSlot:(NSInteger)slot;
- (NSDictionary *)startQRLoginForSlot:(NSInteger)slot;
- (NSDictionary *)loginPasswordForSlot:(NSInteger)slot
                                 phone:(NSString *)phone
                              password:(NSString *)password;
- (NSDictionary *)logoutSlot:(NSInteger)slot;
- (NSDictionary *)refreshThreadsForSlot:(NSInteger)slot;

/// Account & Thread Operations.
- (NSDictionary *)switchAccount:(NSInteger)slot;
- (NSArray<NSDictionary *> *)listThreadsForSlot:(NSInteger)slot
                                     filterMode:(NSInteger)filterMode
                                    searchQuery:(nullable NSString *)query;
- (NSArray<NSDictionary *> *)getMessagesForSlot:(NSInteger)slot
                                       threadId:(NSString *)threadId;
- (NSArray<NSDictionary *> *)sendMessageForSlot:(NSInteger)slot
                                       threadId:(NSString *)threadId
                                        content:(NSString *)content
                                   replyToMsgId:(nullable NSString *)replyToMsgId;
- (NSArray<NSDictionary *> *)reactMessageForSlot:(NSInteger)slot
                                        threadId:(NSString *)threadId
                                           msgId:(NSString *)msgId
                                           emoji:(NSString *)emoji;
- (NSArray<NSDictionary *> *)performThreadActionForSlot:(NSInteger)slot
                                               threadId:(NSString *)threadId
                                                 action:(NSInteger)action;

/// Scheduled Messages (#38) & Auto-Reply (#35).
- (NSArray<NSDictionary *> *)scheduleMessageForSlot:(NSInteger)slot
                                           threadId:(NSString *)threadId
                                            content:(NSString *)content
                                        deliverAtMs:(int64_t)deliverAtMs;
- (NSArray<NSDictionary *> *)listScheduledForSlot:(NSInteger)slot;
- (NSArray<NSDictionary *> *)cancelScheduledForSlot:(NSInteger)slot
                                            schedId:(int64_t)schedId;
- (NSArray<NSDictionary *> *)pollDueScheduledMessages;
- (NSArray<NSDictionary *> *)listAutoReplyRules;
- (NSArray<NSDictionary *> *)mutateAutoReplyOp:(NSInteger)op
                                   patternOrId:(NSString *)patternOrId
                                      response:(NSString *)response
                                     matchMode:(NSString *)matchMode;

/// Native CommonCrypto AES-CBC / MD5 Signkey & GitHub Releases Updater.
- (NSDictionary *)buildSignedRequestForService:(NSString *)service
                                        method:(NSString *)method
                                    jsonParams:(NSString *)jsonParams;
- (NSDictionary *)parseGitHubReleaseJSON:(NSString *)rawJson
                         versionOverride:(nullable NSString *)versionOverride;
- (void)checkGitHubLatestReleaseWithSimulateOldVersion:(BOOL)simulateOld
                                            completion:(void (^)(NSDictionary *releaseInfo))completion;
- (NSString *)exportHistoryJSONForSlot:(NSInteger)slot;
- (NSDictionary *)importHistoryJSON:(NSString *)jsonString forSlot:(NSInteger)slot;

/// Crypto self-test for `make test`.
+ (nullable NSString *)aesCBCEncryptUTF8:(NSString *)plainText keyData:(NSData *)keyData;
+ (nullable NSData *)aesCBCDecryptBase64:(NSString *)base64Cipher keyData:(NSData *)keyData;
+ (NSString *)md5Hex:(NSString *)input;
+ (NSString *)zaloSignKeyForTag:(NSString *)tag params:(NSDictionary<NSString *, id> *)params;
@end

NS_ASSUME_NONNULL_END
