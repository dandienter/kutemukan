part of '../main.dart';

// ===========================================================================
// Helper bersama: konstanta, format, unggah, badge, cek update
// ===========================================================================

Future<File> kompresKeWebp(File asal) async {
  final tujuan =
      '${asal.parent.path}/webp_${DateTime.now().millisecondsSinceEpoch}.webp';
  final hasil = await FlutterImageCompress.compressAndGetFile(
    asal.absolute.path,
    tujuan,
    quality: 78,
    minWidth: 1280,
    minHeight: 1280,
    format: CompressFormat.webp,
  );
  if (hasil == null) return asal;
  return File(hasil.path);
}

/// Unggah satu berkas ke endpoint foto API MySIKA, kembalikan URL publiknya.
/// Autentikasi memakai token login Supabase pengguna saat ini.
Future<String> unggahBerkas(File f) async {
  final req = http.MultipartRequest('POST', Uri.parse(kUploadUrl));
  final token = sb.auth.currentSession?.accessToken ?? '';
  req.headers['Authorization'] = 'Bearer $token';
  req.files.add(await http.MultipartFile.fromPath('foto', f.path));
  final res = await req.send();
  final body = await res.stream.bytesToString();
  if (res.statusCode != 200) throw 'Unggah foto gagal: $body';
  final data = jsonDecode(body) as Map<String, dynamic>;
  return data['url'] as String;
}

/// Unggah satu berkas audio (pesan suara) ke API MySIKA, kembalikan
/// URL publiknya.
Future<String> unggahAudio(File f) async {
  final req = http.MultipartRequest('POST', Uri.parse(kUploadAudioUrl));
  final token = sb.auth.currentSession?.accessToken ?? '';
  req.headers['Authorization'] = 'Bearer $token';
  req.files.add(await http.MultipartFile.fromPath('audio', f.path));
  final res = await req.send();
  final body = await res.stream.bytesToString();
  if (res.statusCode != 200) throw 'Unggah audio gagal: $body';
  final data = jsonDecode(body) as Map<String, dynamic>;
  return data['url'] as String;
}

/// Tampilkan pilihan sumber foto: ambil langsung dari kamera atau pilih
/// dari galeri. Mengembalikan null bila pengguna membatalkan pilihan.
Future<ImageSource?> pilihSumberFoto(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(tr('Ambil dari Kamera')),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(tr('Pilih dari Galeri')),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Panggil endpoint SIKA di API MySIKA. Melempar pesan galat yang sudah
/// diterjemahkan ke bahasa pengguna bila server menolak.

SupabaseClient get sb => Supabase.instance.client;

const Color kBiru = Color(0xFF0061C9);

/// Kunci target panduan interaktif, dipasang di widget aslinya masing
/// masing layar agar tur bisa menyorot posisinya.
final kunciPanduanCari = GlobalKey();
final kunciPanduanCepat = GlobalKey();
final kunciPanduanPantau = GlobalKey();
final kunciPanduanNotif = GlobalKey();
final kunciPanduanNav = GlobalKey();

/// Pemicu panduan interaktif, didaftarkan layar utama saat aktif agar
/// menu Akun bisa memulai tur dari halaman mana pun.
VoidCallback? pemicuPanduan;

/// Transisi halaman halus untuk semua layar: memudar masuk sambil
/// bergeser ringan dari kanan, kurva lembut 260 ms.
class TransisiHalus extends PageTransitionsBuilder {
  const TransisiHalus();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final kurva = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: kurva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(kurva),
        child: child,
      ),
    );
  }
}

/// Getar halus untuk momen penting (klaim disetujui, postingan terbit,
/// serah terima selesai) supaya terasa nyata tanpa mengganggu.
void getarRingan() => HapticFeedback.lightImpact();
void getarSedang() => HapticFeedback.mediumImpact();

