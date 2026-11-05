import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  runApp(const KutemuKanApp());
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

class KutemuKanApp extends StatelessWidget {
  const KutemuKanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KutemuKan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kTeal),
        useMaterial3: true,
      ),
      home: const Gerbang(),
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
  @override
  void initState() {
    super.initState();
    sb.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = sb.auth.currentUser;
    if (user == null) return const LayarLogin();
    return FutureBuilder<Map<String, dynamic>?>(
      future: _ambilProfil(user.id),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final profil = snap.data;
        if (profil == null) return const LayarProfil();
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
              const Icon(Icons.find_replace_rounded, size: 72, color: kTeal),
              const SizedBox(height: 12),
              const Text('KutemuKan',
                  style:
                      TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const Text('Lost and Found Kampus - Unindrabase',
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _sandi,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Kata sandi', border: OutlineInputBorder()),
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
                      ? 'Memproses...'
                      : (_modeDaftar ? 'Daftar' : 'Masuk')),
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _modeDaftar = !_modeDaftar),
                child: Text(_modeDaftar
                    ? 'Sudah punya akun? Masuk'
                    : 'Belum punya akun? Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LayarProfil extends StatefulWidget {
  const LayarProfil({super.key});
  @override
  State<LayarProfil> createState() => _LayarProfilState();
}

class _LayarProfilState extends State<LayarProfil> {
  final _nama = TextEditingController();
  final _wa = TextEditingController();
  bool _sibuk = false;

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    var wa = _wa.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (nama.isEmpty || wa.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Isi nama dan nomor WhatsApp yang benar.')));
      return;
    }
    if (wa.startsWith('0')) wa = '62${wa.substring(1)}';
    setState(() => _sibuk = true);
    await sb.from('lf_profiles').insert({
      'id': sb.auth.currentUser!.id,
      'nama': nama,
      'wa': wa,
    });
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Gerbang()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lengkapi Profil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
                'Nomor WhatsApp hanya dipakai saat ada yang perlu menghubungi soal barang. Nomor tidak tampil terbuka di papan.'),
            const SizedBox(height: 20),
            TextField(
              controller: _nama,
              decoration: const InputDecoration(
                  labelText: 'Nama lengkap', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _wa,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp (08xx)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sibuk ? null : _simpan,
                child: Text(_sibuk ? 'Menyimpan...' : 'Simpan dan Masuk'),
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

  @override
  Widget build(BuildContext context) {
    final admin = widget.profil['peran'] == 'admin';
    final halaman = <Widget>[
      const LayarBeranda(),
      LayarBuat(profil: widget.profil),
      LayarPostinganku(profil: widget.profil),
      const LayarNotif(),
      if (admin) const LayarModerasi(),
      LayarAkun(profil: widget.profil),
    ];
    final tujuan = <NavigationDestination>[
      const NavigationDestination(
          icon: Icon(Icons.home_outlined), label: 'Beranda'),
      const NavigationDestination(
          icon: Icon(Icons.add_circle_outline), label: 'Buat'),
      const NavigationDestination(
          icon: Icon(Icons.list_alt_outlined), label: 'Postinganku'),
      const NavigationDestination(
          icon: Icon(Icons.notifications_outlined), label: 'Notif'),
      if (admin)
        const NavigationDestination(
            icon: Icon(Icons.shield_outlined), label: 'Moderasi'),
      const NavigationDestination(
          icon: Icon(Icons.person_outline), label: 'Akun'),
    ];
    if (_tab >= halaman.length) _tab = 0;
    return Scaffold(
      body: halaman[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: tujuan,
      ),
    );
  }
}

String fmtTanggal(dynamic v) {
  if (v == null) return '-';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return '-';
  return DateFormat('d MMM yyyy, HH:mm', 'id').format(d.toLocal());
}

class KartuPostingan extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onTap;
  const KartuPostingan({super.key, required this.post, this.onTap});
  @override
  Widget build(BuildContext context) {
    final hilang = post['jenis'] == 'hilang';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: post['foto_url'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(post['foto_url'],
                    width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_not_supported_outlined)),
              )
            : CircleAvatar(
                backgroundColor:
                    hilang ? Colors.red.shade50 : Colors.green.shade50,
                child: Icon(
                    hilang ? Icons.search_off : Icons.find_in_page_outlined,
                    color: hilang ? Colors.red : Colors.green),
              ),
        title: Text(post['judul'] ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${post['kategori']} - ${post['lokasi']}\n${fmtTanggal(post['created_at'])}',
          maxLines: 2,
        ),
        trailing: Chip(
          label: Text(hilang ? 'HILANG' : 'TEMUAN',
              style: const TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: hilang ? Colors.red : Colors.green,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class LayarBeranda extends StatefulWidget {
  const LayarBeranda({super.key});
  @override
  State<LayarBeranda> createState() => _LayarBerandaState();
}

class _LayarBerandaState extends State<LayarBeranda> {
  String _jenis = 'semua';
  String _cari = '';

  Future<List<Map<String, dynamic>>> _ambil() async {
    var q = sb
        .from('lf_posts')
        .select('*, lf_profiles(nama)')
        .eq('status', 'tampil');
    if (_jenis != 'semua') q = q.eq('jenis', _jenis);
    if (_cari.isNotEmpty) q = q.ilike('judul', '%$_cari%');
    final rows = await q.order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KutemuKan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _cari = v.trim()),
              decoration: const InputDecoration(
                hintText: 'Cari barang...',
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
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(j == 'semua'
                          ? 'Semua'
                          : (j == 'hilang' ? 'Hilang' : 'Temuan')),
                      selected: _jenis == j,
                      onSelected: (_) => setState(() => _jenis = j),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _ambil(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Gagal memuat: ${snap.error}'));
                }
                final data = snap.data ?? [];
                if (data.isEmpty) {
                  return const Center(
                      child: Text('Belum ada postingan yang tampil.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (_, i) => KartuPostingan(
                      post: data[i],
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) =>
                                  LayarDetail(post: data[i])))
                          .then((_) => setState(() {})),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LayarDetail extends StatelessWidget {
  final Map<String, dynamic> post;
  const LayarDetail({super.key, required this.post});

  Future<void> _hubungi(BuildContext context) async {
    try {
      // Catat kontak sebagai klaim: memicu notif ke pemilik postingan
      try {
        await sb.from('lf_claims').insert({
          'post_id': post['id'],
          'user_id': sb.auth.currentUser!.id,
          'pesan': '',
        });
      } catch (_) {}
      final hasil =
          await sb.rpc('lf_kontak', params: {'p_post_id': post['id']});
      final wa = hasil?.toString() ?? '';
      if (wa.isEmpty) throw 'Nomor tidak tersedia';
      final teks = Uri.encodeComponent(
          'Halo, saya melihat postingan KutemuKan soal "${post['judul']}". ');
      await launchUrl(Uri.parse('https://wa.me/$wa?text=$teks'),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak bisa menghubungi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hilang = post['jenis'] == 'hilang';
    final namaPemilik =
        (post['lf_profiles'] as Map?)?['nama'] ?? 'Pengguna KutemuKan';
    return Scaffold(
      appBar: AppBar(title: Text(hilang ? 'Barang Hilang' : 'Barang Temuan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (post['foto_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(post['foto_url'],
                  height: 240, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      height: 120,
                      child: Center(
                          child: Icon(Icons.image_not_supported_outlined)))),
            ),
          const SizedBox(height: 16),
          Text(post['judul'] ?? '',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Kategori: ${post['kategori']}'),
          Text('Lokasi: ${post['lokasi']}'),
          Text('Waktu kejadian: ${fmtTanggal(post['waktu_kejadian'])}'),
          if (post['penitipan'] != null &&
              (post['penitipan'] as String).isNotEmpty)
            Text('Dititipkan di: ${post['penitipan']}'),
          Text('Dilaporkan oleh: $namaPemilik'),
          const SizedBox(height: 12),
          Text(post['deskripsi'] ?? ''),
          const SizedBox(height: 24),
          if (post['user_id'] != sb.auth.currentUser?.id &&
              post['status'] == 'tampil')
            FilledButton.icon(
              onPressed: () => _hubungi(context),
              icon: const Icon(Icons.chat),
              label: const Text('Hubungi via WhatsApp'),
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
  DateTime _waktu = DateTime.now();
  File? _foto;
  bool _sibuk = false;

  Future<void> _pilihFoto() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 78);
    if (x != null) setState(() => _foto = File(x.path));
  }

  Future<String?> _unggahFoto() async {
    if (_foto == null) return null;
    final req = http.MultipartRequest('POST', Uri.parse(kUploadUrl));
    req.headers['X-Upload-Key'] = kUploadKey;
    req.files.add(await http.MultipartFile.fromPath('foto', _foto!.path));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) throw 'Unggah foto gagal: $body';
    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['url'] as String?;
  }

  Future<void> _kirim() async {
    if (_judul.text.trim().isEmpty || _lokasi.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Judul dan lokasi wajib diisi.')));
      return;
    }
    setState(() => _sibuk = true);
    try {
      final fotoUrl = await _unggahFoto();
      await sb.from('lf_posts').insert({
        'user_id': sb.auth.currentUser!.id,
        'jenis': _jenis,
        'judul': _judul.text.trim(),
        'kategori': _kategori,
        'deskripsi': _deskripsi.text.trim(),
        'lokasi': _lokasi.text.trim(),
        'waktu_kejadian': _waktu.toUtc().toIso8601String(),
        'foto_url': fotoUrl,
        'penitipan': _jenis == 'temuan' ? _penitipan.text.trim() : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Postingan terkirim. Menunggu moderasi admin sebelum tampil.')));
        _judul.clear();
        _deskripsi.clear();
        _lokasi.clear();
        _penitipan.clear();
        setState(() => _foto = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal mengirim: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Postingan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'hilang', label: Text('Saya Kehilangan')),
              ButtonSegment(value: 'temuan', label: Text('Saya Menemukan')),
            ],
            selected: {_jenis},
            onSelectionChanged: (s) => setState(() => _jenis = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _judul,
            decoration: const InputDecoration(
                labelText: 'Judul (mis. Dompet hitam berisi KTM)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _kategori,
            items: kKategori
                .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                .toList(),
            onChanged: (v) => setState(() => _kategori = v!),
            decoration: const InputDecoration(
                labelText: 'Kategori', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lokasi,
            decoration: const InputDecoration(
                labelText: 'Lokasi (hilang / ditemukan)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Waktu kejadian'),
            subtitle: Text(fmtTanggal(_waktu.toIso8601String())),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final tgl = await showDatePicker(
                context: context,
                initialDate: _waktu,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (tgl != null && mounted) {
                setState(() => _waktu = DateTime(
                    tgl.year, tgl.month, tgl.day, _waktu.hour, _waktu.minute));
              }
            },
          ),
          if (_jenis == 'temuan')
            TextField(
              controller: _penitipan,
              decoration: const InputDecoration(
                  labelText: 'Barang dititipkan di (mis. pos satpam)',
                  border: OutlineInputBorder()),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _deskripsi,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Deskripsi dan ciri-ciri',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pilihFoto,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_foto == null ? 'Tambah Foto' : 'Ganti Foto'),
          ),
          if (_foto != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_foto!, height: 160, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sibuk ? null : _kirim,
            child: Text(_sibuk ? 'Mengirim...' : 'Kirim untuk Moderasi'),
          ),
        ],
      ),
    );
  }
}

class LayarPostinganku extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarPostinganku({super.key, required this.profil});
  @override
  State<LayarPostinganku> createState() => _LayarPostingankuState();
}

class _LayarPostingankuState extends State<LayarPostinganku> {
  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_posts')
        .select()
        .eq('user_id', sb.auth.currentUser!.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _aksi(Map<String, dynamic> post, String status) async {
    await sb.from('lf_posts').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', post['id']);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Postinganku')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambil(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('Belum ada postingan.'));
          }
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (_, i) {
              final p = data[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(p['judul'] ?? ''),
                  subtitle: Text('Status: ${p['status']}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'kembali') await _aksi(p, 'kembali');
                      if (v == 'hapus') {
                        await sb.from('lf_posts').delete().eq('id', p['id']);
                        setState(() {});
                      }
                    },
                    itemBuilder: (_) => [
                      if (p['status'] == 'tampil')
                        const PopupMenuItem(
                            value: 'kembali',
                            child: Text('Tandai sudah kembali')),
                      const PopupMenuItem(
                          value: 'hapus', child: Text('Hapus')),
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

class LayarModerasi extends StatefulWidget {
  const LayarModerasi({super.key});
  @override
  State<LayarModerasi> createState() => _LayarModerasiState();
}

class _LayarModerasiState extends State<LayarModerasi> {
  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_posts')
        .select('*, lf_profiles(nama)')
        .eq('status', 'menunggu')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
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
      appBar: AppBar(title: const Text('Moderasi')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambil(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return const Center(
                child: Text('Tidak ada postingan menunggu moderasi.'));
          }
          return ListView.builder(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _putuskan(p, 'ditolak'),
                            child: const Text('Tolak',
                                style: TextStyle(color: Colors.red)),
                          ),
                          FilledButton(
                            onPressed: () => _putuskan(p, 'tampil'),
                            child: const Text('Setujui dan Tampilkan'),
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

class LayarAkun extends StatelessWidget {
  final Map<String, dynamic> profil;
  const LayarAkun({super.key, required this.profil});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(profil['nama'] ?? ''),
            subtitle: Text(
                'WA: ${profil['wa']}\nPeran: ${profil['peran']}'),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Info Aplikasi'),
            subtitle: const Text('Tentang KutemuKan dan pembuatnya'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LayarInfo())),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await sb.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const Gerbang()),
                    (_) => false);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
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
        return Icons.check_circle_outline;
      case 'ditolak':
        return Icons.block_outlined;
      case 'moderasi':
        return Icons.shield_outlined;
      case 'dihubungi':
        return Icons.chat_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _buka(Map<String, dynamic> n) async {
    await sb
        .from('lf_notif')
        .update({'dibaca': true}).eq('id', n['id']);
    if (n['post_id'] != null && mounted) {
      final rows = await sb
          .from('lf_posts')
          .select('*, lf_profiles(nama)')
          .eq('id', n['post_id']);
      if (rows.isNotEmpty && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LayarDetail(post: rows.first)));
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambil(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Text(
                    'Notifikasi belum aktif di server: ${snap.error}'));
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('Belum ada notifikasi.'));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
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

class LayarInfo extends StatelessWidget {
  const LayarInfo({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(
            child: Column(
              children: [
                Icon(Icons.find_replace_rounded, size: 76, color: kTeal),
                SizedBox(height: 10),
                Text('KutemuKan',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                Text('Versi 1.0.1'),
                SizedBox(height: 14),
                Text(
                  'Papan lost and found kampus: laporkan barang hilang, umumkan barang temuan, dan biarkan sistem mengabari saat ada yang cocok. Setiap postingan melewati moderasi admin agar papan tetap bersih.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.people_outline),
            title: Text('Komunitas'),
            subtitle: Text('Unindrabase - Universitas Indraprasta PGRI'),
          ),
          const ListTile(
            leading: Icon(Icons.code_outlined),
            title: Text('Teknologi'),
            subtitle:
                Text('Flutter, Supabase (PostgreSQL dan Auth), Cloudflare R2'),
          ),
          const Divider(),
          const SizedBox(height: 6),
          const Center(
              child: Text('Dibuat oleh',
                  style: TextStyle(color: Colors.grey))),
          const Center(
            child: Text('Ahmad Dandi Subhani',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          const Center(
              child: Text('Teknik Informatika - UNINDRA',
                  style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                  Uri.parse('https://instagram.com/dandisubhani_'),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('@dandisubhani_'),
            ),
          ),
        ],
      ),
    );
  }
}
