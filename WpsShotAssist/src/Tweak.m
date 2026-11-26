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
#import <stdlib.h>

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
@property (nonatomic, assign) int lockMode;
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

    // 1. Oyuncu Noktasından (playerPt) Haritadaki Sol ve Sağ Kale Direği Noktalarına Kesikli Çizgi
    if (self.playerPt.x > 10.0f) {
        CGFloat dashLengths[2] = {5.0f, 4.0f};

        // Sol direk nişan hattı (Turkuaz)
        CGContextSaveGState(ctx);
        CGContextSetLineDash(ctx, 0, dashLengths, 2);
        CGContextSetRGBStrokeColor(ctx, 0.0f, 0.95f, 1.0f, 0.80f);
        CGContextSetLineWidth(ctx, 1.8f);
        CGContextMoveToPoint(ctx, self.playerPt.x, self.playerPt.y);
        CGContextAddLineToPoint(ctx, self.leftPostPt.x, self.leftPostPt.y);
        CGContextStrokePath(ctx);

        // Sağ direk nişan hattı (Sarı/Turuncu)
        CGContextSetRGBStrokeColor(ctx, 1.0f, 0.80f, 0.0f, 0.80f);
        CGContextSetLineWidth(ctx, 1.8f);
        CGContextMoveToPoint(ctx, self.playerPt.x, self.playerPt.y);
        CGContextAddLineToPoint(ctx, self.rightPostPt.x, self.rightPostPt.y);
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);

        // İki direk arası kale ağzı çizgisi
        CGContextSetRGBStrokeColor(ctx, 0.2f, 1.0f, 0.4f, 0.85f);
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

        // 3. SOL DİREK NOKTASI (● L90)
        CGRect lOuter = CGRectMake(self.leftPostPt.x - 8.0f, self.leftPostPt.y - 8.0f, 16.0f, 16.0f);
        CGRect lInner = CGRectMake(self.leftPostPt.x - 4.0f, self.leftPostPt.y - 4.0f, 8.0f, 8.0f);
        CGContextSetRGBFillColor(ctx, 0.0f, 0.92f, 1.0f, 0.95f);
        CGContextFillEllipseInRect(ctx, lOuter);
        CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
        CGContextSetLineWidth(ctx, 2.0f);
        CGContextStrokeEllipseInRect(ctx, lOuter);
        CGContextSetRGBFillColor(ctx, 0.95f, 0.1f, 0.2f, 1.0f);
        CGContextFillEllipseInRect(ctx, lInner);

        // 4. SAĞ DİREK NOKTASI (● R90)
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
- (void)onTouchEvent:(UITouch *)touch inWindow:(UIWindow *)win;
- (void)onCapturedIOSurface:(IOSurfaceRef)surface;
- (void)onMetalTextureCaptured:(id<MTLTexture>)tex;
- (void)executeShotToRightCorner:(BOOL)targetRight;
- (void)toggleAttackDirection;
- (void)resetGoalToCenter;
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

    // Frame-accurate CADisplayLink şut & harita kale takip motoru
    CADisplayLink *_displayLink;
    NSTimeInterval _lastFrameTime;
    CGFloat _chargeDuration; // Varsayılan: 0.64s

    // Aktif şut durumu
    BOOL _isShooting;
    int _shotMoveStep;
    NSTimeInterval _shotStartTime;
    CGPoint _shotStartPt;
    CGPoint _shotEndPt;
    NSString *_activeCornerName;
    WpsMockTouch *_activeMockTouch;
    __weak UIViewController *_activeFlutterVC;

    // Harita Üzerindeki Kalenin Gerçek Ekran Koordinatları (UIWindow Point Uzayında)
    // Oyuncu yürüdükçe kamera oyuncuyla hareket ettiği için kale noktaları ters yönde (-vx*dt, -vy*dt) kayarak haritada SABİT kalır!
    CGPoint _leftPostScreenPt;   // ● L90
    CGPoint _rightPostScreenPt;  // ● R90
    CGPoint _playerScreenPt;     // ⊕ Oyuncu (Kamera merkezinde)
    CGFloat _screenW;
    CGFloat _screenH;
    int _lastLockMode;           // 0=HaritaTakip, 1=SahaÇizgiKilit, 2=KaleAğıKilit

    // Sol Hareket Joystick Takibi (Takılma Korumalı 60 FPS Ters-Kamera Harita Sabitleyici)
    __weak UITouch *_moveTouch;
    CGPoint _moveOrigin;
    CGPoint _moveCurrent;

    // Metal / IOSurface Framebuffer Yakalayıcı
    IOSurfaceRef _latestSurface;
    id<MTLTexture> _currTexture;
    id<MTLTexture> _prevTexture;
    uint8_t *_rowBuf0;
    uint8_t *_rowBuf1;
    size_t _rowBufCap;
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
    NSString *lockTag = (_lastLockMode == 2) ? @"🟢KALE-KİLİT" : ((_lastLockMode == 1) ? @"🟡SAHA-KİLİT" : @"🔵HARİTA-SABİT");
    _statusOverlay.message = [NSString stringWithFormat:@"%@ | L90:(%.0f,%.0f) R90:(%.0f,%.0f) [Sıfırlamak İçin Bara Dokun]",
                              lockTag,
                              _leftPostScreenPt.x, _leftPostScreenPt.y,
                              _rightPostScreenPt.x, _rightPostScreenPt.y];
}