/// Filter penurun saturasi untuk foto postingan yang sudah kembali,
/// supaya tampil agak redup di balik stempel.
const ColorFilter kFilterFotoRedup = ColorFilter.matrix(<double>[
  0.7795, 0.2003, 0.0202, 0, 0, //
  0.0595, 0.9203, 0.0202, 0, 0, //
  0.0595, 0.2003, 0.7402, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Stempel "SUDAH KEMBALI" miring ala cap karet untuk postingan yang
/// barangnya sudah balik ke pemiliknya. Menggantikan badge status:
/// sekali lihat langsung terbaca selesai. [ukuran] = ukuran huruf.
class StempelKembali extends StatelessWidget {
  final double ukuran;
  const StempelKembali({super.key, this.ukuran = 15});
  @override
  Widget build(BuildContext context) {
    const warna = Color(0xFF1E7A34);
    return Transform.rotate(
      angle: -0.24,
      child: Container(
        padding: EdgeInsets.all(ukuran * 0.2),
        decoration: BoxDecoration(
          border: Border.all(
            color: warna.withOpacity(0.9),
            width: ukuran * 0.16,
          ),
          borderRadius: BorderRadius.circular(ukuran * 0.5),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ukuran * 0.7,
            vertical: ukuran * 0.26,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: warna.withOpacity(0.9), width: 1.3),
            borderRadius: BorderRadius.circular(ukuran * 0.34),
          ),
          child: Text(
            'SUDAH KEMBALI',
            style: TextStyle(
              color: warna.withOpacity(0.95),
              fontSize: ukuran,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rapikan nama dari data kampus yang biasanya HURUF BESAR semua
/// menjadi kapital di awal tiap kata, misal "AHMAD DANDI SUBHANI"
/// menjadi "Ahmad Dandi Subhani".
String namaRapi(String nama) {
  return nama
      .trim()
      .split(RegExp(r'\s+'))
      .where((k) => k.isNotEmpty)
      .map((k) => k[0].toUpperCase() + k.substring(1).toLowerCase())
      .join(' ');
}

/// Rangka berkilau saat daftar postingan dimuat, pengganti lingkaran
/// putar agar Beranda terasa hidup sejak detik pertama.
class DaftarKerangka extends StatefulWidget {
  const DaftarKerangka({super.key});

  @override
  State<DaftarKerangka> createState() => _DaftarKerangkaState();
}

class _DaftarKerangkaState extends State<DaftarKerangka>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _kendali,
      builder: (context, _) {
        final dasar = gelap ? Colors.white : Colors.black;
        final warna = dasar.withOpacity(0.05 + 0.06 * _kendali.value);
        Widget kotak(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: warna,
            borderRadius: BorderRadius.circular(8),
          ),
        );
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: 5,
          itemBuilder: (context, i) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  kotak(64, 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        kotak(160, 14),
                        const SizedBox(height: 8),
                        kotak(110, 12),
                        const SizedBox(height: 8),
                        kotak(80, 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Warna khas tiap kategori barang, dipakai di kartu, chip, dan ikon
/// supaya tampilan tidak monoton.
Color warnaKategori(String k) => switch (k) {
  'Dompet & Uang' => const Color(0xFFD97706),
  'KTM & Dokumen' => const Color(0xFF2563EB),
  'Kunci' => const Color(0xFFEA580C),
  'HP & Elektronik' => const Color(0xFF7C3AED),
  'Helm & Kendaraan' => const Color(0xFF0D9488),
  'Tas & Pakaian' => const Color(0xFFDB2777),
  'Buku & Alat Tulis' => const Color(0xFF16A34A),
  _ => const Color(0xFF64748B),
};

/// Ikon khas tiap kategori barang.
IconData ikonKategori(String k) => switch (k) {
  'Dompet & Uang' => Icons.wallet_outlined,
  'KTM & Dokumen' => Icons.badge_outlined,
  'Kunci' => Icons.key_outlined,
  'HP & Elektronik' => Icons.smartphone_outlined,
  'Helm & Kendaraan' => Icons.sports_motorsports_outlined,
  'Tas & Pakaian' => Icons.shopping_bag_outlined,
  'Buku & Alat Tulis' => Icons.menu_book_outlined,
  _ => Icons.category_outlined,
};
const List<String> kKategori = [
  'Dompet & Uang',
  'KTM & Dokumen',
  'Kunci',
  'HP & Elektronik',
  'Helm & Kendaraan',
  'Tas & Pakaian',
  'Buku & Alat Tulis',
  'Lainnya',
];

/// Daftar foto sebuah postingan: foto_urls (baru) lalu foto_url (lama).
List<String> daftarFoto(Map<String, dynamic> post) {
  final hasil = <String>[];
  final urls = post['foto_urls'];
  if (urls is List) {
    for (final u in urls) {
      if (u != null && u.toString().isNotEmpty) hasil.add(u.toString());
    }
  }
  if (hasil.isEmpty) {
    final satu = post['foto_url'];
    if (satu != null && satu.toString().isNotEmpty) {
      hasil.add(satu.toString());
    }
  }
  return hasil;
}

String fmtTanggal(dynamic v) {
  if (v == null) return '-';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return '-';
  return DateFormat('d MMM yyyy, HH:mm', kBahasa.value).format(d.toLocal());
}

/// Waktu relatif ringkas untuk kartu postingan: baru saja, sekian
/// menit atau jam lalu, Kemarin, sekian hari lalu, lalu tanggal biasa.
String fmtRelatif(dynamic v) {
  if (v == null) return '';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return '';
  final beda = DateTime.now().difference(d.toLocal());
  final en = kBahasa.value == 'en';
  if (beda.inMinutes < 1) return en ? 'just now' : 'baru saja';
  if (beda.inMinutes < 60) {
    return en ? '${beda.inMinutes}m ago' : '${beda.inMinutes} menit lalu';
  }
  if (beda.inHours < 24) {
    return en ? '${beda.inHours}h ago' : '${beda.inHours} jam lalu';
  }
  if (beda.inDays == 1) return en ? 'Yesterday' : 'Kemarin';
  if (beda.inDays < 7) {
    return en ? '${beda.inDays} days ago' : '${beda.inDays} hari lalu';
  }
  return fmtTanggal(v);
}

/// Tampilkan satu foto layar penuh di dalam aplikasi (bisa dicubit
/// untuk memperbesar), tanpa melempar pengguna ke peramban.
void lihatFotoBesar(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

String fmtBulan(dynamic v) {
  if (v == null) return '-';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return '-';
  return DateFormat('d MMM yyyy', kBahasa.value).format(d.toLocal());
}

/// Ambil nama dan foto publik sekelompok pengguna dari view aman
/// (tanpa nomor WA). Mengembalikan peta id -> baris publik.
Future<Map<String, Map<String, dynamic>>> ambilProfilPublik(
  Iterable<String> ids,
) async {
  final unik = ids.where((e) => e.isNotEmpty).toSet().toList();
  if (unik.isEmpty) return {};
  try {
    final rows = await sb
        .from('lf_profiles_publik')
        .select('id, nama, foto_url, terverifikasi, prodi, nama_tampilan')
        .inFilter('id', unik);
    return {
      for (final r in rows) (r['id'] as String): Map<String, dynamic>.from(r),
    };
  } catch (_) {
    return {};
  }
}

/// Isi kolom nama_pemilik pada daftar baris yang punya user_id.
Future<void> pasangNama(List<Map<String, dynamic>> rows) async {
  final peta = await ambilProfilPublik(
    rows.map((r) => (r['user_id'] ?? '').toString()),
  );
  for (final r in rows) {
    final pub = peta[(r['user_id'] ?? '').toString()];
    if (pub != null) {
      final tampilan = (pub['nama_tampilan'] ?? '').toString().trim();
      r['nama_pemilik'] = tampilan.isNotEmpty ? tampilan : pub['nama'];
      r['foto_pemilik'] = pub['foto_url'];
      r['terverifikasi_pemilik'] = pub['terverifikasi'];
      r['prodi_pemilik'] = pub['prodi'];
      if (r['samarkan_nama'] == true) {
        r['nama_pemilik'] = tr(
          pub['terverifikasi'] == true
              ? 'Pengguna Terverifikasi'
              : 'Sesama Pengguna',
        );
        r['foto_pemilik'] = null;
        r['nama_disamarkan'] = true;
      }
    }
  }
}

String _tingkatBadge(int n, List<int> ambang) {
  if (n >= ambang[2]) return tr('Emas');
  if (n >= ambang[1]) return tr('Perak');
  if (n >= ambang[0]) return tr('Perunggu');
  return '';
}

/// Badge seorang pengguna, dihitung server lewat view agregat
/// lf_stat_pengguna sehingga angkanya utuh untuk semua orang.
Future<List<Map<String, String>>> badgeUntuk(String userId) async {
  final hasil = <Map<String, String>>[];
  if (userId.isEmpty) return hasil;
  try {
    final rows = await sb
        .from('lf_stat_pengguna')
        .select()
        .eq('user_id', userId);
    if (rows.isEmpty) return hasil;
    final s = rows.first;
    final sejak = DateTime.tryParse((s['sejak'] ?? '').toString());
    if (sejak != null && DateTime.now().difference(sejak).inDays < 7) {
      hasil.add({'nama': 'Warga Baru', 'tingkat': ''});
    }
    void tambah(String nama, dynamic nilai, List<int> ambang) {
      final t = _tingkatBadge((nilai as num?)?.toInt() ?? 0, ambang);
      if (t.isNotEmpty) hasil.add({'nama': nama, 'tingkat': t});
    }

    tambah('Sering Lapor', s['total_posting'], [5, 15, 30]);
    tambah('Penemu Andal', s['temuan_kembali'], [1, 3, 10]);
    tambah('Suka Menolong', s['klaim_ok'], [1, 5, 15]);
    tambah(
      'Kontributor Tepercaya',
      ((s['temuan_kembali'] as num?) ?? 0) + ((s['klaim_ok'] as num?) ?? 0),
      [3, 8, 20],
    );
    tambah('Pengangkat Rame', s['up_diberikan'], [25, 75, 200]);
  } catch (_) {
    // badge gagal dimuat, tampilan tetap jalan
  }
  return hasil;
}

class BarisBadge extends StatelessWidget {
  final String userId;
  const BarisBadge({super.key, required this.userId});

  Color _warna(String tingkat) {
    switch (tingkat) {
      case 'Emas':
        return const Color(0xFFB8860B);
      case 'Perak':
        return const Color(0xFF757575);
      case 'Perunggu':
        return const Color(0xFFA0522D);
      default:
        return kBiru;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: badgeUntuk(userId),
      builder: (context, snap) {
        final data = snap.data ?? [];
        if (data.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < data.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Chip(
                  avatar: Icon(
                    Icons.emoji_events_outlined,
                    size: 13,
                    color: _warna(data[i]['tingkat'] ?? ''),
                  ),
                  label: Text(
                    (data[i]['tingkat'] ?? '').isEmpty
                        ? tr((data[i]['nama'] ?? '').toString())
                        : '${tr((data[i]['nama'] ?? '').toString())} ${data[i]['tingkat']}',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  labelPadding: const EdgeInsets.only(right: 4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

bool _sudahCekUpdate = false;

/// Periksa pembaruan: otomatis sekali per sesi (diam bila sudah terbaru),
/// atau manual dari menu Akun (memberi kabar apa pun hasilnya).
Future<void> cekUpdate(BuildContext context, {bool manual = false}) async {
  if (!manual && _sudahCekUpdate) return;
  try {
    final info = await PackageInfo.fromPlatform();
    final lokal = int.tryParse(info.buildNumber) ?? 0;
    final resp = await http
        .get(Uri.parse(kVersionJsonUrl))
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) throw 'server';
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _sudahCekUpdate = true;
    // Berkas penanda memakai kunci "kode"; "code" dibaca juga untuk
    // berjaga bila formatnya berubah lagi.
    final terbaru =
        (data['kode'] as num?)?.toInt() ?? (data['code'] as num?)?.toInt() ?? 0;
    if (!context.mounted) return;
    if (terbaru > lokal) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            kBahasa.value == 'en'
                ? 'Version ${data['versi'] ?? data['nama'] ?? ''} is available'
                : 'Versi ${data['versi'] ?? data['nama'] ?? ''} tersedia',
          ),
          content: Text((data['catatan'] ?? '').toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Nanti saja')),
            ),
            FilledButton(
              onPressed: () async {
                // Berkas penanda menaruh tautan di kunci "apk"; "url"
                // dibaca juga untuk format lama. Dulu tombol ini hanya
                // membaca "url" sehingga tautannya kosong dan unduhan
                // tidak pernah terbuka.
                final tautan = (data['apk'] ?? data['url'] ?? '').toString();
                Navigator.of(context).pop();
                var terkirim = false;
                if (tautan.isNotEmpty) {
                  try {
                    terkirim = await launchUrl(
                      Uri.parse(tautan),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}
                }
                if (!terkirim && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr('Tidak bisa membuka tautan unduhan, coba lagi.'),
                      ),
                    ),
                  );
                }
              },
              child: Text(tr('Unduh Sekarang')),
            ),
          ],
        ),
      );
    } else if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kBahasa.value == 'en'
                ? 'Your app is already up to date (${info.version}).'
                : 'Aplikasimu sudah versi terbaru (${info.version}).',
          ),
        ),
      );
    }
  } catch (_) {
    if (manual && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Tidak bisa memeriksa pembaruan saat ini.'))),
      );
    }
  }
}

Future<bool> konfirmasiHapusPost(BuildContext context) async {
  final jadi = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Hapus postingan?')),
      content: Text(
        tr('Postingan ini akan dihapus permanen dan tidak bisa dikembalikan.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(tr('Batal')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(tr('Ya, hapus')),
        ),
      ],
    ),
  );
  return jadi == true;
}

/// Tombol akun berbentuk foto profil di kanan atas AppBar.
/// Bila profil tidak diberikan, diambil sendiri dari database.
class TombolAkun extends StatelessWidget {
  final Map<String, dynamic>? profil;
  const TombolAkun({super.key, this.profil});

  Future<void> _buka(BuildContext context) async {
    var p = profil;
    if (p == null) {
      final id = sb.auth.currentUser?.id;
      if (id == null) return;
      final rows = await sb.from('lf_profiles').select().eq('id', id);
      if (rows.isEmpty || !context.mounted) return;
      p = rows.first;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LayarAkun(profil: p!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foto = (profil?['foto_url'] ?? '').toString();
    final nama = (profil?['nama'] ?? 'A').toString();
    return IconButton(
      tooltip: tr('Akun'),
      onPressed: () => _buka(context),
      icon: CircleAvatar(
        radius: 15,
        backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
        child: foto.isEmpty
            ? Text(
                nama.isNotEmpty ? nama[0].toUpperCase() : 'A',
                style: const TextStyle(fontSize: 13),
              )
            : null,
      ),
    );
  }
}
