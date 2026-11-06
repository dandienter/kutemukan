import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'i18n.dart';

@pragma('vm:entry-point')
Future<void> _fcmLatar(RemoteMessage pesan) async {
  // Pesan berkategori notification ditampilkan sistem secara otomatis.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  await muatPreferensi();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_fcmLatar);
  } catch (_) {
    // Firebase belum terpasang sempurna: aplikasi tetap jalan tanpa push.
  }
  runApp(const KutemuKanApp());
}

/// Daftarkan token FCM perangkat ini untuk pengguna yang sedang masuk.
Future<void> daftarkanTokenFcm() async {
  try {
    final user = sb.auth.currentUser;
    if (user == null) return;
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission();
    final token = await fm.getToken();
    if (token != null) {
      await sb.from('lf_devices').delete().eq('user_id', user.id);
      await sb.from('lf_devices').insert({
        'user_id': user.id,
        'token': token,
        'platform': 'android',
      });
    }
  } catch (_) {
    // Token gagal tercatat: notif dalam aplikasi tetap berfungsi.
  }
}

/// Kompres foto apa pun menjadi WebP ringan sebelum diunggah.
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

SupabaseClient get sb => Supabase.instance.client;

const Color kTeal = Color(0xFF0F766E);
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
                    child: Icon(Icons.image_not_supported_outlined,
                        color: Colors.white54, size: 40)),
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
    Iterable<String> ids) async {
  final unik = ids.where((e) => e.isNotEmpty).toSet().toList();
  if (unik.isEmpty) return {};
  try {
    final rows = await sb
        .from('lf_profiles_publik')
        .select('id, nama, foto_url')
        .inFilter('id', unik);
    return {
      for (final r in rows)
        (r['id'] as String): Map<String, dynamic>.from(r)
    };
  } catch (_) {
    return {};
  }
}

/// Isi kolom nama_pemilik pada daftar baris yang punya user_id.
Future<void> pasangNama(List<Map<String, dynamic>> rows) async {
  final peta = await ambilProfilPublik(
      rows.map((r) => (r['user_id'] ?? '').toString()));
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
        return kTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: badgeUntuk(userId),
      builder: (context, snap) {
        final data = snap.data ?? [];
        if (data.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in data)
              Chip(
                avatar: Icon(Icons.emoji_events_outlined,
                    size: 15, color: _warna(b['tingkat'] ?? '')),
                label: Text(
                    (b['tingkat'] ?? '').isEmpty
                        ? tr((b['nama'] ?? '').toString())
                        : '${tr((b['nama'] ?? '').toString())} ${b['tingkat']}',
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
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
          title: Text(kBahasa.value == 'en'
              ? 'Version ${data['versi']} is available'
              : 'Versi ${data['versi']} tersedia'),
          content: Text((data['catatan'] ?? '').toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Nanti saja')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                launchUrl(Uri.parse((data['url'] ?? '').toString()),
                    mode: LaunchMode.externalApplication);
              },
              child: Text(tr('Unduh Sekarang')),
            ),
          ],
        ),
      );
    } else if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(kBahasa.value == 'en'
              ? 'Your app is already up to date (${info.version}).'
              : 'Aplikasimu sudah versi terbaru (${info.version}).')));
    }
  } catch (_) {
    if (manual && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Tidak bisa memeriksa pembaruan saat ini.'))));
    }
  }
}

class KutemuKanApp extends StatelessWidget {
  const KutemuKanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: kTemaMode,
      builder: (_, mode, __) => ValueListenableBuilder<String>(
        valueListenable: kBahasa,
        builder: (_, bahasa, __) => MaterialApp(
          title: 'KutemuKan',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          locale: Locale(bahasa),
          supportedLocales: const [Locale('id'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: kTeal),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: kTeal, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          home: const LayarSplash(),
        ),
      ),
    );
  }
}

/// Splash pembuka beranimasi: maskot memudar masuk, nama dan gelar menyusul.
class LayarSplash extends StatefulWidget {
  const LayarSplash({super.key});
  @override
  State<LayarSplash> createState() => _LayarSplashState();
}

class _LayarSplashState extends State<LayarSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pudar;
  late final Animation<double> _skala;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pudar = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _skala = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const Pembuka()));
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTeal,
      body: Center(
        child: FadeTransition(
          opacity: _pudar,
          child: ScaleTransition(
            scale: _skala,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/maskot.png', height: 210),
                const SizedBox(height: 10),
                Text(tr('Lost and Found Kampus Unindra'),
                    style: TextStyle(fontSize: 15, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sesudah splash: tampilkan panduan sekali, sesudah itu langsung Gerbang.
class Pembuka extends StatelessWidget {
  const Pembuka({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance()
          .then((p) => p.getBool('panduan_v1') ?? false),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == false) return const LayarPanduan();
        return const Gerbang();
      },
    );
  }
}

class LayarPanduan extends StatefulWidget {
  const LayarPanduan({super.key});
  @override
  State<LayarPanduan> createState() => _LayarPanduanState();
}

class _LayarPanduanState extends State<LayarPanduan> {
  final _ctrl = PageController();
  int _hal = 0;

  static const _slides = [
    (
      'Barangmu hilang?',
      'Buat laporan kehilangan lengkap dengan foto, lokasi, dan ciri-cirinya. Makin jelas, makin besar peluang ketemu.'
    ),
    (
      'Menemukan barang?',
      'Umumkan sebagai temuan dan isi ciri khusus rahasianya. Hanya pemilik asli yang bisa menjawabnya saat mengklaim.'
    ),
    (
      'Klaim yang aman',
      'Nomor WhatsApp tidak terbuka sembarangan. Klaim harus disetujui dulu oleh yang memposting, baru kalian terhubung.'
    ),
  ];

  Future<void> _selesai() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('panduan_v1', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Gerbang()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: _selesai, child: Text(tr('Lewati'))),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _hal = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/maskot.png', height: 210),
                      const SizedBox(height: 26),
                      Text(tr(_slides[i].$1),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text(tr(_slides[i].$2), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.all(4),
                  width: _hal == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _hal == i ? kTeal : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_hal < _slides.length - 1) {
                      _ctrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut);
                    } else {
                      _selesai();
                    }
                  },
                  child:
                      Text(_hal < _slides.length - 1 ? 'Lanjut' : 'Mulai'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menentukan layar awal: login, lengkapi profil, atau beranda.
class Gerbang extends StatefulWidget {
  const Gerbang({super.key});
  @override
  State<Gerbang> createState() => _GerbangState();
}

class _GerbangState extends State<Gerbang> {
  StreamSubscription<AuthState>? _sub;
  Future<Map<String, dynamic>?>? _fProfil;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _sub = sb.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
      daftarkanTokenFcm();
    });
    daftarkanTokenFcm();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = sb.auth.currentUser;
    if (user == null) {
      _fProfil = null;
      _uid = null;
      return const LayarLogin();
    }
    // Future profil disimpan per pengguna. Membuat future baru pada setiap
    // build akan me-reset FutureBuilder, membongkar LayarUtama, dan membuat
    // Beranda memuat ulang dari nol setiap ada peristiwa auth atau tema.
    if (_uid != user.id) {
      _uid = user.id;
      _fProfil = _ambilProfil(user.id);
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fProfil,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done &&
            !snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final profil = snap.data;
        if (profil == null) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const LayarProfil();
        }
        return LayarUtama(profil: profil);
      },
    );
  }

  Future<Map<String, dynamic>?> _ambilProfil(String id) async {
    final rows = await sb.from('lf_profiles').select().eq('id', id);
    if (rows.isEmpty) return null;
    return rows.first;
  }
}

class LayarLogin extends StatefulWidget {
  const LayarLogin({super.key});
  @override
  State<LayarLogin> createState() => _LayarLoginState();
}

class _LayarLoginState extends State<LayarLogin> {
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  bool _modeDaftar = false;
  bool _sibuk = false;
  String? _galat;

