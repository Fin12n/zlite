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
// CTDOTheme — Official Zalo iOS Theme Engine (Default: Zalo Light matching ref1..ref5)
// ============================================================================
@implementation CTDOTheme

+ (instancetype)shared {
    static CTDOTheme *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CTDOTheme alloc] init];
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"ctdoz_theme_v2"] != nil) {
            NSInteger saved = [[NSUserDefaults standardUserDefaults] integerForKey:@"ctdoz_theme_v2"];
            instance.mode = (CTDOThemeMode)saved;
        } else {
            instance.mode = CTDOThemeModeZaloLight;
        }
    });
    return instance;
}

- (void)setMode:(CTDOThemeMode)mode {
    _mode = mode;
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:@"ctdoz_theme_v2"];
}

- (void)cycleTheme {
    self.mode = (CTDOThemeMode)((self.mode + 1) % 3);
}

- (NSString *)themeName {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return @"Sáng (Mặc định Zalo)";
        case CTDOThemeModeZaloDark:
            return @"Tối (Zalo Dark)";
        case CTDOThemeModeOLEDMidnight:
        default:
            return @"OLED Midnight (Tiết kiệm pin)";
    }
}

- (UIColor *)bgPrimary {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor colorWithRed:0.953 green:0.961 blue:0.973 alpha:1.0]; // #F3F5F8
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.01 green:0.01 blue:0.02 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.055 green:0.078 blue:0.125 alpha:1.0];
    }
}

- (UIColor *)bgSecondary {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor whiteColor]; // #FFFFFF
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.082 green:0.114 blue:0.180 alpha:1.0];
    }
}

- (UIColor *)bgElevated {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor colorWithRed:0.933 green:0.953 blue:0.984 alpha:1.0]; // #EEF3FB
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.118 green:0.161 blue:0.239 alpha:1.0];
    }
}

- (UIColor *)bgHeader {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor colorWithRed:0.00 green:0.42 blue:1.00 alpha:1.0]; // #006BFF
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.03 green:0.05 blue:0.09 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.043 green:0.063 blue:0.106 alpha:1.0];
    }
}

- (UIColor *)bgChatCanvas {
    switch (self.mode) {
        case CTDOThemeModeZaloLight:
            return [UIColor colorWithRed:0.886 green:0.910 blue:0.945 alpha:1.0]; // #E2E8F1 (Zalo chat wallpaper gray-blue)
        case CTDOThemeModeOLEDMidnight:
            return [UIColor colorWithRed:0.01 green:0.01 blue:0.02 alpha:1.0];
        default:
            return [UIColor colorWithRed:0.055 green:0.078 blue:0.125 alpha:1.0];
    }
}

- (UIColor *)textPrimary {
    if (self.mode == CTDOThemeModeZaloLight) {
        return [UIColor colorWithRed:0.067 green:0.094 blue:0.153 alpha:1.0]; // #111827
    }
    return [UIColor colorWithRed:0.94 green:0.96 blue:0.99 alpha:1.0];
}

- (UIColor *)textSecondary {
    if (self.mode == CTDOThemeModeZaloLight) {
        return [UIColor colorWithRed:0.420 green:0.447 blue:0.502 alpha:1.0]; // #6B7280
    }
    return [UIColor colorWithRed:0.58 green:0.64 blue:0.74 alpha:1.0];
}

- (UIColor *)accentPrimary {
    return [UIColor colorWithRed:0.00 green:0.41 blue:1.00 alpha:1.0]; // #0068FF
}

- (UIColor *)accentOnline {
    return [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0];
}

- (UIColor *)bubbleSelf {
    if (self.mode == CTDOThemeModeZaloLight) {
        return [UIColor colorWithRed:0.835 green:0.945 blue:1.00 alpha:1.0]; // #D5F1FF
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
        return [UIColor colorWithRed:0.910 green:0.922 blue:0.937 alpha:1.0]; // #E8EBEF
    }
    return [UIColor colorWithRed:0.16 green:0.22 blue:0.32 alpha:1.0];
}

- (UIColor *)dangerColor {
    return [UIColor colorWithRed:0.937 green:0.267 blue:0.267 alpha:1.0]; // #EF4444
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
        @"accent_primary": @"#0068FF",
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
        return [UIColor colorWithRed:0.0 green:0.41 blue:1.0 alpha:1.0];
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
// CTDOIconRenderer — Official Zalo Avatar Cache, 2x2 Group Collage & Vector Icons
// ============================================================================
@implementation CTDOIconRenderer

+ (NSCache *)sharedImageCache {
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 400;
    });
    return cache;
}

+ (NSMutableSet *)inFlightURLs {
    static NSMutableSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSMutableSet set];
    });
    return set;
}

+ (NSString *)avatarCacheDirectory {
    static NSString *dir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        dir = [(paths.firstObject ?: NSTemporaryDirectory()) stringByAppendingPathComponent:@"ctdozlite_avatars"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

+ (nullable UIImage *)cachedOrDiskRawImageForURL:(NSString *)urlString onCompletion:(nullable void (^)(void))completion {
    if (!urlString || urlString.length < 8 || [urlString hasSuffix:@"/default"]) {
        return nil;
    }
    NSCache *cache = [self sharedImageCache];
    NSString *rawKey = [NSString stringWithFormat:@"raw_%@", urlString];
    UIImage *memImg = [cache objectForKey:rawKey];
    if (memImg) {
        return memImg;
    }

    NSString *hash = [CTDOCoreBridge md5Hex:urlString];
    NSString *diskPath = [[self avatarCacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.img", hash]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        NSData *d = [NSData dataWithContentsOfFile:diskPath];
        UIImage *diskImg = d ? [UIImage imageWithData:d] : nil;
        if (diskImg) {
            [cache setObject:diskImg forKey:rawKey];
            return diskImg;
        }
    }

    NSMutableSet *inFlight = [self inFlightURLs];
    BOOL shouldStart = NO;
    @synchronized (inFlight) {
        if (![inFlight containsObject:urlString]) {
            [inFlight addObject:urlString];
            shouldStart = YES;
        }
    }

    if (shouldStart) {
        NSString *safeUrl = [urlString stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
        NSURL *url = [NSURL URLWithString:safeUrl];
        if (url) {
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                               cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                           timeoutInterval:12.0];
            [req setValue:kZaloUserAgent forHTTPHeaderField:@"User-Agent"];
            [req setValue:@"https://chat.zalo.me/" forHTTPHeaderField:@"Referer"];
            NSURLSessionDataTask *task = [[NSURLSession sharedSession]
                dataTaskWithRequest:req
                  completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                      @synchronized (inFlight) {
                          [inFlight removeObject:urlString];
                      }
                      if (data.length > 64 && !error) {
                          UIImage *dl = [UIImage imageWithData:data];
                          if (dl) {
                              [cache setObject:dl forKey:rawKey];
                              [data writeToFile:diskPath atomically:YES];
                              if (completion) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      completion();
                                  });
                              }
                          }
                      }
                  }];
            [task resume];
        } else {
            @synchronized (inFlight) {
                [inFlight removeObject:urlString];
            }
        }
    }
    return nil;
}

+ (void)drawVerifiedOrangeBadgeInRect:(CGRect)badgeRect context:(CGContextRef)ctx {
    CGContextSaveGState(ctx);
    [[UIColor whiteColor] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectInset(badgeRect, -1.2, -1.2)] fill];

    [[UIColor colorWithRed:0.96 green:0.62 blue:0.07 alpha:1.0] setFill]; // #F59E12 Zalo verified gold-orange
    [[UIBezierPath bezierPathWithOvalInRect:badgeRect] fill];

    UIBezierPath *check = [UIBezierPath bezierPath];
    CGFloat bx = badgeRect.origin.x;
    CGFloat by = badgeRect.origin.y;
    CGFloat bw = badgeRect.size.width;
    CGFloat bh = badgeRect.size.height;
    [check moveToPoint:CGPointMake(bx + bw * 0.27, by + bh * 0.52)];
    [check addLineToPoint:CGPointMake(bx + bw * 0.44, by + bh * 0.69)];
    [check addLineToPoint:CGPointMake(bx + bw * 0.74, by + bh * 0.34)];
    check.lineWidth = MAX(1.5, bw * 0.13);
    check.lineCapStyle = kCGLineCapRound;
    check.lineJoinStyle = kCGLineJoinRound;
    [[UIColor whiteColor] setStroke];
    [check stroke];
    CGContextRestoreGState(ctx);
}

+ (UIImage *)myDocumentsAvatarWithSize:(CGFloat)size {
    NSString *key = [NSString stringWithFormat:@"mydocs_%.0f", size];
    UIImage *cached = [[self sharedImageCache] objectForKey:key];
    if (cached) return cached;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Blue circle (#4A89F3) matching ref1.png My Documents
    [[UIColor colorWithRed:0.29 green:0.54 blue:0.95 alpha:1.0] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size, size)] fill];

    // White folder shape
    [[UIColor colorWithWhite:1.0 alpha:0.95] setFill];
    UIBezierPath *folder = [UIBezierPath bezierPath];
    CGFloat fx = size * 0.22;
    CGFloat fy = size * 0.28;
    CGFloat fw = size * 0.56;
    CGFloat fh = size * 0.42;
    [folder moveToPoint:CGPointMake(fx, fy + fh * 0.18)];
    [folder addLineToPoint:CGPointMake(fx + fw * 0.36, fy + fh * 0.18)];
    [folder addLineToPoint:CGPointMake(fx + fw * 0.45, fy + fh * 0.30)];
    [folder addLineToPoint:CGPointMake(fx + fw, fy + fh * 0.30)];
    [folder addLineToPoint:CGPointMake(fx + fw, fy + fh)];
    [folder addLineToPoint:CGPointMake(fx, fy + fh)];
    [folder closePath];
    [folder fill];

    // Subtle cloud silhouette at bottom-right of folder
    [[UIColor colorWithRed:0.74 green:0.86 blue:1.0 alpha:1.0] setFill];
    CGRect cloudBase = CGRectMake(size * 0.42, size * 0.52, size * 0.38, size * 0.20);
    [[UIBezierPath bezierPathWithRoundedRect:cloudBase cornerRadius:size * 0.10] fill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.48, size * 0.44, size * 0.20, size * 0.20)] fill];

    // Verified orange badge at bottom-right (matching ref1.png)
    CGFloat bSize = MAX(14.0, size * 0.30);
    [self drawVerifiedOrangeBadgeInRect:CGRectMake(size - bSize, size - bSize, bSize, bSize) context:ctx];

    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (out) [[self sharedImageCache] setObject:out forKey:key];
    return out;
}

