part of '../main.dart';

// ===========================================================================
// Layar edit profil
// ===========================================================================

class LayarProfil extends StatefulWidget {
  final Map<String, dynamic>? profilAwal;
  const LayarProfil({super.key, this.profilAwal});
  @override
  State<LayarProfil> createState() => _LayarProfilState();
}

class _LayarProfilState extends State<LayarProfil> {
  final _nama = TextEditingController();
  final _namaTampilan = TextEditingController();
  final _wa = TextEditingController();
  bool _sibuk = false;
  bool _waAktif = true;
  bool _fotoDihapus = false;
  String? _fotoUrl;
  File? _fotoBaru;

  bool get _modeEdit => widget.profilAwal != null;

  @override
  void initState() {
    super.initState();
    final awal = widget.profilAwal;
    if (awal != null) {
      _nama.text = awal['nama'] ?? '';
      _namaTampilan.text = awal['nama_tampilan'] ?? '';
      _wa.text = awal['wa'] ?? '';
      _waAktif = awal['wa_aktif'] != false;
      _fotoUrl = awal['foto_url'] as String?;
    } else {
      final meta = sb.auth.currentUser?.userMetadata;
      final namaAwal = meta?['nama'] ?? meta?['full_name'] ?? meta?['name'];
      if (namaAwal is String && namaAwal.isNotEmpty) {
        _nama.text = namaAwal;
      }
    }
  }

  Future<void> _pilihFoto() async {
    final sumber = await pilihSumberFoto(context);
    if (sumber == null || !mounted) return;
    final x = await ImagePicker().pickImage(source: sumber, imageQuality: 85);
    if (x != null) {
      setState(() {
        _fotoBaru = File(x.path);
        _fotoDihapus = false;
      });
    }
  }

