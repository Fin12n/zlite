#import "CTDOBridge.h"
#import <CoreImage/CoreImage.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#include <sys/utsname.h>

static NSString * const kZaloZpwVer = @"694";
static NSString * const kZaloZpwType = @"30";
static NSString * const kZaloParamCipherKey = @"3FC4F0D2AB50057BCE0D90D9187A22B1";
static NSString * const kZaloUserAgent = @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) ZaloPC/26.10.11 Chrome/122.0.0.0 Electron/29.0.0 Safari/537.36";

// ============================================================================
// CTDOTheme — Native iOS 12.0+ Theme Engine
// ============================================================================
@implementation CTDOTheme

+ (instancetype)shared {
    static CTDOTheme *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CTDOTheme alloc] init];
        NSInteger saved = [[NSUserDefaults standardUserDefaults] integerForKey:@"ctdoz_theme_mode"];
        instance.mode = (CTDOThemeMode)saved;
    });
    return instance;
}

- (void)setMode:(CTDOThemeMode)mode {
    _mode = mode;
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:@"ctdoz_theme_mode"];
}

- (void)cycleTheme {
    self.mode = (CTDOThemeMode)((self.mode + 1) % 3);
}

- (NSString *)themeName {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return @"Zalo Light (Sáng)";
        case CTDOThemeModeOLEDMidnight:
            return @"OLED Midnight (Tiết kiệm pin)";
        case CTDOThemeModeZaloDark:
        default:
            return @"Zalo Dark (Mặc định)";
    }
}

- (UIColor *)bgPrimary {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor colorWithRed:0.95 green:0.96 blue:0.98 alpha:1.0];
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.01 green:0.01 blue:0.02 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.055 green:0.078 blue:0.125 alpha:1.0];
    }
}

- (UIColor *)bgSecondary {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor whiteColor];
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.082 green:0.114 blue:0.180 alpha:1.0];
    }
}

- (UIColor *)bgElevated {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor colorWithRed:0.91 green:0.93 blue:0.96 alpha:1.0];
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.118 green:0.161 blue:0.239 alpha:1.0];
    }
}

- (UIColor *)bgHeader {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor colorWithRed:0.00 green:0.41 blue:1.00 alpha:1.0];
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.03 green:0.05 blue:0.09 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.043 green:0.063 blue:0.106 alpha:1.0];
    }
}

- (UIColor *)textPrimary {
    if (self.mode == CTDOThemeModeZaloLight) {
        return [UIColor colorWithRed:0.07 green:0.09 blue:0.15 alpha:1.0];
    }
    return [UIColor colorWithRed:0.94 green:0.96 blue:0.99 alpha:1.0];
}

- (UIColor *)textSecondary {
    if (self.mode == CTDOThemeModeZaloLight) {
        return [UIColor colorWithRed:0.38 green:0.44 blue:0.53 alpha:1.0];
    }
    return [UIColor colorWithRed:0.58 green:0.64 blue:0.74 alpha:1.0];
}

- (UIColor *)accentPrimary {
    return [UIColor colorWithRed:0.00 green:0.45 blue:1.00 alpha:1.0];
}

- (UIColor *)accentOnline {
    return [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0];
}

- (UIColor *)bubbleSelf {
    if (self.mode == CTDOThemeModeZaloLight) {
        return [UIColor colorWithRed:0.86 green:0.93 blue:1.00 alpha:1.0];
    }
    return [UIColor colorWithRed:0.05 green:0.32 blue:0.68 alpha:1.0];
}

- (UIColor *)bubblePartner {
    if (self.mode == CTDOThemeModeZaloLight) {
        return [UIColor whiteColor];
    }
    return [UIColor colorWithRed:0.118 green:0.161 blue:0.239 alpha:1.0];
}

- (UIColor *)borderSubtle {
    if (self.mode == CTDOThemeModeZaloLight) {
        return [UIColor colorWithRed:0.84 green:0.87 blue:0.92 alpha:1.0];
    }
    return [UIColor colorWithRed:0.16 green:0.22 blue:0.32 alpha:1.0];
}

- (UIColor *)dangerColor {
    return [UIColor colorWithRed:0.94 green:0.27 blue:0.27 alpha:1.0];
}

- (UIColor *)warningColor {
    return [UIColor colorWithRed:0.96 green:0.62 blue:0.04 alpha:1.0];
}

- (NSString *)exportThemeJSON {
    NSDictionary *dict = @{
        @"schema": @"ctdozlite.theme.v1",
        @"name": [self themeName],
        @"mode": @(self.mode),
        @"min_ios": @"12.0",
        @"accent_primary": @"#0073FF",
        @"accent_online": @"#10B981"
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}

+ (UIColor *)colorFromHex:(NSString *)hexString {
    NSString *clean = [[hexString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([clean hasPrefix:@"#"]) {
        clean = [clean substringFromIndex:1];
    }
    if (clean.length != 6) {
        return [UIColor colorWithRed:0.0 green:0.45 blue:1.0 alpha:1.0];
    }
    unsigned int rgb = 0;
    [[NSScanner scannerWithString:clean] scanHexInt:&rgb];
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1.0];
}

@end

// ============================================================================
// CTDOIconRenderer — CoreGraphics & CoreImage QR Generator (min iOS 12.0+)
// ============================================================================
@implementation CTDOIconRenderer

+ (UIImage *)avatarWithInitials:(NSString *)initials
                       colorHex:(NSString *)colorHex
                           size:(CGFloat)size
                       isOnline:(BOOL)isOnline {
    static NSCache *avatarCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        avatarCache = [[NSCache alloc] init];
        avatarCache.countLimit = 128;
    });
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@_%.0f_%d", initials, colorHex, size, isOnline];
    UIImage *cached = [avatarCache objectForKey:cacheKey];
    if (cached) {
        return cached;
    }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *bg = [CTDOTheme colorFromHex:colorHex];
    [bg setFill];
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size, size)];
    [circle fill];

    NSMutableParagraphStyle *pStyle = [[NSMutableParagraphStyle alloc] init];
    pStyle.alignment = NSTextAlignmentCenter;
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:size * 0.38],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSParagraphStyleAttributeName: pStyle
    };
    CGSize txtSize = [initials sizeWithAttributes:attrs];
    CGRect txtRect = CGRectMake(0, (size - txtSize.height) * 0.5, size, txtSize.height);
    [initials drawInRect:txtRect withAttributes:attrs];

    if (isOnline) {
        CGFloat dotSize = MAX(10.0, size * 0.26);
        CGRect dotRect = CGRectMake(size - dotSize - 1.0, size - dotSize - 1.0, dotSize, dotSize);
        CGContextSaveGState(ctx);
        [[[CTDOTheme shared] bgSecondary] setStroke];
        [[[CTDOTheme shared] accentOnline] setFill];
        UIBezierPath *dotPath = [UIBezierPath bezierPathWithOvalInRect:dotRect];
        dotPath.lineWidth = 2.0;
        [dotPath fill];
        [dotPath stroke];
        CGContextRestoreGState(ctx);
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (img) {
        [avatarCache setObject:img forKey:cacheKey];
    }
    return img;
}

+ (UIImage *)qrCodeImageForString:(NSString *)content size:(CGFloat)size {
    if (!content || content.length == 0) {
        return [self appLogoWithSize:size];
    }
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if (!filter) {
        return [self appLogoWithSize:size];
    }
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *ciImage = filter.outputImage;
    if (!ciImage) {
        return [self appLogoWithSize:size];
    }
    CGRect extent = CGRectIntegral(ciImage.extent);
    CGFloat scale = MIN(size / CGRectGetWidth(extent), size / CGRectGetHeight(extent));
    size_t width = (size_t)(CGRectGetWidth(extent) * scale);
    size_t height = (size_t)(CGRectGetHeight(extent) * scale);

    CIContext *ciCtx = [CIContext contextWithOptions:nil];
    CGImageRef cgImg = [ciCtx createCGImage:ciImage fromRect:extent];
    if (!cgImg) {
        return [self appLogoWithSize:size];
    }

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(NULL, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(cs);
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, cgImg);
    CGImageRef scaledImg = CGBitmapContextCreateImage(bitmapRef);
    CGContextRelease(bitmapRef);
    CGImageRelease(cgImg);

    UIImage *result = [UIImage imageWithCGImage:scaledImg];
    CGImageRelease(scaledImg);
    return result;
}

+ (nullable UIImage *)imageFromBase64String:(NSString *)base64String {
    if (!base64String || base64String.length == 0) {
        return nil;
    }
    NSString *clean = [base64String stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([clean hasPrefix:@"data:image"]) {
        NSRange comma = [clean rangeOfString:@","];
        if (comma.location != NSNotFound) {
            clean = [clean substringFromIndex:comma.location + 1];
        }
    }
    NSData *data = [[NSData alloc] initWithBase64EncodedString:clean options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data || data.length == 0) {
        return nil;
    }
    return [UIImage imageWithData:data];
}

+ (UIImage *)appLogoWithSize:(CGFloat)size {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size)
                                                       cornerRadius:size * 0.24];
    [[UIColor colorWithRed:0.0 green:0.42 blue:1.0 alpha:1.0] setFill];
    [rounded fill];

    NSMutableParagraphStyle *pStyle = [[NSMutableParagraphStyle alloc] init];
    pStyle.alignment = NSTextAlignmentCenter;
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:size * 0.44],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSParagraphStyleAttributeName: pStyle
    };
    NSString *txt = @"Z";
    CGSize s = [txt sizeWithAttributes:attrs];
    [txt drawInRect:CGRectMake(0, (size - s.height) * 0.5, size, s.height) withAttributes:attrs];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end

// ============================================================================
// CTDOSlotRuntime — Per-Account Real Zalo Session, Threads & Long-Polling State
// ============================================================================
@interface CTDOSlotRuntime : NSObject
@property (nonatomic, assign) NSInteger slotIndex;
@property (nonatomic, copy) NSString *status; // "unauthenticated", "qr_loading", "qr_waiting_scan", "qr_scanned", "authenticated", "error"
@property (nonatomic, copy) NSString *statusMessage;
@property (nonatomic, copy) NSString *qrPayload;
@property (nonatomic, copy) NSString *qrImageBase64;
@property (nonatomic, copy) NSString *qrTokenId;
@property (nonatomic, copy) NSString *chkWaitScan;
@property (nonatomic, copy) NSString *chkWaitCfirm;
@property (nonatomic, assign) NSUInteger qrGeneration;

@property (nonatomic, copy) NSString *imei;
@property (nonatomic, copy) NSString *computerName;
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarUrl;
@property (nonatomic, copy) NSString *zpwSek;
@property (nonatomic, copy) NSString *zpwEnk;
@property (nonatomic, strong, nullable) NSData *secretKeyData;
@property (nonatomic, copy) NSString *send2meId;

// Verified Zalo service hosts
@property (nonatomic, copy) NSString *hostAuth;
@property (nonatomic, copy) NSString *hostWpaChat;
@property (nonatomic, copy) NSString *hostChat;
@property (nonatomic, copy) NSString *hostFriend;
@property (nonatomic, copy) NSString *hostConvers;
@property (nonatomic, copy) NSString *hostProfile;
@property (nonatomic, copy) NSString *hostGroup;
@property (nonatomic, copy) NSString *hostCloudMsg;
@property (nonatomic, copy) NSString *hostLpChat;

@property (nonatomic, copy) NSString *lastActionId;
@property (nonatomic, copy) NSString *lastActionIdOther;
@property (nonatomic, assign) BOOL pollLoopRunning;

@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *threads;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<NSMutableDictionary *> *> *messagesByThread;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *cookies;
@end

@implementation CTDOSlotRuntime

- (instancetype)initWithSlot:(NSInteger)slot {
    self = [super init];
    if (self) {
        _slotIndex = slot;
        _status = @"unauthenticated";
        _statusMessage = @"Chưa đăng nhập Zalo. Hãy quét mã QR bên dưới bằng điện thoại để đăng nhập.";
        _qrPayload = @"";
        _qrImageBase64 = @"";
        _qrTokenId = @"";
        _chkWaitScan = @"";
        _chkWaitCfirm = @"";
        _qrGeneration = 0;

        NSString *uuid = [[NSUUID UUID].UUIDString lowercaseString];
        NSString *suffix = [CTDOCoreBridge md5Hex:[NSString stringWithFormat:@"ctdozlite_ios_slot_%ld_%@", (long)slot, uuid]];
        _imei = [NSString stringWithFormat:@"%@-%@", uuid, suffix];
        _computerName = (slot == 0) ? @"ctdozlite-iOS" : @"ctdozlite-iOS-Duo2";
        _uid = @"";
        _displayName = @"";
        _avatarUrl = @"";
        _zpwSek = @"";
        _zpwEnk = @"";
        _secretKeyData = nil;
        _send2meId = @"";

        _hostAuth = @"https://wpa.zaloapp.com";
        _hostWpaChat = @"https://wpa.chat.zalo.me";
        _hostChat = @"https://tt-chat3-wpa.api.zaloapp.com";
        _hostFriend = @"https://tt-friend-wpa.chat.zalo.me";
        _hostConvers = @"https://tt-convers-wpa.chat.zalo.me";
        _hostProfile = @"https://tt-profile-wpa.chat.zalo.me";
        _hostGroup = @"https://tt-group-wpa.zaloapp.com";
        _hostCloudMsg = @"https://tt-group-cm.api.zaloapp.com";
        _hostLpChat = @"https://p4-msg-chat.zaloapp.com";

        _lastActionId = @"1";
        _lastActionIdOther = @"1";
        _pollLoopRunning = NO;

        _threads = [NSMutableArray array];
        _messagesByThread = [NSMutableDictionary dictionary];
        _cookies = [NSMutableDictionary dictionary];
    }
    return self;
}

