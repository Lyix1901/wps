#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

// ==========================================
// IOSurface C API Declarations (Public iOS SDK Framework)
// ==========================================
typedef struct __IOSurface *IOSurfaceRef;
extern CFTypeID IOSurfaceGetTypeID(void);
extern kern_return_t IOSurfaceLock(IOSurfaceRef buffer, uint32_t options, uint32_t *seed);
extern kern_return_t IOSurfaceUnlock(IOSurfaceRef buffer, uint32_t options, uint32_t *seed);
extern void *IOSurfaceGetBaseAddress(IOSurfaceRef buffer);
extern size_t IOSurfaceGetWidth(IOSurfaceRef buffer);
extern size_t IOSurfaceGetHeight(IOSurfaceRef buffer);
extern size_t IOSurfaceGetBytesPerRow(IOSurfaceRef buffer);

// ==========================================
// Mock UITouch for 100% Native Flutter Touch Delivery
// ==========================================
@interface WpsMockTouch : UITouch
@property (nonatomic, assign) CGPoint customLocation;
@property (nonatomic, assign) CGPoint customPreviousLocation;
@property (nonatomic, assign) UITouchPhase customPhase;
@property (nonatomic, assign) NSTimeInterval customTimestamp;
@property (nonatomic, weak) UIView *customView;
@property (nonatomic, weak) UIWindow *customWindow;
@end

@implementation WpsMockTouch
- (CGPoint)locationInView:(UIView *)view {
    return self.customLocation;
}
- (CGPoint)previousLocationInView:(UIView *)view {
    return self.customPreviousLocation;
}
- (UITouchPhase)phase {
    return self.customPhase;
}
- (NSTimeInterval)timestamp {
    return self.customTimestamp;
}
- (UIWindow *)window {
    return self.customWindow;
}
- (UIView *)view {
    return self.customView;
}
- (NSUInteger)tapCount {
    return 1;
}
@end

// ==========================================
// Harita Kale Direk Noktaları (L90 / R90) & Nişan Çizgisi Overlay
// ==========================================
@interface WpsStatusOverlay : UIView
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) CGPoint leftPostPt;
@property (nonatomic, assign) CGPoint rightPostPt;
@property (nonatomic, assign) CGPoint playerPt;
@property (nonatomic, assign) int lockMode; // 0=Varsayılan, 1=Saha Çizgisi Kilidi, 2=Kale Ağı Tam Kilit
@end

@implementation WpsStatusOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGSize scr = self.bounds.size;

    // 1. Oyuncu Noktasından (playerPt) Haritadaki Sol ve Sağ Kale Direği Noktalarına (leftPostPt / rightPostPt) Kesikli Çizgi
    if (self.playerPt.x > 10.0f) {
        CGFloat dashLengths[2] = {5.0f, 4.0f};

        // Sol direk nişan hattı (Turkuaz)
        CGContextSaveGState(ctx);
        CGContextSetLineDash(ctx, 0, dashLengths, 2);
        CGContextSetRGBStrokeColor(ctx, 0.0f, 0.95f, 1.0f, 0.75f);
        CGContextSetLineWidth(ctx, 1.8f);
        CGContextMoveToPoint(ctx, self.playerPt.x, self.playerPt.y);
        CGContextAddLineToPoint(ctx, self.leftPostPt.x, self.leftPostPt.y);
        CGContextStrokePath(ctx);

        // Sağ direk nişan hattı (Sarı/Turuncu)
        CGContextSetRGBStrokeColor(ctx, 1.0f, 0.80f, 0.0f, 0.75f);
        CGContextSetLineWidth(ctx, 1.8f);
        CGContextMoveToPoint(ctx, self.playerPt.x, self.playerPt.y);
        CGContextAddLineToPoint(ctx, self.rightPostPt.x, self.rightPostPt.y);
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);

        // İki direk arası kale ağzı çizgisi
        CGContextSetRGBStrokeColor(ctx, 0.2f, 1.0f, 0.4f, 0.80f);
        CGContextSetLineWidth(ctx, 2.2f);
        CGContextMoveToPoint(ctx, self.leftPostPt.x, self.leftPostPt.y);
        CGContextAddLineToPoint(ctx, self.rightPostPt.x, self.rightPostPt.y);
        CGContextStrokePath(ctx);

        // 2. OYUNCU MERKEZ NOKTASI (Yeşil Halka ⊕)
        CGRect pRing = CGRectMake(self.playerPt.x - 7.0f, self.playerPt.y - 7.0f, 14.0f, 14.0f);
        CGContextSetRGBFillColor(ctx, 0.1f, 1.0f, 0.3f, 0.35f);
        CGContextFillEllipseInRect(ctx, pRing);
        CGContextSetRGBStrokeColor(ctx, 0.2f, 1.0f, 0.4f, 0.95f);
        CGContextSetLineWidth(ctx, 2.0f);
        CGContextStrokeEllipseInRect(ctx, pRing);

        // 3. SOL DİREK NOKTASI (● L90 - Parlak Turkuaz/Kırmızı Hedef Noktası)
        CGRect lOuter = CGRectMake(self.leftPostPt.x - 8.0f, self.leftPostPt.y - 8.0f, 16.0f, 16.0f);
        CGRect lInner = CGRectMake(self.leftPostPt.x - 4.0f, self.leftPostPt.y - 4.0f, 8.0f, 8.0f);
        CGContextSetRGBFillColor(ctx, 0.0f, 0.92f, 1.0f, 0.95f);
        CGContextFillEllipseInRect(ctx, lOuter);
        CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
        CGContextSetLineWidth(ctx, 2.0f);
        CGContextStrokeEllipseInRect(ctx, lOuter);
        CGContextSetRGBFillColor(ctx, 0.95f, 0.1f, 0.2f, 1.0f);
        CGContextFillEllipseInRect(ctx, lInner);

        // 4. SAĞ DİREK NOKTASI (● R90 - Parlak Sarı/Kırmızı Hedef Noktası)
        CGRect rOuter = CGRectMake(self.rightPostPt.x - 8.0f, self.rightPostPt.y - 8.0f, 16.0f, 16.0f);
        CGRect rInner = CGRectMake(self.rightPostPt.x - 4.0f, self.rightPostPt.y - 4.0f, 8.0f, 8.0f);
        CGContextSetRGBFillColor(ctx, 1.0f, 0.82f, 0.0f, 0.95f);
        CGContextFillEllipseInRect(ctx, rOuter);
        CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
        CGContextSetLineWidth(ctx, 2.0f);
        CGContextStrokeEllipseInRect(ctx, rOuter);
        CGContextSetRGBFillColor(ctx, 0.95f, 0.1f, 0.2f, 1.0f);
        CGContextFillEllipseInRect(ctx, rInner);

        NSDictionary *tagAttrs = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:9.5f],
            NSForegroundColorAttributeName: [UIColor whiteColor]
        };
        [@"L90" drawAtPoint:CGPointMake(self.leftPostPt.x - 10.0f, self.leftPostPt.y - 20.0f) withAttributes:tagAttrs];
        [@"R90" drawAtPoint:CGPointMake(self.rightPostPt.x - 10.0f, self.rightPostPt.y - 20.0f) withAttributes:tagAttrs];
    }

    // 5. Üst Bilgilendirme Banner'ı
    if (self.message.length == 0) return;
    CGRect bannerRect = CGRectMake(scr.width / 2.0f - 230.0f, 6.0f, 460.0f, 24.0f);

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:bannerRect cornerRadius:6.0f];
    CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 0.82);
    [path fill];

    CGContextSetRGBStrokeColor(ctx, 0.2, 1.0, 0.4, 0.95);
    CGContextSetLineWidth(ctx, 1.2);
    [path stroke];

    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:11.0f],
        NSForegroundColorAttributeName: [UIColor colorWithRed:1.0f green:0.92f blue:0.2f alpha:1.0f]
    };

    CGSize textSz = [self.message sizeWithAttributes:attrs];
    CGRect textRect = CGRectMake(bannerRect.origin.x + (bannerRect.size.width - textSz.width) / 2.0f,
                                 bannerRect.origin.y + (bannerRect.size.height - textSz.height) / 2.0f,
                                 textSz.width, textSz.height);
    [self.message drawInRect:textRect withAttributes:attrs];
}
@end

