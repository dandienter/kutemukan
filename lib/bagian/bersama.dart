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

/// Panggil endpoint SIKA di API MySIKA. Melempar pesan galat yang sudah
/// diterjemahkan ke bahasa pengguna bila server menolak.

SupabaseClient get sb => Supabase.instance.client;

const Color kBiru = Color(0xFF0057A8);
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
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, anak, progres) => progres == null
                    ? anak
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, __, ___) => const Center(
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
        .select('id, nama, foto_url')
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
      r['nama_pemilik'] = pub['nama'];
      r['foto_pemilik'] = pub['foto_url'];
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
  _sudahCekUpdate = true;
  try {
    final info = await PackageInfo.fromPlatform();
    final lokal = int.tryParse(info.buildNumber) ?? 0;
    final resp = await http
        .get(Uri.parse(kVersionJsonUrl))
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) throw 'server';
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final terbaru = (data['code'] as num?)?.toInt() ?? 0;
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
              onPressed: () {
                Navigator.of(context).pop();
                launchUrl(
                  Uri.parse((data['url'] ?? '').toString()),
                  mode: LaunchMode.externalApplication,
                );
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
