part of '../main.dart';

// ===========================================================================
// Manajemen Pengguna (admin): daftar pengguna, rincian, ubah peran,
// verifikasi, aktif/nonaktifkan akun, dan proses permintaan hapus akun.
// Semua aksi dijaga server oleh lf_is_admin() dan trigger identitas;
// layar ini hanya tampil untuk akun berperan admin.
// ===========================================================================

String _namaTampil(Map<String, dynamic> p) {
  final t = (p['nama_tampilan'] ?? '').toString().trim();
  if (t.isNotEmpty) return t;
  final n = (p['nama'] ?? '').toString().trim();
  return n.isEmpty ? tr('Pengguna') : n;
}

class LayarPenggunaAdmin extends StatefulWidget {
  const LayarPenggunaAdmin({super.key});
  @override
  State<LayarPenggunaAdmin> createState() => _LayarPenggunaAdminState();
}

class _LayarPenggunaAdminState extends State<LayarPenggunaAdmin> {
  late Future<List<Map<String, dynamic>>> _masaDepan;
  String _kata = '';
  String _saring = 'semua';

  @override
  void initState() {
    super.initState();
    _masaDepan = _ambil();
  }

  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_profiles')
        .select(
          'id, nama, nama_tampilan, foto_url, peran, terverifikasi, prodi, kelas, aktif, created_at',
        )
        .order('created_at');
    final data = List<Map<String, dynamic>>.from(rows);
    data.sort((a, b) {
      final admA = a['peran'] == 'admin' ? 0 : 1;
      final admB = b['peran'] == 'admin' ? 0 : 1;
      if (admA != admB) return admA - admB;
      return _namaTampil(a).toLowerCase().compareTo(_namaTampil(b).toLowerCase());
    });
    return data;
  }

  bool _lolos(Map<String, dynamic> p) {
    if (_saring == 'admin' && p['peran'] != 'admin') return false;
    if (_saring == 'pengguna' && p['peran'] == 'admin') return false;
    if (_saring == 'terverifikasi' && p['terverifikasi'] != true) return false;
    if (_saring == 'nonaktif' && p['aktif'] != false) return false;
    if (_kata.isEmpty) return true;
    final k = _kata.toLowerCase();
    return _namaTampil(p).toLowerCase().contains(k) ||
        (p['prodi'] ?? '').toString().toLowerCase().contains(k) ||
        (p['kelas'] ?? '').toString().toLowerCase().contains(k);
  }

  Widget _ringkasan(List<Map<String, dynamic>> semua) {
    final total = semua.length;
    final admin = semua.where((p) => p['peran'] == 'admin').length;
    final verif = semua.where((p) => p['terverifikasi'] == true).length;
    final nonaktif = semua.where((p) => p['aktif'] == false).length;
    Widget kartu(String angka, String label, {Color? warna}) {
      return Expanded(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              children: [
                Text(
                  angka,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: warna ?? kBiruUtama,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        kartu('$total', tr('Total Pengguna')),
        const SizedBox(width: 8),
        kartu('$admin', tr('Admin')),
        const SizedBox(width: 8),
        kartu('$verif', tr('Terverifikasi')),
        const SizedBox(width: 8),
        kartu(
          '$nonaktif',
          tr('Nonaktif'),
          warna: nonaktif > 0 ? Colors.red : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saring = <(String, String)>[
      ('semua', tr('Semua')),
      ('admin', tr('Admin')),
      ('pengguna', tr('Pengguna')),
      ('terverifikasi', tr('Terverifikasi')),
      ('nonaktif', tr('Nonaktif')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('Manajemen Pengguna'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _masaDepan,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('Gagal memuat daftar pengguna.')),
              ),
            );
          }
          final semua = snap.data ?? [];
          final tampil = semua.where(_lolos).toList();
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _masaDepan = _ambil());
              await _masaDepan;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: tr('Cari nama, prodi, atau kelas...'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _kata = v.trim()),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final (kunci, label) in saring)
                      ChoiceChip(
                        label: Text(label),
                        selected: _saring == kunci,
                        onSelected: (_) => setState(() => _saring = kunci),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _ringkasan(semua),
                const SizedBox(height: 8),
                if (tampil.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: Center(
                      child: Text(tr('Tidak ada pengguna yang cocok.')),
                    ),
                  ),
                for (final p in tampil)
                  Opacity(
                    opacity: p['aktif'] == false ? 0.55 : 1,
                    child: Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: ListTile(
                        leading: AvatarPengguna(
                          nama: _namaTampil(p),
                          foto: p['foto_url']?.toString(),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _namaTampil(p),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            LencanaEmas(
                              terverifikasi: p['terverifikasi'] == true,
                              ukuran: 15,
                            ),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if ((p['prodi'] ?? '').toString().isNotEmpty)
                              p['prodi'].toString(),
                            if ((p['kelas'] ?? '').toString().isNotEmpty)
                              p['kelas'].toString(),
                          ].join(' - '),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: p['peran'] == 'admin'
                                    ? kBiruUtama.withValues(alpha: 0.12)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p['peran'] == 'admin'
                                    ? tr('ADMIN')
                                    : tr('PENGGUNA'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: p['peran'] == 'admin'
                                      ? kBiruUtama
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p['aktif'] == false
                                  ? tr('Nonaktif')
                                  : tr('Aktif'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: p['aktif'] == false
                                    ? Colors.red
                                    : const Color(0xFF1E9E6A),
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LayarRincianPenggunaAdmin(profil: p),
                            ),
                          );
                          setState(() => _masaDepan = _ambil());
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class LayarRincianPenggunaAdmin extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarRincianPenggunaAdmin({super.key, required this.profil});
  @override
  State<LayarRincianPenggunaAdmin> createState() =>
      _LayarRincianPenggunaAdminState();
}

class _LayarRincianPenggunaAdminState
    extends State<LayarRincianPenggunaAdmin> {
  late Map<String, dynamic> _p;
  Map<String, dynamic>? _stat;
  Map<String, dynamic>? _permintaan;
  List<Map<String, dynamic>> _postingan = [];
  bool _memuat = true;
  bool _sibuk = false;

  bool get _saya => sb.auth.currentUser?.id == _p['id'];
  String get _nama => _namaTampil(_p);

  @override
  void initState() {
    super.initState();
    _p = Map<String, dynamic>.from(widget.profil);
    _muatDetail();
  }

  Future<void> _muatDetail() async {
    final id = _p['id'];
    try {
      final stat = await sb
          .from('lf_stat_pengguna')
          .select()
          .eq('user_id', id)
          .maybeSingle();
      final minta = await sb
          .from('lf_permintaan_hapus')
          .select()
          .eq('user_id', id)
          .isFilter('diproses_pada', null)
          .maybeSingle();
      final posts = await sb
          .from('lf_posts')
          .select()
          .eq('user_id', id)
          .order('created_at', ascending: false)
          .limit(20);
      if (!mounted) return;
      setState(() {
        _stat = stat;
        _permintaan = minta;
        _postingan = List<Map<String, dynamic>>.from(posts);
        _memuat = false;
      });
    } catch (_) {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<bool> _tanya(
    String judul,
    String isi,
    String tombol, {
    bool bahaya = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(judul),
        content: Text(isi),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            style: bahaya
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tombol),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _kabar(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _ubah(String kolom, dynamic nilai, String pesanOk) async {
    setState(() => _sibuk = true);
    try {
      await sb.from('lf_profiles').update({kolom: nilai}).eq('id', _p['id']);
      if (!mounted) return;
      setState(() {
        _p[kolom] = nilai;
        _sibuk = false;
      });
      _kabar(pesanOk);
    } catch (_) {
      if (mounted) setState(() => _sibuk = false);
      _kabar(tr('Gagal menyimpan perubahan.'));
    }
  }

  Future<void> _gantiVerifikasi() async {
    final jadi = _p['terverifikasi'] != true;
    final ok = await _tanya(
      jadi ? tr('Verifikasi akun ini?') : tr('Cabut verifikasi?'),
      jadi
          ? tr(
              'Akun {nama} akan mendapat centang emas terverifikasi di seluruh aplikasi.',
            ).replaceAll('{nama}', _nama)
          : tr(
              'Centang emas akun {nama} akan dicabut.',
            ).replaceAll('{nama}', _nama),
      jadi ? tr('Verifikasi') : tr('Cabut'),
    );
    if (ok) {
      await _ubah(
        'terverifikasi',
        jadi,
        jadi
            ? tr('Akun berhasil diverifikasi.')
            : tr('Verifikasi dicabut.'),
      );
    }
  }

  Future<void> _gantiPeran() async {
    final jadiAdmin = _p['peran'] != 'admin';
    final ok = await _tanya(
      jadiAdmin ? tr('Jadikan admin?') : tr('Turunkan jadi pengguna?'),
      jadiAdmin
          ? tr(
              '{nama} akan punya akses admin penuh: moderasi, statistik admin, dan manajemen pengguna.',
            ).replaceAll('{nama}', _nama)
          : tr(
              '{nama} kehilangan semua akses admin dan kembali menjadi pengguna biasa.',
            ).replaceAll('{nama}', _nama),
      jadiAdmin ? tr('Jadikan Admin') : tr('Turunkan'),
      bahaya: !jadiAdmin,
    );
    if (ok) {
      await _ubah(
        'peran',
        jadiAdmin ? 'admin' : 'user',
        jadiAdmin ? tr('Peran diubah jadi admin.') : tr('Peran diturunkan.'),
      );
    }
  }

  Future<void> _gantiAktif() async {
    final jadiAktif = _p['aktif'] == false;
    final ok = await _tanya(
      jadiAktif ? tr('Aktifkan lagi akun ini?') : tr('Nonaktifkan akun ini?'),
      jadiAktif
          ? tr(
              '{nama} bisa masuk dan memakai aplikasi lagi, dan postingannya tampil kembali.',
            ).replaceAll('{nama}', _nama)
          : tr(
              '{nama} tidak bisa masuk, posting, klaim, atau chat sampai diaktifkan lagi. Postingan yang sedang tampil ikut disembunyikan.',
            ).replaceAll('{nama}', _nama),
      jadiAktif ? tr('Aktifkan') : tr('Nonaktifkan'),
      bahaya: !jadiAktif,
    );
    if (ok) {
      await _ubah(
        'aktif',
        jadiAktif,
        jadiAktif ? tr('Akun diaktifkan lagi.') : tr('Akun dinonaktifkan.'),
      );
    }
  }

  Future<void> _tolakHapus() async {
    final ok = await _tanya(
      tr('Tolak permintaan hapus?'),
      tr(
        'Permintaan hapus akun {nama} dibuang. Akunnya tetap aktif seperti biasa.',
      ).replaceAll('{nama}', _nama),
      tr('Tolak Permintaan'),
    );
    if (!ok) return;
    setState(() => _sibuk = true);
    try {
      await sb.from('lf_permintaan_hapus').delete().eq('user_id', _p['id']);
      if (!mounted) return;
      setState(() {
        _permintaan = null;
        _sibuk = false;
      });
      _kabar(tr('Permintaan hapus ditolak.'));
    } catch (_) {
      if (mounted) setState(() => _sibuk = false);
      _kabar(tr('Gagal menyimpan perubahan.'));
    }
  }

  Future<void> _prosesHapus() async {
    final ok = await _tanya(
      tr('Proses hapus akun ini?'),
      tr(
        'Akun {nama} akan dinonaktifkan permanen dari sisi pengguna dan semua postingan yang masih tampil atau menunggu akan diarsipkan. Permintaan ditandai selesai.',
      ).replaceAll('{nama}', _nama),
      tr('Proses Hapus'),
      bahaya: true,
    );
    if (!ok) return;
    setState(() => _sibuk = true);
    try {
      await sb
          .from('lf_permintaan_hapus')
          .update({
            'diproses_pada': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', _p['id']);
      await sb
          .from('lf_profiles')
          .update({'aktif': false})
          .eq('id', _p['id']);
      await sb
          .from('lf_posts')
          .update({'status': 'arsip'})
          .eq('user_id', _p['id'])
          .inFilter('status', ['tampil', 'menunggu']);
      if (!mounted) return;
      setState(() {
        _permintaan = null;
        _p['aktif'] = false;
        _sibuk = false;
      });
      await _muatDetail();
      _kabar(tr('Permintaan hapus selesai diproses.'));
    } catch (_) {
      if (mounted) setState(() => _sibuk = false);
      _kabar(tr('Gagal menyimpan perubahan.'));
    }
  }

  String _labelStatus(String s) {
    switch (s) {
      case 'tampil':
        return tr('Sedang tampil');
      case 'menunggu':
        return tr('Menunggu moderasi');
      case 'kembali':
        return tr('Sudah kembali');
      case 'ditolak':
        return tr('Ditolak');
      case 'arsip':
        return tr('Arsip');
      case 'musnah_hibah':
        return tr('Musnah/Hibah');
      default:
        return s;
    }
  }

  Widget _tombolAksi({
    required IconData ikon,
    required String judul,
    required String sub,
    required VoidCallback? onTap,
    bool bahaya = false,
  }) {
    final skema = Theme.of(context).colorScheme;
    final warna = bahaya ? Colors.red : kBiruUtama;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(
            color: bahaya
                ? Colors.red.withValues(alpha: 0.45)
                : kBiruUtama.withValues(alpha: 0.35),
          ),
          borderRadius: BorderRadius.circular(14),
          color: skema.surface,
        ),
        child: Row(
          children: [
            Icon(ikon, size: 20, color: onTap == null ? null : warna),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: onTap == null ? null : warna,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10,
                      color: skema.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final stat = _stat ?? const {};
    final infoKampus = [
      if (( _p['prodi'] ?? '').toString().isNotEmpty) _p['prodi'].toString(),
      if ((_p['kelas'] ?? '').toString().isNotEmpty) _p['kelas'].toString(),
    ].join(' - ');
    return Scaffold(
      appBar: AppBar(title: Text(tr('Rincian Pengguna'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AvatarPengguna(
                    nama: _nama,
                    foto: _p['foto_url']?.toString(),
                    radius: 32,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _nama,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      LencanaEmas(
                        terverifikasi: _p['terverifikasi'] == true,
                        ukuran: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (infoKampus.isNotEmpty) infoKampus,
                      '${tr('Bergabung')} ${fmtTanggal(_p['created_at'])}',
                      _p['peran'] == 'admin' ? tr('Admin') : tr('Pengguna'),
                      if (_p['aktif'] == false) tr('Nonaktif'),
                    ].join(' - '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: skema.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      for (final (angka, label) in <(String, String)>[
                        ('${stat['total_posting'] ?? 0}', tr('Postingan')),
                        ('${stat['klaim_ok'] ?? 0}', tr('Klaim Berhasil')),
                        (
                          '${stat['temuan_kembali'] ?? 0}',
                          tr('Temuan Kembali'),
                        ),
                        ('${stat['up_diberikan'] ?? 0}', tr('Up Diberikan')),
                      ])
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                angka,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: skema.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _tombolAksi(
                  ikon: _p['terverifikasi'] == true
                      ? Icons.verified
                      : Icons.verified_outlined,
                  judul: _p['terverifikasi'] == true
                      ? tr('Terverifikasi')
                      : tr('Verifikasi'),
                  sub: _p['terverifikasi'] == true
                      ? tr('Centang emas aktif')
                      : tr('Beri centang emas'),
                  onTap: _sibuk ? null : _gantiVerifikasi,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _tombolAksi(
                  ikon: Icons.shield_outlined,
                  judul: _p['peran'] == 'admin'
                      ? tr('Admin')
                      : tr('Jadikan Admin'),
                  sub: _p['peran'] == 'admin'
                      ? tr('Turunkan peran')
                      : tr('Naikkan peran'),
                  onTap: (_sibuk || _saya) ? null : _gantiPeran,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _tombolAksi(
                  ikon: _p['aktif'] == false
                      ? Icons.lock_open_outlined
                      : Icons.block,
                  judul: _p['aktif'] == false
                      ? tr('Aktifkan')
                      : tr('Nonaktifkan'),
                  sub: _p['aktif'] == false
                      ? tr('Buka lagi akses akun')
                      : tr('Blokir akses akun'),
                  onTap: (_sibuk || _saya) ? null : _gantiAktif,
                  bahaya: _p['aktif'] != false,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(child: SizedBox()),
            ],
          ),
          if (_saya)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(
                  'Ini akun Anda sendiri. Peran dan status aktif tidak bisa diubah dari sini.',
                ),
                style: TextStyle(fontSize: 11, color: skema.onSurfaceVariant),
              ),
            ),
          if (_permintaan != null) ...[
            const SizedBox(height: 16),
            Text(
              tr('Permintaan Hapus Akun'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                border: Border.all(color: const Color(0xFFF2DFAE)),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Color(0xFFB98A1D),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr('Menunggu diproses'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8A6D1F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr(
                      'Pengguna meminta akunnya dihapus. Memproses akan menonaktifkan akun dan mengarsipkan postingan yang masih tampil.',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A7A4A),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _sibuk ? null : _tolakHapus,
                          child: Text(tr('Tolak')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: _sibuk ? null : _prosesHapus,
                          child: Text(tr('Proses Hapus')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            tr('Postingan Pengguna'),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          if (_memuat)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_postingan.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                tr('Belum ada postingan.'),
                style: TextStyle(color: skema.onSurfaceVariant),
              ),
            )
          else
            for (final post in _postingan)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    post['jenis'] == 'hilang'
                        ? Icons.search
                        : Icons.find_in_page_outlined,
                    color: kBiruUtama,
                  ),
                  title: Text(
                    (post['judul'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${post['jenis'] == 'hilang' ? tr('Hilang') : tr('Temuan')} - ${_labelStatus((post['status'] ?? '').toString())}',
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 17),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LayarDetail(post: post)),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Layar penahan untuk akun yang dinonaktifkan admin.
// ===========================================================================

class LayarAkunNonaktif extends StatelessWidget {
  const LayarAkunNonaktif({super.key});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block, size: 38, color: Colors.red),
              ),
              const SizedBox(height: 18),
              Text(
                tr('Akun Dinonaktifkan'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'Akun Anda dinonaktifkan oleh admin KutemuKan, jadi untuk sementara tidak bisa memakai aplikasi. Bila ini keliru, hubungi admin untuk mengaktifkannya lagi.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: skema.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () async {
                  await sb.auth.signOut();
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(tr('Keluar')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