// ==========================================
// Tweak Manager
// ==========================================
@interface WpsShotManager : NSObject
+ (instancetype)sharedInstance;
- (void)setupTweak;
- (void)onKickButtonTouchedAt:(CGPoint)pos;
- (void)onCapturedIOSurface:(IOSurfaceRef)surface;
- (void)onMetalTextureCaptured:(id<MTLTexture>)tex;
- (void)executeShotToRightCorner:(BOOL)targetRight;
- (void)toggleAttackDirection;
@end

@implementation WpsShotManager {
    UIButton *_shotBtn;
    UILabel *_aimLabel;
    UIView *_timerPill;
    UILabel *_timerLabel;
    WpsStatusOverlay *_statusOverlay;

    BOOL _targetingRightCorner;
    BOOL _attackDirectionDown; // NO = Üst Kale (Varsayılan), YES = Alt Kale
    CGPoint _calibratedKickPos;
    BOOL _isCalibrated;

    // Frame-accurate CADisplayLink şut & harita kale takip motoru
    CADisplayLink *_displayLink;
    CGFloat _chargeDuration; // Varsayılan: 0.64s

    // Aktif şut durumu
    BOOL _isShooting;
    BOOL _shotMovedSent;
    NSTimeInterval _shotStartTime;
    CGPoint _shotStartPt;
    CGPoint _shotEndPt;
    NSString *_activeCornerName;
    WpsMockTouch *_activeMockTouch;
    __weak UIViewController *_activeFlutterVC;

    // Harita Üzerindeki Kalenin Gerçek Ekran Koordinatları (UIWindow Point Uzayında)
    CGPoint _leftPostScreenPt;   // ● L90
    CGPoint _rightPostScreenPt;  // ● R90
    CGPoint _playerScreenPt;     // ⊕ Oyuncu
    CGFloat _screenW;
    CGFloat _screenH;
    int _lastLockMode;           // 0=Yok, 1=CezaSahası/Taç Kilidi, 2=Kale Ağı Kilidi

    // FlutterMetalLayer / CAMetalLayer Framebuffer Yakalayıcı
    IOSurfaceRef _latestSurface;
    id<MTLTexture> _currTexture;
    id<MTLTexture> _prevTexture;
    NSTimeInterval _lastVisionScanTime;
    BOOL _hasCustomToast;
}