@end

// ============================================================================
// CTDOCoreBridge — 100% Pure Native Objective-C Zalo Engine (CommonCrypto + NSURLSession)
// ============================================================================
@interface CTDOCoreBridge ()
@property (nonatomic, copy) NSString *appDataDir;
@property (nonatomic, strong) NSArray<CTDOSlotRuntime *> *slots;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *scheduledMessages;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *autoReplyRules;
@property (nonatomic, assign) int64_t nextScheduleId;
@property (nonatomic, strong) dispatch_queue_t netQueue;
@end

@implementation CTDOCoreBridge

+ (instancetype)shared {
    static CTDOCoreBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CTDOCoreBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *supportDir = paths.firstObject ?: NSTemporaryDirectory();
        _appDataDir = [supportDir stringByAppendingPathComponent:@"ctdozlite_ios"];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:_appDataDir
      withIntermediateDirectories:YES
                       attributes:@{NSFilePosixPermissions: @(0700)}
                            error:nil];

        // Remove any legacy fake/seeded state file from earlier builds
        NSString *legacySeeded = [_appDataDir stringByAppendingPathComponent:@"ctdozlite_ios_state_v5.json"];
        if ([fm fileExistsAtPath:legacySeeded]) {
            [fm removeItemAtPath:legacySeeded error:nil];
        }

        _netQueue = dispatch_queue_create("net.ctdo.ctdozlite.ios.network", DISPATCH_QUEUE_CONCURRENT);
        _slots = @[
            [[CTDOSlotRuntime alloc] initWithSlot:0],
            [[CTDOSlotRuntime alloc] initWithSlot:1]
        ];
        _scheduledMessages = [NSMutableArray array];
        _autoReplyRules = [NSMutableArray array];
        _nextScheduleId = 1;

        [self loadPersistedSessionsAndRules];
    }
    return self;
}

- (NSString *)versionString {
    return @"0.0.5";
}

// ============================================================================
// Hardware-Truth Device Detection (iPhone vs iPhone Duo vs iPad)
// ============================================================================
- (NSString *)deviceHardwareName {
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSString *simDevName = env[@"SIMULATOR_DEVICE_NAME"];
    NSString *simModel = env[@"SIMULATOR_MODEL_IDENTIFIER"];
    if (simDevName.length > 0 && simModel.length > 0) {
        return [NSString stringWithFormat:@"%@ (%@)", simDevName, simModel];
    }
    if (simDevName.length > 0) {
        return simDevName;
    }
    struct utsname sysinfo;
    if (uname(&sysinfo) == 0) {
        NSString *machine = [NSString stringWithUTF8String:sysinfo.machine];
        if (machine.length > 0) {
            return [NSString stringWithFormat:@"%@ (%@)", [UIDevice currentDevice].model, machine];
        }
    }
    return [UIDevice currentDevice].model ?: @"iOS Device";
}

- (BOOL)isiPhoneDuoHardwareOrGeometry:(CGSize)windowSize {
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSString *simModel = env[@"SIMULATOR_MODEL_IDENTIFIER"] ?: @"";
    NSString *simDevName = env[@"SIMULATOR_DEVICE_NAME"] ?: @"";
    if ([simModel isEqualToString:@"iPhone19,4"] ||
        [simModel isEqualToString:@"V68"] ||
        [simDevName localizedCaseInsensitiveContainsString:@"Duo"]) {
        return YES;
    }
    struct utsname sysinfo;
    if (uname(&sysinfo) == 0) {
        NSString *machine = [NSString stringWithUTF8String:sysinfo.machine];
        if ([machine isEqualToString:@"iPhone19,4"] || [machine isEqualToString:@"V68"]) {
            return YES;
        }
    }
    if ([UIScreen screens].count > 1) {
        return YES;
    }
    CGFloat w = round(windowSize.width);
    CGFloat h = round(windowSize.height);
    if ((fabs(w - 951.0) <= 4.0 && fabs(h - 669.0) <= 4.0) ||
        (fabs(w - 669.0) <= 4.0 && fabs(h - 951.0) <= 4.0) ||
        (fabs(w - 466.0) <= 4.0 && fabs(h - 678.0) <= 4.0) ||
        (fabs(w - 678.0) <= 4.0 && fabs(h - 466.0) <= 4.0)) {
        return YES;
    }
    return NO;
}

- (CTDODeviceClass)hardwareDeviceClassForWindowSize:(CGSize)windowSize {
    if ([self isiPhoneDuoHardwareOrGeometry:windowSize]) {
        return CTDODeviceClassiPhoneDuo;
    }
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ||
        windowSize.width >= 900.0) {
        return CTDODeviceClassiPad;
    }
    return CTDODeviceClassiPhone;
}

// ============================================================================
// Pure Objective-C CommonCrypto Helpers (AES-128/256-CBC, MD5, SHA-256, ParamCipher v2)
// ============================================================================
+ (NSString *)md5Hex:(NSString *)input {
    NSData *data = [input ?: @"" dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
#pragma clang diagnostic pop
    NSMutableString *out = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [out appendFormat:@"%02x", digest[i]];
    }
    return out;
}

+ (NSString *)sha256HexUpper:(NSString *)input {
    NSData *data = [input ?: @"" dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *out = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [out appendFormat:@"%02X", digest[i]];
    }
    return out;
}

+ (nullable NSData *)aesCBCRawEncrypt:(NSData *)plainData keyData:(NSData *)keyData {
    if (!plainData || !keyData) return nil;
    size_t keyLen = keyData.length;
    if (keyLen != kCCKeySizeAES128 && keyLen != kCCKeySizeAES256) {
        return nil;
    }
    uint8_t iv[kCCBlockSizeAES128];
    memset(iv, 0, sizeof(iv));
    size_t bufSize = plainData.length + kCCBlockSizeAES128;
    NSMutableData *cipherData = [NSMutableData dataWithLength:bufSize];
    size_t numBytesEncrypted = 0;
    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES,
                                     kCCOptionPKCS7Padding,
                                     keyData.bytes,
                                     keyLen,
                                     iv,
                                     plainData.bytes,
                                     plainData.length,
                                     cipherData.mutableBytes,
                                     bufSize,
                                     &numBytesEncrypted);
    if (status != kCCSuccess) {
        return nil;
    }
    cipherData.length = numBytesEncrypted;
    return cipherData;
}

+ (nullable NSString *)aesCBCEncryptUTF8:(NSString *)plainText keyData:(NSData *)keyData {
    NSData *plainData = [plainText ?: @"" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *cipherData = [self aesCBCRawEncrypt:plainData keyData:keyData];
    if (!cipherData) return nil;
    return [cipherData base64EncodedStringWithOptions:0];
}

+ (nullable NSData *)aesCBCDecryptBase64:(NSString *)base64Cipher keyData:(NSData *)keyData {
    if (!base64Cipher || base64Cipher.length == 0 || !keyData) return nil;
    size_t keyLen = keyData.length;
    if (keyLen != kCCKeySizeAES128 && keyLen != kCCKeySizeAES256) {
        return nil;
    }
    NSString *clean = [base64Cipher stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    clean = [clean stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    clean = [clean stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (clean.length % 4 != 0) {
        clean = [clean stringByAppendingString:@"="];
    }
    NSData *cipherData = [[NSData alloc] initWithBase64EncodedString:clean
                                                             options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!cipherData || cipherData.length == 0 || (cipherData.length % kCCBlockSizeAES128 != 0)) {
        return nil;
    }
    uint8_t iv[kCCBlockSizeAES128];
    memset(iv, 0, sizeof(iv));
    size_t bufSize = cipherData.length + kCCBlockSizeAES128;
    NSMutableData *plainData = [NSMutableData dataWithLength:bufSize];
    size_t numBytesDecrypted = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES,
                                     kCCOptionPKCS7Padding,
                                     keyData.bytes,
                                     keyLen,
                                     iv,
                                     cipherData.bytes,
                                     cipherData.length,
                                     plainData.mutableBytes,
                                     bufSize,
                                     &numBytesDecrypted);
    if (status != kCCSuccess) {
        return nil;
    }
    plainData.length = numBytesDecrypted;
    return plainData;
}

+ (NSString *)zaloSignKeyForTag:(NSString *)tag params:(NSDictionary<NSString *, id> *)params {
    NSArray<NSString *> *sortedKeys = [[params allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *concat = [NSMutableString stringWithFormat:@"zsecure%@", tag ?: @""];
    for (NSString *k in sortedKeys) {
        id val = params[k];
        if ([val isKindOfClass:[NSString class]]) {
            [concat appendString:(NSString *)val];
        } else if (val == [NSNull null]) {
            [concat appendString:@"null"];
        } else if ([val isKindOfClass:[NSNumber class]]) {
            [concat appendString:[(NSNumber *)val stringValue]];
        } else {
            NSData *jd = [NSJSONSerialization dataWithJSONObject:val options:0 error:nil];
            NSString *js = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding] ?: @"";
            [concat appendString:js];
        }
    }
    return [self md5Hex:concat];
}

+ (NSString *)urlEncode:(NSString *)str {
    if (!str) return @"";
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet alphanumericCharacterSet];
    [allowed addCharactersInString:@"-_.~"];
    return [str stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

+ (NSString *)randomHexOfLength:(NSUInteger)len {
    static const char *hexChars = "0123456789abcdef";
    NSMutableString *out = [NSMutableString stringWithCapacity:len];
    for (NSUInteger i = 0; i < len; i++) {
        uint32_t r = arc4random_uniform(16);
        [out appendFormat:@"%c", hexChars[r]];
    }
    return out;
}

+ (void)splitEvenOdd:(NSString *)str evenOut:(NSString **)evenOut oddOut:(NSString **)oddOut oddReversedOut:(NSString **)oddRevOut {
    NSMutableString *even = [NSMutableString string];
    NSMutableString *odd = [NSMutableString string];
    NSMutableString *oddRev = [NSMutableString string];
    NSUInteger n = str.length;
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = [str characterAtIndex:i];
        if (i % 2 == 0) {
            [even appendFormat:@"%C", c];
        } else {
            [odd appendFormat:@"%C", c];
        }
    }
    for (NSInteger j = (NSInteger)odd.length - 1; j >= 0; j--) {
        [oddRev appendFormat:@"%C", [odd characterAtIndex:(NSUInteger)j]];
    }
    if (evenOut) *evenOut = even;
    if (oddOut) *oddOut = odd;
    if (oddRevOut) *oddRevOut = oddRev;
}

+ (NSDictionary *)buildParamCipherV2BodyForPayload:(NSDictionary *)payload
                                              imei:(NSString *)imei
                                                ts:(int64_t)ts
                                               tag:(NSString *)tag
                                     outEncryptKey:(NSString **)outEncryptKey {
    NSString *zcidPlain = [NSString stringWithFormat:@"%@,%@,%lld", kZaloZpwType, imei, ts];
    NSData *paramCipherKeyData = [kZaloParamCipherKey dataUsingEncoding:NSUTF8StringEncoding];
    NSData *zcidRaw = [self aesCBCRawEncrypt:[zcidPlain dataUsingEncoding:NSUTF8StringEncoding]
                                     keyData:paramCipherKeyData];
    NSMutableString *zcidHexUpper = [NSMutableString stringWithCapacity:zcidRaw.length * 2];
    const uint8_t *bytes = (const uint8_t *)zcidRaw.bytes;
    for (NSUInteger i = 0; i < zcidRaw.length; i++) {
        [zcidHexUpper appendFormat:@"%02X", bytes[i]];
    }

    NSString *zcidExt = [self randomHexOfLength:10];
    NSString *md5Upper = [[self md5Hex:zcidExt] uppercaseString];

    NSString *md5Even = nil;
    [self splitEvenOdd:md5Upper evenOut:&md5Even oddOut:nil oddReversedOut:nil];
    NSString *zcidEven = nil;
    NSString *zcidOddRev = nil;
    [self splitEvenOdd:zcidHexUpper evenOut:&zcidEven oddOut:nil oddReversedOut:&zcidOddRev];

    NSString *p1 = (md5Even.length >= 8) ? [md5Even substringToIndex:8] : md5Even;
    NSString *p2 = (zcidEven.length >= 12) ? [zcidEven substringToIndex:12] : zcidEven;
    NSString *p3 = (zcidOddRev.length >= 12) ? [zcidOddRev substringToIndex:12] : zcidOddRev;
    NSString *encryptKey = [NSString stringWithFormat:@"%@%@%@", p1, p2, p3];
    if (outEncryptKey) {
        *outEncryptKey = encryptKey;
    }

    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payload ?: @{} options:0 error:nil];
    NSString *payloadJson = [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding] ?: @"{}";
    NSString *encParams = [self aesCBCEncryptUTF8:payloadJson
                                          keyData:[encryptKey dataUsingEncoding:NSUTF8StringEncoding]] ?: @"";

    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"zcid": zcidHexUpper,
        @"zcid_ext": zcidExt,
        @"enc_ver": @"v2",
        @"params": encParams,
        @"type": kZaloZpwType,
        @"client_version": kZaloZpwVer
    }];
    NSString *sig = [self zaloSignKeyForTag:tag params:body];
    body[@"signkey"] = sig;
    return body;
}

+ (nullable NSData *)parseZaloSecretKey:(NSString *)enk {
    if (!enk || enk.length == 0) return nil;
    NSData *utf8 = [enk dataUsingEncoding:NSUTF8StringEncoding];
    if (utf8.length == 16 || utf8.length == 32) {
        return utf8;
    }
    NSData *b64 = [[NSData alloc] initWithBase64EncodedString:enk options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (b64.length == 16 || b64.length == 32) {
        return b64;
    }
    if (utf8.length > 32) {
        return [utf8 subdataWithRange:NSMakeRange(0, 32)];
    }
    if (utf8.length > 16) {
        return [utf8 subdataWithRange:NSMakeRange(0, 16)];
    }
    return nil;
}

// ============================================================================
// Synchronous HTTP Transport Helper (Runs on background GCD queue)
// ============================================================================
- (NSDictionary *)sendSyncHTTPForSlot:(CTDOSlotRuntime *)slot
                               method:(NSString *)method
                                  url:(NSString *)urlString
                             formBody:(nullable NSString *)formBody
                              timeout:(NSTimeInterval)timeout {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        return @{@"status": @0, @"error": @"URL không hợp lệ"};
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:timeout];
    req.HTTPMethod = method ?: @"GET";
    [req setValue:kZaloUserAgent forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"https://chat.zalo.me/" forHTTPHeaderField:@"Referer"];
    [req setValue:@"https://chat.zalo.me" forHTTPHeaderField:@"Origin"];
    [req setValue:@"application/json, text/plain, */*" forHTTPHeaderField:@"Accept"];

    @synchronized (slot) {
        NSMutableArray<NSString *> *cookiePairs = [NSMutableArray array];
        if (slot.zpwSek.length > 0) {
            slot.cookies[@"zpw_sek"] = slot.zpwSek;
        }
        for (NSString *ck in slot.cookies) {
            [cookiePairs addObject:[NSString stringWithFormat:@"%@=%@", ck, slot.cookies[ck]]];
        }
        if (cookiePairs.count > 0) {
            [req setValue:[cookiePairs componentsJoinedByString:@"; "] forHTTPHeaderField:@"Cookie"];
        }
    }

    if (formBody && [method isEqualToString:@"POST"]) {
        [req setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        req.HTTPBody = [formBody dataUsingEncoding:NSUTF8StringEncoding];
    }

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSData *respData = nil;
    __block NSHTTPURLResponse *httpResp = nil;
    __block NSError *respErr = nil;

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:req
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        respData = data;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResp = (NSHTTPURLResponse *)response;
        }
        respErr = error;
        dispatch_semaphore_signal(sem);
    }];
    [task resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    [session finishTasksAndInvalidate];

    NSInteger statusCode = httpResp ? httpResp.statusCode : 0;
    if (httpResp && url) {
        NSArray<NSHTTPCookie *> *parsedCookies = [NSHTTPCookie cookiesWithResponseHeaderFields:httpResp.allHeaderFields forURL:url];
        @synchronized (slot) {
            for (NSHTTPCookie *c in parsedCookies) {
                if (c.name.length > 0 && c.value.length > 0) {
                    slot.cookies[c.name] = c.value;
                    if ([c.name isEqualToString:@"zpw_sek"]) {
                        slot.zpwSek = c.value;
                    }
                }
            }
        }
    }

    NSString *text = respData ? ([[NSString alloc] initWithData:respData encoding:NSUTF8StringEncoding] ?: @"") : @"";
    id jsonObj = nil;
    if (respData.length > 0) {
        jsonObj = [NSJSONSerialization JSONObjectWithData:respData options:NSJSONReadingAllowFragments error:nil];
    }
    return @{
        @"status": @(statusCode),
        @"text": text,
        @"json": jsonObj ?: [NSNull null],
        @"error": respErr ? (respErr.localizedDescription ?: @"Lỗi kết nối") : @""
    };
}

