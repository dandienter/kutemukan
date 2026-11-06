import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan tampilan dan bahasa yang hidup di seluruh aplikasi.
final ValueNotifier<ThemeMode> kTemaMode = ValueNotifier(ThemeMode.system);
final ValueNotifier<String> kBahasa = ValueNotifier('id');

Future<void> muatPreferensi() async {
  final p = await SharedPreferences.getInstance();
  final tema = p.getString('tema') ?? 'sistem';
  kTemaMode.value = tema == 'terang'
      ? ThemeMode.light
      : tema == 'gelap'
          ? ThemeMode.dark
          : ThemeMode.system;
  kBahasa.value = p.getString('bahasa') ?? 'id';
}

Future<void> aturTema(String nilai) async {
  kTemaMode.value = nilai == 'terang'
      ? ThemeMode.light
      : nilai == 'gelap'
          ? ThemeMode.dark
          : ThemeMode.system;
  final p = await SharedPreferences.getInstance();
  await p.setString('tema', nilai);
}

Future<void> aturBahasa(String nilai) async {
  kBahasa.value = nilai;
  final p = await SharedPreferences.getInstance();
  await p.setString('bahasa', nilai);
}

/// Terjemahkan teks antarmuka. Bahasa sumber adalah Bahasa Indonesia;
/// bila bahasa aktif Inggris dan ada padanannya, pakai padanan itu.
String tr(String s) =>
    kBahasa.value == 'en' ? (_idKeEn[s] ?? s) : s;