+ (instancetype)sharedInstance {
    static WpsShotManager *inst = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        inst = [[WpsShotManager alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSNumber *savedDur = [[NSUserDefaults standardUserDefaults] objectForKey:@"wps_charge_duration_v3"];
        if (savedDur && savedDur.doubleValue >= 0.40 && savedDur.doubleValue <= 0.90) {
            _chargeDuration = (CGFloat)savedDur.doubleValue;
        } else {
            _chargeDuration = 0.64f;
        }
    }
    return self;
}

- (UIViewController *)findFlutterVC:(UIViewController *)vc {
    if (!vc) return nil;
    if ([NSStringFromClass([vc class]) containsString:@"FlutterViewController"]) {
        return vc;
    }
    for (UIViewController *child in vc.childViewControllers) {
        UIViewController *res = [self findFlutterVC:child];
        if (res) return res;
    }
    if (vc.presentedViewController) {
        UIViewController *res = [self findFlutterVC:vc.presentedViewController];
        if (res) return res;
    }
    return nil;
}

- (void)showToast:(NSString *)msg duration:(NSTimeInterval)sec {
    if (!_statusOverlay) return;
    _hasCustomToast = YES;
    _statusOverlay.message = msg;
    [_statusOverlay setNeedsDisplay];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearToast) object:nil];
    [self performSelector:@selector(clearToast) withObject:nil afterDelay:sec];
}

- (void)clearToast {
    _hasCustomToast = NO;
    [self updateBannerCoordinates];
}

- (void)updateBannerCoordinates {
    if (!_statusOverlay || _hasCustomToast) return;
    NSString *lockTag = (_lastLockMode == 2) ? @"🟢KALE-KİLİT" : ((_lastLockMode == 1) ? @"🟡SAHA-KİLİT" : @"⚪️ARANIYOR");
    _statusOverlay.message = [NSString stringWithFormat:@"%@ | L90:(%.0f,%.0f) R90:(%.0f,%.0f) | P:(%.0f,%.0f)",
                              lockTag,
                              _leftPostScreenPt.x, _leftPostScreenPt.y,
                              _rightPostScreenPt.x, _rightPostScreenPt.y,
                              _playerScreenPt.x, _playerScreenPt.y];
}

- (void)setupTweak {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWin = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWin = w; break; }
        }
        if (!keyWin && [UIApplication sharedApplication].windows.count > 0) {
            keyWin = [UIApplication sharedApplication].windows.firstObject;
        }
        if (!keyWin) return;

        CGSize scr = [UIScreen mainScreen].bounds.size;
        CGFloat w = MAX(scr.width, scr.height);
        CGFloat h = MIN(scr.width, scr.height);
        self->_screenW = w;
        self->_screenH = h;

        self->_calibratedKickPos = CGPointMake(761.0f, 212.0f);
        self->_isCalibrated = YES;
        self->_attackDirectionDown = NO;

        self->_leftPostScreenPt  = CGPointMake(w * 0.420f, h * 0.285f);
        self->_rightPostScreenPt = CGPointMake(w * 0.519f, h * 0.285f);
        self->_playerScreenPt    = CGPointMake(w * 0.500f, h * 0.610f);

        if (!self->_statusOverlay) {
            self->_statusOverlay = [[WpsStatusOverlay alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            self->_statusOverlay.leftPostPt = self->_leftPostScreenPt;
            self->_statusOverlay.rightPostPt = self->_rightPostScreenPt;
            self->_statusOverlay.playerPt = self->_playerScreenPt;
            [keyWin addSubview:self->_statusOverlay];
            [self showToast:[NSString stringWithFormat:@"🟢 HARİTA KALE KİLİDİ AKTİF | ŞARJ: %.2fs", self->_chargeDuration] duration:3.0];
        }

        // ⚡SHOT Ana Butonu
        if (!self->_shotBtn) {
            CGFloat btnSize = 72.0f;
            self->_shotBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            self->_shotBtn.frame = CGRectMake(w - 88.0f, h / 2.0f - 44.0f, btnSize, btnSize);
            self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.92f green:0.10f blue:0.18f alpha:0.95f];
            self->_shotBtn.layer.cornerRadius = btnSize / 2.0f;
            self->_shotBtn.layer.borderWidth = 2.5f;
            self->_shotBtn.layer.borderColor = [UIColor whiteColor].CGColor;
            self->_shotBtn.layer.shadowColor = [UIColor blackColor].CGColor;
            self->_shotBtn.layer.shadowOffset = CGSizeMake(0, 3);
            self->_shotBtn.layer.shadowOpacity = 0.6f;
            self->_shotBtn.layer.shadowRadius = 5.0f;

            UILabel *topLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, btnSize, 18)];
            topLbl.text = @"⚡SHOT";
            topLbl.font = [UIFont boldSystemFontOfSize:13.5f];
            topLbl.textColor = [UIColor whiteColor];
            topLbl.textAlignment = NSTextAlignmentCenter;
            topLbl.userInteractionEnabled = NO;
            [self->_shotBtn addSubview:topLbl];

            UILabel *subLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 27, btnSize, 14)];
            subLbl.text = @"◀ L90|R90 ▶";
            subLbl.font = [UIFont boldSystemFontOfSize:9.5f];
            subLbl.textColor = [UIColor colorWithRed:1.0f green:0.88f blue:0.15f alpha:1.0f];
            subLbl.textAlignment = NSTextAlignmentCenter;
            subLbl.userInteractionEnabled = NO;
            [self->_shotBtn addSubview:subLbl];

            self->_aimLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 44, btnSize, 16)];
            self->_aimLabel.text = @"🎯 KALEYE";
            self->_aimLabel.font = [UIFont boldSystemFontOfSize:8.5f];
            self->_aimLabel.textColor = [UIColor colorWithRed:0.3f green:1.0f blue:0.5f alpha:1.0f];
            self->_aimLabel.textAlignment = NSTextAlignmentCenter;
            self->_aimLabel.userInteractionEnabled = NO;
            [self->_shotBtn addSubview:self->_aimLabel];

            [self->_shotBtn addTarget:self action:@selector(handleShotBtnTapped:forEvent:) forControlEvents:UIControlEventTouchUpInside];

            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
            [self->_shotBtn addGestureRecognizer:pan];

            UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
            lp.minimumPressDuration = 0.45;
            [self->_shotBtn addGestureRecognizer:lp];

            [keyWin addSubview:self->_shotBtn];

            // Şarj Süresi Milisaniyelik İnce Ayar Hapı: [- 0.64s +]
            self->_timerPill = [[UIView alloc] initWithFrame:CGRectMake(w - 92.0f, h / 2.0f + 34.0f, 80.0f, 24.0f)];
            self->_timerPill.backgroundColor = [UIColor colorWithWhite:0.08f alpha:0.88f];
            self->_timerPill.layer.cornerRadius = 12.0f;
            self->_timerPill.layer.borderWidth = 1.0f;
            self->_timerPill.layer.borderColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.15f alpha:0.85f].CGColor;

            UIButton *minusBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            minusBtn.frame = CGRectMake(0, 0, 24.0f, 24.0f);
            [minusBtn setTitle:@"-" forState:UIControlStateNormal];
            minusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
            [minusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [minusBtn addTarget:self action:@selector(decreaseChargeTime) forControlEvents:UIControlEventTouchUpInside];
            [self->_timerPill addSubview:minusBtn];

            self->_timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(22.0f, 0, 36.0f, 24.0f)];
            self->_timerLabel.text = [NSString stringWithFormat:@"%.2fs", self->_chargeDuration];
            self->_timerLabel.font = [UIFont boldSystemFontOfSize:9.5f];
            self->_timerLabel.textColor = [UIColor colorWithRed:1.0f green:0.9f blue:0.2f alpha:1.0f];
            self->_timerLabel.textAlignment = NSTextAlignmentCenter;
            [self->_timerPill addSubview:self->_timerLabel];

            UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            plusBtn.frame = CGRectMake(56.0f, 0, 24.0f, 24.0f);
            [plusBtn setTitle:@"+" forState:UIControlStateNormal];
            plusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
            [plusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [plusBtn addTarget:self action:@selector(increaseChargeTime) forControlEvents:UIControlEventTouchUpInside];
            [self->_timerPill addSubview:plusBtn];

            [keyWin addSubview:self->_timerPill];
        }

        if (!self->_displayLink) {
            self->_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLink:)];
            [self->_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }

        [self setupVolumeHook];
    });
}