- (id)decryptZaloEnvelope:(id)envelope withKeyData:(nullable NSData *)keyData {
    if (![envelope isKindOfClass:[NSDictionary class]] || !keyData) {
        return envelope;
    }
    NSDictionary *dict = (NSDictionary *)envelope;
    id dataNode = dict[@"data"];
    if ([dataNode isKindOfClass:[NSString class]]) {
        NSString *b64 = (NSString *)dataNode;
        if (b64.length > 0) {
            NSData *decData = [CTDOCoreBridge aesCBCDecryptBase64:b64 keyData:keyData];
            if (decData.length > 0) {
                id innerJson = [NSJSONSerialization JSONObjectWithData:decData options:NSJSONReadingAllowFragments error:nil];
                if ([innerJson isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *innerDict = (NSDictionary *)innerJson;
                    if (innerDict[@"error_code"] != nil && innerDict[@"data"] != nil) {
                        return [self decryptZaloEnvelope:innerDict withKeyData:keyData];
                    }
                    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:dict];
                    merged[@"data"] = innerDict;
                    return merged;
                } else if (innerJson != nil) {
                    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:dict];
                    merged[@"data"] = innerJson;
                    return merged;
                }
            }
        }
    }
    return envelope;
}

// ============================================================================
// Persistence of Real Sessions, Threads Cache, Scheduled & Auto-Reply Rules
// ============================================================================
- (NSString *)sessionFilePathForSlot:(NSInteger)slot {
    return [self.appDataDir stringByAppendingPathComponent:[NSString stringWithFormat:@"session_slot%ld.json", (long)slot]];
}

- (NSString *)rulesFilePath {
    return [self.appDataDir stringByAppendingPathComponent:@"automation_rules.json"];
}

- (void)saveSlotSession:(CTDOSlotRuntime *)slot {
    @synchronized (slot) {
        NSDictionary *doc = @{
            @"imei": slot.imei ?: @"",
            @"computer_name": slot.computerName ?: @"",
            @"uid": slot.uid ?: @"",
            @"display_name": slot.displayName ?: @"",
            @"avatar_url": slot.avatarUrl ?: @"",
            @"zpw_sek": slot.zpwSek ?: @"",
            @"zpw_enk": slot.zpwEnk ?: @"",
            @"send2me_id": slot.send2meId ?: @"",
            @"cookies": slot.cookies ?: @{},
            @"host_chat": slot.hostChat ?: @"",
            @"host_friend": slot.hostFriend ?: @"",
            @"host_convers": slot.hostConvers ?: @"",
            @"host_profile": slot.hostProfile ?: @"",
            @"host_group": slot.hostGroup ?: @"",
            @"host_cloud_msg": slot.hostCloudMsg ?: @"",
            @"host_lp_chat": slot.hostLpChat ?: @"",
            @"threads": slot.threads ?: @[],
            @"messages_by_thread": slot.messagesByThread ?: @{}
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:doc options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            [data writeToFile:[self sessionFilePathForSlot:slot.slotIndex] atomically:YES];
        }
    }
}

- (void)saveAutomationRules {
    @synchronized (self) {
        NSDictionary *doc = @{
            @"next_schedule_id": @(self.nextScheduleId),
            @"scheduled": self.scheduledMessages ?: @[],
            @"autoreply": self.autoReplyRules ?: @[]
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:doc options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            [data writeToFile:[self rulesFilePath] atomically:YES];
        }
    }
}