  Future<void> _hapusFoto() async {
    final jadi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Hapus Foto')),
        content: Text(
          tr('Foto profil akan dihapus dan diganti avatar inisial.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Hapus')),
          ),
        ],
      ),
    );
    if (jadi == true) {
      setState(() {
        _fotoBaru = null;
        _fotoDihapus = true;
      });
    }
  }

  ImageProvider? _fotoProfilTampil() {
    if (_fotoBaru != null) return FileImage(_fotoBaru!);
    if (_fotoDihapus) return null;
    if (_fotoUrl != null && _fotoUrl!.isNotEmpty) {
      return NetworkImage(_fotoUrl!);
    }
    return null;
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    var wa = _wa.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (nama.isEmpty || wa.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Isi nama dan nomor WhatsApp yang benar.'))),
      );
      return;
    }
    if (wa.startsWith('0')) wa = '62${wa.substring(1)}';
    setState(() => _sibuk = true);
    try {
      var fotoUrl = _fotoDihapus ? null : _fotoUrl;
      if (_fotoBaru != null) {
        fotoUrl = await unggahBerkas(await kompresKeWebp(_fotoBaru!));
      }
      final id = sb.auth.currentUser!.id;
      if (_modeEdit) {
        await sb
            .from('lf_profiles')
            .update({
              'nama': nama,
              'wa': wa,
              'foto_url': fotoUrl,
              'nama_tampilan': _namaTampilan.text.trim().isEmpty
                  ? null
                  : _namaTampilan.text.trim(),
              'wa_aktif': _waAktif,
            })
            .eq('id', id);
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          } else {
            // Dibuka Gerbang sebagai pelengkap profil (mis. akun SIKA
            // yang belum punya nomor WhatsApp), bukan rute yang ditumpuk.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const Gerbang()),
            );
          }
        }
      } else {
        await sb.from('lf_profiles').insert({
          'id': id,
          'nama': nama,
          'wa': wa,
          'foto_url': fotoUrl,
          'nama_tampilan': _namaTampilan.text.trim().isEmpty
              ? null
              : _namaTampilan.text.trim(),
          'wa_aktif': _waAktif,
        });
        if (mounted) {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => const Gerbang()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('Gagal menyimpan')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_modeEdit ? 'Edit Profil' : 'Lengkapi Profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pilihFoto,
              child: CircleAvatar(
                radius: 46,
                backgroundImage: _fotoProfilTampil(),
                child: _fotoProfilTampil() == null
                    ? const Icon(Icons.add_a_photo_outlined, size: 30)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('Ketuk untuk pasang foto profil'),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (_fotoProfilTampil() != null)
              TextButton.icon(
                onPressed: _hapusFoto,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                label: Text(
                  tr('Hapus Foto'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              tr(
                'Nomor WhatsApp hanya dipakai saat ada yang perlu menghubungi soal barang. Nomor tidak tampil terbuka di papan.',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nama,
              decoration: InputDecoration(
                labelText: tr('Nama lengkap'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _namaTampilan,
              decoration: InputDecoration(
                labelText: tr('Nama tampilan (opsional)'),
                helperText: tr(
                  'Dipakai di postingan dan profil publik. Kosongkan untuk memakai nama asli.',
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _wa,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('Nomor WhatsApp (08xx)'),
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Bagikan WhatsApp saat klaim disetujui')),
              subtitle: Text(
                tr(
                  'Bila mati, nomor WhatsApp-mu tidak dibuka ke siapa pun. Komunikasi berjalan lewat Chat di Aplikasi.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
              value: _waAktif,
              onChanged: (v) => setState(() => _waAktif = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sibuk ? null : _simpan,
                child: Text(
                  _sibuk
                      ? tr('Menyimpan...')
                      : (_modeEdit
                            ? tr('Simpan Perubahan')
                            : tr('Simpan dan Masuk')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ===========================================================================
// Profil publik pengguna lain: hanya data aman (tanpa WA, email, NPM).
// ===========================================================================

class LayarProfilPublik extends StatefulWidget {
  final String userId;
  const LayarProfilPublik({super.key, required this.userId});

  @override
  State<LayarProfilPublik> createState() => _LayarProfilPublikState();
}

class _LayarProfilPublikState extends State<LayarProfilPublik> {
  late Future<Map<String, dynamic>> _fProfil = _muat();

  Future<Map<String, dynamic>> _muat() async {
    final peta = await ambilProfilPublik([widget.userId]);
    final pub = peta[widget.userId] ?? <String, dynamic>{};
    var posts = <Map<String, dynamic>>[];
    try {
      final rows = await sb
          .from('lf_posts')
          .select(
            'id, jenis, judul, status, foto_url, foto_urls, kategori, lokasi, waktu_kejadian, created_at, deskripsi, penitipan, up_count, views_count, user_id, kembali_pada',
          )
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      posts = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}
    Map<String, dynamic> stat = {};
    try {
      final rows = await sb
          .from('lf_stat_pengguna')
          .select()
          .eq('user_id', widget.userId);
      if (rows.isNotEmpty) stat = Map<String, dynamic>.from(rows.first);
    } catch (_) {}
    return {'pub': pub, 'posts': posts, 'stat': stat};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Profil Pengguna'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fProfil,
        builder: (context, snap) {
          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final pub = snap.data!['pub'] as Map<String, dynamic>;
          final stat = snap.data!['stat'] as Map<String, dynamic>;
          final semuaPost =
              (snap.data!['posts'] as List).cast<Map<String, dynamic>>();
          final milikSaya = widget.userId == (sb.auth.currentUser?.id ?? '');
          final posts = milikSaya
              ? semuaPost
              : semuaPost
                    .where(
                      (x) =>
                          x['status'] == 'tampil' || x['status'] == 'kembali',
                    )
                    .toList();
          final totalPost = posts.length;
          final totalKembali =
              posts.where((x) => x['status'] == 'kembali').length;
          final tampilan = (pub['nama_tampilan'] ?? '').toString().trim();
          final nama = tampilan.isNotEmpty
              ? tampilan
              : (pub['nama'] ?? tr('Pengguna')).toString();
          final foto = (pub['foto_url'] ?? '').toString();
          final terverifikasi = pub['terverifikasi'] == true;
          final prodi = (pub['prodi'] ?? '').toString();
          final sejak = DateTime.tryParse((pub['created_at'] ?? '').toString());
          int angka(String k) => (stat[k] as num?)?.toInt() ?? 0;
          Widget sel(String label, int nilai) => Expanded(
            child: Column(
              children: [
                Text(
                  '$nilai',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: kBiru,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
          return RefreshIndicator(
onRefresh: () async {
              setState(() => _fProfil = _muat());
              await _fProfil;
            },
child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: AvatarPengguna(
                  nama: nama,
                  foto: foto,
                  radius: 44,
                  onTap: foto.isNotEmpty
                      ? () => lihatFotoBesar(context, foto)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      nama,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (terverifikasi) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 19, color: kBiru),
                  ],
                ],
              ),
              if (terverifikasi)
                Center(
                  child: Text(
                    tr('Mahasiswa Terverifikasi'),
                    style: const TextStyle(color: kBiru, fontSize: 13),
                  ),
                ),
              if (prodi.isNotEmpty)
                Center(
                  child: Text(
                    prodi,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              if (sejak != null)
                Center(
                  child: Text(
                    '${tr('Bergabung sejak')} ${fmtTanggal(sejak.toIso8601String())}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      sel(tr('Total Postingan'), totalPost),
                      sel(tr('Sudah Kembali'), totalKembali),
                      sel(tr('Klaim Disetujui'), angka('klaim_ok')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              BarisBadge(userId: widget.userId),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('Postingan'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      tr('Belum ada postingan.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
              for (final x in posts)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: daftarFoto(x).isEmpty
                          ? Container(
                              width: 48,
                              height: 48,
                              color: Colors.grey.shade200,
                              child: Icon(
                                x['jenis'] == 'hilang'
                                    ? Icons.search
                                    : Icons.inventory_2_outlined,
                                color: Colors.grey,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: daftarFoto(x).first,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                    title: Text(
                      (x['judul'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${x['kategori'] ?? ''} - ${x['lokasi'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: warnaStatus(
                          (x['status'] ?? '').toString(),
                        ).withOpacity(0.13),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        labelStatus((x['status'] ?? '').toString()),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: warnaStatus((x['status'] ?? '').toString()),
                        ),
                      ),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => LayarDetail(post: x)),
                    ),
                  ),
                ),
            ],
          )
);
        },
      ),
    );
  }
}