- (void)decreaseChargeTime {
    _chargeDuration = fmaxf(0.44f, _chargeDuration - 0.02f);
    [[NSUserDefaults standardUserDefaults] setDouble:_chargeDuration forKey:@"wps_charge_duration_v3"];
    _timerLabel.text = [NSString stringWithFormat:@"%.2fs", _chargeDuration];
    AudioServicesPlaySystemSound(1519);
    [self showToast:[NSString stringWithFormat:@"⏱ ŞUT ŞARJ SÜRESİ: %.2f sn (-20ms)", _chargeDuration] duration:1.8];
}

- (void)increaseChargeTime {
    _chargeDuration = fminf(0.84f, _chargeDuration + 0.02f);
    [[NSUserDefaults standardUserDefaults] setDouble:_chargeDuration forKey:@"wps_charge_duration_v3"];
    _timerLabel.text = [NSString stringWithFormat:@"%.2fs", _chargeDuration];
    AudioServicesPlaySystemSound(1519);
    [self showToast:[NSString stringWithFormat:@"⏱ ŞUT ŞARJ SÜRESİ: %.2f sn (+20ms)", _chargeDuration] duration:1.8];
}

// ==========================================
// FlutterMetalLayer / CALayer Ağacından Canlı IOSurface Yakalama
// ==========================================
- (void)onCapturedIOSurface:(IOSurfaceRef)surface {
    if (surface) {
        _latestSurface = surface;
    }
}

- (void)onMetalTextureCaptured:(id<MTLTexture>)tex {
    if (!tex) return;
    if (_currTexture && _currTexture != tex) {
        _prevTexture = _currTexture;
    }
    _currTexture = tex;
}

