#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

// ==========================================
// Flutter Engine Pointer Definitions
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
// ESP Overlay View
// ==========================================
@interface WpsEspOverlayView : UIView
@property (nonatomic, assign) BOOL espEnabled;
@property (nonatomic, assign) CGPoint kickButtonPos;
@end

@implementation WpsEspOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.espEnabled = YES;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    if (!self.espEnabled) return;

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    // 1. Radar Kutusu (Sol Üst Köşe)
    CGRect radarRect = CGRectMake(20, 20, 140, 80);
    CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 0.55);
    CGContextFillRect(ctx, radarRect);
    CGContextSetRGBStrokeColor(ctx, 0.2, 0.8, 0.2, 0.9);
    CGContextSetLineWidth(ctx, 1.5);
    CGContextStrokeRect(ctx, radarRect);

    // Saha Orta Çizgisi
    CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.4);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextMoveToPoint(ctx, radarRect.origin.x + radarRect.size.width / 2.0, radarRect.origin.y);
    CGContextAddLineToPoint(ctx, radarRect.origin.x + radarRect.size.width / 2.0, radarRect.origin.y + radarRect.size.height);
    CGContextStrokePath(ctx);

    // Kaleler (Sol ve Sağ Kale Çizgileri)
    CGContextSetRGBStrokeColor(ctx, 1.0, 0.8, 0.0, 0.9);
    CGContextSetLineWidth(ctx, 2.5);
    // Sol Kale
    CGContextMoveToPoint(ctx, radarRect.origin.x + 2, radarRect.origin.y + 24);
    CGContextAddLineToPoint(ctx, radarRect.origin.x + 2, radarRect.origin.y + 56);
    // Sağ Kale
    CGContextMoveToPoint(ctx, radarRect.origin.x + radarRect.size.width - 2, radarRect.origin.y + 24);
    CGContextAddLineToPoint(ctx, radarRect.origin.x + radarRect.size.width - 2, radarRect.origin.y + 56);
    CGContextStrokePath(ctx);

    // Kendi Oyuncun (Cyan Nokta)
    CGContextSetRGBFillColor(ctx, 0.0, 1.0, 1.0, 1.0);
    CGContextFillEllipseInRect(ctx, CGRectMake(radarRect.origin.x + 55, radarRect.origin.y + 36, 8, 8));

    // Rakip Kaleci (Kırmızı Nokta)
    CGContextSetRGBFillColor(ctx, 1.0, 0.1, 0.1, 1.0);
    CGContextFillEllipseInRect(ctx, CGRectMake(radarRect.origin.x + radarRect.size.width - 10, radarRect.origin.y + 37, 6, 6));

    // Top (Sarı Yanıp Sönen Nokta)
    CGContextSetRGBFillColor(ctx, 1.0, 0.9, 0.0, 1.0);
    CGContextFillEllipseInRect(ctx, CGRectMake(radarRect.origin.x + 68, radarRect.origin.y + 38, 5, 5));

    // 2. Şut Hedefleme Çaprazı (Kalenin 90 Direkleri Görsel Göstergesi)
    if (self.kickButtonPos.x > 0 && self.kickButtonPos.y > 0) {
        // Şut butonunun etrafına hedefleme halkası
        CGContextSetRGBStrokeColor(ctx, 1.0, 0.0, 0.3, 0.8);
        CGContextSetLineWidth(ctx, 2.0);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(self.kickButtonPos.x - 35, self.kickButtonPos.y - 35, 70, 70));
    }
}
@end

// ==========================================
// Tweak Manager
// ==========================================
@interface WpsShotManager : NSObject
+ (instancetype)sharedInstance;
- (void)setupTweak;
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
    CGPoint _detectedKickBtnPos;
}

+ (instancetype)sharedInstance {
    static WpsShotManager *inst = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        inst = [[WpsShotManager alloc] init];
    });
    return inst;
}

