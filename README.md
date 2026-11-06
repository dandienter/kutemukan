# KutemuKan - Lost and Found Kampus Unindra

![Logo KutemuKan](docs/logo.png)

**KutemuKan** adalah aplikasi lost and found untuk lingkungan kampus Universitas Indraprasta PGRI (UNINDRA). Mahasiswa yang kehilangan barang bisa memasang laporan kehilangan, penemu bisa memasang temuan, dan keduanya dipertemukan lewat alur klaim yang aman: nomor WhatsApp hanya terbuka sesudah klaim disetujui pemilik postingan.

Aplikasi ini karya komunitas mahasiswa dan bukan aplikasi resmi universitas.

## Unduh

APK Android terbaru selalu tersedia di halaman rilis:

**[Unduh KutemuKan.apk](https://github.com/dandienter/kutemukan/releases/latest/download/KutemuKan.apk)**

Di dalam aplikasi juga ada tombol Cek Update di tab Akun yang akan memberi tahu bila ada versi baru.

## Fitur utama

- **Masuk dan verifikasi SIKA**: mahasiswa UNINDRA bisa masuk langsung dengan NPM dan kata sandi SIKA (kata sandi tidak pernah disimpan) atau memverifikasi akun email dan Google yang sudah ada. Akun terverifikasi berstatus Mahasiswa Terverifikasi, dan nama, NPM, program studi, fakultas, kelas, angkatan, nomor WhatsApp, serta foto profil terisi otomatis dari biodata SIKA.
- **Papan hilang dan temuan** dengan kategori Dompet dan Uang, KTM dan Dokumen, Kunci, HP dan Elektronik, Helm dan Kendaraan, Tas dan Pakaian, Buku dan Alat Tulis, dan Lainnya. Dilengkapi pencarian, saringan jenis dan kategori, urutan terbaru atau terlama, dan saringan rentang tanggal.
- **Pencocokan otomatis** dengan TF-IDF dan cosine similarity. Setiap postingan dibandingkan dengan postingan lawan jenis memakai skor gabungan kemiripan teks (0.55), kategori (0.20), lokasi (0.15), dan kedekatan waktu (0.10). Pasangan yang mirip muncul di seksi Kemungkinan Cocok pada rincian postingan, dan pasangan kuat memicu notifikasi ke kedua pemilik.
- **Klaim aman berlapis**: pengklaim wajib menyebut ciri khusus rahasia dan boleh melampirkan foto bukti. Pemilik postingan yang menyetujui atau menolak. Tombol WhatsApp hanya muncul sesudah persetujuan, jadi nomor pribadi tidak tersebar.
- **Titip satpam**: penemu dapat mencatat lokasi penitipan barang, misalnya Pos Satpam Gerbang Utama, dan pemilik mengambil barang di sana dengan menunjukkan klaim yang disetujui.
- **Notifikasi dan push FCM** untuk klaim masuk, klaim disetujui atau ditolak, komentar, pantauan kategori, pasangan cocok, dan pengingat postingan lama.
- **Pantau Kategori**: nyalakan kategori yang dicari dan terima kabar setiap ada postingan baru di kategori itu.
- **Bantu UP** satu kali per postingan per hari, jumlah tayang asli, komentar, dan berbagi kartu postingan.
- **Gamifikasi ringan**: badge otomatis berdasarkan aktivitas dan Papan Pahlawan bulanan untuk penemu paling berjasa.
- **Mode gelap dan terang** mengikuti sistem atau dipilih manual, serta **dwibahasa Indonesia dan Inggris** di seluruh aplikasi.
- **Panel admin**: moderasi postingan, laporan pengguna, statistik kampus, dan pengelolaan pengguna.

## Cara pakai singkat

1. Mahasiswa UNINDRA: masuk dengan SIKA memakai NPM dan kata sandi SIKA, profil langsung lengkap dan terverifikasi. Pengguna lain bisa daftar dengan email atau masuk dengan Google, lalu melengkapi nama dan nomor WhatsApp.
2. Kehilangan barang: buat postingan jenis Kehilangan, isi ciri khususnya dan simpan ciri rahasia yang hanya kamu yang tahu.
3. Menemukan barang: buat postingan jenis Temuan, foto barangnya, dan catat bila barang dititipkan ke satpam.
4. Ada yang mengklaim: periksa ciri dan foto buktinya di tab Postinganku, lalu setujui bila cocok. Tombol WhatsApp terbuka dan pengembalian bisa diatur.
5. Barang kembali: tandai postingan Selesai supaya papan tetap bersih.

## Teknologi

- Flutter (Android, arm64) dengan satu basis kode
- Supabase: Postgres, Auth, Row Level Security, dan Realtime pada proyek khusus KutemuKan
- Cloudflare R2 untuk penyimpanan foto lewat endpoint unggah di backend pendamping
- Firebase Cloud Messaging untuk notifikasi push, dikirim worker di server yang juga menjalankan pemeriksaan pencocokan berkala
- Build APK otomatis dengan GitHub Actions pada setiap push ke branch main, terbit sebagai Release

## Privasi

Nomor WhatsApp tidak pernah tampil publik. Yang terlihat publik hanya nama, foto profil, badge, dan isi postingan. Ciri rahasia hanya dibaca pemilik postingan dan pengklaim yang bersangkutan. Kebijakan privasi tersedia di dalam aplikasi dan di https://temubalik.43-130-228-96.sslip.io/privasi.html

## Lisensi dan kontribusi

Kode sumber dibuka untuk tujuan belajar. Saran dan laporan bug bisa disampaikan lewat menu Kritik dan Saran di dalam aplikasi atau lewat Issues di repo ini.
