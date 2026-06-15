Panduan menyiapkan ikon untuk Google Play Store

1. Siapkan aset

- Tempatkan file logo utama (yang Anda lampirkan) ke: `assets/logo.png`.
- Buat versi khusus Play Store berukuran 512x512 PNG (32-bit RGBA) dan simpan sebagai: `assets/playstore_icon.png`.

2. Opsi otomatis (disarankan)

- Tambahkan konfigurasi berikut di `pubspec.yaml` (di bawah top-level):

  flutter_icons:
  android: true
  ios: true
  image_path: "assets/playstore_icon.png"

- Jalankan:

```bash
flutter pub get
flutter pub run flutter_launcher_icons:main
```

3. Opsi manual

- Jika tidak ingin menggunakan generator, cukup upload `assets/playstore_icon.png` (512x512 PNG) ke konsol Google Play saat Anda membuat listing aplikasi.

Catatan penting:

- Pastikan gambar 512x512 tidak terlalu kecil atau terkompresi; gunakan PNG 32-bit dengan alpha jika perlu.
- Jika ingin ikon adaptif Android, siapkan juga foreground/background sesuai pedoman Android Adaptive Icons.
