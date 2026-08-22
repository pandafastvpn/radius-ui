# NETORA-Radius

Sistem Manajemen Jaringan berbasis Web UI untuk otentikasi (FreeRADIUS).

## Cara Instalasi

1. Download atau *clone* seluruh isi repositori ini ke server Linux Ubuntu 22.04 / 20.04 yang masih bersih (Fresh Install).
2. Masuk ke direktori repositori ini (`cd radius-ui` atau sesuai nama foldernya).
3. Jalankan perintah instalasi otomatis sebagai `root`:
   ```bash
   apt update && apt install git -y
   git clone https://github.com/desienkz-slp/radius-ui.git
   cd radius-ui
   chmod +x install.sh
   ./install.sh
   ```
4. Tunggu hingga proses selesai. Semua *service* (Nginx, MariaDB, Node.js, FreeRADIUS) akan dipasang otomatis.

## Login Default

Setelah instalasi selesai, buka IP Address server Anda di browser (misal: `http://192.168.1.10` atau domain).

- **Username Default**: `superadmin`
- **Password Default**: `admin123`

âš ï¸ **Sangat disarankan** untuk segera mengganti password `superadmin` setelah berhasil login pertama kali demi keamanan server Anda.

## Cara Update (Pembaruan)

Mulai versi terbaru, NETORA-Radius mendukung pembaruan otomatis (Auto-Update) langsung dari Web UI (Dashboard Admin).

### Opsi 1: Auto-Update via Web UI (Rekomendasi)
Jika ada rilis terbaru di GitHub, akan muncul tombol **Update Available** di pojok kanan atas panel *Header* Anda. Cukup klik tombol tersebut untuk mengupdate dan me-restart sistem secara otomatis.

**PENTING: Konfigurasi Git Passwordless**
Agar fitur Auto-Update Web UI berfungsi di latar belakang tanpa terhenti karena meminta password, jalankan perintah ini **satu kali saja** di terminal server Anda:
```bash
cd /var/www/radius-ui  # Atau direktori tempat Anda men-clone repo
git config --global --add safe.directory /var/www/radius-ui
git pull origin main
```

### Opsi 2: Update Manual via Terminal
Jika Anda sedang menggunakan terminal SSH:
1. Masuk ke folder *clone* repositori Anda:
   ```bash
   cd /var/www/radius-ui
   ```
2. Jalankan script update:
   ```bash
   bash update.sh
   ```

*(Jika Anda mendapati error "fatal: not a git repository" saat update, itu berarti server Anda belum terhubung dengan Git. Jalankan perintah ini: `git init && git remote add origin https://github.com/desienkz-slp/radius-ui.git && git fetch && git reset --hard origin/main`)*

## Catatan Penting

### Username dengan Karakter `@` (Email)
Secara bawaan (*default*), FreeRADIUS memotong nama user di belakang tanda `@` karena menganggapnya sebagai *realm* (domain). Ini akan menyebabkan user dengan tanda `@` gagal terhubung (Authentication Failed) karena namanya tidak akan ditemukan di database.

Untuk mengatasi hal ini dan mengizinkan pemakaian tanda `@` di Username PPP, Anda wajib mematikan modul `suffix` pada server Radius secara manual. Jalankan perintah ini di Terminal/SSH Anda (cukup sekali di awal instalasi):

```bash
sed -i 's/^[[:space:]]*suffix/#\tsuffix/g' /etc/freeradius/3.0/sites-enabled/default && systemctl restart freeradius
```