- (IOSurfaceRef)findIOSurfaceInLayer:(CALayer *)layer depth:(int)depth {
    if (!layer || depth > 8) return NULL;

    // 1. FlutterMetalLayer her karede layer.contents = (__bridge id)iosurface atar!
    id contents = layer.contents;
    if (contents) {
        CFTypeRef cf = (__bridge CFTypeRef)contents;
        if (CFGetTypeID(cf) == IOSurfaceGetTypeID()) {
            return (IOSurfaceRef)cf;
        }
    }

    // 2. FlutterMetalLayer -> _front ivar -> _surface ivar kontrolü
    Ivar frontIvar = class_getInstanceVariable([layer class], "_front");
    if (frontIvar) {
        id frontObj = object_getIvar(layer, frontIvar);
        if (frontObj) {
            Ivar surfIvar = class_getInstanceVariable([frontObj class], "_surface");
            if (surfIvar) {
                id surfObj = object_getIvar(frontObj, surfIvar);
                if (surfObj && CFGetTypeID((__bridge CFTypeRef)surfObj) == IOSurfaceGetTypeID()) {
                    return (__bridge IOSurfaceRef)surfObj;
                }
            }
            Ivar texIvar = class_getInstanceVariable([frontObj class], "_texture");
            if (texIvar) {
                id texObj = object_getIvar(frontObj, texIvar);
                if (texObj && [texObj respondsToSelector:@selector(iosurface)]) {
                    typedef IOSurfaceRef (*GetSurfaceFn)(id, SEL);
                    IOSurfaceRef s = ((GetSurfaceFn)objc_msgSend)(texObj, @selector(iosurface));
                    if (s) return s;
                }
            }
        }
    }

    for (CALayer *sub in [layer.sublayers copy]) {
        IOSurfaceRef found = [self findIOSurfaceInLayer:sub depth:depth + 1];
        if (found) return found;
    }
    return NULL;
}

- (IOSurfaceRef)acquireActiveIOSurface {
    UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
    if (!keyWin) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWin = w; break; }
        }
    }
    if (keyWin) {
        IOSurfaceRef fromLayer = [self findIOSurfaceInLayer:keyWin.layer depth:0];
        if (fromLayer) return fromLayer;
    }
    if (_latestSurface) return _latestSurface;

    id<MTLTexture> tex = _prevTexture ? _prevTexture : _currTexture;
    if (tex && [tex respondsToSelector:@selector(iosurface)]) {
        typedef IOSurfaceRef (*GetSurfaceFn)(id, SEL);
        return ((GetSurfaceFn)objc_msgSend)(tex, @selector(iosurface));
    }
    return NULL;
}