- (void)loadPersistedSessionsAndRules {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *rulesPath = [self rulesFilePath];
    if ([fm fileExistsAtPath:rulesPath]) {
        NSData *rd = [NSData dataWithContentsOfFile:rulesPath];
        NSDictionary *rdoc = rd ? [NSJSONSerialization JSONObjectWithData:rd options:0 error:nil] : nil;
        if ([rdoc isKindOfClass:[NSDictionary class]]) {
            self.nextScheduleId = [rdoc[@"next_schedule_id"] longLongValue] ?: 1;
            for (NSDictionary *s in (rdoc[@"scheduled"] ?: @[])) {
                if ([s isKindOfClass:[NSDictionary class]]) {
                    [self.scheduledMessages addObject:[s mutableCopy]];
                }
            }
            for (NSDictionary *r in (rdoc[@"autoreply"] ?: @[])) {
                if ([r isKindOfClass:[NSDictionary class]]) {
                    [self.autoReplyRules addObject:[r mutableCopy]];
                }
            }
        }
    }

    for (CTDOSlotRuntime *slot in self.slots) {
        NSString *p = [self sessionFilePathForSlot:slot.slotIndex];
        if (![fm fileExistsAtPath:p]) {
            continue;
        }
        NSData *sd = [NSData dataWithContentsOfFile:p];
        NSDictionary *sdoc = sd ? [NSJSONSerialization JSONObjectWithData:sd options:0 error:nil] : nil;
        if (![sdoc isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *sek = sdoc[@"zpw_sek"] ?: @"";
        NSString *enk = sdoc[@"zpw_enk"] ?: @"";
        if (sek.length == 0 || enk.length == 0) {
            continue;
        }
        slot.imei = [sdoc[@"imei"] length] > 10 ? sdoc[@"imei"] : slot.imei;
        slot.computerName = sdoc[@"computer_name"] ?: slot.computerName;
        slot.uid = sdoc[@"uid"] ?: @"";
        slot.displayName = sdoc[@"display_name"] ?: @"";
        slot.avatarUrl = sdoc[@"avatar_url"] ?: @"";
        slot.zpwSek = sek;
        slot.zpwEnk = enk;
        slot.secretKeyData = [CTDOCoreBridge parseZaloSecretKey:enk];
        slot.send2meId = sdoc[@"send2me_id"] ?: @"";
        if ([sdoc[@"cookies"] isKindOfClass:[NSDictionary class]]) {
            [slot.cookies addEntriesFromDictionary:sdoc[@"cookies"]];
        }
        slot.cookies[@"zpw_sek"] = sek;
        if ([sdoc[@"host_lp_chat"] length] > 0) slot.hostLpChat = sdoc[@"host_lp_chat"];

        if ([sdoc[@"threads"] isKindOfClass:[NSArray class]]) {
            for (NSDictionary *t in sdoc[@"threads"]) {
                if ([t isKindOfClass:[NSDictionary class]]) {
                    [slot.threads addObject:[t mutableCopy]];
                }
            }
        }
        if ([sdoc[@"messages_by_thread"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *mbt = sdoc[@"messages_by_thread"];
            for (NSString *tid in mbt) {
                NSArray *arr = mbt[tid];
                if ([arr isKindOfClass:[NSArray class]]) {
                    NSMutableArray *marr = [NSMutableArray array];
                    for (NSDictionary *m in arr) {
                        if ([m isKindOfClass:[NSDictionary class]]) {
                            [marr addObject:[m mutableCopy]];
                        }
                    }
                    slot.messagesByThread[tid] = marr;
                }
            }
        }
        if (slot.secretKeyData != nil) {
            slot.status = @"authenticated";
            slot.statusMessage = [NSString stringWithFormat:@"✓ Đã đăng nhập: %@ (%@)",
                                  slot.displayName.length > 0 ? slot.displayName : @"Tài khoản Zalo",
                                  slot.uid];
            [self startBackgroundSyncAndPollingForSlot:slot];
        }
    }
}

// ============================================================================
// Real Zalo QR Login & Password Login Flow
// ============================================================================
- (CTDOSlotRuntime *)runtimeForSlot:(NSInteger)slot {
    NSInteger idx = (slot == 1) ? 1 : 0;
    return self.slots[idx];
}

- (NSDictionary *)authStateForSlot:(NSInteger)slot {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    @synchronized (rt) {
        return @{
            @"slot": @(rt.slotIndex),
            @"status": rt.status ?: @"unauthenticated",
            @"status_message": rt.statusMessage ?: @"",
            @"qr_payload": rt.qrPayload ?: @"",
            @"qr_image_b64": rt.qrImageBase64 ?: @"",
            @"qr_token_id": rt.qrTokenId ?: @"",
            @"uid": rt.uid ?: @"",
            @"display_name": rt.displayName ?: @"",
            @"imei": rt.imei ?: @"",
            @"threads_count": @(rt.threads.count)
        };
    }
}

- (NSDictionary *)startQRLoginForSlot:(NSInteger)slot {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    NSUInteger gen = 0;
    @synchronized (rt) {
        rt.qrGeneration += 1;
        gen = rt.qrGeneration;
        rt.status = @"qr_loading";
        rt.statusMessage = @"Đang kết nối máy chủ Zalo (wpa.zaloapp.com/api/login/reqqr) để lấy mã QR thực tế...";
        rt.qrPayload = @"";
        rt.qrImageBase64 = @"";
        rt.qrTokenId = @"";
    }

    dispatch_async(self.netQueue, ^{
        [self executeQRLoginWorkerForSlot:rt generation:gen];
    });

    return [self authStateForSlot:slot];
}

- (void)executeQRLoginWorkerForSlot:(CTDOSlotRuntime *)rt generation:(NSUInteger)gen {
    // 1. Call getServerInfo
    int64_t nowSec = (int64_t)[[NSDate date] timeIntervalSince1970];
    NSDictionary *srvParams = @{
        @"imei": rt.imei,
        @"type": kZaloZpwType,
        @"client_version": kZaloZpwVer,
        @"computer_name": rt.computerName,
        @"sp_mtn": @(-1),
        @"bkt": @(-1)
    };
    NSString *srvSig = [CTDOCoreBridge zaloSignKeyForTag:@"getserverinfo" params:srvParams];
    NSString *srvUrl = [NSString stringWithFormat:@"%@/api/login/getServerInfo?bkt=-1&client_version=%@&computer_name=%@&imei=%@&sp_mtn=-1&type=%@&signkey=%@",
                        rt.hostAuth,
                        kZaloZpwVer,
                        [CTDOCoreBridge urlEncode:rt.computerName],
                        [CTDOCoreBridge urlEncode:rt.imei],
                        kZaloZpwType,
                        srvSig];
    [self sendSyncHTTPForSlot:rt method:@"GET" url:srvUrl formBody:nil timeout:10.0];

    // 2. Call /api/login/reqqr
    NSDictionary *qrParams = @{
        @"language": @"vi",
        @"client_time": @(nowSec),
        @"imei": rt.imei,
        @"computer_name": rt.computerName,
        @"logged_uids": @"[]",
        @"self_g": @(1),
        @"qr_form": @(0),
        @"type": kZaloZpwType,
        @"client_version": kZaloZpwVer
    };
    NSString *qrSig = [CTDOCoreBridge zaloSignKeyForTag:@"reqqr" params:qrParams];
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *k in [[qrParams allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *vStr = [NSString stringWithFormat:@"%@", qrParams[k]];
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", k, [CTDOCoreBridge urlEncode:vStr]]];
    }
    [pairs addObject:[NSString stringWithFormat:@"signkey=%@", qrSig]];
    NSString *reqQrUrl = [NSString stringWithFormat:@"%@/api/login/reqqr?%@", rt.hostAuth, [pairs componentsJoinedByString:@"&"]];

    NSDictionary *qrResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:reqQrUrl formBody:nil timeout:12.0];
    NSDictionary *qrJson = [qrResp[@"json"] isKindOfClass:[NSDictionary class]] ? qrResp[@"json"] : nil;
    NSInteger errCode = [qrJson[@"error_code"] integerValue];
    NSDictionary *qrData = [qrJson[@"data"] isKindOfClass:[NSDictionary class]] ? qrJson[@"data"] : nil;

    if (!qrData || errCode != 0) {
        @synchronized (rt) {
            if (rt.qrGeneration != gen) return;
            rt.status = @"error";
            rt.statusMessage = [NSString stringWithFormat:@"Không lấy được mã QR từ Zalo (HTTP %@, mã %ld): %@",
                                qrResp[@"status"], (long)errCode, qrJson[@"error_message"] ?: qrResp[@"error"]];
        }
        return;
    }

    NSString *qrCnt = [qrData[@"qr_cnt"] isKindOfClass:[NSString class]] ? qrData[@"qr_cnt"] : @"";
    NSString *b64Qr = [qrData[@"base64_qr"] isKindOfClass:[NSString class]] ? qrData[@"base64_qr"] : @"";
    NSString *tokenId = [qrData[@"token_id"] isKindOfClass:[NSString class]] ? qrData[@"token_id"] : @"";
    NSString *waitScan = [qrData[@"chk_wait_scan"] isKindOfClass:[NSString class]] ? qrData[@"chk_wait_scan"] : @"";
    NSString *waitCfirm = [qrData[@"chk_wait_cfirm"] isKindOfClass:[NSString class]] ? qrData[@"chk_wait_cfirm"] : @"";
    NSInteger qrTimeout = [qrData[@"qr_timeout"] integerValue] ?: 180;

    @synchronized (rt) {
        if (rt.qrGeneration != gen) return;
        rt.qrPayload = qrCnt;
        rt.qrImageBase64 = b64Qr;
        rt.qrTokenId = tokenId;
        rt.chkWaitScan = waitScan;
        rt.chkWaitCfirm = waitCfirm;
        rt.status = @"qr_waiting_scan";
        rt.statusMessage = [NSString stringWithFormat:@"Mở Zalo trên điện thoại → Quét mã QR này để đăng nhập (Hiệu lực %lds)", (long)qrTimeout];
    }

    if (waitScan.length == 0) {
        return;
    }

    // 3. Long-poll chk_wait_scan until phone scans the QR code
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:MAX(60, qrTimeout)];
    NSString *scanUrl = [NSString stringWithFormat:@"%@&lang=vi", waitScan];
    BOOL scanned = NO;

    while ([[NSDate date] compare:deadline] == NSOrderedAscending) {
        @synchronized (rt) {
            if (rt.qrGeneration != gen) return;
        }
        NSDictionary *scanResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:scanUrl formBody:nil timeout:25.0];
        NSInteger st = [scanResp[@"status"] integerValue];
        if (st == 408 || st == 0) {
            [NSThread sleepForTimeInterval:0.8];
            continue;
        }
        if (st == 200 && [scanResp[@"json"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *sj = scanResp[@"json"];
            NSInteger scode = [sj[@"error_code"] integerValue];
            id sdata = sj[@"data"];
            if (scode == 0 && [sdata isKindOfClass:[NSDictionary class]]) {
                NSString *scanName = sdata[@"display_name"] ?: (sdata[@"displayName"] ?: @"Điện thoại Zalo");
                NSString *scanAvt = sdata[@"avatar"] ?: @"";
                @synchronized (rt) {
                    if (rt.qrGeneration != gen) return;
                    rt.displayName = scanName;
                    if (scanAvt.length > 0) rt.avatarUrl = scanAvt;
                    rt.status = @"qr_scanned";
                    rt.statusMessage = [NSString stringWithFormat:@"✓ Đã quét mã QR (%@)! Vui lòng bấm 'Đăng nhập' trên điện thoại của bạn...", scanName];
                }
                scanned = YES;
                break;
            }
        }
        [NSThread sleepForTimeInterval:0.8];
    }

    if (!scanned) {
        @synchronized (rt) {
            if (rt.qrGeneration != gen) return;
            rt.status = @"qr_expired";
            rt.statusMessage = @"Mã QR đã hết hạn chờ quét. Hãy bấm 'Lấy mã QR mới' để tải lại.";
        }
        return;
    }

    // 4. Long-poll chk_wait_cfirm until phone confirms login
    NSDate *cfirmDeadline = [NSDate dateWithTimeIntervalSinceNow:120.0];
    BOOL confirmed = NO;
    while ([[NSDate date] compare:cfirmDeadline] == NSOrderedAscending) {
        @synchronized (rt) {
            if (rt.qrGeneration != gen) return;
        }
        NSDictionary *cfResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:waitCfirm formBody:nil timeout:25.0];
        NSInteger st = [cfResp[@"status"] integerValue];
        if (st == 408 || st == 0) {
            [NSThread sleepForTimeInterval:0.8];
            continue;
        }
        if (st == 200 && [cfResp[@"json"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *cj = cfResp[@"json"];
            NSInteger ccode = [cj[@"error_code"] integerValue];
            if (ccode == 18012) {
                [NSThread sleepForTimeInterval:0.8];
                continue;
            }
            if (ccode == 0) {
                NSDictionary *cdata = [cj[@"data"] isKindOfClass:[NSDictionary class]] ? cj[@"data"] : nil;
                if ([cdata[@"zpw_sek"] isKindOfClass:[NSString class]] && [cdata[@"zpw_sek"] length] > 0) {
                    @synchronized (rt) {
                        rt.zpwSek = cdata[@"zpw_sek"];
                        rt.cookies[@"zpw_sek"] = rt.zpwSek;
                    }
                }
                confirmed = YES;
                break;
            } else {
                @synchronized (rt) {
                    if (rt.qrGeneration != gen) return;
                    rt.status = @"error";
                    rt.statusMessage = [NSString stringWithFormat:@"Từ chối xác nhận đăng nhập (mã %ld): %@",
                                        (long)ccode, cj[@"error_message"] ?: @""];
                }
                return;
            }
        }
        [NSThread sleepForTimeInterval:0.8];
    }

    if (!confirmed) {
        @synchronized (rt) {
            if (rt.qrGeneration != gen) return;
            rt.status = @"qr_expired";
            rt.statusMessage = @"Hết thời gian chờ xác nhận trên điện thoại. Bấm 'Lấy mã QR mới' để thử lại.";
        }
        return;
    }

    // 5. Fetch getLoginInfo (ParamCipher v2) to obtain zpw_enk, uid, send2me_id, service_map
    @synchronized (rt) {
        rt.statusMessage = @"✓ Điện thoại đã xác nhận! Đang đồng bộ khoá phiên (getLoginInfo) & danh bạ...";
    }
    [self completeLoginBootstrapForSlot:rt];
}

- (NSDictionary *)loginPasswordForSlot:(NSInteger)slot
                                 phone:(NSString *)phone
                              password:(NSString *)password {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    NSString *cleanPhone = [phone stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanPhone.length == 0 || password.length == 0) {
        return [self authStateForSlot:slot];
    }
    @synchronized (rt) {
        rt.qrGeneration += 1;
        rt.status = @"qr_loading";
        rt.statusMessage = @"Đang xác thực SĐT & Mật khẩu qua ParamCipher v2 (loginByPasswv2)...";
    }

    dispatch_async(self.netQueue, ^{
        int64_t ts = (int64_t)[[NSDate date] timeIntervalSince1970];
        NSString *salt = [[CTDOCoreBridge randomHexOfLength:8] lowercaseString];
        NSString *shaInput = [NSString stringWithFormat:@"9fc5vEW3-%@-%@-%@", cleanPhone, rt.imei, salt];
        NSString *shaUpper = [CTDOCoreBridge sha256HexUpper:shaInput];
        NSString *even = nil;
        NSString *oddRev = nil;
        [CTDOCoreBridge splitEvenOdd:shaUpper evenOut:&even oddOut:nil oddReversedOut:&oddRev];
        NSString *pwEnk = [NSString stringWithFormat:@"%@%@",
                           even.length >= 16 ? [even substringToIndex:16] : even,
                           oddRev.length >= 16 ? [oddRev substringToIndex:16] : oddRev];

        NSMutableString *revPwd = [NSMutableString stringWithString:salt];
        for (NSInteger i = (NSInteger)password.length - 1; i >= 0; i--) {
            [revPwd appendFormat:@"%C", [password characterAtIndex:(NSUInteger)i]];
        }
        NSString *encPwd = [CTDOCoreBridge aesCBCEncryptUTF8:revPwd
                                                     keyData:[pwEnk dataUsingEncoding:NSUTF8StringEncoding]] ?: @"";

        NSDictionary *payload = @{
            @"phone_num": cleanPhone,
            @"iso_country_code": @"VN",
            @"password": encPwd,
            @"salt": salt,
            @"cptch_token": @"",
            @"cptch_answer": @"",
            @"make_answer": @(0),
            @"language": @"vi",
            @"logged_uids": [NSNull null],
            @"computer_name": rt.computerName,
            @"imei": rt.imei
        };
        NSString *cipherKey = nil;
        NSDictionary *body = [CTDOCoreBridge buildParamCipherV2BodyForPayload:payload
                                                                         imei:rt.imei
                                                                           ts:ts
                                                                          tag:@"loginbypasswv2"
                                                                outEncryptKey:&cipherKey];
        NSMutableArray *qPairs = [NSMutableArray array];
        for (NSString *k in body) {
            [qPairs addObject:[NSString stringWithFormat:@"%@=%@", k, [CTDOCoreBridge urlEncode:[NSString stringWithFormat:@"%@", body[k]]]]];
        }
        [qPairs addObject:[NSString stringWithFormat:@"ref=%@", [CTDOCoreBridge urlEncode:@"https://chat.zalo.me"]]];
        NSString *url = [NSString stringWithFormat:@"%@/api/login/loginByPasswv2?%@", rt.hostAuth, [qPairs componentsJoinedByString:@"&"]];

        NSDictionary *resp = [self sendSyncHTTPForSlot:rt method:@"POST" url:url formBody:@"" timeout:15.0];
        id dec = [self decryptZaloEnvelope:resp[@"json"] withKeyData:[cipherKey dataUsingEncoding:NSUTF8StringEncoding]];
        if ([dec isKindOfClass:[NSDictionary class]]) {
            NSInteger code = [dec[@"error_code"] integerValue];
            if (code == 0 && [dec[@"data"] isKindOfClass:[NSDictionary class]]) {
                [self applyLoginConfig:dec[@"data"] toSlot:rt];
                [self completeLoginBootstrapForSlot:rt];
                return;
            }
            @synchronized (rt) {
                rt.status = @"error";
                rt.statusMessage = [NSString stringWithFormat:@"Đăng nhập SĐT thất bại (mã %ld): %@. Khuyên dùng Quét mã QR Zalo!",
                                    (long)code, dec[@"error_message"] ?: @"Yêu cầu xác thực QR"];
            }
        }
    });

    return [self authStateForSlot:slot];
}

- (void)completeLoginBootstrapForSlot:(CTDOSlotRuntime *)rt {
    int64_t ts = (int64_t)[[NSDate date] timeIntervalSince1970];
    NSDictionary *payload = @{
        @"imei": rt.imei,
        @"computer_name": rt.computerName,
        @"language": @"vi",
        @"ts": @(ts)
    };
    NSString *cipherKey = nil;
    NSDictionary *body = [CTDOCoreBridge buildParamCipherV2BodyForPayload:payload
                                                                     imei:rt.imei
                                                                       ts:ts
                                                                      tag:@"getlogininfo"
                                                            outEncryptKey:&cipherKey];
    NSMutableArray *qPairs = [NSMutableArray array];
    for (NSString *k in body) {
        [qPairs addObject:[NSString stringWithFormat:@"%@=%@", k, [CTDOCoreBridge urlEncode:[NSString stringWithFormat:@"%@", body[k]]]]];
    }
    NSString *query = [qPairs componentsJoinedByString:@"&"];

    NSArray<NSString *> *hosts = @[rt.hostAuth, rt.hostWpaChat];
    BOOL gotLoginInfo = NO;
    for (NSString *h in hosts) {
        NSString *url = [NSString stringWithFormat:@"%@/api/login/getLoginInfo?%@&nretry=0", h, query];
        NSDictionary *resp = [self sendSyncHTTPForSlot:rt method:@"GET" url:url formBody:nil timeout:15.0];
        id dec = [self decryptZaloEnvelope:resp[@"json"] withKeyData:[cipherKey dataUsingEncoding:NSUTF8StringEncoding]];
        if ([dec isKindOfClass:[NSDictionary class]] && [dec[@"error_code"] integerValue] == 0) {
            NSDictionary *cfg = [dec[@"data"] isKindOfClass:[NSDictionary class]] ? dec[@"data"] : nil;
            if (cfg) {
                [self applyLoginConfig:cfg toSlot:rt];
                gotLoginInfo = YES;
                break;
            }
        }
    }

    if (!gotLoginInfo || !rt.secretKeyData) {
        @synchronized (rt) {
            rt.status = @"error";
            rt.statusMessage = @"Không đồng bộ được zpw_enk từ getLoginInfo. Vui lòng lấy mã QR mới và thử lại.";
        }
        return;
    }

    // Sync profile (/api/social/profile/me-v2)
    [self syncMyProfileForSlot:rt];

    @synchronized (rt) {
        rt.status = @"authenticated";
        rt.statusMessage = [NSString stringWithFormat:@"✓ Đã đăng nhập: %@ (UID: %@)",
                            rt.displayName.length > 0 ? rt.displayName : @"Tài khoản Zalo",
                            rt.uid];
    }

    // Sync real friends, groups, and messages from Zalo API
    [self syncRealThreadsAndMessagesForSlot:rt];
    [self saveSlotSession:rt];
    [self startBackgroundSyncAndPollingForSlot:rt];
}

- (void)applyLoginConfig:(NSDictionary *)cfg toSlot:(CTDOSlotRuntime *)rt {
    if (![cfg isKindOfClass:[NSDictionary class]]) return;
    @synchronized (rt) {
        id uidVal = cfg[@"uid"] ?: (cfg[@"userId"] ?: (cfg[@"dkey"] ?: cfg[@"account"][@"uid"]));
        if (uidVal && uidVal != [NSNull null]) {
            rt.uid = [NSString stringWithFormat:@"%@", uidVal];
        }
        id enkVal = cfg[@"zpw_enk"];
        if ([enkVal isKindOfClass:[NSString class]] && [(NSString *)enkVal length] > 0) {
            rt.zpwEnk = (NSString *)enkVal;
            rt.secretKeyData = [CTDOCoreBridge parseZaloSecretKey:rt.zpwEnk];
        }
        id sekVal = cfg[@"zpw_sek"] ?: cfg[@"account"][@"zpw_sek"];
        if ([sekVal isKindOfClass:[NSString class]] && [(NSString *)sekVal length] > 0) {
            rt.zpwSek = (NSString *)sekVal;
            rt.cookies[@"zpw_sek"] = rt.zpwSek;
        }
        id s2mVal = cfg[@"send2me_id"];
        if (s2mVal && s2mVal != [NSNull null]) {
            rt.send2meId = [NSString stringWithFormat:@"%@", s2mVal];
        }
        id nameVal = cfg[@"display_name"] ?: (cfg[@"account"][@"display_name"] ?: cfg[@"settings"][@"profile"][@"name"]);
        if ([nameVal isKindOfClass:[NSString class]] && [(NSString *)nameVal length] > 0) {
            rt.displayName = (NSString *)nameVal;
        }
        id chts = cfg[@"zpw_chts_new"];
        if ([chts isKindOfClass:[NSArray class]] && [(NSArray *)chts count] > 0) {
            NSString *first = [NSString stringWithFormat:@"%@", [(NSArray *)chts firstObject]];
            if (first.length > 0) {
                rt.hostLpChat = [first hasPrefix:@"http"] ? first : [NSString stringWithFormat:@"https://%@", first];
            }
        } else if ([chts isKindOfClass:[NSString class]] && [(NSString *)chts length] > 0) {
            NSString *first = (NSString *)chts;
            rt.hostLpChat = [first hasPrefix:@"http"] ? first : [NSString stringWithFormat:@"https://%@", first];
        }
    }
}

// ============================================================================
// Real Zalo Chat Sync (me-v2, getfriends, getlg/v4, getmg-v2, get-last-msgs, cm/getrecentv2, lp_chat)
// ============================================================================
- (nullable NSString *)encodeAuthenticatedParams:(NSDictionary *)obj forSlot:(CTDOSlotRuntime *)rt {
    if (!rt.secretKeyData) return nil;
    NSData *jd = [NSJSONSerialization dataWithJSONObject:obj ?: @{} options:0 error:nil];
    NSString *js = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding] ?: @"{}";
    NSString *b64 = [CTDOCoreBridge aesCBCEncryptUTF8:js keyData:rt.secretKeyData];
    return [CTDOCoreBridge urlEncode:b64];
}

- (void)syncMyProfileForSlot:(CTDOSlotRuntime *)rt {
    NSString *enc = [self encodeAuthenticatedParams:@{@"avatar_size": @(160), @"imei": rt.imei} forSlot:rt];
    if (!enc) return;
    NSString *url = [NSString stringWithFormat:@"%@/api/social/profile/me-v2?zpw_ver=%@&zpw_type=%@&params=%@&os=8",
                     rt.hostProfile, kZaloZpwVer, kZaloZpwType, enc];
    NSDictionary *resp = [self sendSyncHTTPForSlot:rt method:@"GET" url:url formBody:nil timeout:10.0];
    id dec = [self decryptZaloEnvelope:resp[@"json"] withKeyData:rt.secretKeyData];
    if ([dec isKindOfClass:[NSDictionary class]]) {
        NSDictionary *prof = dec[@"data"][@"profile"] ?: dec[@"profile"];
        if ([prof isKindOfClass:[NSDictionary class]]) {
            @synchronized (rt) {
                id uid = prof[@"userId"] ?: prof[@"uid"];
                if (uid && uid != [NSNull null]) rt.uid = [NSString stringWithFormat:@"%@", uid];
                NSString *dname = prof[@"displayName"] ?: prof[@"zaloName"];
                if ([dname isKindOfClass:[NSString class]] && dname.length > 0) rt.displayName = dname;
                NSString *avt = prof[@"avatar"] ?: prof[@"avt"];
                if ([avt isKindOfClass:[NSString class]] && avt.length > 0) rt.avatarUrl = avt;
            }
        }
    }
}

+ (NSString *)initialsForName:(NSString *)name {
    NSArray<NSString *> *parts = [[name ?: @"Z" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                                  componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray<NSString *> *clean = [NSMutableArray array];
    for (NSString *p in parts) {
        if (p.length > 0) [clean addObject:p];
    }
    if (clean.count == 0) return @"Z";
    if (clean.count == 1) {
        NSString *w = clean[0];
        return [[w substringToIndex:MIN((NSUInteger)2, w.length)] uppercaseString];
    }
    NSString *first = [clean.firstObject substringToIndex:1];
    NSString *last = [clean.lastObject substringToIndex:1];
    return [[NSString stringWithFormat:@"%@%@", first, last] uppercaseString];
}

+ (NSString *)colorHexForThreadId:(NSString *)threadId {
    NSArray<NSString *> *palette = @[
        @"#0068FF", @"#10B981", @"#8B5CF6", @"#F59E0B",
        @"#EC4899", @"#06B6D4", @"#EF4444", @"#3B82F6"
    ];
    NSUInteger h = [threadId hash];
    return palette[h % palette.count];
}

+ (NSString *)timeLabelFromTimestampMs:(int64_t)tsMs {
    if (tsMs <= 0) return @"";
    NSTimeInterval sec = (tsMs > 20000000000LL) ? ((double)tsMs / 1000.0) : (double)tsMs;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:sec];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm";
    return [fmt stringFromDate:date] ?: @"";
}

- (NSMutableDictionary *)ensureThreadInSlot:(CTDOSlotRuntime *)rt
                                   threadId:(NSString *)tid
                                       name:(NSString *)name
                                    isGroup:(BOOL)isGroup {
    if (tid.length == 0) return nil;
    @synchronized (rt) {
        for (NSMutableDictionary *existing in rt.threads) {
            if ([existing[@"id"] isEqualToString:tid]) {
                if (name.length > 0 && ([existing[@"name"] isEqualToString:tid] || [existing[@"name"] hasPrefix:@"Người dùng "] || [existing[@"name"] hasPrefix:@"Nhóm "])) {
                    existing[@"name"] = name;
                    existing[@"avatar_initials"] = [CTDOCoreBridge initialsForName:name];
                }
                return existing;
            }
        }
        NSString *finalName = (name.length > 0) ? name : (isGroup ? [NSString stringWithFormat:@"Nhóm %@", tid] : [NSString stringWithFormat:@"Người dùng %@", tid]);
        NSString *tag = isGroup ? [NSString stringWithFormat:@"Nhóm Zalo · ID: %@", tid] : [NSString stringWithFormat:@"Cá nhân · UID: %@", tid];
        NSMutableDictionary *t = [NSMutableDictionary dictionaryWithDictionary:@{
            @"id": tid,
            @"name": finalName,
            @"subtitle_tag": tag,
            @"avatar_initials": [CTDOCoreBridge initialsForName:finalName],
            @"avatar_color_hex": [CTDOCoreBridge colorHexForThreadId:tid],
            @"last_message": @"Chưa có tin nhắn",
            @"last_time_label": @"",
            @"last_ts": @(0),
            @"unread_count": @(0),
            @"is_pinned": @(NO),
            @"is_muted": @(NO),
            @"is_hidden": @(NO),
            @"is_group": @(isGroup),
            @"is_online": @(YES)
        }];
        [rt.threads addObject:t];
        if (!rt.messagesByThread[tid]) {
            rt.messagesByThread[tid] = [NSMutableArray array];
        }
        return t;
    }
}

- (void)appendOrMergeMessageInSlot:(CTDOSlotRuntime *)rt
                          threadId:(NSString *)tid
                           isGroup:(BOOL)isGroup
                             msgId:(NSString *)mid
                        senderName:(NSString *)senderName
                           content:(NSString *)content
                            isSelf:(BOOL)isSelf
                              tsMs:(int64_t)tsMs
                      replyPreview:(nullable NSString *)replyPreview {
    if (tid.length == 0 || content.length == 0) return;
    @synchronized (rt) {
        NSMutableDictionary *thread = [self ensureThreadInSlot:rt threadId:tid name:(isGroup ? @"" : (isSelf ? @"" : senderName)) isGroup:isGroup];
        NSMutableArray<NSMutableDictionary *> *msgs = rt.messagesByThread[tid];
        if (!msgs) {
            msgs = [NSMutableArray array];
            rt.messagesByThread[tid] = msgs;
        }
        for (NSMutableDictionary *m in msgs) {
            if (mid.length > 0 && [m[@"id"] isEqualToString:mid]) {
                return;
            }
        }
        NSString *timeLbl = [CTDOCoreBridge timeLabelFromTimestampMs:tsMs];
        NSMutableDictionary *msgObj = [NSMutableDictionary dictionaryWithDictionary:@{
            @"id": mid.length > 0 ? mid : [NSString stringWithFormat:@"m_%lld", tsMs],
            @"thread_id": tid,
            @"sender_name": senderName.length > 0 ? senderName : (isSelf ? @"Tôi" : (thread[@"name"] ?: @"Đối tác")),
            @"content": content,
            @"time_label": timeLbl,
            @"timestamp_ms": @(tsMs),
            @"is_self": @(isSelf),
            @"reply_preview": replyPreview ?: [NSNull null],
            @"reactions": [NSMutableArray array]
        }];
        [msgs addObject:msgObj];
        [msgs sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            int64_t ta = [a[@"timestamp_ms"] longLongValue];
            int64_t tb = [b[@"timestamp_ms"] longLongValue];
            if (ta < tb) return NSOrderedAscending;
            if (ta > tb) return NSOrderedDescending;
            return NSOrderedSame;
        }];

        NSDictionary *newest = msgs.lastObject;
        if (newest) {
            thread[@"last_message"] = newest[@"content"] ?: @"";
            thread[@"last_time_label"] = newest[@"time_label"] ?: @"";
            thread[@"last_ts"] = newest[@"timestamp_ms"] ?: @(0);
        }
    }
}

- (void)syncRealThreadsAndMessagesForSlot:(CTDOSlotRuntime *)rt {
    if (!rt.secretKeyData || rt.zpwSek.length == 0) return;

    // 1. Add Cloud của tôi (send2me_id) if present
    if (rt.send2meId.length > 0) {
        NSMutableDictionary *cloudThread = [self ensureThreadInSlot:rt
                                                           threadId:rt.send2meId
                                                               name:@"Cloud của tôi (Lưu trữ)"
                                                            isGroup:NO];
        @synchronized (rt) {
            cloudThread[@"is_pinned"] = @(YES);
            cloudThread[@"subtitle_tag"] = [NSString stringWithFormat:@"Lưu trữ cá nhân · ID: %@", rt.send2meId];
        }
    }

    // 2. Fetch friend list (/api/social/friend/getfriends)
    NSDictionary *friendBody = @{
        @"incInvalid": @(1),
        @"page": @(1),
        @"count": @(20000),
        @"avatar_size": @(160),
        @"actiontime": @(0),
        @"imei": rt.imei
    };
    NSString *friendEnc = [self encodeAuthenticatedParams:friendBody forSlot:rt];
    if (friendEnc) {
        NSString *fUrl = [NSString stringWithFormat:@"%@/api/social/friend/getfriends?zpw_ver=%@&zpw_type=%@&params=%@",
                          rt.hostFriend, kZaloZpwVer, kZaloZpwType, friendEnc];
        NSDictionary *fResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:fUrl formBody:nil timeout:15.0];
        id fDec = [self decryptZaloEnvelope:fResp[@"json"] withKeyData:rt.secretKeyData];
        id fData = [fDec isKindOfClass:[NSDictionary class]] ? (fDec[@"data"] ?: fDec) : nil;
        NSArray *friendItems = nil;
        if ([fData isKindOfClass:[NSArray class]]) {
            friendItems = (NSArray *)fData;
        } else if ([fData isKindOfClass:[NSDictionary class]]) {
            if ([fData[@"friends"] isKindOfClass:[NSArray class]]) friendItems = fData[@"friends"];
            else if ([fData[@"data"] isKindOfClass:[NSArray class]]) friendItems = fData[@"data"];
        }
        for (NSDictionary *item in (friendItems ?: @[])) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            id rawId = item[@"userId"] ?: (item[@"uid"] ?: item[@"id"]);
            if (!rawId || rawId == [NSNull null]) continue;
            NSString *tid = [NSString stringWithFormat:@"%@", rawId];
            NSString *name = item[@"displayName"] ?: (item[@"zaloName"] ?: tid);
            [self ensureThreadInSlot:rt threadId:tid name:name isGroup:NO];
        }
    }

    // 3. Fetch joined groups (/api/group/getlg/v4 -> /api/group/getmg-v2)
    NSString *lgUrl = [NSString stringWithFormat:@"%@/api/group/getlg/v4?zpw_ver=%@&zpw_type=%@",
                       rt.hostGroup, kZaloZpwVer, kZaloZpwType];
    NSDictionary *lgResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:lgUrl formBody:nil timeout:12.0];
    id lgDec = [self decryptZaloEnvelope:lgResp[@"json"] withKeyData:rt.secretKeyData];
    NSDictionary *gridVerMap = [lgDec isKindOfClass:[NSDictionary class]] ? lgDec[@"data"][@"gridVerMap"] : nil;
    if ([gridVerMap isKindOfClass:[NSDictionary class]] && gridVerMap.count > 0) {
        NSArray<NSString *> *allGrids = [gridVerMap allKeys];
        NSMutableDictionary *batchMap = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < MIN((NSUInteger)60, allGrids.count); i++) {
            NSString *gid = allGrids[i];
            batchMap[gid] = @0;
        }
        NSData *bmData = [NSJSONSerialization dataWithJSONObject:batchMap options:0 error:nil];
        NSString *bmJson = [[NSString alloc] initWithData:bmData encoding:NSUTF8StringEncoding] ?: @"{}";
        NSString *mgEnc = [self encodeAuthenticatedParams:@{@"gridVerMap": bmJson} forSlot:rt];
        if (mgEnc) {
            NSString *mgUrl = [NSString stringWithFormat:@"%@/api/group/getmg-v2?zpw_ver=%@&zpw_type=%@",
                               rt.hostGroup, kZaloZpwVer, kZaloZpwType];
            NSDictionary *mgResp = [self sendSyncHTTPForSlot:rt
                                                      method:@"POST"
                                                         url:mgUrl
                                                    formBody:[NSString stringWithFormat:@"params=%@", mgEnc]
                                                     timeout:15.0];
            id mgDec = [self decryptZaloEnvelope:mgResp[@"json"] withKeyData:rt.secretKeyData];
            NSDictionary *gridInfoMap = [mgDec isKindOfClass:[NSDictionary class]] ? mgDec[@"data"][@"gridInfoMap"] : nil;
            if ([gridInfoMap isKindOfClass:[NSDictionary class]]) {
                for (NSString *gid in gridInfoMap) {
                    NSDictionary *ginfo = gridInfoMap[gid];
                    if (![ginfo isKindOfClass:[NSDictionary class]]) continue;
                    NSString *gname = ginfo[@"name"] ?: [NSString stringWithFormat:@"Nhóm %@", gid];
                    NSString *groupKey = [gid hasPrefix:@"g"] ? gid : [NSString stringWithFormat:@"g%@", gid];
                    [self ensureThreadInSlot:rt threadId:groupKey name:gname isGroup:YES];
                }
            }
        }
    }

    // 4. Fetch recent messages via /api/conv/get-last-msgs
    NSDictionary *lastMsgsBody = @{
        @"threadIdLastMsgIdMap": @"{}",
        @"imei": rt.imei
    };
    NSString *lmEnc = [self encodeAuthenticatedParams:lastMsgsBody forSlot:rt];
    if (lmEnc) {
        NSString *lmUrl = [NSString stringWithFormat:@"%@/api/conv/get-last-msgs?zpw_ver=%@&zpw_type=%@&params=%@",
                           rt.hostConvers, kZaloZpwVer, kZaloZpwType, lmEnc];
        NSDictionary *lmResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:lmUrl formBody:nil timeout:15.0];
        id lmDec = [self decryptZaloEnvelope:lmResp[@"json"] withKeyData:rt.secretKeyData];
        [self ingestZaloMessagesEnvelope:lmDec forSlot:rt];
    }

    // 5. Fetch Cloud của tôi recent messages via /api/cm/getrecentv2
    if (rt.send2meId.length > 0) {
        [self syncCloudMessagesForThread:rt.send2meId inSlot:rt];
    }
}

