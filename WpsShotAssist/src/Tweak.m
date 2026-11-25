#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

// ==========================================
// Flutter Engine C API Definitions
// ==========================================
typedef enum {
    kFlutterPointerPhaseCancel = 0,
    kFlutterPointerPhaseUp     = 1,
    kFlutterPointerPhaseDown   = 2,
    kFlutterPointerPhaseMove   = 3,
    kFlutterPointerPhaseAdd    = 4,
    kFlutterPointerPhaseRemove = 5,
    kFlutterPointerPhaseHover  = 6,
} FlutterPointerPhase;

typedef struct {
    size_t struct_size;
    int32_t phase;
    size_t timestamp; // microseconds
    double x;
    double y;
    int64_t device;
    int32_t signal_kind;
    double scroll_delta_x;
    double scroll_delta_y;
    int32_t device_kind; // 1 = touch
    int64_t buttons;
    double pan_x;
    double pan_y;
    double scale;
    double rotation;
} FlutterPointerEvent;

typedef int (*FlutterEngineSendPointerEventFunc)(id engine, const FlutterPointerEvent* events, size_t count);

// ==========================================
// Dynamic ESP & Sightline Overlay
// ==========================================
@interface WpsEspOverlayView : UIView
@property (nonatomic, assign) BOOL espEnabled;
@property (nonatomic, assign) CGPoint calibratedKickPos;
@property (nonatomic, assign) BOOL isTargetingRightCorner;
@property (nonatomic, copy) NSString *statusMessage;
@end

@implementation WpsEspOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.espEnabled = YES;
        self.statusMessage = @"[WPS] Mavi Butona 1 Kez Bas (Konum Kalibre Edilsin)";
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGSize scr = self.bounds.size;

    // Durum Bildirimi / Status Banner
    if (self.statusMessage.length > 0) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:11.0f],
            NSForegroundColorAttributeName: [UIColor colorWithRed:1.0f green:0.85f blue:0.1f alpha:1.0f]
        };
        CGRect bannerRect = CGRectMake(scr.width / 2.0f - 160.0f, 12.0f, 320.0f, 22.0f);
        CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 0.65);
        CGContextFillRect(ctx, bannerRect);
        [self.statusMessage drawInRect:CGRectMake(bannerRect.origin.x + 8, bannerRect.origin.y + 4, bannerRect.size.width - 16, 16) withAttributes:attrs];
    }

    if (!self.espEnabled) return;

    // 1. Taktik Radar (Sol Üst)
    CGRect radar = CGRectMake(20, 25, 130, 75);
    CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 0.60);
    CGContextFillRect(ctx, radar);
    CGContextSetRGBStrokeColor(ctx, 0.1, 0.9, 0.2, 0.9);
    CGContextSetLineWidth(ctx, 1.5);
    CGContextStrokeRect(ctx, radar);

    // Orta Çizgi & Çember
    CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.35);
    CGContextMoveToPoint(ctx, radar.origin.x + radar.size.width / 2.0, radar.origin.y);
    CGContextAddLineToPoint(ctx, radar.origin.x + radar.size.width / 2.0, radar.origin.y + radar.size.height);
    CGContextStrokePath(ctx);
    CGContextStrokeEllipseInRect(ctx, CGRectMake(radar.origin.x + radar.size.width/2.0 - 10, radar.origin.y + radar.size.height/2.0 - 10, 20, 20));

    // Kaleler
    CGContextSetRGBStrokeColor(ctx, 1.0, 0.85, 0.0, 0.9);
    CGContextSetLineWidth(ctx, 2.5);
    CGContextStrokeRect(ctx, CGRectMake(radar.origin.x, radar.origin.y + 22, 4, 31)); // Sol Kale
    CGContextStrokeRect(ctx, CGRectMake(radar.origin.x + radar.size.width - 4, radar.origin.y + 22, 4, 31)); // Sağ Kale

    // 2. Kale Direkleri ESP Nişangahı (Sol 90 & Sağ 90 Hedefleme Göstergesi)
    CGFloat aimAngle = self.isTargetingRightCorner ? -0.45f : -1.15f;
    CGFloat lineLen = 120.0f;
    CGPoint pCenter = CGPointMake(scr.width / 2.0f, scr.height / 2.0f);
    CGPoint aimTarget = CGPointMake(pCenter.x + lineLen * cosf(aimAngle), pCenter.y + lineLen * sinf(aimAngle));

    // Hedefleme Lazer Çizgisi (Yeşil / Kırmızı)
    CGContextSetRGBStrokeColor(ctx, 0.0, 1.0, 0.3, 0.75);
    CGContextSetLineWidth(ctx, 1.5);
    CGFloat dash[] = {4.0, 3.0};
    CGContextSetLineDash(ctx, 0, dash, 2);
    CGContextMoveToPoint(ctx, pCenter.x, pCenter.y);
    CGContextAddLineToPoint(ctx, aimTarget.x, aimTarget.y);
    CGContextStrokePath(ctx);
    CGContextSetLineDash(ctx, 0, NULL, 0);

    // 3. Kalibre Edilmiş Şut Butonu Halkası
    if (self.calibratedKickPos.x > 0 && self.calibratedKickPos.y > 0) {
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.1, 0.2, 0.85);
        CGContextSetLineWidth(ctx, 2.0);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(self.calibratedKickPos.x - 35, self.calibratedKickPos.y - 35, 70, 70));

        NSDictionary *lblAttr = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:9.0f],
            NSForegroundColorAttributeName: [UIColor whiteColor]
        };
        [@"⚡KICK" drawAtPoint:CGPointMake(self.calibratedKickPos.x - 14, self.calibratedKickPos.y - 6) withAttributes:lblAttr];
    }
}
@end