const Map<String, String> _idKeEn = {
  '30 hari terakhir': 'Last 30 days',
  '7 hari terakhir': 'Last 7 days',
  'Abaikan': 'Dismiss',
  'Ada klaim menunggu keputusanmu. Periksa ciri khususnya baik-baik sebelum menyetujui.':
      'There is a claim waiting for your decision. Check its secret characteristics carefully before approving.',
  'Ajukan Klaim': 'Submit a Claim',
  'Aktivitas Pengguna': 'User Activity',
  'Akun': 'Account',
  'Bagikan': 'Share',
  'Bagikan Postingan': 'Share Post',
  'Bantu UP gagal, coba lagi sebentar.':
      'Boost failed, please try again shortly.',
  'Batal': 'Cancel',
  'Belum ada aktivitas bulan ini. Jadilah pahlawan pertama.':
      'No activity this month yet. Be the first hero.',
  'Belum ada aktivitas.': 'No activity yet.',
  'Belum ada klaim untuk postingan ini.': 'No claims for this post yet.',
  'Belum ada komentar. Tanya ciri barang di sini dulu sebelum mengajukan klaim juga boleh.':
      'No comments yet. Asking about the item characteristics here before claiming is fine too.',
  'Belum ada notifikasi.': 'No notifications yet.',
  'Belum ada ulasan masuk.': 'No reviews yet.',
  'Belum ada ulasan. Jadilah yang pertama.':
      'No reviews yet. Be the first.',
  'Beri bintang dan tulis ulasanmu': 'Rate and write your review',
  'Berlaku juga untuk akun yang masuk via Google':
      'Also works for accounts signed in with Google',
  'Beranda': 'Home',
  'Buat': 'Create',
  'Buat Postingan': 'Create Post',
  'Buka': 'Open',
  'Cara Kerja': 'How It Works',
  'Cara data kamu dikelola di KutemuKan':
      'How your data is managed in KutemuKan',
  'Cari barang...': 'Search items...',
  'Cek Pembaruan': 'Check for Updates',
  'Ciri khusus barang': 'Item secret characteristics',
  'Diurutkan dari yang paling banyak menghasilkan pengembalian barang.':
      'Sorted by who returned the most items.',
  'Edit Profil': 'Edit Profile',
  'Fitur apa yang kurang, apa yang mengganggu, apa yang mau kamu minta ditambah...':
      'What feature is missing, what bothers you, what would you like added...',
  'Gagal memuat': 'Failed to load',
  'Hapus': 'Delete',
  'Hapus postingan?': 'Delete this post?',
  'Hari ini': 'Today',
  'Hubungi Pengklaim': 'Contact Claimant',
  'Hubungi via WhatsApp': 'Contact via WhatsApp',
  'Info Aplikasi': 'App Info',
  'Isi nama dan nomor WhatsApp yang benar.':
      'Please enter a correct name and WhatsApp number.',
  'Judul dan lokasi wajib diisi.': 'Title and location are required.',
  'Kamu belum punya postingan.': 'You have no posts yet.',
  'Kamu sudah bantu UP postingan ini hari ini.':
      'You already boosted this post today.',
  'Kamu sudah pernah melaporkan postingan ini.':
      'You already reported this post.',
  'Kartu ini tidak memuat ciri khusus rahasia dan nomor WhatsApp siapa pun.':
      'This card contains no secret characteristics and no one\'s WhatsApp number.',
  'Kata sandi': 'Password',
  'Kata sandi baru': 'New password',
  'Kata sandi minimal 6 karakter.':
      'Password must be at least 6 characters.',
  'Kata sandi terpasang. Sekarang kamu juga bisa masuk memakai email dan sandi ini.':
      'Password set. You can now also sign in with this email and password.',
  'Kebijakan Privasi': 'Privacy Policy',
  'Keluar': 'Sign Out',
  'Kenapa postingan ini bermasalah?': 'Why is this post a problem?',
  'Ketuk untuk pasang foto profil': 'Tap to set a profile photo',
  'Kirim Laporan': 'Send Report',
  'Kirim Ulasan': 'Send Review',
  'Kirim untuk Moderasi': 'Submit for Moderation',
  'Klaim Masuk': 'Incoming Claims',
  'Klaimmu belum bisa disetujui. Pastikan ciri khusus yang kamu sebutkan benar-benar hanya diketahui pemilik aslinya.':
      'Your claim could not be approved yet. Make sure the secret characteristics you mentioned are truly known only to the real owner.',
  'Klaimmu sudah terkirim dan menunggu keputusan yang memposting. Kamu akan mendapat notif begitu ada keputusan.':
      'Your claim has been sent and is waiting for the poster\'s decision. You will be notified once there is a decision.',
  'Komentar': 'Comments',
  'Kemungkinan Cocok': 'Possible Matches',
  'Dihitung otomatis dari kemiripan isi, kategori, lokasi, dan waktu.':
      'Calculated automatically from content, category, location, and time similarity.',
  'Konfirmasi kata sandi tidak sama.':
      'Password confirmation does not match.',
  'Kritik & Saran': 'Feedback',
  'Kritik & Saran Terbaru': 'Latest Feedback',
  'KutemuKan adalah aplikasi komunitas independen dan bukan aplikasi resmi Universitas Indraprasta PGRI.':
      'KutemuKan is an independent community app and is not an official app of Universitas Indraprasta PGRI.',
  'Laporan Pengguna': 'User Reports',
  'Laporan terkirim. Admin akan memeriksanya.':
      'Report sent. An admin will review it.',
  'Laporkan': 'Report',
  'Laporkan Postingan': 'Report Post',
  'Lewati': 'Skip',
  'Lihat foto bukti': 'View proof photo',
  'Lost and Found Kampus Unindra': 'Unindra Campus Lost and Found',
  'Lost and Found Kampus Unindra - buka aplikasi KutemuKan untuk klaim atau bantu UP':
      'Unindra Campus Lost and Found - open the KutemuKan app to claim or boost',
  'Mahasiswa Teknik Informatika, Universitas Indraprasta PGRI':
      'Informatics Engineering student, Universitas Indraprasta PGRI',
  'Masuk': 'Sign In',
  'Masuk dengan Google': 'Continue with Google',
  'Sistem Informasi Akademik Unindra': 'Unindra Academic Information System',
  'Mahasiswa Unindra? Pakai NPM dan kata sandi SIKA, statusmu langsung terverifikasi.':
      'Unindra student? Use your NPM and SIKA password and your status is verified right away.',
  'Kata sandi SIKA': 'SIKA password',
  'Masuk dengan SIKA': 'Sign in with SIKA',
  'Daftar Akun Baru': 'Create Account',
  'Masuk dengan Email': 'Sign in with Email',
  'Pilihan lain': 'Other options',
  'Kata sandi SIKA hanya diteruskan ke server kampus, tidak disimpan.':
      'Your SIKA password is only forwarded to the campus server, never stored.',
  'Isi NPM dan kata sandi SIKA dulu.': 'Enter your NPM and SIKA password first.',
  'Verifikasi Mahasiswa': 'Student Verification',
  'Hubungkan akun SIKA untuk badge terverifikasi':
      'Link your SIKA account for a verified badge',
  'Mahasiswa Terverifikasi': 'Verified Student',
  'Ketuk untuk melihat kontak': 'Tap to view contact',
  'Nomor WhatsApp belum diisi': 'WhatsApp number not set yet',
  'Berhasil terverifikasi sebagai mahasiswa.':
      'Successfully verified as a student.',
  'Masukkan NPM dan kata sandi SIKA. Bila cocok, akunmu naik status jadi Mahasiswa Terverifikasi dan nama, prodi, serta NPM resmi dari SIKA tampil di profilmu.':
      'Enter your NPM and SIKA password. If they match, your account is upgraded to Verified Student and your official name, study program, and NPM from SIKA appear on your profile.',
  'Kata sandi SIKA hanya diteruskan ke server kampus untuk verifikasi, tidak disimpan di KutemuKan.':
      'Your SIKA password is only forwarded to the campus server for verification, never stored in KutemuKan.',
  'Perbarui Data SIKA': 'Refresh SIKA Data',
  'Verifikasi': 'Verify',
  'Mengirim...': 'Sending...',
  'Moderasi': 'Moderation',
  'Moderasi Postingan': 'Post Moderation',
  'Nama lengkap': 'Full name',
  'Nama, nomor WhatsApp, dan foto profil':
      'Name, WhatsApp number, and profile photo',
  'Nanti saja': 'Later',
  'Nomor WhatsApp (08xx)': 'WhatsApp number (08xx)',
  'Nomor WhatsApp hanya dipakai saat ada yang perlu menghubungi soal barang. Nomor tidak tampil terbuka di papan.':
      'Your WhatsApp number is only used when someone needs to contact you about an item. It is never shown publicly on the board.',
  'Notif': 'Alerts',
  'Notifikasi': 'Notifications',
  'Pantau Kategori': 'Watch Categories',
  'Papan Pahlawan': 'Hero Board',
  'Papan Pahlawan Kampus': 'Campus Hero Board',
  'Pengembang KutemuKan': 'KutemuKan Developer',
  'Pengguna, keberhasilan, dan aktivitas klaim':
      'Users, success rate, and claim activity',
  'Periksa versi aplikasi terbaru': 'Check for the latest app version',
  'Peringkat penolong kampus bulan ini':
      'This month\'s campus helper ranking',
  'Pilih dari kalender...': 'Pick from calendar...',
  'Postingan ini akan dihapus permanen.':
      'This post will be permanently deleted.',
  'Postingan terkirim. Menunggu moderasi admin sebelum tampil.':
      'Post submitted. Waiting for admin moderation before it appears.',
  'Postingan yang dilaporkan bermasalah': 'Posts reported as problematic',
  'Sampul': 'Cover',
  'Saya': 'Mine',
  'Saya Kehilangan': 'I Lost Something',
  'Saya Menemukan': 'I Found Something',
  'Seberapa puas kamu dengan KutemuKan?':
      'How satisfied are you with KutemuKan?',
  'Sebutkan ciri khusus barangnya lebih jelas (minimal 10 karakter).':
      'Describe the item\'s secret characteristics more clearly (minimum 10 characters).',
  'Semua': 'All',
  'Semua waktu': 'All time',
  'Setujui': 'Approve',
  'Setujui atau tolak postingan yang menunggu':
      'Approve or reject pending posts',
  'Setujui dan Tampilkan': 'Approve and Publish',
  'Statistik': 'Statistics',
  'Sudah di-UP': 'Boosted',
  'Bantu UP': 'Boost',
  'Tampilan': 'Appearance',
  'Tandai Selesai': 'Mark Done',
  'Tandai Sudah Selesai': 'Mark as Done',
  'Tandai sudah selesai': 'Mark as done',
  'Tentang KutemuKan dan pembuatnya': 'About KutemuKan and its maker',
  'Terbaru': 'Newest',
  'Terima kasih sudah bantu UP.': 'Thanks for the boost.',
  'Terima kasih, ulasanmu terkirim.': 'Thank you, your review has been sent.',
  'Terlama': 'Oldest',
  'Tidak ada laporan masuk.': 'No incoming reports.',
  'Tidak ada postingan menunggu moderasi.':
      'No posts waiting for moderation.',
  'Tidak bisa memeriksa pembaruan saat ini.':
      'Could not check for updates right now.',
  'Tingkat Keberhasilan': 'Success Rate',
  'Tolak': 'Reject',
  'Tulis dulu kritik atau saranmu.': 'Write your feedback first.',
  'Tulis komentar...': 'Write a comment...',
  'Turunkan': 'Take Down',
  'Ubah Kata Sandi': 'Change Password',
  'Ulangi kata sandi baru': 'Repeat new password',
  'Ulasanku sebelumnya': 'My previous reviews',
  'Unduh Sekarang': 'Download Now',
  'Urutkan dan saring waktu': 'Sort and filter by time',
  'Versi 1.5.8': 'Version 1.5.8',
  'atau': 'or',
  'Buat akun baru': 'Create a new account',
  'Selamat datang kembali': 'Welcome back',
  'Daftar supaya bisa posting dan klaim barang.': 'Sign up to post and claim items.',
  'Masuk untuk melanjutkan.': 'Sign in to continue.',
  'Bahasa': 'Language',
  'Emas': 'Gold',
  'Perak': 'Silver',
  'Perunggu': 'Bronze',
  'Foto': 'Photo',
  'Postingan': 'Post',
  'Gagal menyimpan': 'Failed to save',
  'Komentar gagal terkirim': 'Comment failed to send',
  'Belum bisa menghubungi': 'Could not make contact',
  'Gagal mengirim klaim': 'Failed to send claim',
  'Gagal mengirim': 'Failed to send',
  'Gagal menyiapkan kartu': 'Failed to prepare the card',
  'Gagal mengubah sandi': 'Failed to change password',
  'Login Google gagal': 'Google sign-in failed',
  'Barangmu hilang?': 'Lost something?',
  'Memproses...': 'Processing...',
  'Sudah punya akun? Masuk': 'Already have an account? Sign In',
  'Belum punya akun? Daftar': 'No account yet? Sign Up',
  'Kehilangan': 'Lost',
  'Ditemukan': 'Found',
  'Laporan gagal terkirim.': 'Report failed to send.',
  'Kategori': 'Category',
  'Lokasi': 'Location',
  'Waktu': 'Time',
  'Waktu kejadian': 'Time of incident',
  'Dititipkan di': 'Kept at',
  'Dilaporkan oleh': 'Reported by',
  'Tambah Foto Bukti (opsional)': 'Add Proof Photo (optional)',
  'Ganti Foto Bukti': 'Change Proof Photo',
  'Kirim Klaim': 'Send Claim',
  'Ciri khusus rahasia': 'Secret characteristics',
  'Judul (mis. Dompet hitam berisi KTM)':
      'Title (e.g. Black wallet containing a student card)',
  'Lokasi (hilang / ditemukan)': 'Location (lost / found)',
  'Barang dititipkan di (mis. pos satpam)':
      'Item kept at (e.g. security post)',
  'Warga Baru': 'New Member',
  'Sering Lapor': 'Frequent Reporter',
  'Penemu Andal': 'Reliable Finder',
  'Suka Menolong': 'Helpful Soul',
  'Pengangkat Rame': 'Top Booster',
  'Pengguna': 'Users',
  'Tampil di Papan': 'On the Board',
  'Menunggu Moderasi': 'Waiting Moderation',
  'Sudah Kembali': 'Returned',
  'Hilang Aktif': 'Active Lost',
  'Temuan Aktif': 'Active Found',
  'Total Bantu UP': 'Total Boosts',
  'Total Dilihat': 'Total Views',
  'Rata-rata Bintang': 'Average Rating',
  'Menyimpan...': 'Saving...',
  'Daftar': 'Sign Up',
  'Tampil': 'Visible',
  'Menunggu moderasi': 'Waiting for moderation',
  'Sudah kembali': 'Returned',
  'Ditolak': 'Rejected',
  'Belum ada postingan yang cocok.': 'No matching posts yet.',
  'Simpan Perubahan': 'Save Changes',
  'Simpan dan Masuk': 'Save and Sign In',
  'Deskripsi dan ciri-ciri (tampil publik)':
      'Description and characteristics (shown publicly)',
  'Tidak tampil publik, untuk verifikasi klaim':
      'Not shown publicly, used to verify claims',
  'postingan baru': 'new posts',
  'Ini barangmu? Ajukan klaim dan sebutkan ciri khususnya. Nomor WhatsApp baru terbuka sesudah klaimmu disetujui yang memposting.':
      'Is this yours? Submit a claim and mention its secret characteristics. WhatsApp numbers are only revealed after the poster approves your claim.',
  'Sebutkan ciri khusus yang hanya diketahui pemilik asli barang ini, misalnya isi di dalamnya, tanda unik, atau nomor serinya. Jawabanmu dibaca yang memposting untuk memutuskan klaim ini benar atau bukan.':
      'Mention secret characteristics that only the real owner of this item would know, such as its contents, a unique mark, or its serial number. The poster reads your answer to decide whether this claim is genuine.',
  'Nyalakan kategori yang mau kamu pantau. Setiap ada postingan baru tampil di kategori itu, kamu menerima notif dan push, walau belum pernah posting kehilangan.':
      'Turn on the categories you want to watch. Whenever a new post appears in one of them, you get an in-app and push notification, even if you have never posted a loss.',
  'Peringkat bulan ini dihitung dari data asli: barang yang kembali, klaim baik yang disetujui, dan Bantu UP yang diberikan. Direset tiap awal bulan.':
      'This month\'s ranking uses real data: items returned, good claims approved, and boosts given. It resets at the start of each month.',
  'Buat laporan kehilangan lengkap dengan foto, lokasi, dan ciri-cirinya. Makin jelas, makin besar peluang ketemu.':
      'Create a loss report complete with a photo, location, and characteristics. The clearer it is, the better the chance of finding it.',
  'Menemukan barang?': 'Found something?',
  'Umumkan sebagai temuan dan isi ciri khusus rahasianya. Hanya pemilik asli yang bisa menjawabnya saat mengklaim.':
      'Announce it as a found item and fill in its secret characteristics. Only the real owner can answer them when claiming.',
  'Klaim yang aman': 'Safe claiming',
  'Nomor WhatsApp tidak terbuka sembarangan. Klaim harus disetujui dulu oleh yang memposting, baru kalian terhubung.':
      'WhatsApp numbers are never exposed carelessly. A claim must be approved by the poster first, and only then are you connected.',
  'Buat laporan kehilangan atau pengumuman temuan, lengkap dengan foto dan ciri khusus rahasia.':
      'Create a loss report or a found item announcement, complete with a photo and secret characteristics.',
  'Admin memeriksa postingan sebelum menampilkannya di papan.':
      'Admins review posts before they appear on the board.',
  'Sistem mencocokkan kategori dan mengabari lewat notifikasi dan push.':
      'The system matches categories and notifies you in-app and by push.',
  'Pemilik mengajukan klaim dengan menyebut ciri khususnya.':
      'The owner submits a claim by mentioning its secret characteristics.',
  'Sesudah klaim disetujui, kedua pihak terhubung ke WhatsApp dan barang ditandai selesai saat sudah kembali.':
      'After a claim is approved, both sides connect on WhatsApp and the item is marked done once it is back.',
  'Papan lost and found untuk civitas kampus Unindra. Laporkan barang hilang, umumkan barang temuan, dan terima kabar otomatis saat ada yang cocok. Setiap postingan melewati moderasi admin dan setiap klaim harus disetujui pemilik postingan, jadi nomor WhatsApp tidak pernah terbuka sembarangan.':
      'A lost and found board for the Unindra campus community. Report lost items, announce found items, and get notified automatically when something matches. Every post passes admin moderation and every claim needs the poster\'s approval, so WhatsApp numbers are never exposed carelessly.',
  'Gelap': 'Dark',
  'Terang': 'Light',
  'Sistem': 'System',
  'Ikuti sistem, terang, atau gelap': 'Follow system, light, or dark',
  'Indonesia atau English': 'Indonesian or English',
};