- (void)syncCloudMessagesForThread:(NSString *)threadId inSlot:(CTDOSlotRuntime *)rt {
    NSString *cleanId = threadId;
    if ([cleanId hasPrefix:@"group_"]) cleanId = [cleanId substringFromIndex:6];
    if ([cleanId hasPrefix:@"g"] || [cleanId hasPrefix:@"G"]) cleanId = [cleanId substringFromIndex:1];
    BOOL isSend2Me = (rt.send2meId.length > 0 && [cleanId isEqualToString:rt.send2meId]);

    NSMutableDictionary *cmBody = [NSMutableDictionary dictionaryWithDictionary:@{
        @"groupId": cleanId,
        @"globalMsgId": @"9223372036854775808",
        @"count": @(40),
        @"msgIds": @[],
        @"imei": rt.imei,
        @"src": @(1)
    }];
    if (isSend2Me) {
        cmBody[@"isOA"] = @(1);
    }
    NSString *cmEnc = [self encodeAuthenticatedParams:cmBody forSlot:rt];
    if (!cmEnc) return;
    NSString *cmUrl = [NSString stringWithFormat:@"%@/api/cm/getrecentv2?zpw_ver=%@&zpw_type=%@&params=%@&nretry=0",
                       rt.hostCloudMsg, kZaloZpwVer, kZaloZpwType, cmEnc];
    NSDictionary *cmResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:cmUrl formBody:nil timeout:12.0];
    id cmDec = [self decryptZaloEnvelope:cmResp[@"json"] withKeyData:rt.secretKeyData];
    [self ingestZaloMessagesEnvelope:cmDec forSlot:rt];
}

