# KutemuKan - Lost and Found Kampus Unindra

![Logo KutemuKan](docs/logo.png)

**KutemuKan** adalah aplikasi lost and found untuk lingkungan kampus Universitas Indraprasta PGRI (UNINDRA). Mahasiswa yang kehilangan barang bisa memasang laporan kehilangan, penemu bisa memasang temuan, dan keduanya dipertemukan lewat alur klaim yang aman, watchlist barang yang dicari, chat di dalam aplikasi tanpa membagikan nomor pribadi, dan serah terima berkode.

Aplikasi ini karya komunitas mahasiswa dan bukan aplikasi resmi universitas.

## Unduh

APK Android terbaru selalu tersedia di halaman rilis:

**[Unduh KutemuKan.apk](https://github.com/dandienter/kutemukan/releases/latest/download/KutemuKan.apk)**

Di dalam aplikasi juga ada tombol Cek Update di tab Akun yang akan memberi tahu bila ada versi baru.

## Fitur utama

- **Masuk dan verifikasi SIKA**: mahasiswa UNINDRA bisa masuk langsung dengan NPM dan kata sandi SIKA (kata sandi tidak pernah disimpan) atau memverifikasi akun email dan Google yang sudah ada. Akun terverifikasi berstatus Mahasiswa Terverifikasi, dan nama, NPM, program studi, fakultas, kelas, angkatan, nomor WhatsApp, serta foto profil terisi otomatis dari biodata SIKA.
- **Papan hilang dan temuan** dengan kategori Dompet dan Uang, KTM dan Dokumen, Kunci, HP dan Elektronik, Helm dan Kendaraan, Tas dan Pakaian, Buku dan Alat Tulis, dan Lainnya. Dilengkapi pencarian, saringan jenis dan kategori, urutan terbaru atau terlama, dan saringan rentang tanggal.
- **Pencocokan otomatis** dengan TF-IDF dan cosine similarity. Setiap postingan dibandingkan dengan postingan lawan jenis memakai skor gabungan kemiripan teks (0.55), kategori (0.20), lokasi (0.15), dan kedekatan waktu (0.10). Pasangan yang mirip muncul di seksi Kemungkinan Cocok pada rincian postingan, dan pasangan kuat memicu notifikasi ke kedua pemilik.
- **Klaim aman berlapis**: pengklaim wajib menyebut ciri khusus rahasia dan boleh melampirkan foto bukti. Pemilik postingan yang menyetujui atau menolak, dan penolakan sekarang wajib disertai alasan. Klaim yang ditolak bisa diajukan sengketa ke admin, dan ada batas jumlah klaim per hari untuk mencegah klaim asal-asalan.
- **Secure Contact (chat di aplikasi)**: sesudah klaim diajukan, pemosting dan pengklaim bisa mengobrol langsung di dalam aplikasi tanpa bertukar nomor pribadi. Chat mendukung teks, foto, pesan suara, berbagi lokasi, dan lokasi live 30 menit. Percakapan otomatis tertutup sesudah serah terima selesai dan bisa diarsipkan pribadi. Berbagi nomor WhatsApp sekarang **opsional** dan bisa dimatikan dari Profil.
- **Serah terima berkode**: saat klaim disetujui, pengklaim menerima kode 6 digit. Kode ditunjukkan saat bertemu dan pemilik postingan memverifikasinya di aplikasi untuk menyelesaikan klaim dan menandai barang kembali.
- **Watchlist Barang**: simpan barang yang sedang kamu cari lengkap dengan kategori, ciri, lokasi, dan rentang tanggal. Sistem memeriksa setiap temuan baru dan mengabari bila ada kandidat yang cocok.
- **Profil publik dan identitas bertingkat**: profil pengguna lain bisa dibuka (foto, nama tampilan, badge terverifikasi, program studi, statistik bantuan). Pengguna bisa memakai nama tampilan, dan akun terverifikasi SIKA bisa menyamarkan namanya pada postingan tertentu. Beranda juga menampilkan statistik publik komunitas.
- **Pengumuman komunitas**: admin bisa menyiarkan pengumuman penting yang tampil sebagai banner di beranda dan terkirim sebagai push ke semua pengguna.
- **Arsip otomatis**: postingan yang tampil 25 hari diingatkan, dan sesudah 30 hari diarsipkan otomatis. Pemilik bisa memperpanjang 30 hari atau menghidupkan lagi postingan terarsip lewat moderasi.
- **Titip satpam**: penemu dapat mencatat lokasi penitipan barang, misalnya Pos Satpam Gerbang Utama, dan pemilik mengambil barang di sana dengan menunjukkan klaim yang disetujui.
- **Notifikasi dan push FCM** untuk klaim masuk, klaim disetujui atau ditolak, komentar, pantauan kategori, pasangan cocok, dan pengingat postingan lama.
- **Pantau Kategori**: nyalakan kategori yang dicari dan terima kabar setiap ada postingan baru di kategori itu.
- **Bantu UP** satu kali per postingan per hari, jumlah tayang asli, komentar, dan berbagi kartu postingan.
- **Gamifikasi ringan**: badge otomatis berdasarkan aktivitas (termasuk Kontributor Tepercaya) dan Papan Pahlawan bulanan untuk penemu paling berjasa.
- **Mode gelap dan terang** mengikuti sistem atau dipilih manual, serta **dwibahasa Indonesia dan Inggris** di seluruh aplikasi.
- **Panel admin**: moderasi postingan, laporan pengguna, statistik kampus, dan pengelolaan pengguna.

## Cara pakai singkat

1. Mahasiswa UNINDRA: masuk dengan SIKA memakai NPM dan kata sandi SIKA, profil langsung lengkap dan terverifikasi. Pengguna lain bisa daftar dengan email atau masuk dengan Google, lalu melengkapi nama dan nomor WhatsApp.
2. Kehilangan barang: buat postingan jenis Kehilangan, isi ciri khususnya dan simpan ciri rahasia yang hanya kamu yang tahu.
3. Menemukan barang: buat postingan jenis Temuan, foto barangnya, dan catat bila barang dititipkan ke satpam.
4. Ada yang mengklaim: periksa ciri dan foto buktinya di rincian postinganmu, lalu setujui bila cocok. Lanjutkan lewat Chat di Aplikasi (atau WhatsApp bila kedua pihak mengaktifkannya) untuk mengatur pertemuan.
5. Serah terima: pengklaim menunjukkan kode 6 digit dari aplikasinya, kamu masukkan kodenya di rincian postingan, dan barang resmi kembali. Postingan lama yang belum selesai bisa diperpanjang sebelum diarsipkan otomatis sesudah 30 hari.

## Teknologi

- Flutter (Android, arm64) dengan satu basis kode
- Supabase: Postgres, Auth, Row Level Security, dan Realtime pada proyek khusus KutemuKan
- Cloudflare R2 untuk penyimpanan foto lewat endpoint unggah di backend pendamping
- Firebase Cloud Messaging untuk notifikasi push, dikirim worker di server yang juga menjalankan pemeriksaan pencocokan berkala
- Build APK otomatis dengan GitHub Actions pada setiap push ke branch main, terbit sebagai Release

## Privasi

Nomor WhatsApp tidak pernah tampil publik dan berbaginya bisa dimatikan sepenuhnya dari Profil. Yang terlihat publik hanya nama tampilan, foto profil, badge, dan isi postingan. Chat hanya bisa dibaca kedua pihak yang bertransaksi dan admin saat ada sengketa. Ciri rahasia hanya dibaca pemilik postingan dan pengklaim yang bersangkutan. Kebijakan privasi lengkap tersedia di dalam aplikasi.

## Lisensi dan kontribusi

Kode sumber dirilis dengan [Lisensi MIT](LICENSE). Saran dan laporan bug bisa disampaikan lewat menu Kritik dan Saran di dalam aplikasi atau lewat Issues di repo ini.