// ==========================================
// Tweak Manager
// ==========================================
@interface WpsShotManager : NSObject
+ (instancetype)sharedInstance;
- (void)setupTweak;
- (void)onKickButtonTouchedAt:(CGPoint)pos;
- (void)triggerPerfectCornerShot;
- (void)toggleEsp;
@end

@implementation WpsShotManager {
    UIButton *_shotBtn;
    UIButton *_espBtn;
    WpsEspOverlayView *_espOverlay;
    BOOL _targetingRightCorner;
    FlutterEngineSendPointerEventFunc _sendPointerFunc;
    id _flutterEngine;
    CGPoint _calibratedKickPos;
    BOOL _isCalibrated;
}

+ (instancetype)sharedInstance {
    static WpsShotManager *inst = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        inst = [[WpsShotManager alloc] init];
    });
    return inst;
}

// Görünüm hiyerarşisinde FlutterViewController'ı ve motorunu derinlemesine bul
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

- (void)setupTweak {
    _sendPointerFunc = (FlutterEngineSendPointerEventFunc)dlsym(RTLD_DEFAULT, "FlutterEngineSendPointerEvent");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWin = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWin = w; break; }
        }
        if (!keyWin && [UIApplication sharedApplication].windows.count > 0) {
            keyWin = [UIApplication sharedApplication].windows.firstObject;
        }
        if (!keyWin) return;

        UIViewController *fvc = [self findFlutterVC:keyWin.rootViewController];
        if (fvc && [fvc respondsToSelector:@selector(engine)]) {
            self->_flutterEngine = [fvc performSelector:@selector(engine)];
        }

        CGSize scr = [UIScreen mainScreen].bounds.size;
        CGFloat w = MAX(scr.width, scr.height);
        CGFloat h = MIN(scr.width, scr.height);

        // Varsayılan tahmini mavi buton konumu
        self->_calibratedKickPos = CGPointMake(w - 95.0f, h - 85.0f);

        // ESP Katmanı Ekle
        if (!self->_espOverlay) {
            self->_espOverlay = [[WpsEspOverlayView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            self->_espOverlay.calibratedKickPos = self->_calibratedKickPos;
            [keyWin addSubview:self->_espOverlay];
        }

        // ⚡SHOT Butonu
        if (!self->_shotBtn) {
            self->_shotBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            self->_shotBtn.frame = CGRectMake(w - 80.0f, h / 2.0f - 35.0f, 62.0f, 62.0f);
            self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.25f alpha:0.92f];
            [self->_shotBtn setTitle:@"⚡SHOT" forState:UIControlStateNormal];
            self->_shotBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
            [self->_shotBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self->_shotBtn.layer.cornerRadius = 31.0f;
            self->_shotBtn.layer.borderWidth = 2.5f;
            self->_shotBtn.layer.borderColor = [UIColor whiteColor].CGColor;
            self->_shotBtn.layer.shadowColor = [UIColor blackColor].CGColor;
            self->_shotBtn.layer.shadowOffset = CGSizeMake(0, 3);
            self->_shotBtn.layer.shadowOpacity = 0.5f;
            self->_shotBtn.layer.shadowRadius = 4.0f;

            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
            [self->_shotBtn addGestureRecognizer:pan];
            [self->_shotBtn addTarget:self action:@selector(triggerPerfectCornerShot) forControlEvents:UIControlEventTouchUpInside];
            [keyWin addSubview:self->_shotBtn];
        }

        // 👁️ESP Butonu
        if (!self->_espBtn) {
            self->_espBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            self->_espBtn.frame = CGRectMake(w - 80.0f, h / 2.0f + 38.0f, 62.0f, 30.0f);
            self->_espBtn.backgroundColor = [UIColor colorWithRed:0.1f green:0.75f blue:0.3f alpha:0.85f];
            [self->_espBtn setTitle:@"ESP: ON" forState:UIControlStateNormal];
            self->_espBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10.0f];
            [self->_espBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self->_espBtn.layer.cornerRadius = 15.0f;
            self->_espBtn.layer.borderWidth = 1.5f;
            self->_espBtn.layer.borderColor = [UIColor whiteColor].CGColor;
            [self->_espBtn addTarget:self action:@selector(toggleEsp) forControlEvents:UIControlEventTouchUpInside];
            [keyWin addSubview:self->_espBtn];
        }

        // Ses Açma Butonu Hook
        [self setupVolumeHook];
    });
}