// ==========================================
// Haritadaki Kalenin Direklerini (L90/R90) ve Ceza Sahasını Canlı Takip
// ==========================================
- (void)scanLiveFrameForGoalPostsAndPlayer {
    if (_screenW < 100.0f || _screenH < 100.0f) return;

    IOSurfaceRef surface = [self acquireActiveIOSurface];
    if (!surface) return;

    if (IOSurfaceLock(surface, 1 /* kIOSurfaceLockReadOnly */, NULL) != 0) {
        return;
    }

    uint8_t *base = (uint8_t *)IOSurfaceGetBaseAddress(surface);
    size_t W = IOSurfaceGetWidth(surface);
    size_t H = IOSurfaceGetHeight(surface);
    size_t bpr = IOSurfaceGetBytesPerRow(surface);

    if (!base || W < 400 || H < 250 || bpr < W * 4) {
        IOSurfaceUnlock(surface, 1, NULL);
        return;
    }

    // 1. Oyuncunun Sarı İsmini (rayancherki31) Bul -> ⊕ Oyuncu Noktası
    long sumX = 0, sumY = 0, yellowCount = 0;
    size_t pY0 = (size_t)(H * 0.25), pY1 = (size_t)(H * 0.82);
    size_t pX0 = (size_t)(W * 0.20), pX1 = (size_t)(W * 0.65);

    for (size_t y = pY0; y < pY1; y += 3) {
        uint8_t *row = base + y * bpr;
        for (size_t x = pX0; x < pX1; x += 3) {
            uint8_t b = row[x * 4 + 0];
            uint8_t g = row[x * 4 + 1];
            uint8_t r = row[x * 4 + 2];
            if (r > 210 && g > 195 && b < 85) {
                sumX += (long)x;
                sumY += (long)y;
                yellowCount++;
            }
        }
    }

    if (yellowCount >= 5) {
        CGFloat normPX = ((CGFloat)sumX / (CGFloat)yellowCount) / (CGFloat)W;
        CGFloat normPY = (((CGFloat)sumY / (CGFloat)yellowCount) / (CGFloat)H) + 0.075f;
        _playerScreenPt = CGPointMake(normPX * _screenW, fminf(_screenH * 0.88f, normPY * _screenH));
    }

    // 2. KALE AĞLARINI DOĞRUDAN YAKALA (Haritadaki Gerçek Sol ve Sağ Direk Koordinatları!)
    BOOL foundGoalNet = NO;
    size_t netY0 = _attackDirectionDown ? (size_t)(H * 0.58) : (size_t)(H * 0.14);
    size_t netY1 = _attackDirectionDown ? (size_t)(H * 0.97) : (size_t)(H * 0.44);
    size_t dyStep = (size_t)fmax(2.0, H * 0.008);

    for (size_t y = netY0; y + dyStep < netY1; y += 3) {
        uint8_t *row0 = base + y * bpr;
        uint8_t *row1 = base + (y + dyStep) * bpr;
        long runStart = -1;

        for (size_t x = (size_t)(W * 0.03); x < (size_t)(W * 0.96); x += 2) {
            uint8_t b0 = row0[x * 4 + 0], g0 = row0[x * 4 + 1], r0 = row0[x * 4 + 2];
            uint8_t b1 = row1[x * 4 + 0], g1 = row1[x * 4 + 1], r1 = row1[x * 4 + 2];

            BOOL isNet = (r0 > 105 && g0 > 110 && b0 > 105 && abs((int)r0 - (int)b0) < 30 &&
                          r1 > 105 && g1 > 110 && b1 > 105 && abs((int)r1 - (int)b1) < 30);
            if (isNet) {
                if (runStart == -1) runStart = (long)x;
            } else {
                if (runStart != -1) {
                    long rw = (long)x - runStart;
                    if (rw >= (long)(W * 0.095) && rw <= (long)(W * 0.165)) {
                        size_t xL = (runStart > 14) ? (size_t)(runStart - 12) : 2;
                        size_t xR = (x + 12 < W) ? (x + 12) : (W - 2);
                        uint8_t *pL = row0 + xL * 4;
                        uint8_t *pR = row0 + xR * 4;
                        if ((int)pL[1] > (int)pL[2] + 22 && (int)pR[1] > (int)pR[2] + 22) {
                            CGFloat normLeftX  = ((CGFloat)runStart / (CGFloat)W) + 0.011f;
                            CGFloat normRightX = ((CGFloat)x / (CGFloat)W) - 0.011f;
                            CGFloat normGoalY  = _attackDirectionDown
                                ? (((CGFloat)y / (CGFloat)H) - 0.010f)
                                : (((CGFloat)y / (CGFloat)H) + 0.068f);

                            _leftPostScreenPt  = CGPointMake(normLeftX * _screenW, normGoalY * _screenH);
                            _rightPostScreenPt = CGPointMake(normRightX * _screenW, normGoalY * _screenH);
                            foundGoalNet = YES;
                            _lastLockMode = 2;
                            break;
                        }
                    }
                    runStart = -1;
                }
            }
        }
        if (foundGoalNet) break;
    }

    // 3. Kale Ağı Ekran Dışındayken (Örn: Çok Sağ/Sol Kornerde veya Orta Sahada):
    // Ceza Sahası Çizgi Çifti (Fark = 0.3789*W) ve Taç-Ceza Sahası Çifti (Fark = 0.2360*W) Çözücüsü!
    if (!foundGoalNet) {
        CGFloat vLines[24];
        int vCount = 0;
        size_t bY0 = _attackDirectionDown ? (size_t)(H * 0.50) : (size_t)(H * 0.32);
        size_t bY1 = _attackDirectionDown ? (size_t)(H * 0.68) : (size_t)(H * 0.50);
        size_t sY = (size_t)fmax(2.0, (bY1 - bY0) / 14);

        for (size_t x = (size_t)(W * 0.02); x < (size_t)(W * 0.80) && vCount < 24; x += 2) {
            int hits = 0, tot = 0;
            for (size_t y = bY0; y < bY1; y += sY) {
                uint8_t *p0 = base + y * bpr + x * 4;
                uint8_t *p1 = base + y * bpr + (x + 1) * 4;
                if ((p0[2] > 150 && p0[1] > 160 && p0[0] > 150) ||
                    (p1[2] > 150 && p1[1] > 160 && p1[0] > 150)) {
                    hits++;
                }
                tot++;
            }
            if (tot > 0 && hits >= (tot * 3) / 4) {
                CGFloat nx = (CGFloat)x / (CGFloat)W;
                if (vCount == 0 || (nx - vLines[vCount - 1]) > 0.03f) {
                    vLines[vCount++] = nx;
                }
            }
        }

        CGFloat solvedGoalCenterNormX = -999.0f;
        // Öncelik A: Ceza sahası sol ve sağ dikey çizgileri (aralarındaki mesafe sabit 0.3789 * W)
        for (int i = 0; i < vCount; i++) {
            for (int j = i + 1; j < vCount; j++) {
                CGFloat dist = vLines[j] - vLines[i];
                if (fabsf(dist - 0.3789f) < 0.018f) {
                    solvedGoalCenterNormX = 0.5f * (vLines[i] + vLines[j]);
                    break;
                }
            }
            if (solvedGoalCenterNormX > -100.0f) break;
        }
        // Öncelik B: Sağ veya Sol Kornerdeyken Ceza Sahası + Dış Taç Çizgisi Çifti (mesafe sabit 0.2360 * W)
        if (solvedGoalCenterNormX < -100.0f) {
            for (int i = 0; i < vCount; i++) {
                for (int j = i + 1; j < vCount; j++) {
                    CGFloat dist = vLines[j] - vLines[i];
                    if (fabsf(dist - 0.2360f) < 0.018f) {
                        if (vLines[j] > 0.52f) {
                            // Sağ ceza sahası çizgisi + Sağ taç çizgisi -> Kale solumuzda!
                            solvedGoalCenterNormX = vLines[i] - 0.1895f;
                        } else if (vLines[i] < 0.48f) {
                            // Sol taç çizgisi + Sol ceza sahası çizgisi -> Kale sağımızda!
                            solvedGoalCenterNormX = vLines[j] + 0.1895f;
                        }
                        break;
                    }
                }
                if (solvedGoalCenterNormX > -100.0f) break;
            }
        }

        if (solvedGoalCenterNormX > -100.0f) {
            CGFloat goalY = _leftPostScreenPt.y;
            if (goalY < 20.0f || goalY > _screenH - 20.0f) {
                goalY = _attackDirectionDown ? (_screenH * 0.72f) : (_screenH * 0.285f);
            }
            _leftPostScreenPt  = CGPointMake((solvedGoalCenterNormX - 0.050f) * _screenW, goalY);
            _rightPostScreenPt = CGPointMake((solvedGoalCenterNormX + 0.050f) * _screenW, goalY);
            _lastLockMode = 1;
        }
    }

    IOSurfaceUnlock(surface, 1, NULL);

    if (_statusOverlay) {
        _statusOverlay.leftPostPt = _leftPostScreenPt;
        _statusOverlay.rightPostPt = _rightPostScreenPt;
        _statusOverlay.playerPt = _playerScreenPt;
        _statusOverlay.lockMode = _lastLockMode;
        [self updateBannerCoordinates];
        [_statusOverlay setNeedsDisplay];
    }
}