- (void)setupTweak {
    // 1. Flutter Engine fonksiyonunu yükle
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

        UIViewController *rootVC = keyWin.rootViewController;
        if ([rootVC respondsToSelector:@selector(engine)]) {
            _flutterEngine = [rootVC performSelector:@selector(engine)];
        }

        CGSize scr = [UIScreen mainScreen].bounds.size;
        CGFloat w = MAX(scr.width, scr.height);
        CGFloat h = MIN(scr.width, scr.height);

        // Varsayılan mavi buton koordinatı (Landscape modda sağ alt)
        _detectedKickBtnPos = CGPointMake(w - 95.0f, h - 85.0f);

        // ESP Overlay Ekle
        if (!_espOverlay) {
            _espOverlay = [[WpsEspOverlayView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            _espOverlay.kickButtonPos = _detectedKickBtnPos;
            [keyWin addSubview:_espOverlay];
        }

        // ⚡SHOT Butonu
        if (!_shotBtn) {
            _shotBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            _shotBtn.frame = CGRectMake(w - 80.0f, h / 2.0f - 30.0f, 60.0f, 60.0f);
            _shotBtn.backgroundColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.25f alpha:0.90f];
            [_shotBtn setTitle:@"⚡SHOT" forState:UIControlStateNormal];
            _shotBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
            [_shotBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            _shotBtn.layer.cornerRadius = 30.0f;
            _shotBtn.layer.borderWidth = 2.5f;
            _shotBtn.layer.borderColor = [UIColor whiteColor].CGColor;
            _shotBtn.layer.shadowColor = [UIColor blackColor].CGColor;
            _shotBtn.layer.shadowOffset = CGSizeMake(0, 3);
            _shotBtn.layer.shadowOpacity = 0.5f;
            _shotBtn.layer.shadowRadius = 4.0f;

            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
            [_shotBtn addGestureRecognizer:pan];
            [_shotBtn addTarget:self action:@selector(triggerPerfectCornerShot) forControlEvents:UIControlEventTouchUpInside];
            [keyWin addSubview:_shotBtn];
        }

        // 👁️ESP Butonu
        if (!_espBtn) {
            _espBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            _espBtn.frame = CGRectMake(w - 80.0f, h / 2.0f + 40.0f, 60.0f, 32.0f);
            _espBtn.backgroundColor = [UIColor colorWithRed:0.1f green:0.75f blue:0.3f alpha:0.85f];
            [_espBtn setTitle:@"ESP: ON" forState:UIControlStateNormal];
            _espBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10.0f];
            [_espBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            _espBtn.layer.cornerRadius = 16.0f;
            _espBtn.layer.borderWidth = 1.5f;
            _espBtn.layer.borderColor = [UIColor whiteColor].CGColor;
            [_espBtn addTarget:self action:@selector(toggleEsp) forControlEvents:UIControlEventTouchUpInside];
            [keyWin addSubview:_espBtn];
        }

        // Ses tuşu ile tetikleme
        [self setupVolumeHook];
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

// Mükemmel Kırmızı Şut ve Direk Açı Enjeksiyonu
- (void)triggerPerfectCornerShot {
    // Buton basma animasyonu
    [UIView animateWithDuration:0.07 animations:^{
        self->_shotBtn.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self->_shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.0f alpha:1.0f];
    } completion:^(BOOL fin) {
        [UIView animateWithDuration:0.07 animations:^{
            self->_shotBtn.transform = CGAffineTransformIdentity;
            self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.25f alpha:0.90f];
        }];
    }];

    // Alternatif olarak sol 90 ve sağ 90 köşelerini seç
    _targetingRightCorner = !_targetingRightCorner;
    CGFloat angle = _targetingRightCorner ? -0.45f : -1.15f; // Yatayda kalenin sol ve sağ direkleri
    CGFloat dragDist = 70.0f; // Tam kırmızı güce ulaşacak çekim mesafesi

    CGPoint start = _detectedKickBtnPos;
    CGPoint end = CGPointMake(start.x + dragDist * cosf(angle), start.y + dragDist * sinf(angle));

    // 1. Flutter Engine Pointer API üzerinden şutu bas
    if (_sendPointerFunc && _flutterEngine) {
        size_t now = (size_t)(CACurrentMediaTime() * 1000000.0);

        // kDown
        FlutterPointerEvent evDown = {
            .struct_size = sizeof(FlutterPointerEvent),
            .phase = kFlutterPointerPhaseDown,
            .timestamp = now,
            .x = start.x,
            .y = start.y,
            .device = 2,
            .device_kind = 1,
            .buttons = 1
        };
        _sendPointerFunc(_flutterEngine, &evDown, 1);

        // Anında kalenin köşesine çek (Drag -> Aim Corner)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            FlutterPointerEvent evMove = {
                .struct_size = sizeof(FlutterPointerEvent),
                .phase = kFlutterPointerPhaseMove,
                .timestamp = (size_t)(CACurrentMediaTime() * 1000000.0),
                .x = end.x,
                .y = end.y,
                .device = 2,
                .device_kind = 1,
                .buttons = 1
            };
            self->_sendPointerFunc(self->_flutterEngine, &evMove, 1);

            // 0.35 saniye bekle (Bar en tepeye, tam kırmızıya dolduğu an) ve serbest bırak (Max Power 49.9999)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                FlutterPointerEvent evUp = {
                    .struct_size = sizeof(FlutterPointerEvent),
                    .phase = kFlutterPointerPhaseUp,
                    .timestamp = (size_t)(CACurrentMediaTime() * 1000000.0),
                    .x = end.x,
                    .y = end.y,
                    .device = 2,
                    .device_kind = 1,
                    .buttons = 0
                };
                self->_sendPointerFunc(self->_flutterEngine, &evUp, 1);
            });
        });
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
