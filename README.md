# Atlas Onboard - Landing Page Perusahaan

Implementasi website perusahaan untuk integrasi hasil [ATL-95](/ATL/issues/ATL-95), [ATL-96](/ATL/issues/ATL-96), dan [ATL-97](/ATL/issues/ATL-97) di repo utama.

## Cakupan

- Halaman utama responsif dengan tema dark aesthetic
- Hero + CTA final dari ATL-96
- Section visi dan misi (copywriting ATL-96)
- Katalog layanan:
  - Pengembangan Web
  - Konten & Kreatif
  - Software Analisa
  - Dukungan TI
- Kontak kanal publik (email, TikTok, Instagram) tanpa kredensial sensitif sesuai SOP ATL-97

## Struktur File

- `index.html` - struktur konten landing page
- `styles.css` - style, layout responsif, dan visual theme
- `script.js` - animasi reveal dan tahun footer otomatis

## Cara Menjalankan

1. Dari root proyek, jalankan server statis:
   - `python3 -m http.server 8080`
2. Buka browser ke:
   - `http://localhost:8080`

Alternatif tanpa server: buka langsung `index.html` di browser.

## Otomasi Laporan Harian 08:00 WIB ke Telegram

Repo ini juga menyertakan otomasi laporan harian berbasis shell script:

- `automation/daily_telegram_report.sh` - ambil status assignment dari Paperclip dan kirim ke Telegram.
- `automation/.env.example` - template konfigurasi environment/secrets.
- `automation/cron.example` - template cron job harian jam 08:00 Asia/Jakarta.

### 1) Konfigurasi Secrets

```bash
cp automation/.env.example automation/.env
```

Edit `automation/.env` lalu isi nilai berikut:

- `PAPERCLIP_API_URL`
- `PAPERCLIP_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

Catatan keamanan:

- Jangan commit `automation/.env` ke git.
- Simpan token hanya di environment/secrets manager.

### 2) Verifikasi Manual (Dry Run)

Untuk validasi format laporan tanpa kirim ke Telegram:

```bash
DRY_RUN=1 ./automation/daily_telegram_report.sh
```

Log tersimpan di `deliverables/logs/daily-telegram-report.log`.

### 3) Verifikasi Pengiriman Telegram

Set `DRY_RUN=0` dan pastikan token + chat id valid:

```bash
DRY_RUN=0 ./automation/daily_telegram_report.sh
```

Jika sukses, log akan mencatat `Laporan berhasil dikirim ke Telegram`.

### 4) Pasang Cron Job 08:00 WIB

Contoh entry ada di `automation/cron.example`:

```cron
CRON_TZ=Asia/Jakarta
0 8 * * * cd /absolute/path/to/ATLAS-ONBOARD && /usr/bin/env bash ./automation/daily_telegram_report.sh >> ./deliverables/logs/cron.log 2>&1
```

Pasang dengan:

```bash
crontab -e
```

Lalu paste entry di atas (sesuaikan path absolut repo).

### 5) Troubleshooting Ringkas

- Gagal ambil data Paperclip:
  - cek `PAPERCLIP_API_URL` dan `PAPERCLIP_API_KEY`.
- Gagal kirim Telegram:
  - cek `TELEGRAM_BOT_TOKEN` dan `TELEGRAM_CHAT_ID`.
  - script menjalankan retry otomatis sesuai `RETRY_MAX_ATTEMPTS`.
