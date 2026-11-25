#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
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
// Status Toast Overlay (Bildirim & Geri Bildirim)
// ==========================================
@interface WpsStatusOverlay : UIView
@property (nonatomic, copy) NSString *message;
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
    if (self.message.length == 0) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGSize scr = self.bounds.size;
    CGRect bannerRect = CGRectMake(scr.width / 2.0f - 210.0f, 8.0f, 420.0f, 26.0f);

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:bannerRect cornerRadius:6.0f];
    CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 0.82);
    [path fill];

    CGContextSetRGBStrokeColor(ctx, 1.0, 0.25, 0.2, 0.95);
    CGContextSetLineWidth(ctx, 1.2);
    [path stroke];

    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:11.5f],
        NSForegroundColorAttributeName: [UIColor colorWithRed:1.0f green:0.9f blue:0.2f alpha:1.0f]
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
- (void)onMoveJoystickTouch:(UITouch *)touch inWindow:(UIWindow *)win;
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

    // Frame-accurate CADisplayLink শut & pozisyon motoru
    CADisplayLink *_displayLink;
    NSTimeInterval _lastFrameTime;
    CGFloat _chargeDuration; // Varsayılan: 0.64s (Geri düşmeden tam %100 Kırmızı Tepe Noktası)

    // Aktif şut durumu (CADisplayLink üzerinden milisaniyelik kontrol)
    BOOL _isShooting;
    BOOL _shotMovedSent;
    NSTimeInterval _shotStartTime;
    CGPoint _shotStartPt;
    CGPoint _shotEndPt;
    NSString *_activeCornerName;
    WpsMockTouch *_activeMockTouch;
    __weak UIViewController *_activeFlutterVC;

    // Canlı Saha & Kale Koordinat Takibi
    // playerNormX: -1.0 (Sol Taç) .. 0.0 (Kale Merkezi) .. +1.0 (Sağ Taç)
    // playerNormY: -1.0 (Üst Kale Çizgisi) .. 0.0 (Orta Saha) .. +1.0 (Alt Kale Çizgisi)
    CGFloat _playerNormX;
    CGFloat _playerNormY;
    BOOL _hasLiveVisionLock;

    // Sol Hareket Joystick Takibi (Canlı Dead-Reckoning)
    __weak UITouch *_moveTouch;
    CGPoint _moveOrigin;
    CGPoint _moveCurrent;
    BOOL _isMoving;

    // Metal Framebuffer Texture (Kale ve Oyuncu Koordinat Tarayıcısı)
    id<MTLTexture> _currTexture;
    id<MTLTexture> _prevTexture;
    NSTimeInterval _lastVisionScanTime;
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
        NSNumber *savedDur = [[NSUserDefaults standardUserDefaults] objectForKey:@"wps_charge_duration_v2"];
        if (savedDur && savedDur.doubleValue >= 0.40 && savedDur.doubleValue <= 0.90) {
            _chargeDuration = (CGFloat)savedDur.doubleValue;
        } else {
            // 0.80s tepeyi çok az geçip geri düştüğü için tam %100 kırmızı tepe noktası = 0.64s
            _chargeDuration = 0.64f;
        }
        _playerNormX = 0.0f;
        _playerNormY = -0.45f;
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
    _statusOverlay.message = msg;
    [_statusOverlay setNeedsDisplay];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearToast) object:nil];
    [self performSelector:@selector(clearToast) withObject:nil afterDelay:sec];
}