  Future<void> _kirim() async {
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      if (_modeDaftar) {
        await sb.auth.signUp(
            email: _email.text.trim(), password: _sandi.text);
      } else {
        await sb.auth.signInWithPassword(
            email: _email.text.trim(), password: _sandi.text);
      }
    } on AuthException catch (e) {
      _galat = e.message;
    } catch (e) {
      _galat = 'Gagal tersambung: $e';
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/maskot.png', height: 200),
              const SizedBox(height: 6),
              Text(tr('Lost and Found Kampus Unindra'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _sandi,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: tr('Kata sandi'), border: OutlineInputBorder()),
              ),
              if (_galat != null) ...[
                const SizedBox(height: 12),
                Text(_galat!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sibuk ? null : _kirim,
                  child: Text(_sibuk
                      ? tr('Memproses...')
                      : (_modeDaftar ? tr('Daftar') : tr('Masuk'))),
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _modeDaftar = !_modeDaftar),
                child: Text(_modeDaftar
                    ? tr('Sudah punya akun? Masuk')
                    : tr('Belum punya akun? Daftar')),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(tr('atau')),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () async {
                  try {
                    await sb.auth.signInWithOAuth(
                      OAuthProvider.google,
                      redirectTo: 'kutemukan://login-callback',
                      authScreenLaunchMode:
                          LaunchMode.externalApplication,
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${tr('Login Google gagal')}: $e')));
                    }
                  }
                },
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: Text(tr('Masuk dengan Google')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LayarProfil extends StatefulWidget {
  final Map<String, dynamic>? profilAwal;
  const LayarProfil({super.key, this.profilAwal});
  @override
  State<LayarProfil> createState() => _LayarProfilState();
}

class _LayarProfilState extends State<LayarProfil> {
  final _nama = TextEditingController();
  final _wa = TextEditingController();
  bool _sibuk = false;
  String? _fotoUrl;
  File? _fotoBaru;

  bool get _modeEdit => widget.profilAwal != null;

  @override
  void initState() {
    super.initState();
    final awal = widget.profilAwal;
    if (awal != null) {
      _nama.text = awal['nama'] ?? '';
      _wa.text = awal['wa'] ?? '';
      _fotoUrl = awal['foto_url'] as String?;
    } else {
      final meta = sb.auth.currentUser?.userMetadata;
      final namaGoogle = meta?['full_name'] ?? meta?['name'];
      if (namaGoogle is String && namaGoogle.isNotEmpty) {
        _nama.text = namaGoogle;
      }
    }
  }

  Future<void> _pilihFoto() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => _fotoBaru = File(x.path));
  }

  ImageProvider? _fotoProfilTampil() {
    if (_fotoBaru != null) return FileImage(_fotoBaru!);
    if (_fotoUrl != null && _fotoUrl!.isNotEmpty) {
      return NetworkImage(_fotoUrl!);
    }
    return null;
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    var wa = _wa.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (nama.isEmpty || wa.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Isi nama dan nomor WhatsApp yang benar.'))));
      return;
    }
    if (wa.startsWith('0')) wa = '62${wa.substring(1)}';
    setState(() => _sibuk = true);
    try {
      var fotoUrl = _fotoUrl;
      if (_fotoBaru != null) {
        fotoUrl = await unggahBerkas(await kompresKeWebp(_fotoBaru!));
      }
      final id = sb.auth.currentUser!.id;
      if (_modeEdit) {
        await sb.from('lf_profiles').update(
            {'nama': nama, 'wa': wa, 'foto_url': fotoUrl}).eq('id', id);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await sb.from('lf_profiles').insert(
            {'id': id, 'nama': nama, 'wa': wa, 'foto_url': fotoUrl});
        if (mounted) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const Gerbang()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${tr('Gagal menyimpan')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_modeEdit ? 'Edit Profil' : 'Lengkapi Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pilihFoto,
              child: CircleAvatar(
                radius: 46,
                backgroundImage: _fotoProfilTampil(),
                child: (_fotoBaru == null &&
                        (_fotoUrl == null || _fotoUrl!.isEmpty))
                    ? const Icon(Icons.add_a_photo_outlined, size: 30)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(tr('Ketuk untuk pasang foto profil'),
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 18),
            Text(tr(
                'Nomor WhatsApp hanya dipakai saat ada yang perlu menghubungi soal barang. Nomor tidak tampil terbuka di papan.')),
            const SizedBox(height: 20),
            TextField(
              controller: _nama,
              decoration: InputDecoration(
                  labelText: tr('Nama lengkap'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _wa,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: tr('Nomor WhatsApp (08xx)'),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sibuk ? null : _simpan,
                child: Text(_sibuk
                    ? tr('Menyimpan...')
                    : (_modeEdit
                        ? tr('Simpan Perubahan')
                        : tr('Simpan dan Masuk'))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LayarUtama extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarUtama({super.key, required this.profil});
  @override
  State<LayarUtama> createState() => _LayarUtamaState();
}

class _LayarUtamaState extends State<LayarUtama> {
  int _tab = 0;
  late Map<String, dynamic> _profil = widget.profil;
  int _belumDibaca = 0;
  RealtimeChannel? _kanalNotif;

  @override
  void initState() {
    super.initState();
    _hitungBelumDibaca();
    final id = sb.auth.currentUser?.id;
    if (id != null) {
      _kanalNotif = sb
          .channel('notif-saya')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'lf_notif',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: id,
            ),
            callback: (_) => _hitungBelumDibaca(),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    if (_kanalNotif != null) sb.removeChannel(_kanalNotif!);
    super.dispose();
  }

  Future<void> _hitungBelumDibaca() async {
    final id = sb.auth.currentUser?.id;
    if (id == null) return;
    try {
      final rows = await sb
          .from('lf_notif')
          .select('id')
          .eq('user_id', id)
          .eq('dibaca', false);
      if (mounted) setState(() => _belumDibaca = rows.length);
    } catch (_) {
      // abaikan, badge hanya pelengkap
    }
  }

  Future<void> _segarkanProfil() async {
    final id = sb.auth.currentUser?.id;
    if (id == null) return;
    final rows = await sb.from('lf_profiles').select().eq('id', id);
    if (rows.isNotEmpty && mounted) {
      setState(() => _profil = rows.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final halaman = <Widget>[
      LayarBeranda(profil: _profil),
      LayarBuat(profil: _profil),
      const LayarNotif(),
      LayarAkun(profil: _profil, onProfilDiubah: _segarkanProfil),
    ];
    final tujuan = <NavigationDestination>[
      NavigationDestination(
          icon: const Icon(Icons.home_outlined), label: tr('Beranda')),
      NavigationDestination(
          icon: const Icon(Icons.add_circle_outline), label: tr('Buat')),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _belumDibaca > 0,
          label: Text('$_belumDibaca'),
          child: const Icon(Icons.notifications_outlined),
        ),
        label: tr('Notif'),
      ),
      NavigationDestination(
          icon: const Icon(Icons.person_outline), label: tr('Akun')),
    ];
    if (_tab >= halaman.length) _tab = 0;
    return Scaffold(
      body: IndexedStack(index: _tab, children: halaman),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 2) {
            Future.delayed(
                const Duration(seconds: 2), _hitungBelumDibaca);
          }
        },
        destinations: tujuan,
      ),
    );
  }
}

Color warnaStatus(String s) {
  switch (s) {
    case 'tampil':
      return Colors.green;
    case 'menunggu':
      return Colors.orange;
    case 'kembali':
      return Colors.blueGrey;
    case 'ditolak':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String labelStatus(String s) {
  switch (s) {
    case 'tampil':
      return tr('Tampil');
    case 'menunggu':
      return tr('Menunggu moderasi');
    case 'kembali':
      return tr('Sudah kembali');
    case 'ditolak':
      return tr('Ditolak');
    default:
      return s;
  }
}

class KartuPostingan extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onTap;
  final bool tampilStatus;
  final void Function(String aksi)? onAksi;
  final VoidCallback? onUp;
  final bool sudahUp;
  const KartuPostingan({
    super.key,
    required this.post,
    this.onTap,
    this.tampilStatus = false,
    this.onAksi,
    this.onUp,
    this.sudahUp = false,
  });
  @override
  Widget build(BuildContext context) {
    final hilang = post['jenis'] == 'hilang';
    final foto = daftarFoto(post);
    final nama = (post['nama_pemilik'] ?? '').toString();
    final dilihat = (post['views_count'] as num?)?.toInt() ?? 0;
    final ups = (post['up_count'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: onTap,
            leading: foto.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(foto.first,
                        width: 56, height: 56, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported_outlined)),
                  )
                : CircleAvatar(
                    backgroundColor:
                        hilang ? Colors.red.shade50 : Colors.green.shade50,
                    child: Icon(
                        hilang
                            ? Icons.search_off
                            : Icons.find_in_page_outlined,
                        color: hilang ? Colors.red : Colors.green),
                  ),
            title: Text(post['judul'] ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${post['kategori']} - ${post['lokasi']}\n'
              '${nama.isNotEmpty ? 'oleh $nama - ' : ''}${fmtTanggal(post['created_at'])}',
              maxLines: 2,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tampilStatus)
                  Chip(
                    label: Text(labelStatus(post['status'] ?? ''),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: warnaStatus(post['status'] ?? ''),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Chip(
                    label: Text(hilang ? 'HILANG' : 'TEMUAN',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: hilang ? Colors.red : Colors.green,
                    visualDensity: VisualDensity.compact,
                  ),
                if (onAksi != null)
                  PopupMenuButton<String>(
                    onSelected: onAksi,
                    itemBuilder: (_) => [
                      if (post['status'] == 'tampil')
                        PopupMenuItem(
                            value: 'kembali',
                            child: Text(tr('Tandai sudah selesai'))),
                      PopupMenuItem(
                          value: 'hapus', child: Text(tr('Hapus'))),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$dilihat',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_upward, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$ups UP',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                if (onUp != null && !sudahUp)
                  TextButton.icon(
                    onPressed: onUp,
                    icon: const Icon(Icons.arrow_circle_up_outlined,
                        size: 18),
                    label: Text(tr('Bantu UP')),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LayarBeranda extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarBeranda({super.key, required this.profil});
  @override
  State<LayarBeranda> createState() => _LayarBerandaState();
}

class _LayarBerandaState extends State<LayarBeranda> {
  int _segmen = 0; // 0 Semua, 1 Saya
  String _jenis = 'semua';
  String _rentang = 'semua';
  String _urut = 'baru';
  DateTimeRange? _rentangCustom;
  String _cari = '';
  int _baru = 0;
  RealtimeChannel? _kanal;
  final ScrollController _gulir = ScrollController();
  final Set<String> _upHariIni = {};
  late Future<List<Map<String, dynamic>>> _fSemua;
  late Future<List<Map<String, dynamic>>> _fSaya;

  void _segarkan() {
    _fSemua = _ambilSemua();
    _fSaya = _ambilSaya();
    _muatUpHariIni();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _fSemua = _ambilSemua();
    _fSaya = _ambilSaya();
    _muatUpHariIni();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cekUpdate(context);
    });
    _kanal = sb
        .channel('beranda-post')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'lf_posts',
          callback: _dariRealtime,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'lf_posts',
          callback: _dariRealtime,
        )
        .subscribe();
  }

  void _dariRealtime(PostgresChangePayload payload) {
    if (!mounted) return;
    final rec = payload.newRecord;
    // Hanya postingan yang BARU tampil yang dihitung sebagai postingan
    // baru: terbit pertama kali (insert) atau baru disetujui admin
    // (status berubah menjadi tampil). Perubahan lain seperti Bantu UP
    // dan jumlah dilihat tidak boleh memicu pil postingan baru.
    final baruTampil = rec['status'] == 'tampil' &&
        (payload.eventType == PostgresChangeEvent.insert ||
            payload.oldRecord['status'] != 'tampil');
    if (baruTampil) setState(() => _baru++);
  }

  @override
  void dispose() {
    if (_kanal != null) sb.removeChannel(_kanal!);
    _gulir.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _ambilSemua() async {
    final rows = await sb
        .from('lf_posts')
        .select()
        .eq('status', 'tampil')
        .order('created_at', ascending: false)
        .limit(100);
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    return data;
  }

  Future<List<Map<String, dynamic>>> _ambilSaya() async {
    final rows = await sb
        .from('lf_posts')
        .select()
        .eq('user_id', sb.auth.currentUser!.id)
        .order('created_at', ascending: false);
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    return data;
  }

  Future<void> _bantuUp(Map<String, dynamic> p) async {
    final sebelum = (p['up_count'] as num?)?.toInt() ?? 0;
    try {
      final hasil = await sb.rpc('lf_up', params: {'p_post_id': p['id']});
      final sesudah = (hasil as num?)?.toInt() ?? sebelum;
      if (!mounted) return;
      if (sesudah > sebelum) {
        setState(() {
          p['up_count'] = sesudah;
          _upHariIni.add((p['id'] ?? '').toString());
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Terima kasih sudah bantu UP.'))));
      } else {
        setState(() => _upHariIni.add((p['id'] ?? '').toString()));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(tr('Kamu sudah bantu UP postingan ini hari ini.'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Bantu UP gagal, coba lagi sebentar.'))));
      }
    }
  }

  Future<void> _muatUpHariIni() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final now = DateTime.now();
      final tgl = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final rows = await sb
          .from('lf_ups')
          .select('post_id')
          .eq('user_id', uid)
          .eq('tanggal', tgl);
      if (!mounted) return;
      setState(() {
        _upHariIni
          ..clear()
          ..addAll(rows.map((r) => (r['post_id'] ?? '').toString()));
      });
    } catch (_) {
      // gagal memuat daftar UP tidak menghalangi beranda tampil
    }
  }

  bool _lolos(Map<String, dynamic> p) {
    if (_jenis != 'semua' && p['jenis'] != _jenis) return false;
    if (_cari.isNotEmpty &&
        !(p['judul'] ?? '').toString().toLowerCase().contains(_cari)) {
      return false;
    }
    if (_rentangCustom != null) {
      final t = DateTime.tryParse((p['created_at'] ?? '').toString());
      if (t == null) return false;
      final lokal = t.toLocal();
      final c = _rentangCustom!;
      final mulai = DateTime(c.start.year, c.start.month, c.start.day);
      final akhir = DateTime(c.end.year, c.end.month, c.end.day, 23, 59, 59);
      if (lokal.isBefore(mulai) || lokal.isAfter(akhir)) return false;
    } else if (_rentang != 'semua') {
      final t = DateTime.tryParse((p['created_at'] ?? '').toString());
      if (t == null) return false;
      final kini = DateTime.now();
      final lokal = t.toLocal();
      if (_rentang == 'hari_ini') {
        if (!(lokal.year == kini.year &&
            lokal.month == kini.month &&
            lokal.day == kini.day)) return false;
      } else if (_rentang == '7_hari') {
        if (kini.difference(lokal).inDays >= 7) return false;
      } else if (_rentang == '30_hari') {
        if (kini.difference(lokal).inDays >= 30) return false;
      }
    }
    return true;
  }

  Future<void> _aksiSaya(Map<String, dynamic> p, String aksi) async {
    if (aksi == 'kembali') {
      await sb.from('lf_posts').update({
        'status': 'kembali',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', p['id']);
    } else if (aksi == 'hapus') {
      await sb.from('lf_posts').delete().eq('id', p['id']);
    }
    _segarkan();
  }

  @override
  Widget build(BuildContext context) {
    final saya = _segmen == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KutemuKan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: tr('Pantau Kategori'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LayarPantau())),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: tr('Papan Pahlawan'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LayarPahlawan())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(tr('Semua'))),
                ButtonSegment(value: 1, label: Text(tr('Saya'))),
              ],
              selected: {_segmen},
              onSelectionChanged: (s) => setState(() => _segmen = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _cari = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: tr('Cari barang...'),
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                for (final j in ['semua', 'hilang', 'temuan'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(tr(j == 'semua'
                          ? 'Semua'
                          : (j == 'hilang' ? 'Kehilangan' : 'Ditemukan'))),
                      selected: _jenis == j,
                      onSelected: (_) => setState(() => _jenis = j),
                    ),
                  ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: tr('Urutkan dan saring waktu'),
                  icon: const Icon(Icons.calendar_month_outlined),
                  onSelected: (v) async {
                    if (v == 'r_kalender') {
                      final pilih = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime.now(),
                        initialDateRange: _rentangCustom,
                      );
                      if (pilih != null) {
                        setState(() => _rentangCustom = pilih);
                      }
                    } else if (v.startsWith('u_')) {
                      setState(() => _urut = v.substring(2));
                    } else if (v.startsWith('r_')) {
                      setState(() {
                        _rentangCustom = null;
                        _rentang = v.substring(2);
                      });
                    }
                  },
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      value: 'u_baru',
                      checked: _urut == 'baru',
                      child: Text(tr('Terbaru')),
                    ),
                    CheckedPopupMenuItem(
                      value: 'u_lama',
                      checked: _urut == 'lama',
                      child: Text(tr('Terlama')),
                    ),
                    const PopupMenuDivider(),
                    CheckedPopupMenuItem(
                      value: 'r_semua',
                      checked:
                          _rentangCustom == null && _rentang == 'semua',
                      child: Text(tr('Semua waktu')),
                    ),
                    CheckedPopupMenuItem(
                      value: 'r_hari_ini',
                      checked:
                          _rentangCustom == null && _rentang == 'hari_ini',
                      child: Text(tr('Hari ini')),
                    ),
                    CheckedPopupMenuItem(
                      value: 'r_7_hari',
                      checked:
                          _rentangCustom == null && _rentang == '7_hari',
                      child: Text(tr('7 hari terakhir')),
                    ),
                    CheckedPopupMenuItem(
                      value: 'r_30_hari',
                      checked:
                          _rentangCustom == null && _rentang == '30_hari',
                      child: Text(tr('30 hari terakhir')),
                    ),
                    CheckedPopupMenuItem(
                      value: 'r_kalender',
                      checked: _rentangCustom != null,
                      child: Text(tr('Pilih dari kalender...')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: saya ? _fSaya : _fSemua,
              builder: (context, snap) {
                if (snap.hasError && snap.data == null) {
                  return Center(child: Text('${tr('Gagal memuat')}: ${snap.error}'));
                }
                if (snap.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = (snap.data ?? []).where(_lolos).toList();
                DateTime dibuat(Map<String, dynamic> p) =>
                    DateTime.tryParse((p['created_at'] ?? '').toString()) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                if (_urut == 'lama') {
                  data.sort((x, y) => dibuat(x).compareTo(dibuat(y)));
                } else if (!saya) {
                  DateTime kunci(Map<String, dynamic> p) {
                    final a =
                        DateTime.tryParse((p['last_up_at'] ?? '').toString());
                    final b = dibuat(p);
                    return (a != null && a.isAfter(b)) ? a : b;
                  }

                  data.sort((x, y) => kunci(y).compareTo(kunci(x)));
                }
                if (data.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/maskot.png', height: 120),
                        const SizedBox(height: 12),
                        Text(tr(saya
                            ? 'Kamu belum punya postingan.'
                            : 'Belum ada postingan yang cocok.')),
                      ],
                    ),
                  );
                }
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        _segarkan();
                        await (saya ? _fSaya : _fSemua);
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: _gulir,
                        itemCount: data.length,
                        itemBuilder: (_, i) => KartuPostingan(
                          post: data[i],
                          tampilStatus: saya,
                          onAksi: saya
                              ? (a) => _aksiSaya(data[i], a)
                              : null,
                          onUp: (!saya &&
                                  data[i]['user_id'] !=
                                      sb.auth.currentUser?.id)
                              ? () => _bantuUp(data[i])
                              : null,
                          sudahUp: _upHariIni
                              .contains((data[i]['id'] ?? '').toString()),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (_) =>
                                      LayarDetail(post: data[i])))
                              .then((_) => _segarkan()),
                        ),
                      ),
                    ),
                    if (_baru > 0 && !saya)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: () {
                              setState(() => _baru = 0);
                              _segarkan();
                              if (_gulir.hasClients) {
                                _gulir.animateTo(0,
                                    duration:
                                        const Duration(milliseconds: 350),
                                    curve: Curves.easeOut);
                              }
                            },
                            icon: const Icon(Icons.arrow_upward, size: 16),
                            label: Text('$_baru ${tr('postingan baru')}'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LayarDetail extends StatefulWidget {
  final Map<String, dynamic> post;
  const LayarDetail({super.key, required this.post});
  @override
  State<LayarDetail> createState() => _LayarDetailState();
}

class _LayarDetailState extends State<LayarDetail> {
  late Map<String, dynamic> _post = widget.post;
  List<Map<String, dynamic>> _klaimMasuk = [];
  Map<String, dynamic>? _klaimSaya;
  List<Map<String, dynamic>> _komentar = [];
  final TextEditingController _isiKomentar = TextEditingController();
  bool _muatKlaim = true;
  bool _sudahUp = false;
  int _fotoKe = 0;
  RealtimeChannel? _kanalKomentar;

  bool get _punyaSaya => _post['user_id'] == sb.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _muat();
    _kanalKomentar = sb
        .channel('komentar-${_post['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'lf_komentar',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: (_post['id'] ?? '').toString(),
          ),
          callback: (_) => _muatKomentar(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_kanalKomentar != null) sb.removeChannel(_kanalKomentar!);
    _isiKomentar.dispose();
    super.dispose();
  }

  Future<void> _muatKomentar() async {
    try {
      final rows = await sb
          .from('lf_komentar')
          .select()
          .eq('post_id', _post['id'])
          .order('created_at', ascending: true);
      final data = List<Map<String, dynamic>>.from(rows);
      await pasangNama(data);
      if (mounted) setState(() => _komentar = data);
    } catch (_) {
      // komentar gagal dimuat, abaikan
    }
  }

  Future<void> _muat() async {
    try {
      final rows =
          await sb.from('lf_posts').select().eq('id', _post['id']);
      if (rows.isNotEmpty) {
        _post = rows.first;
        await pasangNama([_post]);
      }
      // Catat view asli (server menolak hitungan ganda per hari,
      // dan kunjungan pemilik serta admin tidak dihitung).
      try {
        final v = await sb
            .rpc('lf_catat_view', params: {'p_post_id': _post['id']});
        if (v is num && v >= 0) _post['views_count'] = v.toInt();
      } catch (_) {}
      final klaim = await sb
          .from('lf_claims')
          .select()
          .eq('post_id', _post['id'])
          .order('created_at', ascending: false);
      final daftar = List<Map<String, dynamic>>.from(klaim);
      await pasangNama(daftar);
      if (_punyaSaya) {
        _klaimMasuk = daftar;
      } else {
        final saya = daftar.where(
            (k) => k['user_id'] == sb.auth.currentUser?.id);
        _klaimSaya = saya.isEmpty ? null : saya.first;
      }
      // Cek apakah saya sudah bantu UP postingan ini hari ini, supaya
      // tombolnya langsung tidak tampil sejak halaman dibuka.
      final uidSaya = sb.auth.currentUser?.id;
      if (uidSaya != null && !_punyaSaya) {
        try {
          final now = DateTime.now();
          final tgl = '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}';
          final upRows = await sb
              .from('lf_ups')
              .select('id')
              .eq('post_id', _post['id'])
              .eq('user_id', uidSaya)
              .eq('tanggal', tgl);
          if (upRows.isNotEmpty) _sudahUp = true;
        } catch (_) {}
      }
    } catch (_) {
      // klaim gagal dimuat, detail tetap tampil
    }
    await _muatKomentar();
    if (mounted) setState(() => _muatKlaim = false);
  }

  Future<void> _bantuUpDetail() async {
    final sebelum = (_post['up_count'] as num?)?.toInt() ?? 0;
    try {
      final hasil = await sb.rpc('lf_up', params: {'p_post_id': _post['id']});
      final sesudah = (hasil as num?)?.toInt() ?? sebelum;
      if (!mounted) return;
      if (sesudah > sebelum) {
        setState(() {
          _post['up_count'] = sesudah;
          _sudahUp = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Terima kasih sudah bantu UP.'))));
      } else {
        setState(() => _sudahUp = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(tr('Kamu sudah bantu UP postingan ini hari ini.'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Bantu UP gagal, coba lagi sebentar.'))));
      }
    }
  }

  Future<void> _kirimKomentar() async {
    final isi = _isiKomentar.text.trim();
    if (isi.isEmpty) return;
    try {
      await sb.from('lf_komentar').insert({
        'post_id': _post['id'],
        'user_id': sb.auth.currentUser!.id,
        'isi': isi,
      });
      _isiKomentar.clear();
      await _muatKomentar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('Komentar gagal terkirim')}: $e')));
      }
    }
  }

  Future<void> _hapusKomentar(Map<String, dynamic> k) async {
    await sb.from('lf_komentar').delete().eq('id', k['id']);
    await _muatKomentar();
  }

  Future<void> _laporkan() async {
    final alasan = TextEditingController();
    final jadi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Laporkan Postingan')),
        content: TextField(
          controller: alasan,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: tr('Kenapa postingan ini bermasalah?'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Kirim Laporan')),
          ),
        ],
      ),
    );
    if (jadi != true) return;
    try {
      await sb.from('lf_laporan').insert({
        'post_id': _post['id'],
        'user_id': sb.auth.currentUser!.id,
        'alasan': alasan.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(tr('Laporan terkirim. Admin akan memeriksanya.'))));
      }
    } catch (e) {
      if (mounted) {
        final duplikat = e.toString().contains('23505');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(duplikat
                ? 'Kamu sudah pernah melaporkan postingan ini.'
                : 'Laporan gagal terkirim.'))));
      }
    }
  }

  Future<void> _putuskanKlaim(Map<String, dynamic> klaim, String status) async {
    await sb
        .from('lf_claims')
        .update({'status': status}).eq('id', klaim['id']);
    await _muat();
  }

  Future<void> _tandaiSelesai() async {
    await sb.from('lf_posts').update({
      'status': 'kembali',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', _post['id']);
    await _muat();
  }

  Future<void> _bukaWa(String wa, String sapaan) async {
    final teks = Uri.encodeComponent(sapaan);
    await launchUrl(Uri.parse('https://wa.me/$wa?text=$teks'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _hubungiPemilik() async {
    try {
      final hasil =
          await sb.rpc('lf_kontak', params: {'p_post_id': _post['id']});
      final wa = hasil?.toString() ?? '';
      if (wa.isEmpty) throw 'Klaim belum disetujui';
      await _bukaWa(wa,
          'Halo, klaim saya soal "${_post['judul']}" sudah disetujui. ');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('Belum bisa menghubungi')}: $e')));
      }
    }
  }

  Future<void> _hubungiPengklaim(Map<String, dynamic> klaim) async {
    try {
      final hasil = await sb
          .rpc('lf_kontak_klaim', params: {'p_claim_id': klaim['id']});
      final wa = hasil?.toString() ?? '';
      if (wa.isEmpty) throw 'Nomor tidak tersedia';
      await _bukaWa(
          wa, 'Halo, soal klaim "${_post['judul']}" yang sudah saya setujui. ');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('Belum bisa menghubungi')}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hilang = _post['jenis'] == 'hilang';
    final foto = daftarFoto(_post);
    final namaPemilik = _post['nama_pemilik'] ?? 'Pengguna KutemuKan';
    final dilihat = (_post['views_count'] as num?)?.toInt() ?? 0;
    final ups = (_post['up_count'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(hilang ? 'Barang Hilang' : 'Barang Temuan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: tr('Bagikan'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LayarBagikan(post: _post))),
          ),
          if (!_punyaSaya)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: tr('Laporkan'),
              onPressed: _laporkan,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (foto.isNotEmpty) ...[
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: foto.length,
                onPageChanged: (i) => setState(() => _fotoKe = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => lihatFotoBesar(context, foto[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(foto[i],
                        width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                            child:
                                Icon(Icons.image_not_supported_outlined))),
                  ),
                ),
              ),
            ),
            if (foto.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    foto.length,
                    (i) => Container(
                      margin: const EdgeInsets.all(3),
                      width: _fotoKe == i ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _fotoKe == i ? kTeal : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
          ],
          Text(_post['judul'] ?? '',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${tr('Kategori')}: ${_post['kategori']}'),
          Text('${tr('Lokasi')}: ${_post['lokasi']}'),
          Text(
              '${tr('Waktu kejadian')}: ${fmtTanggal(_post['waktu_kejadian'])}'),
          if (_post['penitipan'] != null &&
              (_post['penitipan'] as String).isNotEmpty)
            Text('${tr('Dititipkan di')}: ${_post['penitipan']}'),
          Text('${tr('Dilaporkan oleh')}: $namaPemilik'),
          const SizedBox(height: 6),
          BarisBadge(userId: (_post['user_id'] ?? '').toString()),
          const SizedBox(height: 6),
          Text('Status: ${labelStatus(_post['status'] ?? '')}'),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                  kBahasa.value == 'en'
                      ? 'Viewed $dilihat times'
                      : 'Dilihat $dilihat kali',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(width: 18),
              const Icon(Icons.arrow_upward, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$ups UP',
                  style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              if (!_punyaSaya && _post['status'] == 'tampil' && !_sudahUp)
                FilledButton.tonalIcon(
                  onPressed: _bantuUpDetail,
                  icon: const Icon(Icons.arrow_circle_up_outlined,
                      size: 18),
                  label: Text(tr('Bantu UP')),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_post['deskripsi'] ?? ''),
          const Divider(height: 32),
          if (_muatKlaim)
            const Center(child: CircularProgressIndicator())
          else if (_punyaSaya)
            ..._bagianPemilik()
          else
            ..._bagianPengunjung(),
          const Divider(height: 32),
          ..._bagianKomentar(),
        ],
      ),
    );
  }

  List<Widget> _bagianKomentar() {
    final saya = sb.auth.currentUser?.id;
    return [
      Text('${tr('Komentar')} (${_komentar.length})',
          style:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (_komentar.isEmpty)
        Text(tr(
            'Belum ada komentar. Tanya ciri barang di sini dulu sebelum mengajukan klaim juga boleh.')),
      for (final k in _komentar)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                child: Text(
                    ((k['nama_pemilik'] ?? '?').toString().isNotEmpty
                            ? (k['nama_pemilik'] ?? '?').toString()[0]
                            : '?')
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              k['nama_pemilik'] ?? tr('Pengguna'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                        Text(fmtTanggal(k['created_at']),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        if (k['user_id'] == saya)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _hapusKomentar(k),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text((k['isi'] ?? '').toString()),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (_post['status'] == 'tampil') ...[
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _isiKomentar,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: tr('Tulis komentar...'),
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: kTeal),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _kirimKomentar,
              icon: const Icon(Icons.send, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    ];
  }

  List<Widget> _bagianPemilik() {
    final menunggu =
        _klaimMasuk.where((k) => k['status'] == 'menunggu').toList();
    return [
      if (_post['status'] == 'tampil') ...[
        if (menunggu.isNotEmpty)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  tr('Ada klaim menunggu keputusanmu. Periksa ciri khususnya baik-baik sebelum menyetujui.'),
                  style: const TextStyle(color: Colors.black87)),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _tandaiSelesai,
            icon: const Icon(Icons.verified_outlined),
            label: Text(tr('Tandai Sudah Selesai')),
          ),
        ),
        const SizedBox(height: 16),
      ],
      Text(tr('Klaim Masuk'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (_klaimMasuk.isEmpty)
        Text(tr('Belum ada klaim untuk postingan ini.')),
      for (final k in _klaimMasuk) _kartuKlaim(k),
    ];
  }

  Widget _kartuKlaim(Map<String, dynamic> k) {
    final nama = k['nama_pemilik'] ?? 'Pengguna';
    final status = k['status'] ?? 'menunggu';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(nama,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Chip(
                  label: Text(status,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white)),
                  backgroundColor: status == 'disetujui'
                      ? Colors.green
                      : status == 'ditolak'
                          ? Colors.red
                          : Colors.orange,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            BarisBadge(userId: (k['user_id'] ?? '').toString()),
            const SizedBox(height: 4),
            Text('"${k['pesan'] ?? ''}"'),
            if (k['bukti_url'] != null)
              TextButton.icon(
                onPressed: () =>
                    lihatFotoBesar(context, (k['bukti_url']).toString()),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(tr('Lihat foto bukti')),
              ),
            Text(fmtTanggal(k['created_at']),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (status == 'menunggu')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _putuskanKlaim(k, 'ditolak'),
                    child: Text(tr('Tolak'),
                        style: TextStyle(color: Colors.red)),
                  ),
                  FilledButton(
                    onPressed: () => _putuskanKlaim(k, 'disetujui'),
                    child: Text(tr('Setujui')),
                  ),
                ],
              ),
            if (status == 'disetujui')
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _hubungiPengklaim(k),
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(tr('Hubungi Pengklaim')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _bagianPengunjung() {
    if (_post['status'] != 'tampil') return [];
    final k = _klaimSaya;
    if (k == null) {
      return [
        Card(
          color: const Color(0xFFE6F4F1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
                tr('Ini barangmu? Ajukan klaim dan sebutkan ciri khususnya. Nomor WhatsApp baru terbuka sesudah klaimmu disetujui yang memposting.'),
                style: const TextStyle(color: Colors.black87)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final terkirim = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                      builder: (_) => LayarKlaim(post: _post)));
              if (terkirim == true) await _muat();
            },
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(tr('Ajukan Klaim')),
          ),
        ),
      ];
    }
    final status = k['status'] ?? 'menunggu';
    if (status == 'menunggu') {
      return [
        Card(
          color: Colors.orange,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
                tr('Klaimmu sudah terkirim dan menunggu keputusan yang memposting. Kamu akan mendapat notif begitu ada keputusan.'),
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      ];
    }
    if (status == 'ditolak') {
      return [
        Card(
          color: Colors.red,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
                tr('Klaimmu belum bisa disetujui. Pastikan ciri khusus yang kamu sebutkan benar-benar hanya diketahui pemilik aslinya.'),
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      ];
    }
    return [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _hubungiPemilik,
          icon: const Icon(Icons.chat),
          label: Text(tr('Hubungi via WhatsApp')),
        ),
      ),
    ];
  }
}

class LayarKlaim extends StatefulWidget {
  final Map<String, dynamic> post;
  const LayarKlaim({super.key, required this.post});
  @override
  State<LayarKlaim> createState() => _LayarKlaimState();
}

class _LayarKlaimState extends State<LayarKlaim> {
  final _pesan = TextEditingController();
  File? _bukti;
  bool _sibuk = false;

  Future<void> _kirim() async {
    if (_pesan.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(
              'Sebutkan ciri khusus barangnya lebih jelas (minimal 10 karakter).'))));
      return;
    }
    setState(() => _sibuk = true);
    try {
      String? buktiUrl;
      if (_bukti != null) {
        buktiUrl = await unggahBerkas(await kompresKeWebp(_bukti!));
      }
      await sb.from('lf_claims').insert({
        'post_id': widget.post['id'],
        'user_id': sb.auth.currentUser!.id,
        'pesan': _pesan.text.trim(),
        'bukti_url': buktiUrl,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('Gagal mengirim klaim')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ajukan Klaim'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('${tr('Postingan')}: ${widget.post['judul']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(tr(
              'Sebutkan ciri khusus yang hanya diketahui pemilik asli barang ini, misalnya isi di dalamnya, tanda unik, atau nomor serinya. Jawabanmu dibaca yang memposting untuk memutuskan klaim ini benar atau bukan.')),
          const SizedBox(height: 14),
          TextField(
            controller: _pesan,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: tr('Ciri khusus barang'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final x = await ImagePicker()
                  .pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (x != null) setState(() => _bukti = File(x.path));
            },
            icon: const Icon(Icons.image_outlined),
            label: Text(tr(_bukti == null
                ? 'Tambah Foto Bukti (opsional)'
                : 'Ganti Foto Bukti')),
          ),
          if (_bukti != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_bukti!, height: 150, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _sibuk ? null : _kirim,
            child: Text(_sibuk ? tr('Mengirim...') : tr('Kirim Klaim')),
          ),
        ],
      ),
    );
  }
}

class LayarBuat extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarBuat({super.key, required this.profil});
  @override
  State<LayarBuat> createState() => _LayarBuatState();
}

class _LayarBuatState extends State<LayarBuat> {
  String _jenis = 'hilang';
  String _kategori = kKategori.first;
  final _judul = TextEditingController();
  final _deskripsi = TextEditingController();
  final _lokasi = TextEditingController();
  final _penitipan = TextEditingController();
  final _rahasia = TextEditingController();
  DateTime _waktu = DateTime.now();
  final List<File> _foto = [];
  bool _sibuk = false;

  Future<void> _pilihFoto() async {
    if (_foto.length >= 5) return;
    final xs = await ImagePicker()
        .pickMultiImage(imageQuality: 78, limit: 5);
    if (xs.isEmpty) return;
    setState(() {
      for (final x in xs) {
        if (_foto.length < 5) _foto.add(File(x.path));
      }
    });
  }

  Future<void> _kirim() async {
    if (_judul.text.trim().isEmpty || _lokasi.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Judul dan lokasi wajib diisi.'))));
      return;
    }
    setState(() => _sibuk = true);
    try {
      final urls = <String>[];
      for (final f in _foto) {
        urls.add(await unggahBerkas(await kompresKeWebp(f)));
      }
      await sb.from('lf_posts').insert({
        'user_id': sb.auth.currentUser!.id,
        'jenis': _jenis,
        'judul': _judul.text.trim(),
        'kategori': _kategori,
        'deskripsi': _deskripsi.text.trim(),
        'lokasi': _lokasi.text.trim(),
        'waktu_kejadian': _waktu.toUtc().toIso8601String(),
        'foto_url': urls.isEmpty ? null : urls.first,
        'foto_urls': urls,
        'detail_rahasia':
            _rahasia.text.trim().isEmpty ? null : _rahasia.text.trim(),
        'penitipan': _jenis == 'temuan' ? _penitipan.text.trim() : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Postingan terkirim. Menunggu moderasi admin sebelum tampil.')));
        _judul.clear();
        _deskripsi.clear();
        _lokasi.clear();
        _penitipan.clear();
        _rahasia.clear();
        setState(() => _foto.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${tr('Gagal mengirim')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  InputDecoration _rapat(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Buat Postingan'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'hilang', label: Text(tr('Saya Kehilangan'))),
                    ButtonSegment(
                        value: 'temuan', label: Text(tr('Saya Menemukan'))),
                  ],
                  selected: {_jenis},
                  onSelectionChanged: (s) =>
                      setState(() => _jenis = s.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _judul,
                  decoration: _rapat(tr('Judul (mis. Dompet hitam berisi KTM)')),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _kategori,
                        items: kKategori
                            .map((k) =>
                                DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        onChanged: (v) => setState(() => _kategori = v!),
                        decoration: _rapat(tr('Kategori')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final tgl = await showDatePicker(
                            context: context,
                            initialDate: _waktu,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (tgl != null && mounted) {
                            setState(() => _waktu = DateTime(tgl.year,
                                tgl.month, tgl.day, _waktu.hour, _waktu.minute));
                          }
                        },
                        child: InputDecorator(
                          decoration: _rapat(tr('Waktu')),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      fmtBulan(_waktu.toIso8601String()))),
                              const Icon(Icons.edit_calendar_outlined,
                                  size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _lokasi,
                  decoration: _rapat(tr('Lokasi (hilang / ditemukan)')),
                ),
                if (_jenis == 'temuan') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _penitipan,
                    decoration:
                        _rapat(tr('Barang dititipkan di (mis. pos satpam)')),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _deskripsi,
                  maxLines: 2,
                  decoration:
                      _rapat(tr('Deskripsi dan ciri-ciri (tampil publik)')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _rahasia,
                  maxLines: 2,
                  decoration: _rapat(tr('Ciri khusus rahasia'),
                      hint: tr('Tidak tampil publik, untuk verifikasi klaim')),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 78,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < _foto.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(_foto[i],
                                    width: 78, height: 78, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _foto.removeAt(i)),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                              if (i == 0)
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: Chip(
                                    label: Text(tr('Sampul'),
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white)),
                                    backgroundColor: kTeal,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      InkWell(
                        onTap: _foto.length >= 5 ? null : _pilihFoto,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_outlined,
                                  color: Colors.grey),
                              const SizedBox(height: 2),
                              Text('${tr('Foto')} ${_foto.length}/5',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sibuk ? null : _kirim,
                child: Text(
                    _sibuk ? tr('Mengirim...') : tr('Kirim untuk Moderasi')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LayarBagikan extends StatefulWidget {
  final Map<String, dynamic> post;
  const LayarBagikan({super.key, required this.post});
  @override
  State<LayarBagikan> createState() => _LayarBagikanState();
}

class _LayarBagikanState extends State<LayarBagikan> {
  final GlobalKey _kunciKartu = GlobalKey();
  bool _sibuk = false;

  Future<void> _bagikan() async {
    setState(() => _sibuk = true);
    try {
      final batas = _kunciKartu.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final gambar = await batas.toImage(pixelRatio: 3.0);
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final p = widget.post;
      final teks = StringBuffer()
        ..writeln(
            '${p['jenis'] == 'hilang' ? 'BARANG HILANG' : 'BARANG TEMUAN'}: ${p['judul']}')
        ..writeln('Kategori: ${p['kategori']} - Lokasi: ${p['lokasi']}')
        ..writeln('Waktu: ${fmtTanggal(p['waktu_kejadian'])}')
        ..writeln()
        ..write(
            'Kenali barang ini? Klaim atau bantu sebarkan lewat aplikasi KutemuKan, Lost and Found Kampus Unindra.');
      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              name: 'kutemukan-${p['id']}.png', mimeType: 'image/png')
        ],
        text: teks.toString(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('Gagal menyiapkan kartu')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final hilang = p['jenis'] == 'hilang';
    final foto = daftarFoto(p);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Bagikan Postingan'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: RepaintBoundary(
              key: _kunciKartu,
              child: Container(
                width: 340,
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: kTeal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Image.asset('assets/icon.png', height: 30),
                          const SizedBox(width: 8),
                          const Text('KutemuKan',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: hilang ? Colors.red : Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                                hilang ? 'HILANG' : 'TEMUAN',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    if (foto.isNotEmpty)
                      Image.network(foto.first,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              height: 60,
                              child: Center(
                                  child: Icon(
                                      Icons.image_not_supported_outlined)))),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['judul'] ?? '',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 6),
                          Text('${p['kategori']} - ${p['lokasi']}',
                              style: const TextStyle(color: Colors.black54)),
                          Text('${tr('Waktu')}: ${fmtTanggal(p['waktu_kejadian'])}',
                              style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 8),
                          Text((p['deskripsi'] ?? '').toString(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black87)),
                          const Divider(height: 22),
                          Text(
                            tr('Lost and Found Kampus Unindra - buka aplikasi KutemuKan untuk klaim atau bantu UP'),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sibuk ? null : _bagikan,
            icon: const Icon(Icons.share),
            label:
                Text(_sibuk ? 'Menyiapkan...' : 'Bagikan Sekarang'),
          ),
          const SizedBox(height: 8),
          Text(
            tr('Kartu ini tidak memuat ciri khusus rahasia dan nomor WhatsApp siapa pun.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class LayarPantau extends StatefulWidget {
  const LayarPantau({super.key});
  @override
  State<LayarPantau> createState() => _LayarPantauState();
}

class _LayarPantauState extends State<LayarPantau> {
  Set<String> _aktif = {};
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _ambil();
  }

  Future<void> _ambil() async {
    final rows = await sb
        .from('lf_pantau')
        .select('kategori')
        .eq('user_id', sb.auth.currentUser!.id);
    if (mounted) {
      setState(() {
        _aktif = rows.map((r) => (r['kategori'] ?? '').toString()).toSet();
        _muat = false;
      });
    }
  }

  Future<void> _ubah(String kategori, bool nyala) async {
    if (nyala) {
      await sb.from('lf_pantau').insert({
        'user_id': sb.auth.currentUser!.id,
        'kategori': kategori,
      });
    } else {
      await sb
          .from('lf_pantau')
          .delete()
          .eq('user_id', sb.auth.currentUser!.id)
          .eq('kategori', kategori);
    }
    setState(() {
      if (nyala) {
        _aktif.add(kategori);
      } else {
        _aktif.remove(kategori);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pantau Kategori'))),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tr(
                      'Nyalakan kategori yang mau kamu pantau. Setiap ada postingan baru tampil di kategori itu, kamu menerima notif dan push, walau belum pernah posting kehilangan.')),
                ),
                for (final k in kKategori)
                  SwitchListTile(
                    title: Text(k),
                    value: _aktif.contains(k),
                    onChanged: (v) => _ubah(k, v),
                  ),
              ],
            ),
    );
  }
}

class LayarKritikSaran extends StatefulWidget {
  const LayarKritikSaran({super.key});
  @override
  State<LayarKritikSaran> createState() => _LayarKritikSaranState();
}

class _LayarKritikSaranState extends State<LayarKritikSaran> {
  int _bintang = 5;
  final TextEditingController _isi = TextEditingController();
  bool _sibuk = false;

  Future<List<Map<String, dynamic>>> _ulasanSaya() async {
    final rows = await sb
        .from('lf_feedback')
        .select()
        .eq('user_id', sb.auth.currentUser!.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _kirim() async {
    if (_isi.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Tulis dulu kritik atau saranmu.'))));
      return;
    }
    setState(() => _sibuk = true);
    try {
      await sb.from('lf_feedback').insert({
        'user_id': sb.auth.currentUser!.id,
        'bintang': _bintang,
        'isi': _isi.text.trim(),
      });
      _isi.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Terima kasih, ulasanmu terkirim.'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('Gagal mengirim')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kritik & Saran'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(tr('Seberapa puas kamu dengan KutemuKan?')),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _bintang = i),
                  icon: Icon(
                    i <= _bintang ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 34,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _isi,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: tr(
                  'Fitur apa yang kurang, apa yang mengganggu, apa yang mau kamu minta ditambah...'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _sibuk ? null : _kirim,
            child: Text(_sibuk ? tr('Mengirim...') : tr('Kirim Ulasan')),
          ),
          const Divider(height: 36),
          Text(tr('Ulasanku sebelumnya'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _ulasanSaya(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data ?? [];
              if (data.isEmpty) {
                return Text(tr('Belum ada ulasan. Jadilah yang pertama.'));
              }
              return Column(
                children: [
                  for (final u in data)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            Text(' ${u['bintang']}'),
                          ],
                        ),
                        title: Text(u['isi'] ?? ''),
                        subtitle: Text(fmtTanggal(u['created_at'])),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class LayarPahlawan extends StatelessWidget {
  const LayarPahlawan({super.key});

  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb.from('lf_stat_bulanan').select();
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    int skor(Map<String, dynamic> r) =>
        ((r['kembali_bulan_ini'] as num?)?.toInt() ?? 0) * 3 +
        ((r['klaim_ok_bulan_ini'] as num?)?.toInt() ?? 0) * 2 +
        ((r['up_bulan_ini'] as num?)?.toInt() ?? 0);
    data.sort((a, b) => skor(b).compareTo(skor(a)));
    return data.where((r) => skor(r) > 0).take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Papan Pahlawan Kampus'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambil(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${tr('Gagal memuat')}: ${snap.error}'));
          }
          final data = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: kTeal,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr('Peringkat bulan ini dihitung dari data asli: barang yang kembali, klaim baik yang disetujui, dan Bantu UP yang diberikan. Direset tiap awal bulan.'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (data.isEmpty)
                Text(tr(
                    'Belum ada aktivitas bulan ini. Jadilah pahlawan pertama.')),
              for (int i = 0; i < data.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: i == 0
                          ? const Color(0xFFFFD54F)
                          : i == 1
                              ? const Color(0xFFCFD8DC)
                              : i == 2
                                  ? const Color(0xFFFFAB91)
                                  : Colors.grey.shade200,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(data[i]['nama_pemilik'] ?? 'Pengguna'),
                    subtitle: Text(kBahasa.value == 'en'
                        ? '${data[i]['kembali_bulan_ini']} items returned - ${data[i]['klaim_ok_bulan_ini']} good claims - ${data[i]['up_bulan_ini']} boosts given'
                        : '${data[i]['kembali_bulan_ini']} barang kembali - ${data[i]['klaim_ok_bulan_ini']} klaim baik - ${data[i]['up_bulan_ini']} UP diberikan'),
                    trailing: i < 3
                        ? const Icon(Icons.emoji_events,
                            color: Color(0xFFB8860B))
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LayarModerasi extends StatefulWidget {
  const LayarModerasi({super.key});
  @override
  State<LayarModerasi> createState() => _LayarModerasiState();
}

class _LayarModerasiState extends State<LayarModerasi> {
  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_posts')
        .select()
        .eq('status', 'menunggu')
        .order('created_at', ascending: true);
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    return data;
  }

  Future<void> _putuskan(Map<String, dynamic> post, String status) async {
    await sb.from('lf_posts').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', post['id']);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Moderasi'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambil(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(
                child: Text(tr('Tidak ada postingan menunggu moderasi.')));
          }
          return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
            itemCount: data.length,
            itemBuilder: (_, i) {
              final p = data[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KartuPostingan(
                        post: p,
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => LayarDetail(post: p))),
                      ),
                      if (p['detail_rahasia'] != null &&
                          (p['detail_rahasia'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Text(
                              'Ciri rahasia (khusus admin): ${p['detail_rahasia']}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _putuskan(p, 'ditolak'),
                            child: Text(tr('Tolak'),
                                style: TextStyle(color: Colors.red)),
                          ),
                          TextButton(
                            onPressed: () => _putuskan(p, 'kembali'),
                            child: Text(tr('Tandai Selesai')),
                          ),
                          FilledButton(
                            onPressed: () => _putuskan(p, 'tampil'),
                            child: Text(tr('Setujui dan Tampilkan')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class LayarLaporan extends StatefulWidget {
  const LayarLaporan({super.key});
  @override
  State<LayarLaporan> createState() => _LayarLaporanState();
}

class _LayarLaporanState extends State<LayarLaporan> {
  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_laporan')
        .select()
        .order('created_at', ascending: false);
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    for (final r in data) {
      try {
        final p = await sb
            .from('lf_posts')
            .select('judul, status')
            .eq('id', r['post_id']);
        if (p.isNotEmpty) {
          r['judul_post'] = p.first['judul'];
          r['status_post'] = p.first['status'];
        }
      } catch (_) {}
    }
    return data;
  }

  Future<void> _turunkan(Map<String, dynamic> r) async {
    await sb.from('lf_posts').update({
      'status': 'ditolak',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', r['post_id']);
    await sb.from('lf_laporan').delete().eq('post_id', r['post_id']);
    setState(() {});
  }

  Future<void> _abaikan(Map<String, dynamic> r) async {
    await sb.from('lf_laporan').delete().eq('id', r['id']);
    setState(() {});
  }

  Future<void> _buka(Map<String, dynamic> r) async {
    final rows =
        await sb.from('lf_posts').select().eq('id', r['post_id']);
    if (rows.isEmpty || !mounted) return;
    final post = rows.first;
    await pasangNama([post]);
    if (mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LayarDetail(post: post)));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Laporan Pengguna'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambil(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${tr('Gagal memuat')}: ${snap.error}'));
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(child: Text(tr('Tidak ada laporan masuk.')));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
              itemCount: data.length,
              itemBuilder: (_, i) {
                final r = data[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['judul_post'] ?? 'Postingan',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            'Dilaporkan oleh ${r['nama_pemilik'] ?? 'Pengguna'} - ${fmtTanggal(r['created_at'])}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        if ((r['alasan'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('"${r['alasan']}"'),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _abaikan(r),
                              child: Text(tr('Abaikan')),
                            ),
                            TextButton(
                              onPressed: () => _buka(r),
                              child: Text(tr('Buka')),
                            ),
                            FilledButton(
                              onPressed: () => _turunkan(r),
                              child: Text(tr('Turunkan')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class LayarAkun extends StatelessWidget {
  final Map<String, dynamic> profil;
  final Future<void> Function()? onProfilDiubah;
  const LayarAkun({super.key, required this.profil, this.onProfilDiubah});

  ImageProvider? _foto() {
    final f = profil['foto_url'] as String?;
    if (f != null && f.isNotEmpty) return NetworkImage(f);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final foto = profil['foto_url'] as String?;
    final admin = profil['peran'] == 'admin';
    final email = sb.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(tr('Akun'))),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final berubah = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) =>
                                LayarProfil(profilAwal: profil)));
                    if (berubah == true) await onProfilDiubah?.call();
                  },
                  child: CircleAvatar(
                    radius: 34,
                    backgroundImage: _foto(),
                    child: (foto == null || foto.isEmpty)
                        ? const Icon(Icons.person, size: 34)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profil['nama'] ?? '',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('+${profil['wa']}',
                          style: const TextStyle(color: Colors.grey)),
                      Text(admin ? 'Admin KutemuKan' : 'Pengguna KutemuKan',
                          style: const TextStyle(color: Colors.grey)),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      BarisBadge(
                          userId: (profil['id'] ?? '').toString()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(tr('Edit Profil')),
            subtitle: Text(tr('Nama, nomor WhatsApp, dan foto profil')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final berubah = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                      builder: (_) => LayarProfil(profilAwal: profil)));
              if (berubah == true) await onProfilDiubah?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(tr('Ubah Kata Sandi')),
            subtitle:
                Text(tr('Berlaku juga untuk akun yang masuk via Google')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LayarUbahSandi())),
          ),
          ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: Text(tr('Kritik & Saran')),
            subtitle: Text(tr('Beri bintang dan tulis ulasanmu')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LayarKritikSaran())),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text(tr('Papan Pahlawan')),
            subtitle: Text(tr('Peringkat penolong kampus bulan ini')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LayarPahlawan())),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text(tr('Cek Pembaruan')),
            subtitle: Text(tr('Periksa versi aplikasi terbaru')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => cekUpdate(context, manual: true),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(tr('Tampilan')),
            subtitle: Text(tr('Ikuti sistem, terang, atau gelap')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final sekarang = kTemaMode.value == ThemeMode.dark
                  ? 'gelap'
                  : kTemaMode.value == ThemeMode.light
                      ? 'terang'
                      : 'sistem';
              final pilih = await showDialog<String>(
                context: context,
                builder: (_) => SimpleDialog(
                  title: Text(tr('Tampilan')),
                  children: [
                    for (final o in ['sistem', 'terang', 'gelap'])
                      RadioListTile<String>(
                        value: o,
                        groupValue: sekarang,
                        title: Text(tr(o == 'sistem'
                            ? 'Sistem'
                            : o == 'terang'
                                ? 'Terang'
                                : 'Gelap')),
                        onChanged: (v) =>
                            Navigator.of(context).pop(v),
                      ),
                  ],
                ),
              );
              if (pilih != null) await aturTema(pilih);
            },
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(tr('Bahasa')),
            subtitle: Text(tr('Indonesia atau English')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final pilih = await showDialog<String>(
                context: context,
                builder: (_) => SimpleDialog(
                  title: const Text('Bahasa / Language'),
                  children: [
                    RadioListTile<String>(
                      value: 'id',
                      groupValue: kBahasa.value,
                      title: const Text('Bahasa Indonesia'),
                      onChanged: (v) => Navigator.of(context).pop(v),
                    ),
                    RadioListTile<String>(
                      value: 'en',
                      groupValue: kBahasa.value,
                      title: const Text('English'),
                      onChanged: (v) => Navigator.of(context).pop(v),
                    ),
                  ],
                ),
              );
              if (pilih != null) await aturBahasa(pilih);
            },
          ),
          if (admin) ...[
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: Text(tr('Statistik')),
              subtitle:
                  Text(tr('Pengguna, keberhasilan, dan aktivitas klaim')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LayarStatistik())),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(tr('Moderasi Postingan')),
              subtitle:
                  Text(tr('Setujui atau tolak postingan yang menunggu')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LayarModerasi())),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(tr('Laporan Pengguna')),
              subtitle:
                  Text(tr('Postingan yang dilaporkan bermasalah')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LayarLaporan())),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(tr('Info Aplikasi')),
            subtitle: Text(tr('Tentang KutemuKan dan pembuatnya')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LayarInfo())),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await sb.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const Gerbang()),
                      (_) => false);
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(tr('Keluar')),
            ),
          ),
        ],
      ),
    );
  }
}

class LayarUbahSandi extends StatefulWidget {
  const LayarUbahSandi({super.key});
  @override
  State<LayarUbahSandi> createState() => _LayarUbahSandiState();
}

class _LayarUbahSandiState extends State<LayarUbahSandi> {
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool _sibuk = false;

  Future<void> _simpan() async {
    final b = _baru.text;
    if (b.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Kata sandi minimal 6 karakter.'))));
      return;
    }
    if (b != _ulang.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Konfirmasi kata sandi tidak sama.'))));
      return;
    }
    setState(() => _sibuk = true);
    try {
      await sb.auth.updateUser(UserAttributes(password: b));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(
                'Kata sandi terpasang. Sekarang kamu juga bisa masuk memakai email dan sandi ini.'))));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('Gagal mengubah sandi')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    final email = sb.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ubah Kata Sandi'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(kBahasa.value == 'en'
                ? 'Account: $email\n\nOnce a password is set, you can sign in two ways: the Google button, or the email and password form. Both lead to the same account.'
                : 'Akun: $email\n\nSesudah sandi terpasang, kamu bisa masuk dengan dua cara: tombol Google, atau formulir email dan sandi. Keduanya masuk ke akun yang sama.'),
            const SizedBox(height: 20),
            TextField(
              controller: _baru,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: tr('Kata sandi baru'),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ulang,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: tr('Ulangi kata sandi baru'),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _sibuk ? null : _simpan,
              child: Text(_sibuk ? 'Menyimpan...' : 'Simpan Kata Sandi'),
            ),
          ],
        ),
      ),
    );
  }
}

class LayarStatistik extends StatelessWidget {
  const LayarStatistik({super.key});

  Future<Map<String, dynamic>> _hitung() async {
    final posts = List<Map<String, dynamic>>.from(await sb
        .from('lf_posts')
        .select('user_id, jenis, status, up_count, views_count'));
    final users = List<Map<String, dynamic>>.from(
        await sb.from('lf_profiles').select('id, nama'));
    final klaim = List<Map<String, dynamic>>.from(
        await sb.from('lf_claims').select('user_id, status'));
    final ulasan = List<Map<String, dynamic>>.from(await sb
        .from('lf_feedback')
        .select('user_id, bintang, isi, created_at')
        .order('created_at', ascending: false)
        .limit(30));
    return {
      'posts': posts,
      'users': users,
      'klaim': klaim,
      'ulasan': ulasan
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Statistik'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _hitung(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${tr('Gagal memuat')}: ${snap.error}'));
          }
          final posts = snap.data!['posts'] as List<Map<String, dynamic>>;
          final users = snap.data!['users'] as List<Map<String, dynamic>>;
          final klaim = snap.data!['klaim'] as List<Map<String, dynamic>>;
          final ulasan = snap.data!['ulasan'] as List<Map<String, dynamic>>;
          final totalUp = posts.fold<int>(
              0, (a, p) => a + ((p['up_count'] as num?)?.toInt() ?? 0));
          final totalDilihat = posts.fold<int>(
              0, (a, p) => a + ((p['views_count'] as num?)?.toInt() ?? 0));
          final rataBintang = ulasan.isEmpty
              ? 0.0
              : ulasan.fold<int>(
                      0, (a, u) => a + ((u['bintang'] as num?)?.toInt() ?? 0)) /
                  ulasan.length;

          int hitungPost(bool Function(Map<String, dynamic>) f) =>
              posts.where(f).length;
          final tampil = hitungPost((p) => p['status'] == 'tampil');
          final menunggu = hitungPost((p) => p['status'] == 'menunggu');
          final kembali = hitungPost((p) => p['status'] == 'kembali');
          final hilangAktif = hitungPost(
              (p) => p['status'] == 'tampil' && p['jenis'] == 'hilang');
          final temuanAktif = hitungPost(
              (p) => p['status'] == 'tampil' && p['jenis'] == 'temuan');
          final diproses = posts.length - menunggu;
          final persen = diproses == 0
              ? 0
              : (kembali * 100 / diproses).round();

          final namaUser = <String, String>{
            for (final u in users) (u['id'] ?? ''): (u['nama'] ?? '-')
          };
          final perUser = <String, Map<String, int>>{};
          for (final p in posts) {
            final id = (p['user_id'] ?? '').toString();
            final m = perUser.putIfAbsent(
                id, () => {'posting': 0, 'kembali': 0, 'klaim_ok': 0, 'klaim_no': 0});
            m['posting'] = m['posting']! + 1;
            if (p['status'] == 'kembali') m['kembali'] = m['kembali']! + 1;
          }
          for (final k in klaim) {
            final id = (k['user_id'] ?? '').toString();
            final m = perUser.putIfAbsent(
                id, () => {'posting': 0, 'kembali': 0, 'klaim_ok': 0, 'klaim_no': 0});
            if (k['status'] == 'disetujui') {
              m['klaim_ok'] = m['klaim_ok']! + 1;
            } else if (k['status'] == 'ditolak') {
              m['klaim_no'] = m['klaim_no']! + 1;
            }
          }
          final peringkat = perUser.entries.toList()
            ..sort((a, b) => (b.value['kembali']! + b.value['klaim_ok']!)
                .compareTo(a.value['kembali']! + a.value['klaim_ok']!));

          Widget kartu(String angka, String label, IconData ikon) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Icon(ikon, color: kTeal),
                    const SizedBox(height: 6),
                    Text(angka,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(tr(label),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: kTeal,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text('$persen%',
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text(tr('Tingkat Keberhasilan'),
                          style: TextStyle(color: Colors.white70)),
                      Text(
                          kBahasa.value == 'en'
                              ? '$kembali of $diproses fully processed posts ended up back with their owners'
                              : '$kembali dari $diproses postingan yang selesai diproses berakhir kembali ke pemiliknya',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  kartu('${users.length}', 'Pengguna', Icons.people_outline),
                  kartu('$tampil', 'Tampil di Papan', Icons.dashboard_outlined),
                  kartu('$menunggu', 'Menunggu Moderasi', Icons.hourglass_empty),
                  kartu('$kembali', 'Sudah Kembali', Icons.verified_outlined),
                  kartu('$hilangAktif', 'Hilang Aktif', Icons.search_off),
                  kartu('$temuanAktif', 'Temuan Aktif', Icons.find_in_page_outlined),
                  kartu('$totalUp', 'Total Bantu UP', Icons.arrow_circle_up_outlined),
                  kartu('$totalDilihat', 'Total Dilihat', Icons.visibility_outlined),
                  kartu(rataBintang == 0 ? '-' : rataBintang.toStringAsFixed(1), 'Rata-rata Bintang', Icons.star_outline),
                ],
              ),
              const SizedBox(height: 16),
              Text(tr('Aktivitas Pengguna'),
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(tr('Diurutkan dari yang paling banyak menghasilkan pengembalian barang.'),
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              if (peringkat.isEmpty)
                Text(tr('Belum ada aktivitas.')),
              for (final e in peringkat)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                          (namaUser[e.key] ?? '?').isNotEmpty
                              ? (namaUser[e.key] ?? '?')[0].toUpperCase()
                              : '?'),
                    ),
                    title: Text(namaUser[e.key] ?? 'Pengguna'),
                    subtitle: Text(kBahasa.value == 'en'
                        ? '${e.value['posting']} posts - ${e.value['kembali']} returned - claims approved ${e.value['klaim_ok']} - claims rejected ${e.value['klaim_no']}'
                        : '${e.value['posting']} postingan - ${e.value['kembali']} kembali - klaim disetujui ${e.value['klaim_ok']} - klaim ditolak ${e.value['klaim_no']}'),
                  ),
                ),
              const SizedBox(height: 16),
              Text(tr('Kritik & Saran Terbaru'),
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (ulasan.isEmpty) Text(tr('Belum ada ulasan masuk.')),
              for (final u in ulasan)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(' ${u['bintang']}'),
                      ],
                    ),
                    title: Text(u['isi'] ?? ''),
                    subtitle: Text(
                        '${namaUser[(u['user_id'] ?? '').toString()] ?? 'Pengguna'} - ${fmtTanggal(u['created_at'])}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LayarNotif extends StatefulWidget {
  const LayarNotif({super.key});
  @override
  State<LayarNotif> createState() => _LayarNotifState();
}

class _LayarNotifState extends State<LayarNotif> {
  late Future<List<Map<String, dynamic>>> _fNotif;

  @override
  void initState() {
    super.initState();
    _fNotif = _ambil();
  }

  void _segarkanNotif() {
    _fNotif = _ambil();
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_notif')
        .select()
        .eq('user_id', sb.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  IconData _ikon(String jenis) {
    switch (jenis) {
      case 'cocok':
        return Icons.find_in_page;
      case 'disetujui':
      case 'klaim_disetujui':
        return Icons.check_circle_outline;
      case 'ditolak':
      case 'klaim_ditolak':
        return Icons.block_outlined;
      case 'moderasi':
        return Icons.shield_outlined;
      case 'dihubungi':
        return Icons.how_to_reg_outlined;
      case 'up':
        return Icons.arrow_circle_up_outlined;
      case 'komentar':
        return Icons.comment_outlined;
      case 'pantau':
        return Icons.notifications_active_outlined;
      case 'basi':
        return Icons.schedule_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _buka(Map<String, dynamic> n) async {
    await sb.from('lf_notif').update({'dibaca': true}).eq('id', n['id']);
    if (n['post_id'] != null && mounted) {
      final rows =
          await sb.from('lf_posts').select().eq('id', n['post_id']);
      if (rows.isNotEmpty) await pasangNama([rows.first]);
      if (rows.isNotEmpty && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LayarDetail(post: rows.first)));
      }
    }
    _segarkanNotif();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Notifikasi'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fNotif,
        builder: (context, snap) {
          if (snap.hasError && snap.data == null) {
            return Center(child: Text('${tr('Gagal memuat')}: ${snap.error}'));
          }
          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(child: Text(tr('Belum ada notifikasi.')));
          }
          return RefreshIndicator(
            onRefresh: () async {
              _segarkanNotif();
              await _fNotif;
            },
            child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
              itemCount: data.length,
              itemBuilder: (_, i) {
                final n = data[i];
                final belum = n['dibaca'] != true;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        belum ? kTeal.withOpacity(0.15) : Colors.grey.shade100,
                    child: Icon(_ikon(n['jenis'] ?? ''),
                        color: belum ? kTeal : Colors.grey),
                  ),
                  title: Text(n['judul'] ?? '',
                      style: TextStyle(
                          fontWeight:
                              belum ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(
                      '${n['isi'] ?? ''}\n${fmtTanggal(n['created_at'])}'),
                  isThreeLine: true,
                  onTap: () => _buka(n),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class LayarPrivasi extends StatelessWidget {
  const LayarPrivasi({super.key});
  @override
  Widget build(BuildContext context) {
    const isiId = '''
KutemuKan mengumpulkan data yang kamu berikan sendiri: nama, nomor WhatsApp, alamat email, foto profil, dan isi postingan (judul, deskripsi, lokasi, foto barang, serta ciri khusus rahasia yang hanya dipakai untuk mencocokkan klaim dan tidak ditampilkan ke publik).

Nomor WhatsApp tidak pernah ditampilkan terbuka di papan. Nomor hanya diteruskan sistem kepada pengguna yang klaimnya sudah disetujui oleh pemilik postingan, agar keduanya bisa mengatur pengembalian barang.

Data disimpan di Supabase (database dan autentikasi) dan foto disimpan di Cloudflare R2. Token perangkat disimpan untuk keperluan notifikasi push.

Kamu bisa meminta penghapusan akun dan datamu dengan menghubungi pengelola lewat email dandieoffice@gmail.com. Penghapusan akun menghapus profil dan postingan yang terkait.

KutemuKan adalah aplikasi komunitas independen untuk mahasiswa UNINDRA dan bukan aplikasi resmi Universitas Indraprasta PGRI.''';
    const isiEn = '''
KutemuKan collects the data you provide yourself: your name, WhatsApp number, email address, profile photo, and post contents (title, description, location, item photos, and secret characteristics that are used only to verify claims and are never shown publicly).

Your WhatsApp number is never displayed openly on the board. The system passes it only to a user whose claim has been approved by the post owner, so both sides can arrange the item's return.

Data is stored in Supabase (database and authentication) and photos are stored in Cloudflare R2. Device tokens are stored for push notifications.

You can request deletion of your account and data by contacting the maintainer at dandieoffice@gmail.com. Deleting an account removes the related profile and posts.

KutemuKan is an independent community app for UNINDRA students and is not an official app of Universitas Indraprasta PGRI.''';
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kebijakan Privasi'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(kBahasa.value == 'en' ? isiEn : isiId,
            style: const TextStyle(height: 1.55)),
      ),
    );
  }
}

class LayarInfo extends StatelessWidget {
  const LayarInfo({super.key});

  static const List<String> _langkah = [
    'Buat laporan kehilangan atau pengumuman temuan, lengkap dengan foto dan ciri khusus rahasia.',
    'Admin memeriksa postingan sebelum menampilkannya di papan.',
    'Sistem mencocokkan kategori dan mengabari lewat notifikasi dan push.',
    'Pemilik mengajukan klaim dengan menyebut ciri khususnya.',
    'Sesudah klaim disetujui, kedua pihak terhubung ke WhatsApp dan barang ditandai selesai saat sudah kembali.',
  ];

  Widget _tombolSosial(
      BuildContext context, String aset, String url, String nama) {
    final warna = Theme.of(context).iconTheme.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: () => launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication),
          icon: Image.asset(aset, width: 20, height: 20, color: warna),
        ),
        const SizedBox(height: 2),
        Text(nama, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Info Aplikasi'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/icon.png', height: 96),
                ),
                const SizedBox(height: 14),
                const Text('KutemuKan',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                Text(tr('Lost and Found Kampus Unindra'),
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Chip(
                  label: Text(tr('Versi 1.3.4'),
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 16),
                Text(
                  tr('Papan lost and found untuk civitas kampus Unindra. Laporkan barang hilang, umumkan barang temuan, dan terima kabar otomatis saat ada yang cocok. Setiap postingan melewati moderasi admin dan setiap klaim harus disetujui pemilik postingan, jadi nomor WhatsApp tidak pernah terbuka sembarangan.'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route_outlined, color: kTeal),
                      SizedBox(width: 8),
                      Text(tr('Cara Kerja'),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _langkah.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: kTeal,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tr(_langkah[i]))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: kTeal,
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 10),
                  const Text('Ahmad Dandi Subhani',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(tr('Pengembang KutemuKan'),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                  Text(tr('Mahasiswa Teknik Informatika, Universitas Indraprasta PGRI'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 12)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tombolSosial(context, 'assets/icons/instagram.png',
                          'https://instagram.com/dandisubhani_', 'Instagram'),
                      const SizedBox(width: 18),
                      _tombolSosial(context, 'assets/icons/whatsapp.png',
                          'https://wa.me/628563000126', 'WhatsApp'),
                      const SizedBox(width: 18),
                      _tombolSosial(context, 'assets/icons/github.png',
                          'https://github.com/dandienter', 'GitHub'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(tr('Kebijakan Privasi')),
            subtitle: Text(tr('Cara data kamu dikelola di KutemuKan')),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LayarPrivasi())),
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'KutemuKan adalah aplikasi komunitas independen dan bukan aplikasi resmi Universitas Indraprasta PGRI.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('© 2026 KutemuKan',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