+ (NSString *)extractReadableContentFromZaloMessage:(NSDictionary *)item {
    id rawContent = item[@"content"] ?: (item[@"msg"] ?: item[@"message"]);
    if ([rawContent isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)rawContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([s hasPrefix:@"{"] && [s hasSuffix:@"}"]) {
            NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *inner = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
            if ([inner isKindOfClass:[NSDictionary class]]) {
                for (NSString *k in @[@"description", @"caption", @"title", @"text", @"msg", @"href"]) {
                    if ([inner[k] isKindOfClass:[NSString class]] && [inner[k] length] > 0) {
                        return inner[k];
                    }
                }
                if (inner[@"catId"] || inner[@"stickerId"]) return @"[Nhãn dán Zalo]";
                if (inner[@"hd"] || inner[@"thumb"]) return @"[Hình ảnh Zalo]";
            }
        }
        return s;
    } else if ([rawContent isKindOfClass:[NSDictionary class]]) {
        NSDictionary *inner = (NSDictionary *)rawContent;
        for (NSString *k in @[@"description", @"caption", @"title", @"text", @"msg", @"href"]) {
            if ([inner[k] isKindOfClass:[NSString class]] && [inner[k] length] > 0) {
                return inner[k];
            }
        }
        if (inner[@"catId"] || inner[@"stickerId"]) return @"[Nhãn dán Zalo]";
        if (inner[@"hd"] || inner[@"thumb"]) return @"[Hình ảnh Zalo]";
    }
    return @"";
}