+ (UIImage *)avatarWithInitials:(NSString *)initials
                       colorHex:(NSString *)colorHex
                           size:(CGFloat)size
                       isOnline:(BOOL)isOnline {
    NSString *cacheKey = [NSString stringWithFormat:@"init_%@_%@_%.0f_%d", initials, colorHex, size, isOnline];
    UIImage *cached = [[self sharedImageCache] objectForKey:cacheKey];
    if (cached) {
        return cached;
    }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *bg = [CTDOTheme colorFromHex:colorHex];
    [bg setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size, size)] fill];

    NSMutableParagraphStyle *pStyle = [[NSMutableParagraphStyle alloc] init];
    pStyle.alignment = NSTextAlignmentCenter;
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:size * 0.36 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSParagraphStyleAttributeName: pStyle
    };
    CGSize txtSize = [initials sizeWithAttributes:attrs];
    CGRect txtRect = CGRectMake(0, (size - txtSize.height) * 0.5, size, txtSize.height);
    [initials drawInRect:txtRect withAttributes:attrs];

    if (isOnline) {
        CGFloat dotSize = MAX(10.0, size * 0.24);
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
        [[self sharedImageCache] setObject:img forKey:cacheKey];
    }
    return img;
}

+ (void)drawImageAspectFill:(UIImage *)img inRect:(CGRect)rect {
    if (!img || rect.size.width <= 0 || rect.size.height <= 0) return;
    CGSize imgSize = img.size;
    if (imgSize.width <= 0 || imgSize.height <= 0) {
        [img drawInRect:rect];
        return;
    }
    CGFloat scale = MAX(rect.size.width / imgSize.width, rect.size.height / imgSize.height);
    CGFloat drawW = imgSize.width * scale;
    CGFloat drawH = imgSize.height * scale;
    CGRect drawRect = CGRectMake(rect.origin.x + (rect.size.width - drawW) * 0.5,
                                 rect.origin.y + (rect.size.height - drawH) * 0.5,
                                 drawW,
                                 drawH);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (ctx) {
        CGContextSaveGState(ctx);
        CGContextClipToRect(ctx, rect);
        [img drawInRect:drawRect];
        CGContextRestoreGState(ctx);
    } else {
        [img drawInRect:drawRect];
    }
}

+ (UIImage *)avatarForURL:(nullable NSString *)urlString
             fallbackName:(NSString *)name
                 colorHex:(NSString *)colorHex
                     size:(CGFloat)size
             onCompletion:(nullable void (^)(void))completion {
    if (urlString.length > 8 && ![urlString hasSuffix:@"/default"]) {
        NSString *circKey = [NSString stringWithFormat:@"circ_af_%.0f_%@", size, urlString];
        UIImage *cachedCirc = [[self sharedImageCache] objectForKey:circKey];
        if (cachedCirc) {
            return cachedCirc;
        }
        UIImage *raw = [self cachedOrDiskRawImageForURL:urlString onCompletion:completion];
        if (raw) {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
            CGRect fullRect = CGRectMake(0, 0, size, size);
            UIBezierPath *clip = [UIBezierPath bezierPathWithOvalInRect:fullRect];
            [clip addClip];
            [self drawImageAspectFill:raw inRect:fullRect];
            UIImage *circled = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (circled) {
                [[self sharedImageCache] setObject:circled forKey:circKey];
                return circled;
            }
        }
    }
    NSString *initials = [CTDOCoreBridge initialsForName:name];
    return [self avatarWithInitials:initials colorHex:colorHex ?: @"#0068FF" size:size isOnline:NO];
}

+ (UIImage *)avatarForThread:(NSDictionary *)thread
                        size:(CGFloat)size
                onCompletion:(nullable void (^)(void))completion {
    BOOL isCloud = [thread[@"is_cloud"] boolValue] ||
                   [thread[@"name"] isEqualToString:@"My Documents"] ||
                   [thread[@"name"] hasPrefix:@"Cloud của tôi"];
    if (isCloud) {
        return [self myDocumentsAvatarWithSize:size];
    }

    NSString *avtUrl = [thread[@"avatar_url"] isKindOfClass:[NSString class]] ? thread[@"avatar_url"] : @"";
    NSString *name = thread[@"name"] ?: @"Z";
    NSString *hex = thread[@"avatar_color_hex"] ?: @"#0068FF";

    if (avtUrl.length > 8 && ![avtUrl hasSuffix:@"/default"]) {
        return [self avatarForURL:avtUrl fallbackName:name colorHex:hex size:size onCompletion:completion];
    }

    // Check if group has member_avatars for a 2x2 circular collage (like 신안산 Tháng 3/2027 in ref1.png)
    NSArray *members = [thread[@"member_avatars"] isKindOfClass:[NSArray class]] ? thread[@"member_avatars"] : nil;
    if ([thread[@"is_group"] boolValue] && members.count >= 2) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGFloat subSize = size * 0.50;
        CGPoint origins[4] = {
            CGPointMake(0, 0),
            CGPointMake(size - subSize, 0),
            CGPointMake(0, size - subSize),
            CGPointMake(size - subSize, size - subSize)
        };
        NSUInteger count = MIN((NSUInteger)4, members.count);
        for (NSUInteger i = 0; i < count; i++) {
            NSDictionary *m = [members[i] isKindOfClass:[NSDictionary class]] ? members[i] : @{};
            NSString *mName = m[@"name"] ?: @"T";
            NSString *mUrl = m[@"avatar"] ?: @"";
            NSString *mHex = [CTDOCoreBridge colorHexForThreadId:[NSString stringWithFormat:@"%@_%lu", mName, (unsigned long)i]];
            UIImage *subImg = [self avatarForURL:mUrl fallbackName:mName colorHex:mHex size:subSize onCompletion:completion];
            CGRect r = CGRectMake(origins[i].x, origins[i].y, subSize, subSize);
            CGContextSaveGState(ctx);
            [[[CTDOTheme shared] bgSecondary] setFill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectInset(r, -1.0, -1.0)] fill];
            [[UIBezierPath bezierPathWithOvalInRect:r] addClip];
            [self drawImageAspectFill:subImg inRect:r];
            CGContextRestoreGState(ctx);
        }
        UIImage *collage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (collage) return collage;
    }

    NSString *initials = thread[@"avatar_initials"] ?: [CTDOCoreBridge initialsForName:name];
    return [self avatarWithInitials:initials colorHex:hex size:size isOnline:NO];
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
        NSFontAttributeName: [UIFont boldSystemFontOfSize:size * 0.36],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSParagraphStyleAttributeName: pStyle
    };
    NSString *txt = @"Zalo";
    CGSize s = [txt sizeWithAttributes:attrs];
    [txt drawInRect:CGRectMake(0, (size - s.height) * 0.5, size, s.height) withAttributes:attrs];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// ============================================================================
