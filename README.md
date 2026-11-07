# KutemuKan - Lost and Found Kampus Unindra

![Logo KutemuKan](docs/logo.png)

**KutemuKan** adalah aplikasi lost and found untuk lingkungan kampus Universitas Indraprasta PGRI (UNINDRA). Mahasiswa yang kehilangan barang bisa memasang laporan kehilangan, penemu bisa memasang temuan, dan keduanya dipertemukan lewat alur klaim yang aman, pencocokan otomatis berbasis AI, watchlist barang yang dicari, chat di dalam aplikasi tanpa membagikan nomor pribadi, dan serah terima berkode.

Aplikasi ini karya komunitas mahasiswa dan bukan aplikasi resmi universitas.

Versi saat ini: **1.7.5** (Android, arm64)

## Unduh

APK Android terbaru selalu tersedia di halaman rilis:

**[Unduh KutemuKan.apk](https://github.com/dandienter/kutemukan/releases/latest/download/KutemuKan.apk)**

Di dalam aplikasi juga ada tombol Cek Update di tab Akun yang akan memberi tahu bila ada versi baru.

Versi web (papan publik, klaim, dan panel admin) berjalan dengan backend yang sama dan bisa dicoba di [demo KutemuKan Web](http://demo.43-130-228-96.sslip.io/kutemukan-web/). Tautan postingan yang dibagikan dari aplikasi membuka halaman web-nya, dan dari web ada tombol Buka di Aplikasi yang melompat langsung ke postingan yang sama di aplikasi Android (deep link `kutemukan://post/<id>`).

## Fitur utama

### Masuk dan identitas

- **Masuk dan verifikasi SIKA**: mahasiswa UNINDRA bisa masuk langsung dengan NPM dan kata sandi SIKA (kata sandi tidak pernah disimpan) atau memverifikasi akun email dan Google yang sudah ada. Akun terverifikasi berstatus Mahasiswa Terverifikasi, dan nama, NPM, program studi, fakultas, kelas, angkatan, nomor WhatsApp, serta foto profil terisi otomatis dari biodata SIKA.
- **Masuk dengan Google satu ketuk**: login Google berjalan native di dalam aplikasi lewat akun Google di HP, tanpa membuka browser. Bila jalur native gagal, aplikasi otomatis jatuh ke login Google lewat browser seperti biasa.
- **Profil publik dan identitas bertingkat**: profil pengguna lain bisa dibuka (foto, nama tampilan, badge terverifikasi, program studi, statistik bantuan). Pengguna bisa memakai nama tampilan, dan akun terverifikasi SIKA bisa menyamarkan namanya pada postingan tertentu. Beranda juga menampilkan statistik publik komunitas.

### Papan dan pencarian

- **Papan hilang dan temuan** dengan kategori Dompet dan Uang, KTM dan Dokumen, Kunci, HP dan Elektronik, Helm dan Kendaraan, Tas dan Pakaian, Buku dan Alat Tulis, dan Lainnya. Dilengkapi pencarian, saringan jenis dan kategori, urutan terbaru atau terlama, dan saringan rentang tanggal. Seluruh kepala beranda (sapaan, statistik komunitas, pencarian, dan saringan) ikut menggulir bersama daftar supaya ruang baca lega, statistik komunitas menyatu di dalam kartu sapaan, dan berpindah antara Semua dan Saya bisa dengan menggeser layar ke samping. Sapaan di beranda memakai nama lengkap pengguna.
- **Lapor Cepat**: tulis satu kalimat bebas, misalnya "kehilangan dompet coklat di sekitar parkiran motor kemarin sore", dan aplikasi menguraikannya menjadi kategori, warna, lokasi, dan perkiraan waktu, lalu langsung menampilkan kandidat postingan yang mirip. Formulir Buat Postingan terisi otomatis dari kalimat itu dan tetap bisa diubah sebelum diterbitkan.
- **Papan offline**: papan terakhir yang kamu lihat tersimpan di HP. Saat tidak ada internet, papan tetap bisa dibuka dari simpanan itu dengan penanda bahwa datanya adalah data terakhir, bukan data live.
- **Pantau Kategori**: nyalakan kategori yang dicari dan terima kabar setiap ada postingan baru di kategori itu.
- **Watchlist Barang**: simpan barang yang sedang kamu cari lengkap dengan kategori, ciri, lokasi, dan rentang tanggal. Sistem memeriksa setiap temuan baru dan mengabari bila ada kandidat yang cocok.
- **Bantu UP** satu kali per postingan per hari, jumlah tayang asli, komentar, dan berbagi kartu postingan lengkap dengan tautan ke versi web-nya.

### Pencocokan otomatis

- **Pencocokan teks TF-IDF** dengan cosine similarity. Setiap postingan dibandingkan dengan postingan lawan jenis memakai skor gabungan kemiripan teks (0,55), kategori (0,20), lokasi (0,15), dan kedekatan waktu (0,10).
- **Pencocokan AI semantik**: judul dan deskripsi setiap postingan diubah menjadi vektor embedding oleh worker server (model Nemotron Embed lewat NVIDIA NIM) dan disimpan di Postgres dengan pgvector. Fungsi `lf_cocok_ai` mencari kandidat berdasarkan kemiripan makna, bukan sekadar kata yang sama, jadi "dompet kulit warna cokelat" bisa bertemu "dompet pria coklat". Hasil gabungan TF-IDF dan AI tampil di seksi Kemungkinan Cocok pada rincian postingan, kandidat dari AI diberi lencana khusus, dan pasangan kuat memicu notifikasi ke kedua pemilik.
- Skor visual berbasis kemiripan foto sudah disiapkan strukturnya (kolom embedding visual dan bobotnya di fungsi pencocokan) dan aktif otomatis bila embedding foto tersedia.

### Klaim dan serah terima

- **Klaim aman berlapis**: pengklaim wajib menyebut ciri khusus rahasia dan boleh melampirkan foto bukti. Pemilik postingan yang menyetujui atau menolak, dan penolakan wajib disertai alasan. Klaim yang ditolak bisa diajukan sengketa ke admin, dan ada batas jumlah klaim per hari untuk mencegah klaim asal-asalan.
- **Secure Contact (chat di aplikasi)**: sesudah klaim diajukan, pemosting dan pengklaim bisa mengobrol langsung di dalam aplikasi tanpa bertukar nomor pribadi. Chat mendukung teks, foto, pesan suara, berbagi lokasi, dan lokasi live 30 menit. Percakapan otomatis tertutup sesudah serah terima selesai dan bisa diarsipkan pribadi. Berbagi nomor WhatsApp **opsional** dan bisa dimatikan dari Profil.
- **Serah terima berkode dan QR**: saat klaim disetujui, pengklaim menerima kode 6 digit dan kode QR. Kode ditunjukkan saat bertemu, pemilik postingan memasukkannya atau memindai QR-nya di aplikasi untuk menyelesaikan klaim dan menandai barang kembali.
- **Titip satpam**: penemu dapat mencatat lokasi penitipan barang, misalnya Pos Satpam Gerbang Utama, dan pemilik mengambil barang di sana dengan menunjukkan klaim yang disetujui.

### Notifikasi dan keberlangsungan postingan

- **Notifikasi push FCM dan realtime** untuk klaim masuk, klaim disetujui atau ditolak, komentar, pantauan kategori, pasangan cocok, dan pengingat postingan lama. Notifikasi baru muncul seketika tanpa memuat ulang, dan menghapus notifikasi benar-benar menghapusnya (di HP dan di server).
- **Arsip otomatis**: postingan diingatkan 5 hari dan 3 hari sebelum genap 30 hari tampil, lalu diarsipkan otomatis sesudah 30 hari. Pemilik bisa memperpanjang 30 hari atau menghidupkan lagi postingan terarsip lewat moderasi.
- **Pengumuman komunitas**: admin bisa menyiarkan pengumuman penting yang tampil sebagai banner di beranda dan terkirim sebagai push ke semua pengguna.

### Pengalaman pakai

- **Panduan interaktif bermaskot**: pengguna baru diajak tur keliling tombol penting aplikasi (Cari, Pantau, Lapor Cepat, Notifikasi, Chat, dan navigasi) dengan maskot KutemuKan sebagai pemandu. Panduan bisa diulang kapan saja dari tab Akun.
- **Ringan dan responsif**: animasi transisi antar halaman yang halus, rangka shimmer saat beranda dimuat, getaran sentuh (haptic) pada aksi penting seperti menerbitkan postingan dan mengirim klaim, serta ikon bilah status yang menyesuaikan terang gelap halaman supaya selalu terbaca.
- **Mode gelap dan terang** mengikuti sistem atau dipilih manual, serta **dwibahasa Indonesia dan Inggris** di seluruh aplikasi, dengan pilihan sapaan dan teks yang ramah mahasiswa.
- **Gamifikasi ringan**: badge otomatis berdasarkan aktivitas (termasuk Kontributor Tepercaya) dan Papan Pahlawan bulanan untuk penemu paling berjasa.
- **Panel admin**: moderasi postingan, laporan pengguna, statistik kampus, pengelolaan pengguna, dan ekspor Laporan Barang dalam PDF.

### Kendali data pengguna

- **Unduh Data Saya**: unduh salinan data akunmu (profil, postingan, klaim, dan notifikasi) sebagai berkas JSON dari tab Akun.
- **Hapus Akun Saya**: ajukan penghapusan akun langsung dari aplikasi dengan mengetik kata konfirmasi. Worker server menghapus seluruh data terkait lalu akunnya, tanpa perlu menghubungi admin.

## Cara pakai singkat

1. Mahasiswa UNINDRA: masuk dengan SIKA memakai NPM dan kata sandi SIKA, profil langsung lengkap dan terverifikasi. Pengguna lain bisa daftar dengan email atau masuk dengan Google, lalu melengkapi nama dan nomor WhatsApp.
2. Kehilangan barang: buat postingan jenis Kehilangan, isi ciri khususnya dan simpan ciri rahasia yang hanya kamu yang tahu. Mau lebih cepat, pakai Lapor Cepat dan tulis satu kalimat saja.
3. Menemukan barang: buat postingan jenis Temuan, foto barangnya, dan catat bila barang dititipkan ke satpam.
4. Ada yang mengklaim: periksa ciri dan foto buktinya di rincian postinganmu, lalu setujui bila cocok. Lanjutkan lewat Chat di Aplikasi (atau WhatsApp bila kedua pihak mengaktifkannya) untuk mengatur pertemuan.
5. Serah terima: pengklaim menunjukkan kode 6 digit atau QR dari aplikasinya, kamu masukkan kodenya atau pindai QR-nya di rincian postingan, dan barang resmi kembali. Postingan lama yang belum selesai bisa diperpanjang sebelum diarsipkan otomatis sesudah 30 hari.

## Teknologi

- Flutter (Android, arm64) dengan satu basis kode
- Supabase: Postgres, Auth, Row Level Security, dan Realtime pada proyek khusus KutemuKan
- pgvector untuk embedding semantik postingan dan fungsi pencocokan `lf_cocok_ai`
- NVIDIA NIM (model Nemotron Embed) untuk membuat embedding teks postingan di sisi server
- Cloudflare R2 untuk penyimpanan foto lewat endpoint unggah di backend pendamping
- Firebase Cloud Messaging untuk notifikasi push, dikirim worker di server yang juga menjalankan pembuatan embedding berkala, pemeriksaan pencocokan, pengingat arsip, dan pemrosesan penghapusan akun
- Build APK otomatis dengan GitHub Actions pada setiap push ke branch main, terbit sebagai Release

## Struktur repo

```text
.github/workflows/   Build APK otomatis (GitHub Actions)
assets/              Logo, maskot, dan ikon di dalam aplikasi
docs/                Logo dan screenshot untuk dokumentasi
lib/
  main.dart          Titik masuk aplikasi
  config.dart        Konfigurasi (URL backend, client id, versi)
  cocok.dart         Mesin pencocokan TF-IDF di sisi aplikasi
  laporcepat.dart    Pengurai kalimat Lapor Cepat
  i18n.dart          Kamus dwibahasa Indonesia dan Inggris
  bagian/            Layar per fitur (beranda, buat, klaim, chat, akun, tur, dll)
pubspec.yaml         Definisi paket dan versi aplikasi
```

## Build lokal

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
```

Berkas `google-services.json` tidak disimpan di repo. Untuk build lokal, letakkan berkas itu di `android/app/google-services.json` dari proyek Firebase KutemuKan. Build rilis resmi selalu dibuat oleh GitHub Actions (berkas itu dipasok dari secret repo), ditandatangani dengan keystore rilis, dan diterbitkan ke halaman Releases.

## Riwayat versi

- **1.7.5**: maskot dan logo diwarnai ulang bersih ke biru Unindra cerah, beranda dipadatkan jadi satu aliran scroll (statistik menyatu di kartu sapaan, kepala beranda ikut menggulir, Semua dan Saya bisa digeser), sapaan nama lengkap, ikon bilah status adaptif, dan perbaikan cek update yang sebelumnya tidak pernah mendeteksi versi baru.
- **1.7.4**: login Google native satu ketuk, pencocokan AI semantik (embedding + pgvector), Lapor Cepat satu kalimat, panduan interaktif bermaskot, papan offline, notifikasi dan beranda realtime, unduh data dan hapus akun mandiri, deep link postingan, pengingat arsip H-3, ikon Google resmi dan maskot biru pekat.
- **1.7.3**: pemindaian QR serah terima tertanam di aplikasi (tanpa Google Lens), desain berwarna biru kampus, perbaikan hapus notifikasi.
- **1.7.2 dan 1.7.1**: lima tab utama, chat dengan media dan lokasi live, serah terima kode 6 digit dan QR, Laporan Barang PDF untuk admin, profil publik, Watchlist, Secure Contact, Smart Claim dan sengketa, perpanjang dan arsip postingan, pengumuman admin, badge Kontributor Tepercaya.
- **1.7.0**: login SIKA dengan profil otomatis dan status Mahasiswa Terverifikasi.
- **1.6.x**: papan hilang dan temuan, pencocokan TF-IDF, klaim berciri rahasia, Pantau Kategori, mode gelap dan dwibahasa.

## Privasi

Nomor WhatsApp tidak pernah tampil publik dan berbaginya bisa dimatikan sepenuhnya dari Profil. Yang terlihat publik hanya nama tampilan, foto profil, badge, dan isi postingan. Chat hanya bisa dibaca kedua pihak yang bertransaksi dan admin saat ada sengketa. Ciri rahasia hanya dibaca pemilik postingan dan pengklaim yang bersangkutan. Kata sandi SIKA hanya dipakai saat proses masuk dan tidak pernah disimpan. Setiap pengguna bisa mengunduh salinan datanya dan menghapus akunnya sendiri dari dalam aplikasi. Kebijakan privasi lengkap tersedia di dalam aplikasi.

## Lisensi dan kontribusi

Kode sumber dirilis dengan [Lisensi MIT](LICENSE). Saran dan laporan bug bisa disampaikan lewat menu Kritik dan Saran di dalam aplikasi atau lewat Issues di repo ini.
