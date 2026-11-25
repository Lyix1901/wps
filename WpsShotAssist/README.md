# WPS Shot Assist (Well Played Soccer iOS)

## Özellikler
- **Tek Tuşla Otomatik Kırmızı Şut**: Mavi şut butonunu beklemeden maksimum kırmızı tavan gücüne (`49.9999`) çıkarıp fırlatır.
- **Köşe Direk Kitleme (Corner Aim)**: Vuruş açısını doğrudan kalenin sol ve sağ direk kenarlarına alternatif kilitler.
- **Yüzen Overlay Butonu**: Ekranda istenilen yere sürüklenebilen dairesel `⚡SHOT` butonu.
- **Fiziksel Ses Tuşu Tetikleme (Volume Up)**: Başparmağını hareket joystick'inden kaldırmadan fiziksel ses açma tuşuyla anında şut imkanı.

## Kurulum ve Enjeksiyon (Sideloadly / LuxinaSigner)
1. `WpsShotAssist.dylib` dosyasını temin edin (GitHub Actions veya macOS / Theos üzerinden derlenir).
2. Masaüstündeki **Sideloadly**'yi açın.
3. İndirdiğin `wellplayed.soccer.mobile-1.8.2-Decrypted.ipa` dosyasını Sideloadly'ye sürükleyin.
4. **Advanced Options** sekmesine tıklayın.
5. **Inject Dylibs / Frameworks** bölümüne `WpsShotAssist.dylib` ekleyin.
6. **Start** butonuna basarak iPhone'unuza yükleyin.