// Kullanıcı normal mavi butona bastığında konumunu otomatik öğren
- (void)onKickButtonTouchedAt:(CGPoint)pos {
    _calibratedKickPos = pos;
    _isCalibrated = YES;
    _espOverlay.calibratedKickPos = pos;
    _espOverlay.statusMessage = [NSString stringWithFormat:@"🎯 ŞUT BUTONU KALİBRE EDİLDİ: (%.0f, %.0f)", pos.x, pos.y];
    [_espOverlay setNeedsDisplay];

    // 4 saniye sonra bildirim yazısını gizle
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_espOverlay.statusMessage = @"";
        [self->_espOverlay setNeedsDisplay];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)p {
    UIView *v = p.view;
    CGPoint trans = [p translationInView:v.superview];
    v.center = CGPointMake(v.center.x + trans.x, v.center.y + trans.y);
    [p setTranslation:CGPointZero inView:v.superview];
}

- (void)setupVolumeHook {
    NSError *err;
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&err];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(triggerPerfectCornerShot)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

- (void)toggleEsp {
    _espOverlay.espEnabled = !_espOverlay.espEnabled;
    [_espOverlay setNeedsDisplay];
    if (_espOverlay.espEnabled) {
        [_espBtn setTitle:@"ESP: ON" forState:UIControlStateNormal];
        _espBtn.backgroundColor = [UIColor colorWithRed:0.1f green:0.75f blue:0.3f alpha:0.85f];
    } else {
        [_espBtn setTitle:@"ESP: OFF" forState:UIControlStateNormal];
        _espBtn.backgroundColor = [UIColor colorWithRed:0.5f green:0.5f blue:0.5f alpha:0.85f];
    }
}