- (void)ingestZaloMessagesEnvelope:(id)dec forSlot:(CTDOSlotRuntime *)rt {
    if (![dec isKindOfClass:[NSDictionary class]]) return;
    id dataNode = dec[@"data"] ?: dec;
    if ([dataNode isKindOfClass:[NSString class]]) {
        NSData *d = [(NSString *)dataNode dataUsingEncoding:NSUTF8StringEncoding];
        dataNode = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
    }
    if (![dataNode isKindOfClass:[NSDictionary class]] && ![dataNode isKindOfClass:[NSArray class]]) return;

    NSMutableArray<NSDictionary *> *allItems = [NSMutableArray array];
    if ([dataNode isKindOfClass:[NSArray class]]) {
        for (id x in (NSArray *)dataNode) {
            if ([x isKindOfClass:[NSDictionary class]]) [allItems addObject:x];
        }
    } else if ([dataNode isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dn = (NSDictionary *)dataNode;
        for (NSString *arrKey in @[@"msgs", @"groupMsgs", @"data", @"items", @"messages"]) {
            if ([dn[arrKey] isKindOfClass:[NSArray class]]) {
                for (id x in (NSArray *)dn[arrKey]) {
                    if ([x isKindOfClass:[NSDictionary class]]) [allItems addObject:x];
                }
            } else if ([dn[arrKey] isKindOfClass:[NSDictionary class]]) {
                NSDictionary *mapObj = dn[arrKey];
                for (NSString *k in mapObj) {
                    id entry = mapObj[k];
                    if ([entry isKindOfClass:[NSDictionary class]]) {
                        [allItems addObject:entry];
                    } else if ([entry isKindOfClass:[NSArray class]]) {
                        for (id sub in (NSArray *)entry) {
                            if ([sub isKindOfClass:[NSDictionary class]]) [allItems addObject:sub];
                        }
                    }
                }
            }
        }
    }

    for (NSDictionary *it in allItems) {
        NSString *content = [CTDOCoreBridge extractReadableContentFromZaloMessage:it];
        if (content.length == 0) continue;
        id rawMid = it[@"msgId"] ?: (it[@"cliMsgId"] ?: it[@"globalMsgId"]);
        NSString *mid = rawMid ? [NSString stringWithFormat:@"%@", rawMid] : @"";
        id rawFrom = it[@"uidFrom"] ?: (it[@"fromUid"] ?: it[@"senderId"]);
        NSString *uidFrom = rawFrom ? [NSString stringWithFormat:@"%@", rawFrom] : @"0";
        id rawTo = it[@"idTo"] ?: (it[@"toUid"] ?: (it[@"grid"] ?: it[@"groupId"]));
        NSString *idTo = rawTo ? [NSString stringWithFormat:@"%@", rawTo] : @"";
        NSString *dName = [it[@"dName"] isKindOfClass:[NSString class]] ? it[@"dName"] : @"";
        int64_t ts = [it[@"ts"] longLongValue] ?: ([it[@"cliMsgId"] longLongValue] ?: (int64_t)([[NSDate date] timeIntervalSince1970] * 1000.0));

        BOOL isSelf = ([uidFrom isEqualToString:@"0"] || (rt.uid.length > 0 && [uidFrom isEqualToString:rt.uid]));
        BOOL isGroup = (it[@"grid"] != nil || it[@"groupId"] != nil || [it[@"isGroup"] boolValue]);
        NSString *threadId = isGroup
            ? ([idTo hasPrefix:@"g"] ? idTo : [NSString stringWithFormat:@"g%@", idTo])
            : (isSelf ? idTo : uidFrom);
        if (threadId.length == 0 || [threadId isEqualToString:@"0"]) {
            threadId = rt.send2meId.length > 0 ? rt.send2meId : @"cloud_my";
        }
        [self appendOrMergeMessageInSlot:rt
                                threadId:threadId
                                 isGroup:isGroup
                                   msgId:mid
                              senderName:(isSelf ? @"Tôi" : (dName.length > 0 ? dName : uidFrom))
                                 content:content
                                  isSelf:isSelf
                                    tsMs:ts
                            replyPreview:nil];
    }
}

- (void)startBackgroundSyncAndPollingForSlot:(CTDOSlotRuntime *)rt {
    @synchronized (rt) {
        if (rt.pollLoopRunning) return;
        rt.pollLoopRunning = YES;
    }
    dispatch_async(self.netQueue, ^{
        while (YES) {
            @synchronized (rt) {
                if (![rt.status isEqualToString:@"authenticated"] || !rt.secretKeyData) {
                    rt.pollLoopRunning = NO;
                    return;
                }
            }
            NSString *qJson = [NSString stringWithFormat:@"{\"1\":{\"lastId\":\"%@\",\"ids\":[]},\"2\":{\"lastId\":\"%@\",\"ids\":[]},\"3\":{\"lastId\":\"%@\",\"ids\":[]}}",
                               rt.lastActionId, rt.lastActionId, rt.lastActionId];
            NSString *b64 = [[qJson dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
            NSString *tail = [CTDOCoreBridge urlEncode:[NSString stringWithFormat:@"%@,1", b64]];
            int64_t ts = (int64_t)[[NSDate date] timeIntervalSince1970];
            NSString *lpUrl = [NSString stringWithFormat:@"%@/?zpw_ver=%@&zpw_type=%@&params=%@,%@,%@&ts=%lld",
                               rt.hostLpChat, kZaloZpwVer, kZaloZpwType, rt.lastActionId, rt.lastActionIdOther, tail, ts];
            NSDictionary *lpResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:lpUrl formBody:nil timeout:12.0];
            id lpDec = [self decryptZaloEnvelope:lpResp[@"json"] withKeyData:rt.secretKeyData];
            if ([lpDec isKindOfClass:[NSDictionary class]] && [lpDec[@"error_code"] integerValue] == 0) {
                NSDictionary *dn = [lpDec[@"data"] isKindOfClass:[NSDictionary class]] ? lpDec[@"data"] : lpDec;
                id lai = dn[@"lastActionId"] ?: dn[@"resetLastActionId"];
                if (lai && lai != [NSNull null]) {
                    NSString *laiStr = [NSString stringWithFormat:@"%@", lai];
                    if (laiStr.length > 0 && ![laiStr isEqualToString:@"0"]) {
                        rt.lastActionId = laiStr;
                    }
                }
                [self ingestZaloMessagesEnvelope:lpDec forSlot:rt];
            }
            [NSThread sleepForTimeInterval:2.5];
        }
    });
}

- (NSDictionary *)logoutSlot:(NSInteger)slot {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    @synchronized (rt) {
        rt.qrGeneration += 1;
        rt.status = @"unauthenticated";
        rt.statusMessage = @"Đã đăng xuất phiên Zalo. Hãy quét mã QR mới để đăng nhập.";
        rt.uid = @"";
        rt.displayName = @"";
        rt.zpwSek = @"";
        rt.zpwEnk = @"";
        rt.secretKeyData = nil;
        [rt.cookies removeAllObjects];
        [rt.threads removeAllObjects];
        [rt.messagesByThread removeAllObjects];
    }
    [[NSFileManager defaultManager] removeItemAtPath:[self sessionFilePathForSlot:slot] error:nil];
    return [self startQRLoginForSlot:slot];
}

- (NSDictionary *)refreshThreadsForSlot:(NSInteger)slot {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    if ([rt.status isEqualToString:@"authenticated"]) {
        dispatch_async(self.netQueue, ^{
            [self syncRealThreadsAndMessagesForSlot:rt];
            [self saveSlotSession:rt];
        });
    }
    return [self authStateForSlot:slot];
}

// ============================================================================
// Account, Thread & Message Operations (Real Zalo Outbound API + Local Sync)
// ============================================================================
- (NSDictionary *)switchAccount:(NSInteger)slot {
    return [self authStateForSlot:slot];
}

- (NSArray<NSDictionary *> *)listThreadsForSlot:(NSInteger)slot
                                     filterMode:(NSInteger)filterMode
                                    searchQuery:(nullable NSString *)query {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    NSString *q = [[query ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    @synchronized (rt) {
        for (NSDictionary *t in rt.threads) {
            BOOL hidden = [t[@"is_hidden"] boolValue];
            if (filterMode == 4) {
                if (!hidden) continue;
            } else {
                if (hidden) continue;
                if (filterMode == 1 && [t[@"unread_count"] integerValue] == 0) continue;
                if (filterMode == 2 && ![t[@"is_pinned"] boolValue]) continue;
                if (filterMode == 3 && ![t[@"is_group"] boolValue]) continue;
            }
            if (q.length > 0) {
                NSString *name = [t[@"name"] ?: @"" lowercaseString];
                NSString *tid = [t[@"id"] ?: @"" lowercaseString];
                NSString *tag = [t[@"subtitle_tag"] ?: @"" lowercaseString];
                NSString *last = [t[@"last_message"] ?: @"" lowercaseString];
                if (![name containsString:q] && ![tid containsString:q] && ![tag containsString:q] && ![last containsString:q]) {
                    continue;
                }
            }
            [out addObject:[t copy]];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        BOOL pa = [a[@"is_pinned"] boolValue];
        BOOL pb = [b[@"is_pinned"] boolValue];
        if (pa != pb) return pa ? NSOrderedAscending : NSOrderedDescending;
        int64_t ta = [a[@"last_ts"] longLongValue];
        int64_t tb = [b[@"last_ts"] longLongValue];
        if (ta != tb) return (ta > tb) ? NSOrderedAscending : NSOrderedDescending;
        return [a[@"id"] compare:b[@"id"]];
    }];
    return out;
}

- (NSArray<NSDictionary *> *)getMessagesForSlot:(NSInteger)slot
                                       threadId:(NSString *)threadId {
    if (!threadId || threadId.length == 0) return @[];
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    BOOL shouldSyncHistory = NO;
    @synchronized (rt) {
        for (NSMutableDictionary *t in rt.threads) {
            if ([t[@"id"] isEqualToString:threadId]) {
                t[@"unread_count"] = @(0);
                break;
            }
        }
        NSArray *msgs = rt.messagesByThread[threadId];
        if (!msgs || msgs.count == 0) {
            shouldSyncHistory = ([rt.status isEqualToString:@"authenticated"] && rt.secretKeyData != nil);
        }
        for (NSDictionary *m in (msgs ?: @[])) {
            [out addObject:[m copy]];
        }
    }
    if (shouldSyncHistory && ([threadId hasPrefix:@"g"] || [threadId isEqualToString:rt.send2meId])) {
        dispatch_async(self.netQueue, ^{
            [self syncCloudMessagesForThread:threadId inSlot:rt];
        });
    }
    return out;
}

- (NSArray<NSDictionary *> *)sendMessageForSlot:(NSInteger)slot
                                       threadId:(NSString *)threadId
                                        content:(NSString *)content
                                   replyToMsgId:(nullable NSString *)replyToMsgId {
    NSString *trimmed = [content ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!threadId || threadId.length == 0 || trimmed.length == 0) {
        return [self getMessagesForSlot:slot threadId:threadId ?: @""];
    }
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    int64_t nowMs = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSString *localMid = [NSString stringWithFormat:@"cli_%lld", nowMs];
    BOOL isGroup = [threadId hasPrefix:@"g"] || [threadId hasPrefix:@"group_"];

    NSString *replyPreview = nil;
    if (replyToMsgId.length > 0) {
        @synchronized (rt) {
            for (NSDictionary *m in (rt.messagesByThread[threadId] ?: @[])) {
                if ([m[@"id"] isEqualToString:replyToMsgId]) {
                    replyPreview = [NSString stringWithFormat:@"%@: %@", m[@"sender_name"], m[@"content"]];
                    break;
                }
            }
        }
    }

    [self appendOrMergeMessageInSlot:rt
                            threadId:threadId
                             isGroup:isGroup
                               msgId:localMid
                          senderName:@"Tôi"
                             content:trimmed
                              isSelf:YES
                                tsMs:nowMs
                        replyPreview:replyPreview];
    [self saveSlotSession:rt];

    // Send over real Zalo REST API (/api/message/sms or /api/group/sendmsg) when authenticated
    if ([rt.status isEqualToString:@"authenticated"] && rt.secretKeyData != nil) {
        dispatch_async(self.netQueue, ^{
            if (isGroup) {
                NSString *cleanGrid = [threadId hasPrefix:@"g"] ? [threadId substringFromIndex:1] : threadId;
                NSDictionary *body = @{
                    @"grid": cleanGrid,
                    @"message": trimmed,
                    @"clientId": @(nowMs),
                    @"imei": rt.imei,
                    @"visibility": @(0)
                };
                NSString *enc = [self encodeAuthenticatedParams:body forSlot:rt];
                if (enc) {
                    NSString *url = [NSString stringWithFormat:@"%@/api/group/sendmsg?zpw_ver=%@&zpw_type=%@",
                                     rt.hostGroup, kZaloZpwVer, kZaloZpwType];
                    [self sendSyncHTTPForSlot:rt method:@"POST" url:url formBody:[NSString stringWithFormat:@"params=%@", enc] timeout:12.0];
                }
            } else {
                NSDictionary *body = @{
                    @"toid": threadId,
                    @"message": trimmed,
                    @"clientId": @(nowMs),
                    @"imei": rt.imei
                };
                NSString *enc = [self encodeAuthenticatedParams:body forSlot:rt];
                if (enc) {
                    NSString *url = [NSString stringWithFormat:@"%@/api/message/sms?zpw_ver=%@&zpw_type=%@",
                                     rt.hostChat, kZaloZpwVer, kZaloZpwType];
                    [self sendSyncHTTPForSlot:rt method:@"POST" url:url formBody:[NSString stringWithFormat:@"params=%@", enc] timeout:12.0];
                }
            }
        });
    }

    return [self getMessagesForSlot:slot threadId:threadId];
}

- (NSArray<NSDictionary *> *)reactMessageForSlot:(NSInteger)slot
                                        threadId:(NSString *)threadId
                                           msgId:(NSString *)msgId
                                           emoji:(NSString *)emoji {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    @synchronized (rt) {
        NSMutableArray<NSMutableDictionary *> *msgs = rt.messagesByThread[threadId];
        for (NSMutableDictionary *m in (msgs ?: @[])) {
            if ([m[@"id"] isEqualToString:msgId]) {
                NSMutableArray *r = [m[@"reactions"] isKindOfClass:[NSArray class]]
                    ? [m[@"reactions"] mutableCopy]
                    : [NSMutableArray array];
                if ([r containsObject:emoji]) {
                    [r removeObject:emoji];
                } else {
                    [r addObject:emoji];
                }
                m[@"reactions"] = r;
                break;
            }
        }
    }
    [self saveSlotSession:rt];
    return [self getMessagesForSlot:slot threadId:threadId];
}

- (NSArray<NSDictionary *> *)performThreadActionForSlot:(NSInteger)slot
                                               threadId:(NSString *)threadId
                                                 action:(NSInteger)action {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    @synchronized (rt) {
        for (NSMutableDictionary *t in rt.threads) {
            if ([t[@"id"] isEqualToString:threadId]) {
                if (action == 1) {
                    t[@"is_pinned"] = @(![t[@"is_pinned"] boolValue]);
                } else if (action == 2) {
                    t[@"is_muted"] = @(![t[@"is_muted"] boolValue]);
                } else if (action == 3) {
                    t[@"is_hidden"] = @(![t[@"is_hidden"] boolValue]);
                } else if (action == 4) {
                    [rt.messagesByThread removeObjectForKey:threadId];
                    t[@"last_message"] = @"Đã xoá lịch sử trò chuyện";
                    t[@"unread_count"] = @(0);
                }
                break;
            }
        }
    }
    [self saveSlotSession:rt];
    return [self listThreadsForSlot:slot filterMode:0 searchQuery:@""];
}

// ============================================================================
// Scheduled Messages (#38) & Auto-Reply Rules (#35)
// ============================================================================
- (NSArray<NSDictionary *> *)scheduleMessageForSlot:(NSInteger)slot
                                           threadId:(NSString *)threadId
                                            content:(NSString *)content
                                        deliverAtMs:(int64_t)deliverAtMs {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    NSString *tName = threadId;
    @synchronized (rt) {
        for (NSDictionary *t in rt.threads) {
            if ([t[@"id"] isEqualToString:threadId]) {
                tName = t[@"name"] ?: threadId;
                break;
            }
        }
    }
    @synchronized (self) {
        int64_t sid = self.nextScheduleId++;
        NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{
            @"id": @(sid),
            @"account_slot": @(slot),
            @"thread_id": threadId ?: @"",
            @"thread_name": tName ?: @"",
            @"content": content ?: @"",
            @"deliver_at_ms": @(deliverAtMs),
            @"deliver_time_label": [CTDOCoreBridge timeLabelFromTimestampMs:deliverAtMs],
            @"status": @"pending"
        }];
        [self.scheduledMessages addObject:item];
    }
    [self saveAutomationRules];
    return [self listScheduledForSlot:slot];
}

- (NSArray<NSDictionary *> *)listScheduledForSlot:(NSInteger)slot {
    NSMutableArray *out = [NSMutableArray array];
    @synchronized (self) {
        for (NSDictionary *it in self.scheduledMessages) {
            if ([it[@"account_slot"] integerValue] == slot && [it[@"status"] isEqualToString:@"pending"]) {
                [out addObject:[it copy]];
            }
        }
    }
    return out;
}

- (NSArray<NSDictionary *> *)cancelScheduledForSlot:(NSInteger)slot
                                            schedId:(int64_t)schedId {
    @synchronized (self) {
        for (NSInteger i = (NSInteger)self.scheduledMessages.count - 1; i >= 0; i--) {
            NSDictionary *it = self.scheduledMessages[(NSUInteger)i];
            if ([it[@"id"] longLongValue] == schedId) {
                [self.scheduledMessages removeObjectAtIndex:(NSUInteger)i];
            }
        }
    }
    [self saveAutomationRules];
    return [self listScheduledForSlot:slot];
}

- (NSArray<NSDictionary *> *)pollDueScheduledMessages {
    int64_t nowMs = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSMutableArray *due = [NSMutableArray array];
    @synchronized (self) {
        for (NSMutableDictionary *it in self.scheduledMessages) {
            if ([it[@"status"] isEqualToString:@"pending"] && [it[@"deliver_at_ms"] longLongValue] <= nowMs) {
                it[@"status"] = @"sent";
                [due addObject:[it copy]];
            }
        }
    }
    for (NSDictionary *d in due) {
        [self sendMessageForSlot:[d[@"account_slot"] integerValue]
                        threadId:d[@"thread_id"]
                         content:d[@"content"]
                    replyToMsgId:nil];
    }
    if (due.count > 0) {
        [self saveAutomationRules];
    }
    return due;
}

- (NSArray<NSDictionary *> *)listAutoReplyRules {
    NSMutableArray *out = [NSMutableArray array];
    @synchronized (self) {
        for (NSDictionary *r in self.autoReplyRules) {
            [out addObject:[r copy]];
        }
    }
    return out;
}

- (NSArray<NSDictionary *> *)mutateAutoReplyOp:(NSInteger)op
                                   patternOrId:(NSString *)patternOrId
                                      response:(NSString *)response
                                     matchMode:(NSString *)matchMode {
    @synchronized (self) {
        if (op == 1 && patternOrId.length > 0 && response.length > 0) {
            NSString *rid = [NSString stringWithFormat:@"rule_%lu", (unsigned long)(self.autoReplyRules.count + 1)];
            [self.autoReplyRules addObject:[NSMutableDictionary dictionaryWithDictionary:@{
                @"id": rid,
                @"pattern": patternOrId,
                @"response": response,
                @"match_mode": matchMode ?: @"contains",
                @"enabled": @(YES)
            }]];
        } else if (op == 2) {
            for (NSMutableDictionary *r in self.autoReplyRules) {
                if ([r[@"id"] isEqualToString:patternOrId] || [r[@"pattern"] isEqualToString:patternOrId]) {
                    r[@"enabled"] = @(![r[@"enabled"] boolValue]);
                }
            }
        } else if (op == 3) {
            for (NSInteger i = (NSInteger)self.autoReplyRules.count - 1; i >= 0; i--) {
                NSDictionary *r = self.autoReplyRules[(NSUInteger)i];
                if ([r[@"id"] isEqualToString:patternOrId]) {
                    [self.autoReplyRules removeObjectAtIndex:(NSUInteger)i];
                }
            }
        }
    }
    [self saveAutomationRules];
    return [self listAutoReplyRules];
}

// ============================================================================
// Signed Request Builder, GitHub Releases Updater & History Migration (#9)
// ============================================================================
- (NSDictionary *)buildSignedRequestForService:(NSString *)service
                                        method:(NSString *)method
                                    jsonParams:(NSString *)jsonParams {
    int64_t ts = (int64_t)[[NSDate date] timeIntervalSince1970];
    NSData *pd = [jsonParams ?: @"{}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *payload = pd ? [NSJSONSerialization JSONObjectWithData:pd options:0 error:nil] : @{};
    if (![payload isKindOfClass:[NSDictionary class]]) payload = @{};

    NSString *cipherKey = nil;
    NSDictionary *body = [CTDOCoreBridge buildParamCipherV2BodyForPayload:payload
                                                                     imei:self.slots[0].imei
                                                                       ts:ts
                                                                      tag:[method lowercaseString]
                                                            outEncryptKey:&cipherKey];
    NSArray<NSString *> *failover = @[
        @"https://tt-chat3-wpa.api.zaloapp.com",
        @"https://tt-convers-wpa.chat.zalo.me",
        @"https://tt-friend-wpa.chat.zalo.me",
        @"https://wpa.zaloapp.com"
    ];
    return @{
        @"service": service ?: @"chat",
        @"method": method ?: @"sms",
        @"zpw_ver": kZaloZpwVer,
        @"zpw_type": kZaloZpwType,
        @"zcid": body[@"zcid"] ?: @"",
        @"zcid_ext": body[@"zcid_ext"] ?: @"",
        @"enc_ver": @"v2",
        @"params": body[@"params"] ?: @"",
        @"signkey": body[@"signkey"] ?: @"",
        @"endpoint": [NSString stringWithFormat:@"%@/%@", failover.firstObject, method ?: @"sms"],
        @"failover_hosts": failover
    };
}

- (NSDictionary *)parseGitHubReleaseJSON:(NSString *)rawJson
                         versionOverride:(nullable NSString *)versionOverride {
    NSString *curVer = (versionOverride.length > 0) ? versionOverride : [self versionString];
    NSData *d = [rawJson ?: @"{}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : @{};
    if (![json isKindOfClass:[NSDictionary class]]) json = @{};

    NSString *tagName = json[@"tag_name"] ?: @"v0.0.5";
    NSString *latestVer = [tagName hasPrefix:@"v"] ? [tagName substringFromIndex:1] : tagName;
    NSString *title = json[@"name"] ?: [NSString stringWithFormat:@"ctdozlite %@", tagName];
    NSString *htmlUrl = json[@"html_url"] ?: @"https://github.com/ctdoteam1110/ctdozlite/releases";
    NSString *body = json[@"body"] ?: @"";

    NSMutableArray<NSString *> *bullets = [NSMutableArray array];
    for (NSString *line in [body componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([t hasPrefix:@"- "] || [t hasPrefix:@"* "]) {
            NSString *clean = [[t substringFromIndex:2] stringByReplacingOccurrencesOfString:@"**" withString:@""];
            [bullets addObject:clean];
        }
    }
    BOOL hasUpdate = ([latestVer compare:curVer options:NSNumericSearch] == NSOrderedDescending);
    return @{
        @"current_version": curVer,
        @"latest_version": latestVer,
        @"tag_name": tagName,
        @"title": title,
        @"html_url": htmlUrl,
        @"has_update": @(hasUpdate),
        @"bullets": bullets
    };
}

- (void)checkGitHubLatestReleaseWithSimulateOldVersion:(BOOL)simulateOld
                                            completion:(void (^)(NSDictionary *releaseInfo))completion {
    NSURL *url = [NSURL URLWithString:@"https://api.github.com/repos/ctdoteam1110/ctdozlite/releases/latest"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:8.0];
    [req setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"ctdozlite-ios/0.0.5 (iOS 12.0+; Pure Objective-C)" forHTTPHeaderField:@"User-Agent"];

    NSString *verOverride = simulateOld ? @"0.0.4" : [self versionString];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:req
          completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
              NSString *rawJson = nil;
              if (data && !error) {
                  rawJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
              }
              if (!rawJson || rawJson.length < 10) {
                  rawJson = @"{\"tag_name\":\"v0.0.5\",\"name\":\"ctdozlite v0.0.5\",\"html_url\":\"https://github.com/ctdoteam1110/ctdozlite/releases/tag/v0.0.5\",\"body\":\"- Tự động thông báo cập nhật qua GitHub Releases API\\n- Đăng nhập trực tiếp bằng mã QR Zalo thực tế (reqqr / chk_wait_scan / chk_wait_cfirm)\\n- Hỗ trợ 100% Pure Native Objective-C cho iPhone, iPad và iPhone Duo (min iOS 12.0+)\"}";
              }
              NSDictionary *parsed = [self parseGitHubReleaseJSON:rawJson versionOverride:verOverride];
              dispatch_async(dispatch_get_main_queue(), ^{
                  if (completion) {
                      completion(parsed);
                  }
              });
          }];
    [task resume];
}

- (NSString *)exportHistoryJSONForSlot:(NSInteger)slot {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    @synchronized (rt) {
        NSDictionary *doc = @{
            @"schema": @"ctdozlite.ios.history.v1",
            @"slot": @(slot),
            @"uid": rt.uid ?: @"",
            @"threads": rt.threads ?: @[],
            @"messages_by_thread": rt.messagesByThread ?: @{}
        };
        NSData *d = [NSJSONSerialization dataWithJSONObject:doc options:NSJSONWritingPrettyPrinted error:nil];
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"{}";
    }
}

- (NSDictionary *)importHistoryJSON:(NSString *)jsonString forSlot:(NSInteger)slot {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    NSData *d = [jsonString ?: @"{}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *doc = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
    if (![doc isKindOfClass:[NSDictionary class]]) {
        return @{@"imported_threads": @0, @"imported_messages": @0, @"skipped_duplicates": @0};
    }
    NSInteger impThreads = 0;
    NSInteger impMsgs = 0;
    NSInteger skipped = 0;
    @synchronized (rt) {
        for (NSDictionary *t in (doc[@"threads"] ?: @[])) {
            if (![t isKindOfClass:[NSDictionary class]]) continue;
            NSString *tid = t[@"id"] ?: @"";
            if (tid.length == 0) continue;
            BOOL exists = NO;
            for (NSDictionary *ex in rt.threads) {
                if ([ex[@"id"] isEqualToString:tid]) {
                    exists = YES;
                    break;
                }
            }
            if (!exists) {
                [rt.threads addObject:[t mutableCopy]];
                impThreads++;
            }
        }
        NSDictionary *mbt = doc[@"messages_by_thread"];
        if ([mbt isKindOfClass:[NSDictionary class]]) {
            for (NSString *tid in mbt) {
                NSArray *arr = mbt[tid];
                if (![arr isKindOfClass:[NSArray class]]) continue;
                NSMutableArray *dest = rt.messagesByThread[tid];
                if (!dest) {
                    dest = [NSMutableArray array];
                    rt.messagesByThread[tid] = dest;
                }
                for (NSDictionary *m in arr) {
                    NSString *mid = m[@"id"] ?: @"";
                    BOOL dup = NO;
                    for (NSDictionary *em in dest) {
                        if ([em[@"id"] isEqualToString:mid]) {
                            dup = YES;
                            break;
                        }
                    }
                    if (dup) {
                        skipped++;
                    } else {
                        [dest addObject:[m mutableCopy]];
                        impMsgs++;
                    }
                }
            }
        }
    }
    [self saveSlotSession:rt];
    return @{
        @"imported_threads": @(impThreads),
        @"imported_messages": @(impMsgs),
        @"skipped_duplicates": @(skipped)
    };
}

@end