- (void)clearToast {
    if (_statusOverlay) {
        _statusOverlay.message = @"";
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

        self->_calibratedKickPos = CGPointMake(761.0f, 212.0f);
        self->_isCalibrated = YES;
        self->_attackDirectionDown = NO;

        if (!self->_statusOverlay) {
            self->_statusOverlay = [[WpsStatusOverlay alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            [keyWin addSubview:self->_statusOverlay];
            [self showToast:[NSString stringWithFormat:@"[WPS] ⚡ Dinamik Kale Aim + %.2fs Tepe Güç Hazır", self->_chargeDuration] duration:4.0];
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
            subLbl.text = @"◀ L | R ▶";
            subLbl.font = [UIFont boldSystemFontOfSize:10.5f];
            subLbl.textColor = [UIColor colorWithRed:1.0f green:0.88f blue:0.15f alpha:1.0f];
            subLbl.textAlignment = NSTextAlignmentCenter;
            subLbl.userInteractionEnabled = NO;
            [self->_shotBtn addSubview:subLbl];

            self->_aimLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 44, btnSize, 16)];
            self->_aimLabel.text = @"⬆ KALEYE";
            self->_aimLabel.font = [UIFont boldSystemFontOfSize:9.0f];
            self->_aimLabel.textColor = [UIColor colorWithRed:0.4f green:1.0f blue:0.5f alpha:1.0f];
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
    [[NSUserDefaults standardUserDefaults] setDouble:_chargeDuration forKey:@"wps_charge_duration_v2"];
    _timerLabel.text = [NSString stringWithFormat:@"%.2fs", _chargeDuration];
    AudioServicesPlaySystemSound(1519);
    [self showToast:[NSString stringWithFormat:@"⏱ ŞUT ŞARJ SÜRESİ: %.2f sn (-20ms)", _chargeDuration] duration:1.8];
}

- (void)increaseChargeTime {
    _chargeDuration = fminf(0.84f, _chargeDuration + 0.02f);
    [[NSUserDefaults standardUserDefaults] setDouble:_chargeDuration forKey:@"wps_charge_duration_v2"];
    _timerLabel.text = [NSString stringWithFormat:@"%.2fs", _chargeDuration];
    AudioServicesPlaySystemSound(1519);
    [self showToast:[NSString stringWithFormat:@"⏱ ŞUT ŞARJ SÜRESİ: %.2f sn (+20ms)", _chargeDuration] duration:1.8];
}

// ==========================================
// Canlı Metal Framebuffer'dan Kale ve Oyuncu Koordinatı Okuma
// ==========================================
- (void)onMetalTextureCaptured:(id<MTLTexture>)tex {
    if (!tex) return;
    if (_currTexture && _currTexture != tex) {
        _prevTexture = _currTexture;
    }
    _currTexture = tex;
}

- (BOOL)scanLiveFrameForGoalAndPlayer {
    id<MTLTexture> tex = _prevTexture ? _prevTexture : _currTexture;
    if (!tex) return NO;

    SEL ioSel = @selector(iosurface);
    if (![tex respondsToSelector:ioSel]) return NO;

    typedef IOSurfaceRef (*GetSurfaceFn)(id, SEL);
    IOSurfaceRef surface = ((GetSurfaceFn)objc_msgSend)(tex, ioSel);
    if (!surface) return NO;

    if (IOSurfaceLock(surface, 1 /* kIOSurfaceLockReadOnly */, NULL) != 0) {
        return NO;
    }

    uint8_t *base = (uint8_t *)IOSurfaceGetBaseAddress(surface);
    size_t W = IOSurfaceGetWidth(surface);
    size_t H = IOSurfaceGetHeight(surface);
    size_t bpr = IOSurfaceGetBytesPerRow(surface);

    if (!base || W < 400 || H < 250 || bpr < W * 4) {
        IOSurfaceUnlock(surface, 1, NULL);
        return NO;
    }

    // 1. Kontrol Edilen Oyuncunun Sarı İsmini / Halkasını Bul (rayancherki31)
    long sumX = 0, sumY = 0, yellowCount = 0;
    size_t yStart = (size_t)(H * 0.14);
    size_t yEnd   = (size_t)(H * 0.86);
    size_t xStart = (size_t)(W * 0.16);
    size_t xEnd   = (size_t)(W * 0.67);

    for (size_t y = yStart; y < yEnd; y += 3) {
        uint8_t *row = base + y * bpr;
        for (size_t x = xStart; x < xEnd; x += 3) {
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

    CGFloat playerScreenX = 0.50f;
    CGFloat playerScreenY = 0.54f;
    BOOL foundPlayer = NO;
    if (yellowCount >= 5) {
        playerScreenX = ((CGFloat)sumX / (CGFloat)yellowCount) / (CGFloat)W;
        playerScreenY = (((CGFloat)sumY / (CGFloat)yellowCount) / (CGFloat)H) + 0.085f;
        foundPlayer = YES;
    }

    // 2. Sahanın Sol ve Sağ Beyaz Taç Çizgilerini Bul (Saha Genişliği = 0.8515 * W)
    CGFloat leftLineX = -1.0f;
    CGFloat rightLineX = -1.0f;

    size_t band1Y0 = (size_t)(H * 0.63), band1Y1 = (size_t)(H * 0.89);
    size_t band2Y0 = (size_t)(H * 0.20), band2Y1 = (size_t)(H * 0.39);
    size_t stepY = (size_t)fmax(2.0, H * 0.02);

    for (size_t x = (size_t)(W * 0.02); x < (size_t)(W * 0.98); x += 3) {
        int hits1 = 0, total1 = 0;
        for (size_t y = band1Y0; y < band1Y1; y += stepY) {
            uint8_t *p = base + y * bpr + x * 4;
            if (p[2] > 150 && p[1] > 160 && p[0] > 150) hits1++;
            total1++;
        }
        int hits2 = 0, total2 = 0;
        for (size_t y = band2Y0; y < band2Y1; y += stepY) {
            uint8_t *p = base + y * bpr + x * 4;
            if (p[2] > 150 && p[1] > 160 && p[0] > 150) hits2++;
            total2++;
        }

        BOOL isLine = ((total1 > 0 && hits1 >= (total1 * 3) / 4) ||
                       (total2 > 0 && hits2 >= (total2 * 3) / 4));
        if (isLine) {
            CGFloat nx = (CGFloat)x / (CGFloat)W;
            if (nx < 0.46f && leftLineX < 0.0f) {
                leftLineX = nx;
            }
            if (nx > 0.54f && nx < 0.95f) {
                rightLineX = nx;
            }
        }
    }

    // 3. Kale Ağlarını Doğrudan Kontrol Et (Üst Kale Ağları Y = 0.20*H .. 0.32*H)
    CGFloat goalCenterX = -1.0f;
    if (leftLineX > 0.0f && rightLineX > 0.0f && fabsf((rightLineX - leftLineX) - 0.8515f) < 0.10f) {
        goalCenterX = 0.5f * (leftLineX + rightLineX);
    } else if (leftLineX > 0.0f) {
        goalCenterX = leftLineX + 0.4257f;
    } else if (rightLineX > 0.0f) {
        goalCenterX = rightLineX - 0.4257f;
    }

    // Üst veya Alt Yatay Kale Çizgisini Bul
    CGFloat detectedGoalY = -1.0f;
    if (!_attackDirectionDown) {
        for (size_t y = (size_t)(H * 0.17); y < (size_t)(H * 0.52); y += 3) {
            int hHits = 0, hTot = 0;
            for (size_t x = (size_t)(W * 0.22); x < (size_t)(W * 0.42); x += 8) {
                uint8_t *p0 = base + y * bpr + x * 4;
                uint8_t *p1 = base + (y + 1) * bpr + x * 4;
                if ((p0[2] > 150 && p0[1] > 160) || (p1[2] > 150 && p1[1] > 160)) hHits++;
                hTot++;
            }
            if (hTot > 0 && hHits >= (hTot * 3) / 4) {
                // Bu çizginin 35px üstünde mavi reklam panosu veya kale ağı var mı kontrol et
                size_t cy = (y > (size_t)(H * 0.12)) ? (y - (size_t)(H * 0.10)) : 5;
                int bannerHits = 0;
                for (size_t x = (size_t)(W * 0.20); x < (size_t)(W * 0.80); x += (size_t)(W * 0.05)) {
                    uint8_t *pb = base + cy * bpr + x * 4;
                    if (pb[0] > 145 && pb[2] < 120) bannerHits++;
                }
                if (bannerHits >= 4) {
                    detectedGoalY = (CGFloat)y / (CGFloat)H;
                } else {
                    // Orta saha çizgisi -> Kale yarım saha yukarıda
                    detectedGoalY = ((CGFloat)y / (CGFloat)H) - 0.72f;
                }
                break;
            }
        }
    }

    IOSurfaceUnlock(surface, 1, NULL);

    if (goalCenterX > -0.5f) {
        // Oyuncunun kaleye göre yatay konumu (-1.0 Sol Taç .. 0.0 Kale Merkezi .. +1.0 Sağ Taç)
        CGFloat relX = (playerScreenX - goalCenterX) / 0.4257f;
        _playerNormX = fmaxf(-0.95f, fminf(0.95f, relX));
        if (detectedGoalY > -1.0f) {
            // Oyuncunun kaleye olan dikey uzaklığı
            CGFloat distY = (playerScreenY - detectedGoalY) / 0.75f;
            _playerNormY = _attackDirectionDown ? (1.0f - fmaxf(0.12f, distY)) : (-1.0f + fmaxf(0.12f, distY));
        }
        _hasLiveVisionLock = YES;
        return YES;
    } else if (foundPlayer) {
        return YES;
    }

    return NO;
}

// ==========================================
// Sol Hareket Joystick Takibi + 60 FPS CADisplayLink
// ==========================================
- (void)onMoveJoystickTouch:(UITouch *)touch inWindow:(UIWindow *)win {
    CGPoint pt = [touch locationInView:win];
    if (touch.phase == UITouchPhaseBegan) {
        _moveTouch = touch;
        _moveOrigin = pt;
        _moveCurrent = pt;
        _isMoving = YES;
    } else if (touch == _moveTouch) {
        if (touch.phase == UITouchPhaseMoved || touch.phase == UITouchPhaseStationary) {
            _moveCurrent = pt;
            _isMoving = YES;
        } else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
            _isMoving = NO;
            _moveTouch = nil;
        }
    }
}

- (void)onDisplayLink:(CADisplayLink *)link {
    NSTimeInterval now = CACurrentMediaTime();
    CGFloat dt = (CGFloat)(now - _lastFrameTime);
    if (dt <= 0.0f || dt > 0.2f) dt = 1.0f / 60.0f;
    _lastFrameTime = now;

    // 1. Aktif Şut Varsa Milisaniyelik Hassasiyetle Yönet (Bar Geri Düşmeden Tam Tepede Bırak!)
    if (_isShooting && _activeMockTouch && _activeFlutterVC) {
        NSTimeInterval elapsed = now - _shotStartTime;
        if (elapsed >= _chargeDuration) {
            // TAM %100 KIRMIZI TEPE NOKTASINDA ŞUTU BIRAK (touchesEnded)
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
            [self showToast:[NSString stringWithFormat:@"🚀 TAM GÜÇ 49.9999 (%@ | %.2fs) 🎯", _activeCornerName, _chargeDuration] duration:1.8];
        } else if (elapsed >= 0.022) {
            // Joystick'i hedef kale vektöründe tut
            _activeMockTouch.customPreviousLocation = _shotMovedSent ? _shotEndPt : _shotStartPt;
            _activeMockTouch.customLocation = _shotEndPt;
            _activeMockTouch.customPhase = UITouchPhaseMoved;
            _activeMockTouch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

            [_activeFlutterVC touchesMoved:[NSSet setWithObject:_activeMockTouch] withEvent:nil];
            _shotMovedSent = YES;
        }
    }

    // 2. Sol Hareket Joystick'i İle Saha İçi Konum Entegrasyonu
    if (_isMoving && _moveTouch) {
        CGFloat dx = _moveCurrent.x - _moveOrigin.x;
        CGFloat dy = _moveCurrent.y - _moveOrigin.y;
        CGFloat dist = sqrtf(dx * dx + dy * dy);
        if (dist > 4.0f) {
            CGFloat maxR = 48.0f;
            CGFloat nx = fmaxf(-1.0f, fminf(1.0f, dx / maxR));
            CGFloat ny = fmaxf(-1.0f, fminf(1.0f, dy / maxR));
            // Oyuncunun saha içindeki normalize koordinatlarını güncelle
            _playerNormX = fmaxf(-0.92f, fminf(0.92f, _playerNormX + nx * dt * 0.48f));
            _playerNormY = fmaxf(-0.88f, fminf(0.88f, _playerNormY + ny * dt * 0.38f));
        }
    }

    // 3. Her 120ms'de bir Metal Framebuffer üzerinden kale & oyuncu koordinatını doğrula
    if (now - _lastVisionScanTime >= 0.12) {
        _lastVisionScanTime = now;
        [self scanLiveFrameForGoalAndPlayer];
        [self updateAimIndicatorLabel];
    }
}

- (void)updateAimIndicatorLabel {
    if (!_aimLabel) return;
    NSString *arrow = _attackDirectionDown ? @"⬇" : @"⬆";
    if (_playerNormX > 0.22f) {
        // Oyuncu sağ kanatta/köşede -> Kale sol-yukarıda (veya sol-aşağıda)
        arrow = _attackDirectionDown ? @"↙ SOLA" : @"↖ SOLA";
    } else if (_playerNormX < -0.22f) {
        // Oyuncu sol kanatta/köşede -> Kale sağ-yukarıda (veya sağ-aşağıda)
        arrow = _attackDirectionDown ? @"↘ SAĞA" : @"↗ SAĞA";
    } else {
        arrow = _attackDirectionDown ? @"⬇ MERKEZ" : @"⬆ MERKEZ";
    }
    _aimLabel.text = arrow;
}

// ==========================================
// Oyuncu Konumundan Kalenin 90 Köşesine Dinamik Vektör Hesabı
// ==========================================
- (CGPoint)computeGoalVectorForRightCorner:(BOOL)targetRight {
    // Şut anında en güncel ekran/kale koordinatını oku
    [self scanLiveFrameForGoalAndPlayer];

    // Kale Direk Koordinatları (PitchConstants normalize uzayı: Saha X in [-1..+1], Kale Merkezi X = 0.0)
    // Sol 90 direk içi: X = -0.125, Sağ 90 direk içi: X = +0.125
    CGFloat goalPostX = targetRight ? 0.125f : -0.125f;
    CGFloat goalLineY = _attackDirectionDown ? 1.0f : -1.0f;

    // Oyuncudan (playerNormX, playerNormY) -> Hedef Kale Direğine (goalPostX, goalLineY) Vektör:
    // Aspect ratio düzeltmesi: Saha genişliği / yarım saha yüksekliği
    CGFloat vecX = (goalPostX - _playerNormX) * 1.15f;
    CGFloat vecY = (goalLineY - _playerNormY);

    // Oyuncu korner çizgisine çok yakın olsa bile topun auta çıkmaması için kaleye doğru minimum dikey açı garantisi
    if (!_attackDirectionDown && vecY > -0.22f) {
        vecY = -0.22f;
    } else if (_attackDirectionDown && vecY < 0.22f) {
        vecY = 0.22f;
    }

    CGFloat len = sqrtf(vecX * vecX + vecY * vecY);
    if (len < 0.001f) {
        vecX = targetRight ? 0.22f : -0.22f;
        vecY = _attackDirectionDown ? 0.97f : -0.97f;
        len = 1.0f;
    }

    CGFloat dragRadius = 84.0f;
    return CGPointMake((vecX / len) * dragRadius, (vecY / len) * dragRadius);
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
    _playerNormX = 0.0f;
    _playerNormY = _attackDirectionDown ? 0.45f : -0.45f;
    AudioServicesPlaySystemSound(1519);
    [self updateAimIndicatorLabel];

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
// Dinamik Kale Koordinatlı & Tam Tepe Güçlü Şut İcrası
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

    // Oyuncunun sahadaki anlık konumundan kalenin seçilen 90 direğine tam vektör hesapla
    CGPoint dragVec = [self computeGoalVectorForRightCorner:targetRight];
    CGPoint startPt = _calibratedKickPos;
    CGPoint endPt = CGPointMake(startPt.x + dragVec.x, startPt.y + dragVec.y);

    _activeCornerName = targetRight ? @"SAĞ 90" : @"SOL 90";
    [self updateAimIndicatorLabel];

    // Buton görsel şarj animasyonu
    _shotBtn.transform = CGAffineTransformMakeScale(0.86, 0.86);
    _shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.0f alpha:1.0f];
    [UIView animateWithDuration:_chargeDuration animations:^{
        self->_shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.05f blue:0.05f alpha:1.0f];
    }];

    // 1. ADIM: Şut butonunun merkezine bas (touchesBegan)
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
// CAMetalLayer Hook: Canlı Saha & Kale Koordinatlarını Yakalama
// ==========================================
@interface CAMetalLayer (WpsFrameCapture)
@end

@implementation CAMetalLayer (WpsFrameCapture)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [CAMetalLayer class];
        SEL origSel = @selector(nextDrawable);
        SEL swizSel = @selector(wps_nextDrawable);
        Method origM = class_getInstanceMethod(cls, origSel);
        Method swizM = class_getInstanceMethod(cls, swizSel);
        if (origM && swizM) {
            method_exchangeImplementations(origM, swizM);
        }
    });
}

- (id<CAMetalDrawable>)wps_nextDrawable {
    if (self.framebufferOnly) {
        self.framebufferOnly = NO;
    }
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

// ==========================================
// UIWindow Hook: Sol Hareket Joystick & Sağ Şut Butonu Algılama
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

            CGPoint pt = [touch locationInView:self];

            // Sol yarıdaki Hareket Joystick'i dokunuşlarını takip et (Oyuncunun sağ/sol köşeye gidişini izler)
            if (pt.x < (w * 0.45f) && pt.y > (h * 0.30f)) {
                [[WpsShotManager sharedInstance] onMoveJoystickTouch:touch inWindow:self];
            }
            // Sağ yarıdaki Mavi Şut Butonu kalibrasyonu
            else if (touch.phase == UITouchPhaseBegan && pt.x > (w * 0.55f) && pt.y > (h * 0.40f)) {
                // Kendi ⚡SHOT butonumuza veya süre hapına dokunulmadıysa kalibre et
                UIView *hitView = [self hitTest:pt withEvent:event];
                if (![hitView isKindOfClass:[UIButton class]]) {
                    [[WpsShotManager sharedInstance] onKickButtonTouchedAt:pt];
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