// Mükemmel Şut Tetikleyici (Maksimum Kırmızı 49.9999 + Köşe Direk Kitleme)
- (void)triggerPerfectCornerShot {
    // Buton görsel geri bildirimi
    [UIView animateWithDuration:0.07 animations:^{
        self->_shotBtn.transform = CGAffineTransformMakeScale(0.82, 0.82);
        self->_shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.0f alpha:1.0f];
    } completion:^(BOOL fin) {
        [UIView animateWithDuration:0.07 animations:^{
            self->_shotBtn.transform = CGAffineTransformIdentity;
            self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.25f alpha:0.92f];
        }];
    }];

    // Alternatif olarak sol ve sağ köşe direkleri seç
    _targetingRightCorner = !_targetingRightCorner;
    _espOverlay.isTargetingRightCorner = _targetingRightCorner;
    [_espOverlay setNeedsDisplay];

    CGFloat angle = _targetingRightCorner ? -0.45f : -1.15f;
    CGFloat dragDist = 75.0f; // Tam kırmızı şut barı için çekim mesafesi

    CGPoint startPt = _calibratedKickPos;
    CGPoint endPt = CGPointMake(startPt.x + dragDist * cosf(angle), startPt.y + dragDist * sinf(angle));

    // Flutter Engine'i güncelle
    if (!_flutterEngine) {
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        UIViewController *fvc = [self findFlutterVC:w.rootViewController];
        if (fvc && [fvc respondsToSelector:@selector(engine)]) {
            _flutterEngine = [fvc performSelector:@selector(engine)];
        }
    }

    if (_sendPointerFunc && _flutterEngine) {
        // iOS Physical Pixel dönüşümü (Retina scale: @2x veya @3x)
        CGFloat scale = [UIScreen mainScreen].scale;
        double startX = startPt.x * scale;
        double startY = startPt.y * scale;
        double endX = endPt.x * scale;
        double endY = endPt.y * scale;

        int64_t devId = 99; // Hileye özel ayrılmış Pointer ID

        // 1. ADIM: kAdd (Flutter pointer havuzuna yeni dokunma ekle)
        FlutterPointerEvent evAdd = {
            .struct_size = sizeof(FlutterPointerEvent),
            .phase = kFlutterPointerPhaseAdd,
            .timestamp = (size_t)(CACurrentMediaTime() * 1000000.0),
            .x = startX,
            .y = startY,
            .device = devId,
            .device_kind = 1,
            .buttons = 0
        };
        _sendPointerFunc(_flutterEngine, &evAdd, 1);

        // 2. ADIM: kDown (Mavi şut butonuna bas)
        FlutterPointerEvent evDown = {
            .struct_size = sizeof(FlutterPointerEvent),
            .phase = kFlutterPointerPhaseDown,
            .timestamp = (size_t)(CACurrentMediaTime() * 1000000.0),
            .x = startX,
            .y = startY,
            .device = devId,
            .device_kind = 1,
            .buttons = 1
        };
        _sendPointerFunc(_flutterEngine, &evDown, 1);

        // 3. ADIM: kMove (Direğe doğru çek / Aim Vector)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            FlutterPointerEvent evMove = {
                .struct_size = sizeof(FlutterPointerEvent),
                .phase = kFlutterPointerPhaseMove,
                .timestamp = (size_t)(CACurrentMediaTime() * 1000000.0),
                .x = endX,
                .y = endY,
                .device = devId,
                .device_kind = 1,
                .buttons = 1
            };
            self->_sendPointerFunc(self->_flutterEngine, &evMove, 1);

            // 4. ADIM: Barın en kırmızıya dolması (~0.35s) ve kUp (Bırak -> 49.9999 Max Shot)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                FlutterPointerEvent evUp = {
                    .struct_size = sizeof(FlutterPointerEvent),
                    .phase = kFlutterPointerPhaseUp,
                    .timestamp = (size_t)(CACurrentMediaTime() * 1000000.0),
                    .x = endX,
                    .y = endY,
                    .device = devId,
                    .device_kind = 1,
                    .buttons = 0
                };
                self->_sendPointerFunc(self->_flutterEngine, &evUp, 1);

                // 5. ADIM: kRemove (Pointerı serbest bırak)
                FlutterPointerEvent evRem = {
                    .struct_size = sizeof(FlutterPointerEvent),
                    .phase = kFlutterPointerPhaseRemove,
                    .timestamp = (size_t)(CACurrentMediaTime() * 1000000.0),
                    .x = endX,
                    .y = endY,
                    .device = devId,
                    .device_kind = 1,
                    .buttons = 0
                };
                self->_sendPointerFunc(self->_flutterEngine, &evRem, 1);
            });
        });
    }
}

@end

// ==========================================
// Method Swizzling: UIWindow & FlutterView Touches
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
            if (touch.phase == UITouchPhaseBegan) {
                CGPoint pt = [touch locationInView:self];
                CGSize scr = [UIScreen mainScreen].bounds.size;
                CGFloat w = MAX(scr.width, scr.height);
                CGFloat h = MIN(scr.width, scr.height);

                // Ekranın sağ alt çeyreğine dokunulduysa (mavi şut butonu bölgesi)
                if (pt.x > (w * 0.55f) && pt.y > (h * 0.45f)) {
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