// Crisp CoreGraphics Vector Icons Matching Official Zalo iOS (ref1..ref5)
// ============================================================================
+ (UIImage *)searchIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    CGFloat r = size * 0.32;
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.14, size * 0.14, r * 2, r * 2)];
    circle.lineWidth = 1.8;
    [circle stroke];
    UIBezierPath *handle = [UIBezierPath bezierPath];
    [handle moveToPoint:CGPointMake(size * 0.64, size * 0.64)];
    [handle addLineToPoint:CGPointMake(size * 0.86, size * 0.86)];
    handle.lineWidth = 1.8;
    handle.lineCapStyle = kCGLineCapRound;
    [handle stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)qrScanIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    CGFloat p = size * 0.14;
    CGFloat c = size * 0.22;
    UIBezierPath *path = [UIBezierPath bezierPath];
    // Top-left bracket
    [path moveToPoint:CGPointMake(p, p + c)];
    [path addLineToPoint:CGPointMake(p, p)];
    [path addLineToPoint:CGPointMake(p + c, p)];
    // Top-right bracket
    [path moveToPoint:CGPointMake(size - p - c, p)];
    [path addLineToPoint:CGPointMake(size - p, p)];
    [path addLineToPoint:CGPointMake(size - p, p + c)];
    // Bottom-left bracket
    [path moveToPoint:CGPointMake(p, size - p - c)];
    [path addLineToPoint:CGPointMake(p, size - p)];
    [path addLineToPoint:CGPointMake(p + c, size - p)];
    // Bottom-right bracket
    [path moveToPoint:CGPointMake(size - p - c, size - p)];
    [path addLineToPoint:CGPointMake(size - p, size - p)];
    [path addLineToPoint:CGPointMake(size - p, size - p - c)];
    path.lineWidth = 1.6;
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;
    [path stroke];

    // Inner QR squares
    CGFloat sq = size * 0.16;
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.28, size * 0.28, sq, sq) cornerRadius:1.5] stroke];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.56, size * 0.28, sq, sq) cornerRadius:1.5] stroke];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.28, size * 0.56, sq, sq) cornerRadius:1.5] stroke];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.56, size * 0.56, sq, sq) cornerRadius:1.5] stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)plusIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(size * 0.5, size * 0.16)];
    [p addLineToPoint:CGPointMake(size * 0.5, size * 0.84)];
    [p moveToPoint:CGPointMake(size * 0.16, size * 0.5)];
    [p addLineToPoint:CGPointMake(size * 0.84, size * 0.5)];
    p.lineWidth = 1.8;
    p.lineCapStyle = kCGLineCapRound;
    [p stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)gearIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    CGPoint center = CGPointMake(size * 0.5, size * 0.5);
    UIBezierPath *outer = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.22, size * 0.22, size * 0.56, size * 0.56)];
    outer.lineWidth = 1.7;
    [outer stroke];
    UIBezierPath *inner = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.38, size * 0.38, size * 0.24, size * 0.24)];
    inner.lineWidth = 1.6;
    [inner stroke];
    for (int i = 0; i < 8; i++) {
        CGFloat angle = i * (M_PI / 4.0);
        UIBezierPath *tooth = [UIBezierPath bezierPath];
        [tooth moveToPoint:CGPointMake(center.x + cos(angle) * size * 0.28, center.y + sin(angle) * size * 0.28)];
        [tooth addLineToPoint:CGPointMake(center.x + cos(angle) * size * 0.41, center.y + sin(angle) * size * 0.41)];
        tooth.lineWidth = 2.0;
        tooth.lineCapStyle = kCGLineCapRound;
        [tooth stroke];
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)backChevronIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(size * 0.65, size * 0.18)];
    [p addLineToPoint:CGPointMake(size * 0.28, size * 0.50)];
    [p addLineToPoint:CGPointMake(size * 0.65, size * 0.82)];
    p.lineWidth = 2.0;
    p.lineCapStyle = kCGLineCapRound;
    p.lineJoinStyle = kCGLineJoinRound;
    [p stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)phoneCallIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(size * 0.26, size * 0.20)];
    [p addLineToPoint:CGPointMake(size * 0.38, size * 0.20)];
    [p addLineToPoint:CGPointMake(size * 0.44, size * 0.36)];
    [p addLineToPoint:CGPointMake(size * 0.35, size * 0.44)];
    [p addQuadCurveToPoint:CGPointMake(size * 0.56, size * 0.65) controlPoint:CGPointMake(size * 0.42, size * 0.58)];
    [p addLineToPoint:CGPointMake(size * 0.64, size * 0.56)];
    [p addLineToPoint:CGPointMake(size * 0.80, size * 0.62)];
    [p addLineToPoint:CGPointMake(size * 0.80, size * 0.74)];
    [p addQuadCurveToPoint:CGPointMake(size * 0.26, size * 0.20) controlPoint:CGPointMake(size * 0.32, size * 0.78)];
    p.lineWidth = 1.6;
    p.lineJoinStyle = kCGLineJoinRound;
    [p stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)videoCallIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    UIBezierPath *box = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.14, size * 0.26, size * 0.50, size * 0.48) cornerRadius:4.0];
    box.lineWidth = 1.6;
    [box stroke];
    UIBezierPath *lens = [UIBezierPath bezierPath];
    [lens moveToPoint:CGPointMake(size * 0.64, size * 0.42)];
    [lens addLineToPoint:CGPointMake(size * 0.86, size * 0.30)];
    [lens addLineToPoint:CGPointMake(size * 0.86, size * 0.70)];
    [lens addLineToPoint:CGPointMake(size * 0.64, size * 0.58)];
    lens.lineWidth = 1.6;
    lens.lineJoinStyle = kCGLineJoinRound;
    [lens stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)addFriendIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    UIBezierPath *head = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.24, size * 0.18, size * 0.32, size * 0.32)];
    head.lineWidth = 1.6;
    [head stroke];
    UIBezierPath *shoulders = [UIBezierPath bezierPath];
    [shoulders moveToPoint:CGPointMake(size * 0.14, size * 0.80)];
    [shoulders addQuadCurveToPoint:CGPointMake(size * 0.66, size * 0.80) controlPoint:CGPointMake(size * 0.40, size * 0.52)];
    shoulders.lineWidth = 1.6;
    shoulders.lineCapStyle = kCGLineCapRound;
    [shoulders stroke];
    UIBezierPath *plus = [UIBezierPath bezierPath];
    [plus moveToPoint:CGPointMake(size * 0.78, size * 0.38)];
    [plus addLineToPoint:CGPointMake(size * 0.78, size * 0.62)];
    [plus moveToPoint:CGPointMake(size * 0.66, size * 0.50)];
    [plus addLineToPoint:CGPointMake(size * 0.90, size * 0.50)];
    plus.lineWidth = 1.6;
    plus.lineCapStyle = kCGLineCapRound;
    [plus stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)groupPrefixIconWithSize:(CGFloat)size {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    // Light blue-gray rounded pill (#EBF1F8) with blue people silhouettes (#4B7BEC) matching ref1.png
    [[UIColor colorWithRed:0.91 green:0.94 blue:0.98 alpha:1.0] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:size * 0.32] fill];

    UIColor *fg = [UIColor colorWithRed:0.32 green:0.53 blue:0.85 alpha:1.0];
    [fg setFill];
    // Center person head + shoulders
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.36, size * 0.22, size * 0.28, size * 0.28)] fill];
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.22, size * 0.54, size * 0.56, size * 0.26) cornerRadius:size * 0.12];
    [body fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)pinIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setFill];
    [color setStroke];
    UIBezierPath *head = [UIBezierPath bezierPath];
    [head moveToPoint:CGPointMake(size * 0.35, size * 0.20)];
    [head addLineToPoint:CGPointMake(size * 0.80, size * 0.65)];
    [head addLineToPoint:CGPointMake(size * 0.62, size * 0.72)];
    [head addLineToPoint:CGPointMake(size * 0.28, size * 0.38)];
    [head closePath];
    [head fill];
    UIBezierPath *needle = [UIBezierPath bezierPath];
    [needle moveToPoint:CGPointMake(size * 0.45, size * 0.55)];
    [needle addLineToPoint:CGPointMake(size * 0.18, size * 0.82)];
    needle.lineWidth = 1.5;
    needle.lineCapStyle = kCGLineCapRound;
    [needle stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)mutedBellIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setFill];
    [color setStroke];
    UIBezierPath *bell = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.24, size * 0.20, size * 0.52, size * 0.52) cornerRadius:size * 0.24];
    [bell fill];
    [[UIBezierPath bezierPathWithRect:CGRectMake(size * 0.16, size * 0.64, size * 0.68, size * 0.10)] fill];
    UIBezierPath *slash = [UIBezierPath bezierPath];
    [slash moveToPoint:CGPointMake(size * 0.18, size * 0.18)];
    [slash addLineToPoint:CGPointMake(size * 0.82, size * 0.82)];
    slash.lineWidth = 1.8;
    [[[CTDOTheme shared] bgSecondary] setStroke];
    [slash stroke];
    [color setStroke];
    slash.lineWidth = 1.2;
    [slash stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)tabIconForIndex:(NSInteger)tabIndex selected:(BOOL)selected {
    CGFloat size = 24.0;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    UIColor *color = selected
        ? [UIColor colorWithRed:0.00 green:0.41 blue:1.00 alpha:1.0]
        : [UIColor colorWithRed:0.45 green:0.48 blue:0.53 alpha:1.0];
    [color setStroke];
    [color setFill];

    if (tabIndex == 0) {
        // Tin nhắn: Chat bubble with 2 lines inside (filled when selected, outline when unselected)
        UIBezierPath *bubble = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 3, 20, 15) cornerRadius:7.5];
        [bubble moveToPoint:CGPointMake(6, 18)];
        [bubble addLineToPoint:CGPointMake(4, 22)];
        [bubble addLineToPoint:CGPointMake(10, 18)];
        bubble.lineWidth = 1.6;
        if (selected) {
            [bubble fill];
            [[UIColor whiteColor] setStroke];
        } else {
            [bubble stroke];
        }
        UIBezierPath *lines = [UIBezierPath bezierPath];
        [lines moveToPoint:CGPointMake(7, 9)];
        [lines addLineToPoint:CGPointMake(17, 9)];
        [lines moveToPoint:CGPointMake(7, 13)];
        [lines addLineToPoint:CGPointMake(13, 13)];
        lines.lineWidth = 1.6;
        lines.lineCapStyle = kCGLineCapRound;
        [lines stroke];
    } else if (tabIndex == 1) {
        // Danh bạ: Contact card rectangle with person icon inside (ref3.png)
        UIBezierPath *card = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 2.5, 16, 19) cornerRadius:2.5];
        card.lineWidth = 1.6;
        if (selected) {
            [card fill];
            [[UIColor whiteColor] setFill];
            [[UIColor whiteColor] setStroke];
        } else {
            [card stroke];
        }
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5, 6.5, 5.0, 5.0)] fill];
        UIBezierPath *sh = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.5, 13.0, 9.0, 4.5) cornerRadius:2.2];
        [sh fill];
    } else if (tabIndex == 2) {
        // Khám phá: 4 squares with top-right rotated diamond (ref1.png)
        CGFloat s = 7.0;
        UIBezierPath *b1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.5, 3.5, s, s) cornerRadius:1.5];
        UIBezierPath *b3 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.5, 13.5, s, s) cornerRadius:1.5];
        UIBezierPath *b4 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(13.5, 13.5, s, s) cornerRadius:1.5];
        b1.lineWidth = 1.5; b3.lineWidth = 1.5; b4.lineWidth = 1.5;
        if (selected) { [b1 fill]; [b3 fill]; [b4 fill]; } else { [b1 stroke]; [b3 stroke]; [b4 stroke]; }
        UIBezierPath *diamond = [UIBezierPath bezierPath];
        [diamond moveToPoint:CGPointMake(17.0, 2.5)];
        [diamond addLineToPoint:CGPointMake(21.5, 7.0)];
        [diamond addLineToPoint:CGPointMake(17.0, 11.5)];
        [diamond addLineToPoint:CGPointMake(12.5, 7.0)];
        [diamond closePath];
        diamond.lineWidth = 1.5;
        if (selected) [diamond fill]; else [diamond stroke];
    } else if (tabIndex == 3) {
        // Tường nhà: Timeline card with header line (ref1.png)
        UIBezierPath *card = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 3.5, 18, 17) cornerRadius:3.5];
        card.lineWidth = 1.6;
        [card stroke];
        UIBezierPath *top = [UIBezierPath bezierPath];
        [top moveToPoint:CGPointMake(3, 9.5)];
        [top addLineToPoint:CGPointMake(21, 9.5)];
        top.lineWidth = 1.4;
        [top stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(6, 5.5, 2.5, 2.5)] fill];
    } else {
        // Cá nhân: Person silhouette (ref4.png)
        UIBezierPath *head = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.0, 3.0, 8.0, 8.0)];
        head.lineWidth = 1.6;
        UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4.5, 13.0, 15.0, 7.5) cornerRadius:3.8];
        body.lineWidth = 1.6;
        if (selected) {
            [head fill];
            [body fill];
        } else {
            [head stroke];
            [body stroke];
        }
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)phoneSyncIconWithSize:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    [color setFill];
    // Smartphone outline
    UIBezierPath *phone = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.24, size * 0.10, size * 0.52, size * 0.80)
                                                     cornerRadius:size * 0.10];
    phone.lineWidth = 1.65;
    [phone stroke];
    // Top speaker notch
    UIBezierPath *speaker = [UIBezierPath bezierPath];
    [speaker moveToPoint:CGPointMake(size * 0.42, size * 0.18)];
    [speaker addLineToPoint:CGPointMake(size * 0.58, size * 0.18)];
    speaker.lineWidth = 1.4;
    speaker.lineCapStyle = kCGLineCapRound;
    [speaker stroke];
    // Sync circular arrows inside phone screen
    UIBezierPath *arc1 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size * 0.50, size * 0.52)
                                                        radius:size * 0.14
                                                    startAngle:-M_PI * 0.8
                                                      endAngle:0.0
                                                     clockwise:YES];
    arc1.lineWidth = 1.45;
    [arc1 stroke];
    UIBezierPath *arc2 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size * 0.50, size * 0.52)
                                                        radius:size * 0.14
                                                    startAngle:M_PI * 0.2
                                                      endAngle:M_PI
                                                     clockwise:YES];
    arc2.lineWidth = 1.45;
    [arc2 stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)menuRowIconNamed:(NSString *)iconKey color:(UIColor *)color size:(CGFloat)size {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    [color setStroke];
    [color setFill];
    if ([iconKey isEqualToString:@"shield"] || [iconKey isEqualToString:@"security"]) {
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(size * 0.5, size * 0.12)];
        [p addLineToPoint:CGPointMake(size * 0.84, size * 0.26)];
        [p addLineToPoint:CGPointMake(size * 0.84, size * 0.54)];
        [p addQuadCurveToPoint:CGPointMake(size * 0.5, size * 0.88) controlPoint:CGPointMake(size * 0.80, size * 0.78)];
        [p addQuadCurveToPoint:CGPointMake(size * 0.16, size * 0.54) controlPoint:CGPointMake(size * 0.20, size * 0.78)];
        [p addLineToPoint:CGPointMake(size * 0.16, size * 0.26)];
        [p closePath];
        p.lineWidth = 1.65;
        p.lineJoinStyle = kCGLineJoinRound;
        [p stroke];
        UIBezierPath *chk = [UIBezierPath bezierPath];
        [chk moveToPoint:CGPointMake(size * 0.36, size * 0.50)];
        [chk addLineToPoint:CGPointMake(size * 0.46, size * 0.60)];
        [chk addLineToPoint:CGPointMake(size * 0.65, size * 0.40)];
        chk.lineWidth = 1.6;
        chk.lineCapStyle = kCGLineCapRound;
        chk.lineJoinStyle = kCGLineJoinRound;
        [chk stroke];
    } else if ([iconKey isEqualToString:@"lock"] || [iconKey isEqualToString:@"privacy"]) {
        UIBezierPath *box = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.22, size * 0.44, size * 0.56, size * 0.42) cornerRadius:3.5];
        box.lineWidth = 1.65;
        [box stroke];
        UIBezierPath *shackle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size * 0.5, size * 0.38) radius:size * 0.17 startAngle:M_PI endAngle:0 clockwise:YES];
        shackle.lineWidth = 1.65;
        [shackle stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.45, size * 0.59, size * 0.10, size * 0.10)] fill];
    } else if ([iconKey isEqualToString:@"pie"] || [iconKey isEqualToString:@"storage"]) {
        UIBezierPath *c = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.15, size * 0.15, size * 0.70, size * 0.70)];
        c.lineWidth = 1.65;
        [c stroke];
        UIBezierPath *w = [UIBezierPath bezierPath];
        [w moveToPoint:CGPointMake(size * 0.50, size * 0.15)];
        [w addLineToPoint:CGPointMake(size * 0.50, size * 0.50)];
        [w addLineToPoint:CGPointMake(size * 0.82, size * 0.38)];
        w.lineWidth = 1.65;
        w.lineJoinStyle = kCGLineJoinRound;
        [w stroke];
    } else if ([iconKey isEqualToString:@"cloud"] || [iconKey isEqualToString:@"backup"]) {
        UIBezierPath *c = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.14, size * 0.40, size * 0.72, size * 0.34) cornerRadius:size * 0.17];
        c.lineWidth = 1.65;
        [c stroke];
        UIBezierPath *top = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size * 0.48, size * 0.40) radius:size * 0.18 startAngle:M_PI endAngle:0 clockwise:YES];
        top.lineWidth = 1.65;
        [top stroke];
        if ([iconKey isEqualToString:@"backup"]) {
            UIBezierPath *arr = [UIBezierPath bezierPath];
            [arr moveToPoint:CGPointMake(size * 0.50, size * 0.66)];
            [arr addLineToPoint:CGPointMake(size * 0.50, size * 0.44)];
            [arr moveToPoint:CGPointMake(size * 0.41, size * 0.52)];
            [arr addLineToPoint:CGPointMake(size * 0.50, size * 0.43)];
            [arr addLineToPoint:CGPointMake(size * 0.59, size * 0.52)];
            arr.lineWidth = 1.5;
            arr.lineCapStyle = kCGLineCapRound;
            arr.lineJoinStyle = kCGLineJoinRound;
            [arr stroke];
        }
    } else if ([iconKey isEqualToString:@"sync_phone"]) {
        UIImage *ps = [self phoneSyncIconWithSize:size color:color];
        [ps drawInRect:CGRectMake(0, 0, size, size)];
    } else if ([iconKey isEqualToString:@"folder"] || [iconKey isEqualToString:@"mydocs"]) {
        UIBezierPath *f = [UIBezierPath bezierPath];
        [f moveToPoint:CGPointMake(size * 0.14, size * 0.26)];
        [f addLineToPoint:CGPointMake(size * 0.40, size * 0.26)];
        [f addLineToPoint:CGPointMake(size * 0.48, size * 0.34)];
        [f addLineToPoint:CGPointMake(size * 0.86, size * 0.34)];
        [f addLineToPoint:CGPointMake(size * 0.86, size * 0.78)];
        [f addLineToPoint:CGPointMake(size * 0.14, size * 0.78)];
        [f closePath];
        f.lineWidth = 1.65;
        f.lineJoinStyle = kCGLineJoinRound;
        [f stroke];
    } else if ([iconKey isEqualToString:@"qr_wallet"]) {
        UIImage *qr = [self qrScanIconWithSize:size color:color];
        [qr drawInRect:CGRectMake(0, 0, size, size)];
    } else if ([iconKey isEqualToString:@"bell"] || [iconKey isEqualToString:@"notif"]) {
        UIBezierPath *b = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.24, size * 0.18, size * 0.52, size * 0.50) cornerRadius:size * 0.24];
        b.lineWidth = 1.65;
        [b stroke];
        UIBezierPath *base = [UIBezierPath bezierPath];
        [base moveToPoint:CGPointMake(size * 0.16, size * 0.68)];
        [base addLineToPoint:CGPointMake(size * 0.84, size * 0.68)];
        base.lineWidth = 1.65;
        base.lineCapStyle = kCGLineCapRound;
        [base stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.43, size * 0.73, size * 0.14, size * 0.12)] fill];
    } else if ([iconKey isEqualToString:@"msg"]) {
        UIBezierPath *bub = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.14, size * 0.18, size * 0.72, size * 0.54) cornerRadius:size * 0.22];
        bub.lineWidth = 1.65;
        [bub stroke];
        UIBezierPath *ln = [UIBezierPath bezierPath];
        [ln moveToPoint:CGPointMake(size * 0.30, size * 0.38)];
        [ln addLineToPoint:CGPointMake(size * 0.70, size * 0.38)];
        [ln moveToPoint:CGPointMake(size * 0.30, size * 0.52)];
        [ln addLineToPoint:CGPointMake(size * 0.56, size * 0.52)];
        ln.lineWidth = 1.5;
        ln.lineCapStyle = kCGLineCapRound;
        [ln stroke];
    } else if ([iconKey isEqualToString:@"call"]) {
        UIImage *ph = [self phoneCallIconWithSize:size color:color];
        [ph drawInRect:CGRectMake(0, 0, size, size)];
    } else if ([iconKey isEqualToString:@"journal"] || [iconKey isEqualToString:@"game"]) {
        UIBezierPath *c = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.15, size * 0.15, size * 0.70, size * 0.70)];
        c.lineWidth = 1.65;
        [c stroke];
        UIBezierPath *hands = [UIBezierPath bezierPath];
        [hands moveToPoint:CGPointMake(size * 0.50, size * 0.30)];
        [hands addLineToPoint:CGPointMake(size * 0.50, size * 0.52)];
        [hands addLineToPoint:CGPointMake(size * 0.66, size * 0.60)];
        hands.lineWidth = 1.65;
        hands.lineCapStyle = kCGLineCapRound;
        hands.lineJoinStyle = kCGLineJoinRound;
        [hands stroke];
    } else if ([iconKey isEqualToString:@"video"]) {
        UIImage *vd = [self videoCallIconWithSize:size color:color];
        [vd drawInRect:CGRectMake(0, 0, size, size)];
    } else if ([iconKey isEqualToString:@"contacts"]) {
        UIBezierPath *card = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.20, size * 0.14, size * 0.60, size * 0.72) cornerRadius:3.5];
        card.lineWidth = 1.65;
        [card stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.40, size * 0.28, size * 0.20, size * 0.20)] stroke];
        UIBezierPath *sh = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.32, size * 0.54, size * 0.36, size * 0.18) cornerRadius:3.0];
        sh.lineWidth = 1.5;
        [sh stroke];
    } else if ([iconKey isEqualToString:@"brush"] || [iconKey isEqualToString:@"theme"] || [iconKey isEqualToString:@"style"]) {
        UIBezierPath *b = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.22, size * 0.18, size * 0.56, size * 0.32) cornerRadius:4.0];
        b.lineWidth = 1.65;
        [b stroke];
        UIBezierPath *h = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.42, size * 0.50, size * 0.16, size * 0.34) cornerRadius:2.5];
        h.lineWidth = 1.65;
        [h stroke];
    } else if ([iconKey isEqualToString:@"info"]) {
        UIBezierPath *c = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.15, size * 0.15, size * 0.70, size * 0.70)];
        c.lineWidth = 1.65;
        [c stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.46, size * 0.28, size * 0.08, size * 0.08)] fill];
        UIBezierPath *st = [UIBezierPath bezierPath];
        [st moveToPoint:CGPointMake(size * 0.50, size * 0.44)];
        [st addLineToPoint:CGPointMake(size * 0.50, size * 0.70)];
        st.lineWidth = 1.8;
        st.lineCapStyle = kCGLineCapRound;
        [st stroke];
    } else if ([iconKey isEqualToString:@"help"]) {
        UIBezierPath *c = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.15, size * 0.15, size * 0.70, size * 0.70)];
        c.lineWidth = 1.65;
        [c stroke];
        UIBezierPath *q = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size * 0.50, size * 0.40)
                                                         radius:size * 0.11
                                                     startAngle:M_PI * 1.1
                                                       endAngle:M_PI * 0.25
                                                      clockwise:YES];
        [q addLineToPoint:CGPointMake(size * 0.50, size * 0.57)];
        q.lineWidth = 1.65;
        q.lineCapStyle = kCGLineCapRound;
        [q stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.46, size * 0.66, size * 0.08, size * 0.08)] fill];
    } else if ([iconKey isEqualToString:@"switch_user"] || [iconKey isEqualToString:@"switch_acc"]) {
        UIBezierPath *h = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.26, size * 0.16, size * 0.30, size * 0.30)];
        h.lineWidth = 1.65;
        [h stroke];
        UIBezierPath *s = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size * 0.14, size * 0.52, size * 0.54, size * 0.26) cornerRadius:size * 0.12];
        s.lineWidth = 1.65;
        [s stroke];
        UIBezierPath *arr = [UIBezierPath bezierPath];
        [arr moveToPoint:CGPointMake(size * 0.66, size * 0.34)];
        [arr addLineToPoint:CGPointMake(size * 0.88, size * 0.34)];
        [arr moveToPoint:CGPointMake(size * 0.80, size * 0.26)];
        [arr addLineToPoint:CGPointMake(size * 0.88, size * 0.34)];
        [arr addLineToPoint:CGPointMake(size * 0.80, size * 0.42)];
        arr.lineWidth = 1.5;
        arr.lineCapStyle = kCGLineCapRound;
        arr.lineJoinStyle = kCGLineJoinRound;
        [arr stroke];
    } else {
        UIBezierPath *c = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(size * 0.16, size * 0.16, size * 0.68, size * 0.68)];
        c.lineWidth = 1.65;
        [c stroke];
    }
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
@property (nonatomic, copy) NSString *status;
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
            slot.cookies[@"_zlang"] = @"vi";
            [req setValue:slot.zpwSek forHTTPHeaderField:@"zpw_sek"];
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
    if (![envelope isKindOfClass:[NSDictionary class]]) {
        return envelope;
    }
    NSDictionary *dict = (NSDictionary *)envelope;
    id dataNode = dict[@"data"];
    if ([dataNode isKindOfClass:[NSString class]]) {
        NSString *strVal = [(NSString *)dataNode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (strVal.length > 0) {
            // Case 1: Plain JSON string inside "data" (e.g. getlg/v4, getmg-v2, getrecentv2)
            if (([strVal hasPrefix:@"{"] && [strVal hasSuffix:@"}"]) ||
                ([strVal hasPrefix:@"["] && [strVal hasSuffix:@"]"])) {
                NSData *jd = [strVal dataUsingEncoding:NSUTF8StringEncoding];
                id parsed = jd ? [NSJSONSerialization JSONObjectWithData:jd options:NSJSONReadingAllowFragments error:nil] : nil;
                if (parsed) {
                    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:dict];
                    merged[@"data"] = parsed;
                    if ([parsed isKindOfClass:[NSDictionary class]] && parsed[@"data"] != nil) {
                        return [self decryptZaloEnvelope:merged withKeyData:keyData];
                    }
                    return merged;
                }
            }
            // Case 2: Base64 AES-CBC encrypted "data"
            if (keyData != nil) {
                NSData *decData = [CTDOCoreBridge aesCBCDecryptBase64:strVal keyData:keyData];
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
    } else if ([dataNode isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dn = (NSDictionary *)dataNode;
        if ([dn[@"data"] isKindOfClass:[NSString class]]) {
            NSString *innerStr = [(NSString *)dn[@"data"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (([innerStr hasPrefix:@"{"] && [innerStr hasSuffix:@"}"]) ||
                ([innerStr hasPrefix:@"["] && [innerStr hasSuffix:@"]"])) {
                NSData *jd = [innerStr dataUsingEncoding:NSUTF8StringEncoding];
                id parsed = jd ? [NSJSONSerialization JSONObjectWithData:jd options:NSJSONReadingAllowFragments error:nil] : nil;
                if (parsed) {
                    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:dict];
                    merged[@"data"] = parsed;
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
        slot.cookies[@"_zlang"] = @"vi";
        if ([sdoc[@"host_lp_chat"] length] > 0) slot.hostLpChat = sdoc[@"host_lp_chat"];

        if ([sdoc[@"threads"] isKindOfClass:[NSArray class]]) {
            for (NSDictionary *t in sdoc[@"threads"]) {
                if ([t isKindOfClass:[NSDictionary class]]) {
                    NSMutableDictionary *mt = [t mutableCopy];
                    if ([mt[@"id"] isEqualToString:slot.send2meId] || [mt[@"name"] hasPrefix:@"Cloud của tôi"]) {
                        mt[@"name"] = @"My Documents";
                        mt[@"is_cloud"] = @(YES);
                        mt[@"is_pinned"] = @(YES);
                    }
                    if ([mt[@"last_message"] isEqualToString:@"Chưa có tin nhắn"]) {
                        NSInteger totMem = [mt[@"total_members"] integerValue];
                        mt[@"last_message"] = ([mt[@"is_group"] boolValue] && totMem > 0)
                            ? [NSString stringWithFormat:@"Nhóm · %ld thành viên", (long)totMem]
                            : @"";
                    }
                    int64_t ts = [mt[@"last_ts"] longLongValue];
                    if (ts > 0) {
                        mt[@"last_time_label"] = [CTDOCoreBridge relativeTimeLabelFromTimestampMs:ts];
                    }
                    [slot.threads addObject:mt];
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
            // Trigger an immediate background sync so real friends, avatars & previews populate
            dispatch_async(self.netQueue, ^{
                [self syncMyProfileForSlot:slot];
                [self syncRealThreadsAndMessagesForSlot:slot];
                [self saveSlotSession:slot];
                [self startBackgroundSyncAndPollingForSlot:slot];
            });
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
        BOOL isAuthed = [rt.status isEqualToString:@"authenticated"];
        return @{
            @"slot": @(rt.slotIndex),
            @"authenticated": @(isAuthed),
            @"status": rt.status ?: @"unauthenticated",
            @"status_message": rt.statusMessage ?: @"",
            @"status_text": rt.statusMessage ?: @"",
            @"qr_payload": rt.qrPayload ?: @"",
            @"qr_image_b64": rt.qrImageBase64 ?: @"",
            @"qr_image_base64": rt.qrImageBase64 ?: @"",
            @"qr_token_id": rt.qrTokenId ?: @"",
            @"uid": rt.uid ?: @"",
            @"send2me_id": rt.send2meId ?: @"",
            @"display_name": rt.displayName ?: @"",
            @"avatar_url": rt.avatarUrl ?: @"",
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

    if (b64Qr.length == 0 && qrCnt.length > 0) {
        UIImage *genQr = [CTDOIconRenderer qrCodeImageForString:qrCnt size:420.0];
        NSData *pngData = genQr ? UIImagePNGRepresentation(genQr) : nil;
        if (pngData.length > 0) {
            b64Qr = [pngData base64EncodedStringWithOptions:0] ?: @"";
        }
    }

    @synchronized (rt) {
        if (rt.qrGeneration != gen) return;
        rt.qrPayload = qrCnt;
        rt.qrImageBase64 = b64Qr;
        rt.qrTokenId = tokenId;
        rt.chkWaitScan = waitScan;
        rt.chkWaitCfirm = waitCfirm;
        rt.status = @"qr_waiting_scan";
        rt.statusMessage = [NSString stringWithFormat:@"Mở Zalo trên điện thoại → Quét mã QR này để đăng nhập & đồng bộ (Hiệu lực %lds)", (long)qrTimeout];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"CTDOAuthDidUpdateNotification" object:@(rt.slotIndex)];
    });

    if (waitScan.length == 0) {
        return;
    }

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

    [self syncMyProfileForSlot:rt];

    @synchronized (rt) {
        rt.status = @"authenticated";
        rt.statusMessage = [NSString stringWithFormat:@"✓ Đã đăng nhập: %@ (UID: %@)",
                            rt.displayName.length > 0 ? rt.displayName : @"Tài khoản Zalo",
                            rt.uid];
    }

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
// Real Zalo Chat Sync (me-v2, getfriends, getlg/v4, getmg-v2, group/members, preloadconvers/get-last-msgs, cm/getrecentv2)
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
    NSArray *hosts = @[rt.hostProfile, @"https://tt-profile-wpa.chat.zalo.me", @"https://tt-profile-wpa.zaloapp.com"];
    for (NSString *h in hosts) {
        NSString *url = [NSString stringWithFormat:@"%@/api/social/profile/me-v2?zpw_ver=%@&zpw_type=%@&params=%@&os=8",
                         h, kZaloZpwVer, kZaloZpwType, enc];
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
                break;
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

+ (NSString *)relativeTimeLabelFromTimestampMs:(int64_t)tsMs {
    if (tsMs <= 0) return @"";
    NSTimeInterval sec = (tsMs > 20000000000LL) ? ((double)tsMs / 1000.0) : (double)tsMs;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval diff = MAX(0.0, now - sec);
    if (diff < 60.0) {
        NSInteger s = MAX(1, (NSInteger)round(diff));
        return [NSString stringWithFormat:@"%ld giây", (long)s];
    }
    if (diff < 3600.0) {
        NSInteger m = MAX(1, (NSInteger)(diff / 60.0));
        return [NSString stringWithFormat:@"%ld phút", (long)m];
    }
    if (diff < 86400.0) {
        NSInteger h = MAX(1, (NSInteger)(diff / 3600.0));
        return [NSString stringWithFormat:@"%ld giờ", (long)h];
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:sec];
    if (diff < 86400.0 * 6.5) {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSInteger wd = [cal component:NSCalendarUnitWeekday fromDate:date]; // 1 = Sun, 2 = Mon .. 7 = Sat
        if (wd == 1) return @"CN";
        return [NSString stringWithFormat:@"T%ld", (long)wd];
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"dd/MM";
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
        NSMutableDictionary *t = [NSMutableDictionary dictionaryWithDictionary:@{
            @"id": tid,
            @"name": finalName,
            @"subtitle_tag": isGroup ? @"Nhóm" : @"Bạn bè",
            @"avatar_url": @"",
            @"member_avatars": @[],
            @"total_members": @(0),
            @"avatar_initials": [CTDOCoreBridge initialsForName:finalName],
            @"avatar_color_hex": [CTDOCoreBridge colorHexForThreadId:tid],
            @"last_message": @"",
            @"last_time_label": @"",
            @"last_ts": @(0),
            @"unread_count": @(0),
            @"is_pinned": @(NO),
            @"is_muted": @(NO),
            @"is_hidden": @(NO),
            @"is_group": @(isGroup),
            @"is_friend": @(!isGroup),
            @"is_cloud": @(NO),
            @"is_business": @(NO),
            @"is_other": @(NO),
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
            NSString *rawContent = newest[@"content"] ?: @"";
            BOOL newestSelf = [newest[@"is_self"] boolValue];
            NSString *newestSender = newest[@"sender_name"] ?: @"";
            NSString *previewText = rawContent;
            if (newestSelf) {
                if (![rawContent hasPrefix:@"Bạn: "]) {
                    previewText = [NSString stringWithFormat:@"Bạn: %@", rawContent];
                }
            } else if (isGroup && newestSender.length > 0 && ![newestSender isEqualToString:tid]) {
                previewText = [NSString stringWithFormat:@"%@: %@", newestSender, rawContent];
            }
            thread[@"last_message"] = previewText;
            int64_t nTs = [newest[@"timestamp_ms"] longLongValue];
            thread[@"last_time_label"] = [CTDOCoreBridge relativeTimeLabelFromTimestampMs:nTs];
            thread[@"last_ts"] = @(nTs);
        }
    }
}

- (NSDictionary<NSString *, NSDictionary *> *)fetchMiniProfilesForUserIds:(NSArray<NSString *> *)uids inSlot:(CTDOSlotRuntime *)rt {
    if (uids.count == 0 || !rt.secretKeyData) return @{};
    NSMutableArray<NSString *> *versioned = [NSMutableArray array];
    for (NSString *u in uids) {
        NSString *clean = [u stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (clean.length == 0) continue;
        if ([clean containsString:@"_"]) {
            [versioned addObject:clean];
        } else {
            [versioned addObject:[NSString stringWithFormat:@"%@_0", clean]];
        }
    }
    if (versioned.count == 0) return @{};
    NSString *enc = [self encodeAuthenticatedParams:@{@"friend_pversion_map": versioned} forSlot:rt];
    if (!enc) return @{};
    NSArray *hosts = @[rt.hostProfile, @"https://tt-profile-wpa.chat.zalo.me", @"https://tt-profile-wpa.zaloapp.com"];
    for (NSString *h in hosts) {
        NSString *url = [NSString stringWithFormat:@"%@/api/social/group/members?zpw_ver=%@&zpw_type=%@",
                         h, kZaloZpwVer, kZaloZpwType];
        NSDictionary *resp = [self sendSyncHTTPForSlot:rt
                                                method:@"POST"
                                                   url:url
                                              formBody:[NSString stringWithFormat:@"params=%@", enc]
                                               timeout:12.0];
        id dec = [self decryptZaloEnvelope:resp[@"json"] withKeyData:rt.secretKeyData];
        if ([dec isKindOfClass:[NSDictionary class]]) {
            NSDictionary *profs = dec[@"data"][@"profiles"] ?: (dec[@"profiles"] ?: dec[@"data"]);
            if ([profs isKindOfClass:[NSDictionary class]] && profs.count > 0) {
                return profs;
            }
        }
    }
    return @{};
}

- (void)syncRealThreadsAndMessagesForSlot:(CTDOSlotRuntime *)rt {
    if (!rt.secretKeyData || rt.zpwSek.length == 0) return;

    // 1. Add My Documents (Cloud của tôi / send2me_id) matching ref1.png & ref4.png
    if (rt.send2meId.length > 0) {
        NSMutableDictionary *cloudThread = [self ensureThreadInSlot:rt
                                                           threadId:rt.send2meId
                                                               name:@"My Documents"
                                                            isGroup:NO];
        @synchronized (rt) {
            cloudThread[@"name"] = @"My Documents";
            cloudThread[@"is_pinned"] = @(YES);
            cloudThread[@"is_cloud"] = @(YES);
            cloudThread[@"is_friend"] = @(NO);
            cloudThread[@"subtitle_tag"] = @"Lưu trữ cá nhân";
        }
    }

    // 2. Fetch friend list (/api/social/friend/getfriends) across candidate hosts
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
        NSArray<NSString *> *friendHosts = @[
            rt.hostFriend,
            @"https://tt-friend-wpa.chat.zalo.me",
            @"https://tt-friend-wpa.zaloapp.com",
            rt.hostProfile
        ];
        for (NSString *fh in friendHosts) {
            NSString *fUrl = [NSString stringWithFormat:@"%@/api/social/friend/getfriends?zpw_ver=%@&zpw_type=%@&params=%@",
                              fh, kZaloZpwVer, kZaloZpwType, friendEnc];
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
            if (friendItems.count > 0) {
                for (NSDictionary *item in friendItems) {
                    if (![item isKindOfClass:[NSDictionary class]]) continue;
                    id rawId = item[@"userId"] ?: (item[@"uid"] ?: item[@"id"]);
                    if (!rawId || rawId == [NSNull null]) continue;
                    NSString *tid = [NSString stringWithFormat:@"%@", rawId];
                    if ([tid isEqualToString:@"0"] || [tid isEqualToString:rt.uid]) continue;
                    NSString *name = item[@"displayName"] ?: (item[@"zaloName"] ?: tid);
                    NSString *avt = item[@"avatar"] ?: (item[@"avt"] ?: @"");
                    BOOL isBiz = ([item[@"type"] integerValue] == 1 || [item[@"isFr"] integerValue] == 0);
                    NSMutableDictionary *ft = [self ensureThreadInSlot:rt threadId:tid name:name isGroup:NO];
                    @synchronized (rt) {
                        ft[@"name"] = name;
                        ft[@"avatar_initials"] = [CTDOCoreBridge initialsForName:name];
                        if ([avt isKindOfClass:[NSString class]] && avt.length > 0) {
                            ft[@"avatar_url"] = avt;
                        }
                        ft[@"is_friend"] = @(YES);
                        ft[@"is_business"] = @(isBiz);
                        int64_t lat = [item[@"lastActionTime"] longLongValue];
                        if (lat > 0 && [ft[@"last_ts"] longLongValue] == 0) {
                            int64_t latMs = (lat < 20000000000LL) ? (lat * 1000LL) : lat;
                            ft[@"last_ts"] = @(latMs);
                            ft[@"last_time_label"] = [CTDOCoreBridge relativeTimeLabelFromTimestampMs:latMs];
                        }
                    }
                }
                break;
            }
        }
    }

    // 3. Fetch joined groups (/api/group/getlg/v4 -> /api/group/getmg-v2 -> /api/social/group/members)
    NSString *lgUrl = [NSString stringWithFormat:@"%@/api/group/getlg/v4?zpw_ver=%@&zpw_type=%@",
                       rt.hostGroup, kZaloZpwVer, kZaloZpwType];
    NSDictionary *lgResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:lgUrl formBody:nil timeout:12.0];
    id lgDec = [self decryptZaloEnvelope:lgResp[@"json"] withKeyData:rt.secretKeyData];
    NSDictionary *lgDataNode = [lgDec isKindOfClass:[NSDictionary class]]
        ? ([lgDec[@"data"][@"data"] isKindOfClass:[NSDictionary class]] ? lgDec[@"data"][@"data"] : lgDec[@"data"])
        : nil;
    NSDictionary *gridVerMap = [lgDataNode isKindOfClass:[NSDictionary class]] ? lgDataNode[@"gridVerMap"] : nil;
    if ([gridVerMap isKindOfClass:[NSDictionary class]] && gridVerMap.count > 0) {
        NSArray<NSString *> *allGrids = [gridVerMap allKeys];
        NSMutableDictionary *batchMap = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < MIN((NSUInteger)60, allGrids.count); i++) {
            NSString *gid = allGrids[i];
            batchMap[gid] = @(0);
        }
        NSData *bmData = [NSJSONSerialization dataWithJSONObject:batchMap options:0 error:nil];
        NSString *bmJson = [[NSString alloc] initWithData:bmData encoding:NSUTF8StringEncoding] ?: @"{}";
        NSString *mgEnc = [self encodeAuthenticatedParams:@{@"gridVerMap": bmJson, @"imei": rt.imei} forSlot:rt];
        if (mgEnc) {
            NSString *mgUrl = [NSString stringWithFormat:@"%@/api/group/getmg-v2?zpw_ver=%@&zpw_type=%@",
                               rt.hostGroup, kZaloZpwVer, kZaloZpwType];
            NSDictionary *mgResp = [self sendSyncHTTPForSlot:rt
                                                      method:@"POST"
                                                         url:mgUrl
                                                    formBody:[NSString stringWithFormat:@"params=%@", mgEnc]
                                                     timeout:15.0];
            id mgDec = [self decryptZaloEnvelope:mgResp[@"json"] withKeyData:rt.secretKeyData];
            NSDictionary *mgDataNode = [mgDec isKindOfClass:[NSDictionary class]]
                ? ([mgDec[@"data"][@"data"] isKindOfClass:[NSDictionary class]] ? mgDec[@"data"][@"data"] : mgDec[@"data"])
                : nil;
            NSDictionary *gridInfoMap = [mgDataNode isKindOfClass:[NSDictionary class]] ? mgDataNode[@"gridInfoMap"] : nil;
            NSMutableSet<NSString *> *needMemberUids = [NSMutableSet set];
            NSMutableDictionary<NSString *, NSArray<NSString *> *> *groupMemberUidMap = [NSMutableDictionary dictionary];

            if ([gridInfoMap isKindOfClass:[NSDictionary class]]) {
                for (NSString *gid in gridInfoMap) {
                    NSDictionary *ginfo = gridInfoMap[gid];
                    if (![ginfo isKindOfClass:[NSDictionary class]]) continue;
                    NSString *gname = ginfo[@"name"] ?: [NSString stringWithFormat:@"Nhóm %@", gid];
                    NSString *groupKey = [gid hasPrefix:@"g"] ? gid : [NSString stringWithFormat:@"g%@", gid];
                    NSString *fullAvt = ginfo[@"fullAvt"] ?: (ginfo[@"avt"] ?: @"");
                    NSInteger totalMem = [ginfo[@"totalMember"] integerValue];

                    NSMutableArray<NSString *> *memIds = [NSMutableArray array];
                    if ([ginfo[@"creatorId"] isKindOfClass:[NSString class]] && [ginfo[@"creatorId"] length] > 0) {
                        [memIds addObject:ginfo[@"creatorId"]];
                    }
                    if ([ginfo[@"memVerList"] isKindOfClass:[NSArray class]]) {
                        for (id mItem in ginfo[@"memVerList"]) {
                            if ([mItem isKindOfClass:[NSString class]]) {
                                NSString *u = [[(NSString *)mItem componentsSeparatedByString:@"_"] firstObject];
                                if (u.length > 0 && ![memIds containsObject:u]) {
                                    [memIds addObject:u];
                                }
                            }
                            if (memIds.count >= 4) break;
                        }
                    }
                    if (memIds.count > 0) {
                        groupMemberUidMap[groupKey] = memIds;
                        for (NSString *u in memIds) {
                            [needMemberUids addObject:u];
                        }
                    }

                    NSMutableDictionary *gt = [self ensureThreadInSlot:rt threadId:groupKey name:gname isGroup:YES];
                    @synchronized (rt) {
                        gt[@"name"] = gname;
                        gt[@"avatar_initials"] = [CTDOCoreBridge initialsForName:gname];
                        if ([fullAvt isKindOfClass:[NSString class]] && fullAvt.length > 8 && ![fullAvt hasSuffix:@"/default"]) {
                            gt[@"avatar_url"] = fullAvt;
                        }
                        if (totalMem > 0) {
                            gt[@"total_members"] = @(totalMem);
                            NSString *curLast = gt[@"last_message"] ?: @"";
                            if (curLast.length == 0 || [curLast isEqualToString:@"Chưa có tin nhắn"]) {
                                gt[@"last_message"] = [NSString stringWithFormat:@"Nhóm · %ld thành viên", (long)totalMem];
                            }
                        }
                        int64_t gts = [ginfo[@"ts"] longLongValue] ?: [ginfo[@"createdTime"] longLongValue];
                        if ([gt[@"last_ts"] longLongValue] == 0) {
                            int64_t nowMs = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000.0);
                            int64_t gtsMs = (gts > 0)
                                ? ((gts < 20000000000LL) ? (gts * 1000LL) : gts)
                                : (nowMs - (int64_t)(groupMemberUidMap.count * 240000LL));
                            gt[@"last_ts"] = @(gtsMs);
                            gt[@"last_time_label"] = [CTDOCoreBridge relativeTimeLabelFromTimestampMs:gtsMs];
                        }
                    }
                }
            }

            if (needMemberUids.count > 0) {
                NSDictionary *memberProfiles = [self fetchMiniProfilesForUserIds:[needMemberUids allObjects] inSlot:rt];
                @synchronized (rt) {
                    for (NSMutableDictionary *t in rt.threads) {
                        NSString *gKey = t[@"id"];
                        NSArray<NSString *> *mIds = groupMemberUidMap[gKey];
                        if (!mIds || mIds.count == 0) continue;
                        NSArray<NSString *> *fallbackParts = [t[@"name"] componentsSeparatedByString:@","];
                        NSMutableArray<NSDictionary *> *mAvts = [NSMutableArray array];
                        for (NSUInteger idx = 0; idx < MIN((NSUInteger)4, mIds.count); idx++) {
                            NSString *u = mIds[idx];
                            NSDictionary *prof = [memberProfiles[u] isKindOfClass:[NSDictionary class]] ? memberProfiles[u] : nil;
                            NSString *mName = (prof[@"displayName"] ?: prof[@"zaloName"])
                                ?: (idx < fallbackParts.count ? [fallbackParts[idx] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : @"TV");
                            NSString *mAvt = prof[@"avatar"] ?: (prof[@"avt"] ?: @"");
                            [mAvts addObject:@{@"id": u, @"name": mName, @"avatar": mAvt}];
                        }
                        t[@"member_avatars"] = mAvts;
                    }
                }
            }
        }
    }

    // 4. Fetch recent messages via /api/preloadconvers/get-last-msgs
    NSDictionary *lastMsgsBody = @{
        @"threadIdLocalMsgId": @"{}",
        @"imei": rt.imei
    };
    NSString *lmEnc = [self encodeAuthenticatedParams:lastMsgsBody forSlot:rt];
    if (lmEnc) {
        NSArray<NSString *> *convHosts = @[
            rt.hostConvers,
            @"https://tt-convers-wpa.chat.zalo.me",
            @"https://tt-convers-wpa.zaloapp.com"
        ];
        for (NSString *ch in convHosts) {
            NSString *lmUrl = [NSString stringWithFormat:@"%@/api/preloadconvers/get-last-msgs?zpw_ver=%@&zpw_type=%@&params=%@",
                               ch, kZaloZpwVer, kZaloZpwType, lmEnc];
            NSDictionary *lmResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:lmUrl formBody:nil timeout:15.0];
            id lmDec = [self decryptZaloEnvelope:lmResp[@"json"] withKeyData:rt.secretKeyData];
            if ([lmDec isKindOfClass:[NSDictionary class]] && [lmDec[@"error_code"] integerValue] == 0) {
                [self ingestZaloMessagesEnvelope:lmDec forSlot:rt];
                break;
            }
        }
    }

    // 5. Fetch Cloud của tôi (My Documents) & top Group recent messages via /api/cm/getrecentv2
    if (rt.send2meId.length > 0) {
        [self syncCloudMessagesForThread:rt.send2meId inSlot:rt];
    }
    NSMutableArray<NSString *> *groupIdsToSync = [NSMutableArray array];
    @synchronized (rt) {
        for (NSDictionary *t in rt.threads) {
            if ([t[@"is_group"] boolValue]) {
                [groupIdsToSync addObject:t[@"id"]];
                if (groupIdsToSync.count >= 12) break;
            }
        }
    }
    for (NSString *gid in groupIdsToSync) {
        [self syncCloudMessagesForThread:gid inSlot:rt];
    }

    // 6. Resolve any unknown 1-1 contact names & avatars discovered from messages
    NSMutableArray<NSString *> *unknownUids = [NSMutableArray array];
    @synchronized (rt) {
        for (NSDictionary *t in rt.threads) {
            if (![t[@"is_group"] boolValue] && ![t[@"is_cloud"] boolValue]) {
                NSString *nm = t[@"name"] ?: @"";
                NSString *av = t[@"avatar_url"] ?: @"";
                if ([nm hasPrefix:@"Người dùng "] || nm.length == 0 || av.length == 0) {
                    [unknownUids addObject:t[@"id"]];
                }
            }
        }
    }
    if (unknownUids.count > 0) {
        NSDictionary *resolved = [self fetchMiniProfilesForUserIds:unknownUids inSlot:rt];
        @synchronized (rt) {
            for (NSMutableDictionary *t in rt.threads) {
                NSDictionary *p = [resolved[t[@"id"]] isKindOfClass:[NSDictionary class]] ? resolved[t[@"id"]] : nil;
                if (p) {
                    NSString *nm = p[@"displayName"] ?: (p[@"zaloName"] ?: p[@"name"]);
                    if ([nm isKindOfClass:[NSString class]] && nm.length > 0) {
                        t[@"name"] = nm;
                        t[@"avatar_initials"] = [CTDOCoreBridge initialsForName:nm];
                    }
                    NSString *av = p[@"avatar"] ?: p[@"avt"];
                    if ([av isKindOfClass:[NSString class]] && av.length > 0) {
                        t[@"avatar_url"] = av;
                    }
                    if ( resolved[t[@"id"]] ) {
                        // handled below
                    }
                }
            }
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"CTDOThreadsDidUpdateNotification" object:nil];
    });
}

- (void)syncCloudMessagesForThread:(NSString *)threadId inSlot:(CTDOSlotRuntime *)rt {
    NSString *cleanId = threadId;
    if ([cleanId hasPrefix:@"group_"]) cleanId = [cleanId substringFromIndex:6];
    if ([cleanId hasPrefix:@"g"] || [cleanId hasPrefix:@"G"]) cleanId = [cleanId substringFromIndex:1];
    BOOL isSend2Me = (rt.send2meId.length > 0 && [cleanId isEqualToString:rt.send2meId]);

    NSMutableDictionary *cmBody = [NSMutableDictionary dictionaryWithDictionary:@{
        @"groupId": cleanId,
        @"globalMsgId": @"9223372036854775808",
        @"count": @(30),
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
    [self ingestZaloMessagesEnvelope:cmDec forSlot:rt forcedThreadId:(isSend2Me ? rt.send2meId : threadId)];
}

+ (NSString *)extractReadableContentFromZaloMessage:(NSDictionary *)item {
    NSString *msgType = [NSString stringWithFormat:@"%@", item[@"msgType"] ?: (item[@"type"] ?: @"")];
    if ([msgType isEqualToString:@"chat.photo"] || [msgType isEqualToString:@"2"]) return @"[Hình ảnh]";
    if ([msgType isEqualToString:@"chat.sticker"] || [msgType isEqualToString:@"5"]) return @"[Nhãn dán]";
    if ([msgType isEqualToString:@"chat.voice"] || [msgType isEqualToString:@"3"]) return @"[Tin nhắn thoại]";
    if ([msgType isEqualToString:@"chat.video"] || [msgType isEqualToString:@"4"]) return @"[Video]";
    if ([msgType isEqualToString:@"chat.undo"] || [msgType isEqualToString:@"31"]) return @"[Tin nhắn đã thu hồi]";

    id rawContent = item[@"content"] ?: (item[@"msg"] ?: item[@"message"]);
    if ([rawContent isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)rawContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([s isEqualToString:@"sendBubbleMessage"]) return @"";
        if ([s hasPrefix:@"{"] && [s hasSuffix:@"}"]) {
            NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *inner = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
            if ([inner isKindOfClass:[NSDictionary class]]) {
                for (NSString *k in @[@"description", @"caption", @"title", @"text", @"msg", @"href"]) {
                    if ([inner[k] isKindOfClass:[NSString class]] && [inner[k] length] > 0) {
                        return inner[k];
                    }
                }
                if (inner[@"catId"] || inner[@"stickerId"]) return @"[Nhãn dán]";
                if (inner[@"hd"] || inner[@"thumb"]) return @"[Hình ảnh]";
                return @"[Tin nhắn]";
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
        if (inner[@"catId"] || inner[@"stickerId"]) return @"[Nhãn dán]";
        if (inner[@"hd"] || inner[@"thumb"]) return @"[Hình ảnh]";
    }
    return @"";
}

- (void)ingestZaloMessagesEnvelope:(id)dec forSlot:(CTDOSlotRuntime *)rt {
    [self ingestZaloMessagesEnvelope:dec forSlot:rt forcedThreadId:nil];
}

- (void)ingestZaloMessagesEnvelope:(id)dec forSlot:(CTDOSlotRuntime *)rt forcedThreadId:(nullable NSString *)forcedThreadId {
    if (![dec isKindOfClass:[NSDictionary class]]) return;
    id dataNode = dec[@"data"] ?: dec;
    if ([dataNode isKindOfClass:[NSString class]]) {
        NSData *d = [(NSString *)dataNode dataUsingEncoding:NSUTF8StringEncoding];
        dataNode = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
    }
    if ([dataNode isKindOfClass:[NSDictionary class]] && [dataNode[@"data"] isKindOfClass:[NSDictionary class]]) {
        dataNode = dataNode[@"data"];
    }
    if (![dataNode isKindOfClass:[NSDictionary class]] && ![dataNode isKindOfClass:[NSArray class]]) return;

    NSMutableArray<NSDictionary *> *allItems = [NSMutableArray array];
    if ([dataNode isKindOfClass:[NSArray class]]) {
        for (id x in (NSArray *)dataNode) {
            if ([x isKindOfClass:[NSDictionary class]]) [allItems addObject:x];
        }
    } else if ([dataNode isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dn = (NSDictionary *)dataNode;
        for (NSString *arrKey in @[@"msgs", @"groupMsgs", @"pageMsgs", @"data", @"items", @"messages"]) {
            BOOL bucketIsGroup = [arrKey isEqualToString:@"groupMsgs"];
            if ([dn[arrKey] isKindOfClass:[NSArray class]]) {
                for (id x in (NSArray *)dn[arrKey]) {
                    if ([x isKindOfClass:[NSDictionary class]]) {
                        if (bucketIsGroup) {
                            NSMutableDictionary *mx = [x mutableCopy];
                            mx[@"isGroup"] = @(YES);
                            [allItems addObject:mx];
                        } else {
                            [allItems addObject:x];
                        }
                    }
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
        BOOL isGroup = (it[@"grid"] != nil || it[@"groupId"] != nil || [it[@"isGroup"] boolValue] || [forcedThreadId hasPrefix:@"g"]);
        NSString *threadId = forcedThreadId;
        if (!threadId || threadId.length == 0) {
            threadId = isGroup
                ? ([idTo hasPrefix:@"g"] ? idTo : [NSString stringWithFormat:@"g%@", idTo])
                : (isSelf ? idTo : uidFrom);
        }
        if (threadId.length == 0 || [threadId isEqualToString:@"0"]) {
            threadId = rt.send2meId.length > 0 ? rt.send2meId : @"cloud_my";
            isGroup = NO;
        }
        NSString *senderDisplay = @"Tôi";
        if (!isSelf) {
            if (dName.length > 0 && [dName rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location != NSNotFound) {
                senderDisplay = dName;
            } else {
                senderDisplay = @"Thành viên";
                @synchronized (rt) {
                    for (NSDictionary *t in rt.threads) {
                        if ([t[@"id"] isEqualToString:uidFrom] && [t[@"name"] length] > 0) {
                            senderDisplay = t[@"name"];
                            break;
                        }
                        if ([t[@"member_avatars"] isKindOfClass:[NSArray class]]) {
                            for (NSDictionary *ma in t[@"member_avatars"]) {
                                if ([ma[@"id"] isEqualToString:uidFrom] && [ma[@"name"] length] > 0) {
                                    senderDisplay = ma[@"name"];
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
        [self appendOrMergeMessageInSlot:rt
                                threadId:threadId
                                 isGroup:isGroup
                                   msgId:mid
                              senderName:senderDisplay
                                 content:content
                                  isSelf:isSelf
                                    tsMs:ts
                            replyPreview:nil];
    }
    if (allItems.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CTDOThreadsDidUpdateNotification" object:nil];
        });
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
        rt.avatarUrl = @"";
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
            [self syncMyProfileForSlot:rt];
            [self syncRealThreadsAndMessagesForSlot:rt];
            [self saveSlotSession:rt];
        });
    }
    return [self authStateForSlot:slot];
}

- (void)requestPhoneMessageSyncForSlot:(NSInteger)slot
                            completion:(nullable void (^)(NSInteger syncedCount, NSString *statusText))completion {
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    if (![rt.status isEqualToString:@"authenticated"] || !rt.secretKeyData) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(0, @"Chưa đăng nhập tài khoản Zalo. Hãy quét mã QR để bắt đầu đồng bộ.");
            });
        }
        return;
    }

    void (^emitProgress)(double, NSString *) = ^(double pct, NSString *txt) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CTDOSyncProgressNotification"
                                                                object:nil
                                                              userInfo:@{
                                                                  @"slot": @(slot),
                                                                  @"progress": @(pct),
                                                                  @"text": txt ?: @""
                                                              }];
        });
    };

    emitProgress(0.15, @"📲 Đang gửi yêu cầu đồng bộ tin nhắn tới điện thoại & Zalo Cloud...");

    dispatch_async(self.netQueue, ^{
        // 1. Send active sync signal via lp_chat multi-batch drain (resetLastActionId / more == 1)
        for (NSInteger batch = 0; batch < 3; batch++) {
            NSString *qJson = [NSString stringWithFormat:@"{\"1\":{\"lastId\":\"%@\",\"ids\":[]},\"2\":{\"lastId\":\"%@\",\"ids\":[]},\"3\":{\"lastId\":\"%@\",\"ids\":[]}}",
                               rt.lastActionId ?: @"0", rt.lastActionId ?: @"0", rt.lastActionId ?: @"0"];
            NSString *b64 = [[qJson dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
            NSString *tail = [CTDOCoreBridge urlEncode:[NSString stringWithFormat:@"%@,1", b64]];
            int64_t ts = (int64_t)[[NSDate date] timeIntervalSince1970];
            NSString *lpUrl = [NSString stringWithFormat:@"%@/?zpw_ver=%@&zpw_type=%@&params=%@,%@,%@&ts=%lld",
                               rt.hostLpChat, kZaloZpwVer, kZaloZpwType, rt.lastActionId ?: @"0", rt.lastActionIdOther ?: @"0", tail, ts];
            NSDictionary *lpResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:lpUrl formBody:nil timeout:10.0];
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
                if ([dn[@"more"] integerValue] != 1 && dn[@"resetLastActionId"] == nil) {
                    break;
                }
            } else {
                break;
            }
        }

        emitProgress(0.42, @"🔄 Đang đồng bộ danh bạ, nhóm & hộp thư (/api/preloadconvers/get-last-msgs)...");

        // 2. Refresh profile, friends, and groups
        [self syncMyProfileForSlot:rt];
        [self syncRealThreadsAndMessagesForSlot:rt];

        // 3. Batch-query /api/preloadconvers/get-last-msgs in 25-thread chunks (<id>_0 for 1-1, <id>_1 for groups)
        NSMutableArray<NSDictionary *> *snapThreads = [NSMutableArray array];
        @synchronized (rt) {
            for (NSDictionary *t in rt.threads) {
                [snapThreads addObject:[t copy]];
            }
        }
        NSUInteger chunkSize = 25;
        for (NSUInteger offset = 0; offset < MIN((NSUInteger)75, snapThreads.count); offset += chunkSize) {
            NSMutableDictionary *mapObj = [NSMutableDictionary dictionary];
            NSUInteger endIdx = MIN(offset + chunkSize, snapThreads.count);
            for (NSUInteger i = offset; i < endIdx; i++) {
                NSDictionary *t = snapThreads[i];
                NSString *tid = t[@"id"] ?: @"";
                if (tid.length == 0) continue;
                BOOL isG = [t[@"is_group"] boolValue];
                NSString *clean = [tid hasPrefix:@"g"] ? [tid substringFromIndex:1] : tid;
                NSString *key = [NSString stringWithFormat:@"%@_%d", clean, isG ? 1 : 0];
                mapObj[key] = @"1";
            }
            if (mapObj.count > 0) {
                NSData *md = [NSJSONSerialization dataWithJSONObject:mapObj options:0 error:nil];
                NSString *mJson = [[NSString alloc] initWithData:md encoding:NSUTF8StringEncoding] ?: @"{}";
                NSString *enc = [self encodeAuthenticatedParams:@{@"threadIdLocalMsgId": mJson, @"imei": rt.imei} forSlot:rt];
                if (enc) {
                    NSString *u = [NSString stringWithFormat:@"%@/api/preloadconvers/get-last-msgs?zpw_ver=%@&zpw_type=%@&params=%@",
                                   rt.hostConvers, kZaloZpwVer, kZaloZpwType, enc];
                    NSDictionary *r = [self sendSyncHTTPForSlot:rt method:@"GET" url:u formBody:nil timeout:10.0];
                    id dec = [self decryptZaloEnvelope:r[@"json"] withKeyData:rt.secretKeyData];
                    if ([dec isKindOfClass:[NSDictionary class]] && [dec[@"error_code"] integerValue] == 0) {
                        [self ingestZaloMessagesEnvelope:dec forSlot:rt];
                    }
                }
            }
        }

        emitProgress(0.75, @"☁️ Đang tải lịch sử tin nhắn nhiều trang (/api/cm/getrecentv2 & getoldv2)...");

        // 4. Multi-page cloud message sync (getrecentv2 + getoldv2 walking lastMsgId backwards)
        NSMutableArray<NSString *> *targets = [NSMutableArray array];
        if (rt.send2meId.length > 0) {
            [targets addObject:rt.send2meId];
        }
        for (NSDictionary *t in snapThreads) {
            if ([t[@"is_group"] boolValue]) {
                [targets addObject:t[@"id"]];
                if (targets.count >= 16) break;
            }
        }
        for (NSString *tid in targets) {
            NSString *cleanId = [tid hasPrefix:@"g"] ? [tid substringFromIndex:1] : tid;
            BOOL isSend2Me = (rt.send2meId.length > 0 && [cleanId isEqualToString:rt.send2meId]);
            NSString *cursorMsgId = @"9223372036854775808";
            for (NSInteger page = 0; page < 3; page++) {
                NSString *ep = (page == 0) ? @"/api/cm/getrecentv2" : @"/api/cm/getoldv2";
                NSMutableDictionary *cmBody = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"groupId": cleanId,
                    @"globalMsgId": cursorMsgId,
                    @"count": @(30),
                    @"msgIds": @[],
                    @"imei": rt.imei,
                    @"src": @(1)
                }];
                if (isSend2Me) cmBody[@"isOA"] = @(1);
                NSString *cmEnc = [self encodeAuthenticatedParams:cmBody forSlot:rt];
                if (!cmEnc) break;
                NSString *cmUrl = [NSString stringWithFormat:@"%@%@?zpw_ver=%@&zpw_type=%@&params=%@&nretry=0",
                                   rt.hostCloudMsg, ep, kZaloZpwVer, kZaloZpwType, cmEnc];
                NSDictionary *cmResp = [self sendSyncHTTPForSlot:rt method:@"GET" url:cmUrl formBody:nil timeout:10.0];
                id cmDec = [self decryptZaloEnvelope:cmResp[@"json"] withKeyData:rt.secretKeyData];
                [self ingestZaloMessagesEnvelope:cmDec forSlot:rt forcedThreadId:(isSend2Me ? rt.send2meId : tid)];
                NSDictionary *dn = [cmDec isKindOfClass:[NSDictionary class]] ? (cmDec[@"data"] ?: cmDec) : nil;
                id nextCursor = [dn isKindOfClass:[NSDictionary class]] ? (dn[@"lastMsgId"] ?: dn[@"data"][@"lastMsgId"]) : nil;
                NSInteger moreFlag = [dn isKindOfClass:[NSDictionary class]] ? [dn[@"more"] integerValue] : 0;
                if (nextCursor && nextCursor != [NSNull null]) {
                    NSString *nextStr = [NSString stringWithFormat:@"%@", nextCursor];
                    if (nextStr.length > 0 && ![nextStr isEqualToString:@"0"] && ![nextStr isEqualToString:cursorMsgId] && moreFlag == 1) {
                        cursorMsgId = nextStr;
                        continue;
                    }
                }
                break;
            }
        }

        [self saveSlotSession:rt];

        NSInteger totalThreads = 0;
        NSInteger totalMessages = 0;
        @synchronized (rt) {
            totalThreads = rt.threads.count;
            for (NSString *k in rt.messagesByThread) {
                totalMessages += [rt.messagesByThread[k] count];
            }
        }
        NSString *doneMsg = [NSString stringWithFormat:@"✓ Đã đồng bộ %ld tin nhắn trên %ld hội thoại với điện thoại",
                             (long)totalMessages, (long)totalThreads];
        emitProgress(1.0, doneMsg);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CTDOThreadsDidUpdateNotification" object:nil];
            if (completion) {
                completion(totalMessages, doneMsg);
            }
        });
    });
}

// ============================================================================
// Account, Thread & Contact Operations (Real Zalo Outbound API + Local Sync)
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
                // filterMode 1 = "Khác" tab on Zalo iOS (muted or OA/unpinned secondary threads)
                if (filterMode == 1 && ([t[@"is_pinned"] boolValue] || [t[@"is_cloud"] boolValue])) continue;
                if (filterMode == 2 && ![t[@"is_pinned"] boolValue]) continue;
                if (filterMode == 3 && ![t[@"is_group"] boolValue]) continue;
            }
            if (q.length > 0) {
                NSString *name = [t[@"name"] ?: @"" lowercaseString];
                NSString *tid = [t[@"id"] ?: @"" lowercaseString];
                NSString *last = [t[@"last_message"] ?: @"" lowercaseString];
                if (![name containsString:q] && ![tid containsString:q] && ![last containsString:q]) {
                    continue;
                }
            }
            [out addObject:[t copy]];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        BOOL ca = [a[@"is_cloud"] boolValue];
        BOOL cb = [b[@"is_cloud"] boolValue];
        if (ca != cb) return ca ? NSOrderedAscending : NSOrderedDescending;
        BOOL pa = [a[@"is_pinned"] boolValue];
        BOOL pb = [b[@"is_pinned"] boolValue];
        if (pa != pb) return pa ? NSOrderedAscending : NSOrderedDescending;
        int64_t ta = [a[@"last_ts"] longLongValue];
        int64_t tb = [b[@"last_ts"] longLongValue];
        if (ta != tb) return (ta > tb) ? NSOrderedAscending : NSOrderedDescending;
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    return out;
}

- (NSArray<NSDictionary *> *)listContactsForSlot:(NSInteger)slot
                                      filterType:(NSInteger)filterType
                                     searchQuery:(nullable NSString *)query {
    // filterType: 0 = Bạn bè, 1 = Nhóm, 2 = OA
    CTDOSlotRuntime *rt = [self runtimeForSlot:slot];
    NSString *q = [[query ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    @synchronized (rt) {
        for (NSDictionary *t in rt.threads) {
            if ([t[@"is_cloud"] boolValue]) continue;
            BOOL isGroup = [t[@"is_group"] boolValue];
            BOOL isBiz = [t[@"is_business"] boolValue];
            if (filterType == 0 && isGroup) continue;
            if (filterType == 1 && !isGroup) continue;
            if (filterType == 2 && !isBiz) continue;
            if (q.length > 0) {
                NSString *name = [t[@"name"] ?: @"" lowercaseString];
                if (![name containsString:q]) continue;
            }
            NSMutableDictionary *item = [t mutableCopy];
            NSString *nm = [item[@"name"] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *letter = @"#";
            if (nm.length > 0) {
                NSString *first = [[nm substringToIndex:1] uppercaseString];
                NSString *folded = [first stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
                if ([folded isEqualToString:@"Đ"] || [first isEqualToString:@"Đ"] || [first isEqualToString:@"đ"]) {
                    letter = @"D";
                } else if (folded.length > 0 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[folded characterAtIndex:0]]) {
                    letter = [folded substringToIndex:1];
                }
            }
            item[@"section_letter"] = letter;
            [out addObject:item];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] ?: @"" localizedCaseInsensitiveCompare:b[@"name"] ?: @""];
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