// ==========================================
// 60 FPS CADisplayLink: Milisaniyelik Şut Bırakma & 20Hz Harita Kale Takibi
// ==========================================
- (void)onDisplayLink:(CADisplayLink *)link {
    NSTimeInterval now = CACurrentMediaTime();

    // 1. Aktif Şut Varsa Tam _chargeDuration (0.64s) Dolduğu Karede Bırak!
    if (_isShooting && _activeMockTouch && _activeFlutterVC) {
        NSTimeInterval elapsed = now - _shotStartTime;
        if (elapsed >= _chargeDuration) {
            _activeMockTouch.customPreviousLocation = _shotEndPt;
            _activeMockTouch.customLocation = _shotEndPt;
            _activeMockTouch.customPhase = UITouchPhaseEnded;
            _activeMockTouch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

            [_activeFlutterVC touchesEnded:[NSSet setWithObject:_activeMockTouch] withEvent:nil];

            _isShooting = NO;
            _shotMovedSent = NO;
            _activeMockTouch = nil;

            [UIView animateWithDuration:0.08 animations:^{
                self->_shotBtn.transform = CGAffineTransformIdentity;
                self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.92f green:0.10f blue:0.18f alpha:0.95f];
            }];

            AudioServicesPlaySystemSound(1520);
            [self showToast:[NSString stringWithFormat:@"🚀 ŞUT ATEŞLENDİ -> %@ (%.2fs) 🎯", _activeCornerName, _chargeDuration] duration:1.5];
        } else if (elapsed >= 0.022) {
            _activeMockTouch.customPreviousLocation = _shotMovedSent ? _shotEndPt : _shotStartPt;
            _activeMockTouch.customLocation = _shotEndPt;
            _activeMockTouch.customPhase = UITouchPhaseMoved;
            _activeMockTouch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

            [_activeFlutterVC touchesMoved:[NSSet setWithObject:_activeMockTouch] withEvent:nil];
            _shotMovedSent = YES;
        }
    }

    // 2. Her 50ms'de bir (Saniyede 20 kez) Haritadaki Kale Direği Noktalarını (L90 / R90) Güncelle
    if (now - _lastVisionScanTime >= 0.05) {
        _lastVisionScanTime = now;
        [self scanLiveFrameForGoalPostsAndPlayer];
    }
}

// ==========================================
// Doğrudan Haritada Boyanan Direk Noktasına (● L90 veya ● R90) Vektör Hesabı
// ==========================================
- (CGPoint)computeDirectVectorToPaintedDot:(BOOL)targetRight {
    [self scanLiveFrameForGoalPostsAndPlayer];

    CGPoint targetDot = targetRight ? _rightPostScreenPt : _leftPostScreenPt;
    CGFloat dx = targetDot.x - _playerScreenPt.x;
    CGFloat dy = targetDot.y - _playerScreenPt.y;

    CGFloat len = sqrtf(dx * dx + dy * dy);
    if (len < 1.0f) {
        dx = targetRight ? 18.0f : -18.0f;
        dy = _attackDirectionDown ? 80.0f : -80.0f;
        len = sqrtf(dx * dx + dy * dy);
    }

    CGFloat dragRadius = 84.0f;
    return CGPointMake((dx / len) * dragRadius, (dy / len) * dragRadius);
}

- (void)onKickButtonTouchedAt:(CGPoint)pos {
    _calibratedKickPos = pos;
    _isCalibrated = YES;
    [self showToast:[NSString stringWithFormat:@"🎯 ŞUT BUTONU GÜNCELLENDİ: (%.0f, %.0f)", pos.x, pos.y] duration:2.0];
}

- (void)handlePan:(UIPanGestureRecognizer *)p {
    UIView *v = p.view;
    CGPoint trans = [p translationInView:v.superview];
    v.center = CGPointMake(v.center.x + trans.x, v.center.y + trans.y);
    [p setTranslation:CGPointZero inView:v.superview];
    if (_timerPill) {
        _timerPill.center = CGPointMake(v.center.x, v.center.y + 52.0f);
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)lp {
    if (lp.state == UIGestureRecognizerStateBegan) {
        [self toggleAttackDirection];
    }
}

- (void)toggleAttackDirection {
    _attackDirectionDown = !_attackDirectionDown;
    CGFloat goalY = _attackDirectionDown ? (_screenH * 0.72f) : (_screenH * 0.285f);
    _leftPostScreenPt  = CGPointMake(_screenW * 0.420f, goalY);
    _rightPostScreenPt = CGPointMake(_screenW * 0.519f, goalY);
    _playerScreenPt    = CGPointMake(_screenW * 0.500f, _attackDirectionDown ? (_screenH * 0.42f) : (_screenH * 0.61f));

    if (_statusOverlay) {
        _statusOverlay.leftPostPt = _leftPostScreenPt;
        _statusOverlay.rightPostPt = _rightPostScreenPt;
        _statusOverlay.playerPt = _playerScreenPt;
        [_statusOverlay setNeedsDisplay];
    }

    AudioServicesPlaySystemSound(1519);
    NSString *dirText = _attackDirectionDown ? @"⬇️ HEDEF: ALT KALE" : @"⬆️ HEDEF: ÜST KALE";
    [self showToast:[NSString stringWithFormat:@"🔄 KALE YÖNÜ DEĞİŞTİ: %@", dirText] duration:2.5];
}

- (void)handleShotBtnTapped:(UIButton *)btn forEvent:(UIEvent *)event {
    UITouch *t = [[event touchesForView:btn] anyObject];
    CGPoint loc = [t locationInView:btn];

    BOOL targetRight = (loc.x >= btn.bounds.size.width / 2.0f);
    [self executeShotToRightCorner:targetRight];
}

- (void)setupVolumeHook {
    NSError *err;
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&err];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onVolumeTrigger)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