- (void)resetGoalToCenter {
    CGFloat goalY = _attackDirectionDown ? (_screenH * 0.725f) : (_screenH * 0.275f);
    // Gerçek saha merkezi (0.469*W) etrafında sol direk içi (0.418*W) ve sağ direk içi (0.520*W)
    _leftPostScreenPt  = CGPointMake(_screenW * 0.418f, goalY);
    _rightPostScreenPt = CGPointMake(_screenW * 0.520f, goalY);
    _playerScreenPt    = CGPointMake(_screenW * 0.500f, _attackDirectionDown ? (_screenH * 0.420f) : (_screenH * 0.610f));

    if (_statusOverlay) {
        _statusOverlay.leftPostPt = _leftPostScreenPt;
        _statusOverlay.rightPostPt = _rightPostScreenPt;
        _statusOverlay.playerPt = _playerScreenPt;
        [self updateBannerCoordinates];
        [_statusOverlay setNeedsDisplay];
    }
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

        // Mavi Kick Butonunun Ekran Görüntüsünden Ölçülen TAM MERKEZİ: (0.8523 * W, 0.4585 * H) -> (763.7, 189.8)
        // Önceki (761, 212) değeri merkezden 22pt aşağıda olduğu için şut açısını saptırıyordu!
        self->_calibratedKickPos = CGPointMake(w * 0.8523f, h * 0.4585f);
        self->_attackDirectionDown = NO;

        [self resetGoalToCenter];

        if (!self->_statusOverlay) {
            self->_statusOverlay = [[WpsStatusOverlay alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            self->_statusOverlay.leftPostPt = self->_leftPostScreenPt;
            self->_statusOverlay.rightPostPt = self->_rightPostScreenPt;
            self->_statusOverlay.playerPt = self->_playerScreenPt;
            [keyWin addSubview:self->_statusOverlay];
            [self showToast:[NSString stringWithFormat:@"🟢 HARİTA KALE SABİTLEYİCİ AKTİF | ŞARJ: %.2fs", self->_chargeDuration] duration:3.0];
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
            self->_aimLabel.text = @"🎯 ÇİZGİYE";
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
            self->_lastFrameTime = CACurrentMediaTime();
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
// Metal MTLTexture getBytes & IOSurface Okuyucu
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

- (BOOL)readScanline:(size_t)y into:(uint8_t *)buf width:(size_t)W fromSurfaceBase:(uint8_t *)base bpr:(size_t)bpr orTexture:(id<MTLTexture>)tex {
    if (base) {
        memcpy(buf, base + y * bpr, W * 4);
        return YES;
    }
    if (tex && !tex.framebufferOnly) {
        @try {
            [tex getBytes:buf bytesPerRow:W * 4 fromRegion:MTLRegionMake2D(0, y, W, 1) mipmapLevel:0];
            return YES;
        } @catch (NSException *ex) {
            return NO;
        }
    }
    return NO;
}

// ==========================================
// Boşluk Toleranslı (Gap-Tolerant) Kale Ağı & Saha Çizgisi Tarayıcısı
// ==========================================
- (void)scanLiveFrameForGoalPostsAndPlayer {
    if (_screenW < 100.0f || _screenH < 100.0f) return;

    id<MTLTexture> tex = _prevTexture ? _prevTexture : _currTexture;
    IOSurfaceRef surface = _latestSurface;
    if (!surface && tex && [tex respondsToSelector:@selector(iosurface)]) {
        typedef IOSurfaceRef (*GetSurfaceFn)(id, SEL);
        surface = ((GetSurfaceFn)objc_msgSend)(tex, @selector(iosurface));
    }

    uint8_t *base = NULL;
    size_t W = 0, H = 0, bpr = 0;
    BOOL lockedSurface = NO;

    if (surface && IOSurfaceLock(surface, 1 /* kIOSurfaceLockReadOnly */, NULL) == 0) {
        lockedSurface = YES;
        base = (uint8_t *)IOSurfaceGetBaseAddress(surface);
        W = IOSurfaceGetWidth(surface);
        H = IOSurfaceGetHeight(surface);
        bpr = IOSurfaceGetBytesPerRow(surface);
        if (!base || W < 400 || H < 250 || bpr < W * 4) {
            base = NULL;
        }
    }

    if (!base && tex && !tex.framebufferOnly) {
        W = tex.width;
        H = tex.height;
    }

    if (W < 400 || H < 250) {
        if (lockedSurface) IOSurfaceUnlock(surface, 1, NULL);
        return;
    }

    if (_rowBufCap < W * 4) {
        free(_rowBuf0);
        free(_rowBuf1);
        _rowBufCap = W * 4;
        _rowBuf0 = (uint8_t *)malloc(_rowBufCap);
        _rowBuf1 = (uint8_t *)malloc(_rowBufCap);
    }

    // Kayan Pencere (Sliding Window) Boşluk-Toleranslı Kale Ağı Tespiti:
    // Piksel-art kale ağındaki delikleri ve kalecinin kafasını tolere eder!
    size_t goalW = (size_t)(W * 0.125);
    size_t netY0 = _attackDirectionDown ? (size_t)(H * 0.60) : (size_t)(H * 0.15);
    size_t netY1 = _attackDirectionDown ? (size_t)(H * 0.95) : (size_t)(H * 0.42);
    size_t dyStep = (size_t)fmax(3.0, H * 0.012);
    size_t yStride = (size_t)fmax(4.0, H * 0.010);

    int bestScore = 0;
    size_t bestXL = 0, bestXR = 0, bestY = 0;

    for (size_t y = netY0; y + dyStep < netY1; y += yStride) {
        if (![self readScanline:y into:_rowBuf0 width:W fromSurfaceBase:base bpr:bpr orTexture:tex]) break;
        if (![self readScanline:y + dyStep into:_rowBuf1 width:W fromSurfaceBase:base bpr:bpr orTexture:tex]) break;

        size_t margin = (size_t)(W * 0.015);
        for (size_t xL = margin + 4; xL + goalW + margin + 4 < W; xL += 4) {
            uint8_t *pL0 = _rowBuf0 + xL * 4;
            if (!(pL0[2] > 105 && pL0[1] > 108 && pL0[0] > 105 && abs((int)pL0[2] - (int)pL0[0]) < 32)) continue;

            size_t xR = xL + goalW;
            // Sol dışında ve sağ dışında yeşil çim (G > R + 22 ve R < 85) olmalı
            uint8_t *gL = _rowBuf0 + (xL - margin) * 4;
            uint8_t *gR = _rowBuf0 + (xR + margin) * 4;
            if (!((int)gL[1] > (int)gL[2] + 22 && gL[2] < 88 &&
                  (int)gR[1] > (int)gR[2] + 22 && gR[2] < 88)) {
                continue;
            }

            int score = 0;
            int samples = 0;
            size_t xStep = (size_t)fmax(2.0, goalW / 32);
            for (size_t k = xL; k <= xR; k += xStep) {
                uint8_t *c0 = _rowBuf0 + k * 4;
                uint8_t *c1 = _rowBuf1 + k * 4;
                BOOL hit0 = (c0[2] > 105 && c0[1] > 108 && c0[0] > 105 && abs((int)c0[2] - (int)c0[0]) < 32);
                BOOL hit1 = (c1[2] > 105 && c1[1] > 108 && c1[0] > 105 && abs((int)c1[2] - (int)c1[0]) < 32);
                if (hit0 || hit1) score++;
                samples++;
            }

            if (samples > 0 && score >= (samples * 6) / 10 && score > bestScore) {
                bestScore = score;
                bestXL = xL;
                bestXR = xR;
                bestY = y;
            }
        }
    }

    if (lockedSurface) {
        IOSurfaceUnlock(surface, 1, NULL);
    }

    if (bestScore > 0) {
        CGFloat normLeftX  = ((CGFloat)bestXL / (CGFloat)W) + 0.010f;
        CGFloat normRightX = ((CGFloat)bestXR / (CGFloat)W) - 0.010f;
        CGFloat normGoalY  = _attackDirectionDown
            ? (((CGFloat)bestY / (CGFloat)H) - 0.010f)
            : (((CGFloat)bestY / (CGFloat)H) + 0.064f);

        _leftPostScreenPt  = CGPointMake(normLeftX * _screenW, normGoalY * _screenH);
        _rightPostScreenPt = CGPointMake(normRightX * _screenW, normGoalY * _screenH);
        _lastLockMode = 2;

        if (_statusOverlay) {
            _statusOverlay.leftPostPt = _leftPostScreenPt;
            _statusOverlay.rightPostPt = _rightPostScreenPt;
            _statusOverlay.playerPt = _playerScreenPt;
            _statusOverlay.lockMode = _lastLockMode;
            [self updateBannerCoordinates];
            [_statusOverlay setNeedsDisplay];
        }
    }
}

// ==========================================
// Sol Hareket Joystick & Üst Bar Dokunuş Yakalayıcı
// ==========================================
- (void)onTouchEvent:(UITouch *)touch inWindow:(UIWindow *)win {
    CGPoint pt = [touch locationInView:win];

    // Üst bilgi barına dokunulduysa kaleyi merkeze sıfırla (Santra / Başlangıç sıfırlaması)
    if (touch.phase == UITouchPhaseBegan && pt.y < 36.0f && fabsf(pt.x - _screenW * 0.5f) < 220.0f) {
        [self resetGoalToCenter];
        AudioServicesPlaySystemSound(1519);
        [self showToast:@"🎯 KALE NOKTALARI MERKEZE SIFIRLANDI" duration:1.5];
        return;
    }

    // Sol Hareket Joystick'i: Oyuncu yürüdükçe kaleyi haritada SABİT tutmak için ters-kamera entegrasyonu
    if (touch.phase == UITouchPhaseBegan && pt.x < (_screenW * 0.44f) && pt.y > (_screenH * 0.28f)) {
        _moveTouch = touch;
        _moveOrigin = pt;
        _moveCurrent = pt;
    } else if (touch == _moveTouch) {
        if (touch.phase == UITouchPhaseMoved || touch.phase == UITouchPhaseStationary) {
            _moveCurrent = pt;
        } else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
            _moveTouch = nil;
            _moveCurrent = _moveOrigin;
        }
    }
}

// ==========================================
// 60 FPS CADisplayLink: Ters-Kamera Harita Sabitleyici & Kesikli Çizgi Şut Motoru
// ==========================================
- (void)onDisplayLink:(CADisplayLink *)link {
    NSTimeInterval now = CACurrentMediaTime();
    CGFloat dt = (CGFloat)(now - _lastFrameTime);
    if (dt <= 0.0f || dt > 0.15f) dt = 1.0f / 60.0f;
    _lastFrameTime = now;

    // 1. HARİTA KALE SABİTLEYİCİ (Ters-Kamera Hareketi):
    // Kamera oyuncuyu ekranın ortasında (448, 253) sabit tuttuğu için:
    // Oyuncu sağa (+vx) yürüdüğünde haritadaki kale ekranda sola (-vx) kayar!
    // Oyuncu aşağı (+vy) yürüdüğünde haritadaki kale ekranda yukarı (-vy) kayar!
    if (_moveTouch != nil) {
        UITouchPhase ph = _moveTouch.phase;
        if (ph == UITouchPhaseEnded || ph == UITouchPhaseCancelled) {
            _moveTouch = nil;
        } else {
            CGFloat jdx = _moveCurrent.x - _moveOrigin.x;
            CGFloat jdy = _moveCurrent.y - _moveOrigin.y;
            CGFloat jlen = sqrtf(jdx * jdx + jdy * jdy);
            if (jlen > 5.0f) {
                // Joystick deadzone sonrası yön vektörü ve tam hız (185 pt/sn ekran kayma hızı)
                CGFloat maxJoyR = 38.0f;
                CGFloat throttle = fminf(1.0f, jlen / maxJoyR);
                CGFloat ux = (jdx / jlen) * throttle;
                CGFloat uy = (jdy / jlen) * throttle;

                CGFloat playerSpeedPtPerSec = 185.0f;
                CGFloat camShiftX = -ux * playerSpeedPtPerSec * dt;
                CGFloat camShiftY = -uy * playerSpeedPtPerSec * dt;

                CGFloat newLX = fmaxf(-120.0f, fminf(_screenW + 20.0f, _leftPostScreenPt.x + camShiftX));
                CGFloat newRX = newLX + (_screenW * 0.102f); // Sabit kale genişliği (91.4 pt)
                CGFloat newGY = fmaxf(-150.0f, fminf(_screenH + 150.0f, _leftPostScreenPt.y + camShiftY));

                _leftPostScreenPt  = CGPointMake(newLX, newGY);
                _rightPostScreenPt = CGPointMake(newRX, newGY);

                if (_statusOverlay) {
                    _statusOverlay.leftPostPt = _leftPostScreenPt;
                    _statusOverlay.rightPostPt = _rightPostScreenPt;
                    [self updateBannerCoordinates];
                    [_statusOverlay setNeedsDisplay];
                }
            }
        }
    }

    // 2. AKTİF ŞUT YÖNETİMİ (3 Kademeli Pürüzsüz Çekiş + Tam Tepe Noktasında Bırakma)
    if (_isShooting && _activeMockTouch && _activeFlutterVC) {
        NSTimeInterval elapsed = now - _shotStartTime;
        if (elapsed >= _chargeDuration) {
            _activeMockTouch.customPreviousLocation = _shotEndPt;
            _activeMockTouch.customLocation = _shotEndPt;
            _activeMockTouch.customPhase = UITouchPhaseEnded;
            _activeMockTouch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

            [_activeFlutterVC touchesEnded:[NSSet setWithObject:_activeMockTouch] withEvent:nil];

            _isShooting = NO;
            _shotMoveStep = 0;
            _activeMockTouch = nil;

            [UIView animateWithDuration:0.08 animations:^{
                self->_shotBtn.transform = CGAffineTransformIdentity;
                self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.92f green:0.10f blue:0.18f alpha:0.95f];
            }];

            AudioServicesPlaySystemSound(1520);
            [self showToast:[NSString stringWithFormat:@"🚀 ŞUT ATEŞLENDİ -> %@ (%.2fs) 🎯", _activeCornerName, _chargeDuration] duration:1.5];
        } else if (elapsed >= 0.015) {
            // Mavi şut butonunun tam merkezinden (763.7, 189.8) kesikli çizgi yönüne 3 adımda pürüzsüz çek
            _shotMoveStep++;
            CGFloat frac = (_shotMoveStep == 1) ? 0.35f : ((_shotMoveStep == 2) ? 0.75f : 1.0f);
            CGPoint curPt = CGPointMake(_shotStartPt.x + (_shotEndPt.x - _shotStartPt.x) * frac,
                                        _shotStartPt.y + (_shotEndPt.y - _shotStartPt.y) * frac);

            _activeMockTouch.customPreviousLocation = _activeMockTouch.customLocation;
            _activeMockTouch.customLocation = curPt;
            _activeMockTouch.customPhase = UITouchPhaseMoved;
            _activeMockTouch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

            [_activeFlutterVC touchesMoved:[NSSet setWithObject:_activeMockTouch] withEvent:nil];
        }
    }

    // 3. Her 80ms'de bir Metal/IOSurface üzerinden optik kale ağı kilidini kontrol et
    if (now - _lastVisionScanTime >= 0.08) {
        _lastVisionScanTime = now;
        [self scanLiveFrameForGoalPostsAndPlayer];
    }
}

// ==========================================
// Kesikli Çizgiyle %100 Birebir Örtüşen Şut Vektörü Hesabı
// ==========================================
- (CGPoint)computeDirectVectorToPaintedDot:(BOOL)targetRight {
    [self scanLiveFrameForGoalPostsAndPlayer];

    CGPoint targetDot = targetRight ? _rightPostScreenPt : _leftPostScreenPt;
    CGFloat rawDX = targetDot.x - _playerScreenPt.x;
    CGFloat rawDY = targetDot.y - _playerScreenPt.y;

    // Oyunun _computeAim içindeki kickHorizontalFactor (~1.40x yatay çarpan) sapmasını dengele:
    // Böylece oyunun sarı/turuncu şut çizgisi ekrandaki kesikli çizginin TAM ÜSTÜNDEN geçer!
    CGFloat dx = rawDX * 0.72f;
    CGFloat dy = rawDY;

    CGFloat len = sqrtf(dx * dx + dy * dy);
    if (len < 1.0f) {
        dx = targetRight ? 15.0f : -15.0f;
        dy = _attackDirectionDown ? 78.0f : -78.0f;
        len = sqrtf(dx * dx + dy * dy);
    }

    CGFloat dragRadius = 78.0f;
    return CGPointMake((dx / len) * dragRadius, (dy / len) * dragRadius);
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
    [self resetGoalToCenter];

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
// Kesikli Çizgi Üzerinden Boyalı Direk Noktasına (L90 / R90) Şut İcrası
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

    // Mavi şut butonunun tam merkezini (0.8523*W, 0.4585*H) kullan!
    _calibratedKickPos = CGPointMake(_screenW * 0.8523f, _screenH * 0.4585f);

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
    _shotMoveStep = 0;
    _isShooting = YES;

    [fvc touchesBegan:[NSSet setWithObject:touch] withEvent:nil];
}

@end

// ==========================================
// CAMetalLayer & CALayer Hook: FramebufferOnly=NO Zorlama + Texture/IOSurface Yakalama
// ==========================================
@interface CAMetalLayer (WpsMetalCapture)
@end

@implementation CAMetalLayer (WpsMetalCapture)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [CAMetalLayer class];

        SEL s1 = @selector(setFramebufferOnly:);
        SEL w1 = @selector(wps_setFramebufferOnly:);
        Method m1 = class_getInstanceMethod(cls, s1);
        Method mw1 = class_getInstanceMethod(cls, w1);
        if (m1 && mw1) method_exchangeImplementations(m1, mw1);

        SEL s2 = @selector(nextDrawable);
        SEL w2 = @selector(wps_nextDrawable);
        Method m2 = class_getInstanceMethod(cls, s2);
        Method mw2 = class_getInstanceMethod(cls, w2);
        if (m2 && mw2) method_exchangeImplementations(m2, mw2);
    });
}

- (void)wps_setFramebufferOnly:(BOOL)framebufferOnly {
    // Texture'ların CPU'dan getBytes: ile okunabilmesi için daima NO zorla!
    [self wps_setFramebufferOnly:NO];
}

- (id<CAMetalDrawable>)wps_nextDrawable {
    [self wps_setFramebufferOnly:NO];
    id<CAMetalDrawable> drawable = [self wps_nextDrawable];
    if (drawable) {
        id<MTLTexture> tex = [drawable texture];
        if (tex) {
            [[WpsShotManager sharedInstance] onMetalTextureCaptured:tex];
        }
    }
    return drawable;
}

@end

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
// UIWindow Hook: Sol Hareket Joystick Takibi
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
        for (UITouch *touch in touches) {
            if ([touch isKindOfClass:[WpsMockTouch class]]) continue;
            [[WpsShotManager sharedInstance] onTouchEvent:touch inWindow:self];
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