- (void)onVolumeTrigger {
    _targetingRightCorner = !_targetingRightCorner;
    [self executeShotToRightCorner:_targetingRightCorner];
}

// ==========================================
// Doğrudan Haritada Boyanan Direk Noktasına (L90 / R90) Şut İcrası
// ==========================================
- (void)executeShotToRightCorner:(BOOL)targetRight {
    if (_isShooting) return;

    UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
    if (!keyWin) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWin = w; break; }
        }
    }
    if (!keyWin) return;

    UIViewController *fvc = [self findFlutterVC:keyWin.rootViewController];
    if (!fvc) return;

    CGPoint dragVec = [self computeDirectVectorToPaintedDot:targetRight];
    CGPoint startPt = _calibratedKickPos;
    CGPoint endPt = CGPointMake(startPt.x + dragVec.x, startPt.y + dragVec.y);

    _activeCornerName = targetRight ? @"R90 (SAĞ DİREK)" : @"L90 (SOL DİREK)";

    _shotBtn.transform = CGAffineTransformMakeScale(0.86, 0.86);
    _shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.0f alpha:1.0f];
    [UIView animateWithDuration:_chargeDuration animations:^{
        self->_shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.05f blue:0.05f alpha:1.0f];
    }];

    WpsMockTouch *touch = [[WpsMockTouch alloc] init];
    touch.customWindow = keyWin;
    touch.customView = fvc.view;
    touch.customLocation = startPt;
    touch.customPreviousLocation = startPt;
    touch.customPhase = UITouchPhaseBegan;
    touch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

    _activeMockTouch = touch;
    _activeFlutterVC = fvc;
    _shotStartPt = startPt;
    _shotEndPt = endPt;
    _shotStartTime = CACurrentMediaTime();
    _shotMovedSent = NO;
    _isShooting = YES;

    [fvc touchesBegan:[NSSet setWithObject:touch] withEvent:nil];
}

@end

// ==========================================
// CALayer & CAMetalLayer Hook: FlutterMetalLayer IOSurface Yakalama
// ==========================================
@interface CALayer (WpsSurfaceCapture)
@end

@implementation CALayer (WpsSurfaceCapture)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [CALayer class];
        SEL origSel = @selector(setContents:);
        SEL swizSel = @selector(wps_setContents:);
        Method origM = class_getInstanceMethod(cls, origSel);
        Method swizM = class_getInstanceMethod(cls, swizSel);
        if (origM && swizM) {
            method_exchangeImplementations(origM, swizM);
        }
    });
}

- (void)wps_setContents:(id)contents {
    [self wps_setContents:contents];
    if (contents) {
        CFTypeRef cf = (__bridge CFTypeRef)contents;
        if (CFGetTypeID(cf) == IOSurfaceGetTypeID()) {
            [[WpsShotManager sharedInstance] onCapturedIOSurface:(IOSurfaceRef)cf];
        }
    }
}

@end

// ==========================================
// UIWindow Hook: Şut Butonu Otomatik Kalibrasyon
// ==========================================
@interface UIWindow (WpsTouchCapture)
@end

@implementation UIWindow (WpsTouchCapture)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [UIWindow class];
        SEL origSel = @selector(sendEvent:);
        SEL swizSel = @selector(wps_sendEvent:);
        Method origM = class_getInstanceMethod(cls, origSel);
        Method swizM = class_getInstanceMethod(cls, swizSel);
        if (origM && swizM) {
            method_exchangeImplementations(origM, swizM);
        }
    });
}

- (void)wps_sendEvent:(UIEvent *)event {
    [self wps_sendEvent:event];

    if (event.type == UIEventTypeTouches) {
        NSSet *touches = [event allTouches];
        CGSize scr = [UIScreen mainScreen].bounds.size;
        CGFloat w = MAX(scr.width, scr.height);
        CGFloat h = MIN(scr.width, scr.height);

        for (UITouch *touch in touches) {
            if ([touch isKindOfClass:[WpsMockTouch class]]) continue;

            if (touch.phase == UITouchPhaseBegan) {
                CGPoint pt = [touch locationInView:self];
                if (pt.x > (w * 0.55f) && pt.y > (h * 0.40f)) {
                    UIView *hitView = [self hitTest:pt withEvent:event];
                    if (![hitView isKindOfClass:[UIButton class]]) {
                        [[WpsShotManager sharedInstance] onKickButtonTouchedAt:pt];
                    }
                }
            }
        }
    }
}

@end

// ==========================================
// Entry Point
// ==========================================
__attribute__((constructor))
static void WpsInit(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                       object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        [[WpsShotManager sharedInstance] setupTweak];
    }];
}
