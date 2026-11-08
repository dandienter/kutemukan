part of '../main.dart';

// ===========================================================================
// Layar akun dan kepala profil (redesign v1.9.0)
// ===========================================================================

/// Kepala Akun gaya baru: kepala biru melengkung berisi avatar, nama,
/// dan lencana centang emas kecil saja bila terverifikasi SIKA (tanpa
/// tulisan apa pun). Mengetuk area profil membuka lembar Profil
/// Lengkap dari bawah. Di bawahnya melayang kartu statistik tiga
/// kolom: Postinganku, Klaim, Bantu UP.
class _KepalaAkun extends StatefulWidget {
  final Map<String, dynamic> profil;
  final Future<void> Function()? onProfilDiubah;
  const _KepalaAkun({required this.profil, this.onProfilDiubah});

  @override
  State<_KepalaAkun> createState() => _KepalaAkunState();
}

class _KepalaAkunState extends State<_KepalaAkun> {
  late Future<Map<String, dynamic>> _fStatSaya;

  @override
  void initState() {
    super.initState();
    _fStatSaya = _ambilStat();
  }

  Future<Map<String, dynamic>> _ambilStat() async {
    try {
      final id = (widget.profil['id'] ?? '').toString();
      if (id.isEmpty) return const {};
      final rows = await sb.from('lf_stat_pengguna').select().eq('user_id', id);
      if (rows.isEmpty) return const {};
      return Map<String, dynamic>.from(rows.first);
    } catch (_) {
      return const {};
    }
  }

  Future<void> _keEditProfil() async {
    final berubah = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LayarProfil(profilAwal: widget.profil)),
    );
    if (berubah == true) await widget.onProfilDiubah?.call();
  }

  Widget _barisLembar(IconData ikon, String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kBiruUtama.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(ikon, size: 19, color: kBiruUtama),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(
                  nilai,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _bukaLembarProfil() {
    final profil = widget.profil;
    final foto = profil['foto_url'] as String?;
    final email = sb.auth.currentUser?.email ?? '';
    final npm = (profil['npm'] ?? '').toString();
    final kelas = (profil['kelas'] ?? '').toString();
    final prodi = (profil['prodi'] ?? '').toString();
    final terverifikasi = profil['terverifikasi'] == true;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    tr('Profil Lengkap'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              Row(
                children: [
                  AvatarPengguna(nama: (profil['nama'] ?? '').toString(), foto: foto, radius: 24, onTap: (foto ?? '').isNotEmpty ? () => lihatFotoBesar(ctx, foto!) : null),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                (profil['nama'] ?? '').toString(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            LencanaEmas(terverifikasi: terverifikasi),
                          ],
                        ),
                        Text(
                          prodi.isEmpty ? tr('Mahasiswa') : '${tr('Mahasiswa')} · $prodi',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (npm.isNotEmpty)
                _barisLembar(
                  Icons.badge_outlined,
                  '${tr('NPM')} · ${tr('Kelas')}',
                  kelas.isEmpty ? npm : '$npm · $kelas',
                ),
              if (email.isNotEmpty) _barisLembar(Icons.mail_outline, 'Email', email),
              _barisLembar(
                Icons.shield_outlined,
                tr('Status Verifikasi'),
                terverifikasi ? tr('Terverifikasi SIKA UNINDRA') : tr('Belum terverifikasi'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _keEditProfil();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(tr('Edit Profil')),
                  style: FilledButton.styleFrom(
                    backgroundColor: kBiruUtama,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profil = widget.profil;
    final foto = profil['foto_url'] as String?;
    final prodi = (profil['prodi'] ?? '').toString();
    final email = sb.auth.currentUser?.email ?? '';
    final terverifikasi = profil['terverifikasi'] == true;
    final atas = MediaQuery.of(context).padding.top;
    final bisaKembali = Navigator.of(context).canPop();
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(18, atas + 14, 18, 58),
              decoration: const BoxDecoration(
                gradient: kGradasiKepala,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  if (bisaKembali) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 19),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: InkWell(
                      onTap: _bukaLembarProfil,
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: AvatarPengguna(
                              nama: (profil['nama'] ?? '').toString(),
                              foto: foto,
                              radius: 25,
                              onTap: (foto ?? '').isNotEmpty
                                  ? () => lihatFotoBesar(context, foto!)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        (profil['nama'] ?? '').toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    LencanaEmas(terverifikasi: terverifikasi),
                                  ],
                                ),
                                Text(
                                  prodi.isNotEmpty ? prodi : email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _keEditProfil,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_outlined, color: Colors.white, size: 19),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: -32,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _fStatSaya,
                  builder: (context, snap) {
                    final s = snap.data ?? const {};
                    int angka(String k) => (s[k] as num?)?.toInt() ?? 0;
                    Widget sel(String label, int nilai) => Expanded(
                      child: Column(
                        children: [
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: nilai),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => Text(
                              '$v',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                    return Row(
                      children: [
                        sel(tr('Postinganku'), angka('total_posting')),
                        sel(tr('Klaim'), angka('klaim_ok')),
                        sel(tr('Bantu UP'), angka('up_diberikan')),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
      ],
    );
  }
}

Widget _judulSeksi(String teks) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(18, 16, 16, 2),
    child: Text(
      teks.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade500,
        letterSpacing: 1.1,
      ),
    ),
  );
}

Widget _ikonMenu(IconData ikon, {Color warna = kBiruUtama}) {
  return Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: warna.withOpacity(0.11),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(ikon, size: 19, color: warna),
  );
}

Widget _grupMenu(List<Widget> isi) {
  return Card(
    margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
    child: Column(
      children: [
        for (var i = 0; i < isi.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 68, endIndent: 12),
          isi[i],
        ],
      ],
    ),
  );
}

/// Daftar klaim yang pernah diajukan pengguna ini, lengkap dengan
/// statusnya; mengetuk satu klaim membuka rincian postingannya.
class LayarKlaimku extends StatefulWidget {
  const LayarKlaimku({super.key});
  @override
  State<LayarKlaimku> createState() => _LayarKlaimkuState();
}

class _LayarKlaimkuState extends State<LayarKlaimku> {
  late Future<List<Map<String, dynamic>>> _fData = _ambil();

  Future<List<Map<String, dynamic>>> _ambil() async {
    final uid = sb.auth.currentUser!.id;
    final klaim = await sb
        .from('lf_claims')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    final data = List<Map<String, dynamic>>.from(klaim);
    if (data.isEmpty) return data;
    final ids = data.map((k) => k['post_id']).where((e) => e != null).toSet().toList();
    if (ids.isNotEmpty) {
      final posts = await sb
          .from('lf_posts')
          .select('id, judul, jenis, status')
          .inFilter('id', ids);
      final peta = {for (final p in posts) (p['id'] ?? '').toString(): p};
      for (final k in data) {
        final p = peta[(k['post_id'] ?? '').toString()];
        if (p != null) {
          k['judul_post'] = p['judul'];
          k['jenis_post'] = p['jenis'];
        }
      }
    }
    return data;
  }

  (String, Color) _statusKlaim(String s) {
    switch (s) {
      case 'disetujui':
        return (tr('Disetujui'), Colors.green);
      case 'ditolak':
        return (tr('Ditolak'), Colors.red);
      case 'selesai':
        return (tr('Selesai'), Colors.blueGrey);
      default:
        return (tr('Menunggu'), Colors.orange);
    }
  }

  Future<void> _buka(Map<String, dynamic> k) async {
    final rows = await sb.from('lf_posts').select().eq('id', k['post_id']);
    if (rows.isEmpty || !mounted) return;
    final post = Map<String, dynamic>.from(rows.first);
    await pasangNama([post]);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LayarDetail(post: post)),
    );
    setState(() => _fData = _ambil());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Klaimku'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fData,
        builder: (context, snap) {
          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  tr('Kamu belum pernah mengajukan klaim. Klaim muncul di sini sesudah kamu mengklaim barang dari papan.'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
onRefresh: () async {
              setState(() => _fData = _ambil());
              await _fData;
            },
child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: data.length,
            itemBuilder: (_, i) {
              final k = data[i];
              final (label, warna) = _statusKlaim((k['status'] ?? '').toString());
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(
                  leading: _ikonMenu(
                    (k['jenis_post'] ?? '').toString() == 'temuan'
                        ? Icons.inventory_2_outlined
                        : Icons.search,
                  ),
                  title: Text(
                    (k['judul_post'] ?? tr('Postingan')).toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(fmtTanggal(k['created_at'])),
                  trailing: Chip(
                    label: Text(label, style: TextStyle(fontSize: 11, color: warna, fontWeight: FontWeight.w700)),
                    backgroundColor: warna.withOpacity(0.12),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
                  onTap: () => _buka(k),
                ),
              );
            },
          )
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

  @override
  Widget build(BuildContext context) {
    final admin = profil['peran'] == 'admin';
    final terverifikasi = profil['terverifikasi'] == true;
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
onRefresh: () async {
          await onProfilDiubah?.call();
        },
child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          _KepalaAkun(profil: profil, onProfilDiubah: onProfilDiubah),
          _judulSeksi(tr('Aktivitas')),
          _grupMenu([
            ListTile(
              leading: _ikonMenu(Icons.grid_view_outlined),
              title: Text(tr('Postinganku')),
              subtitle: Text(tr('Lihat dan kelola semua postinganmu')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LayarProfilPublik(userId: (profil['id'] ?? '').toString()),
                ),
              ),
            ),
            ListTile(
              leading: _ikonMenu(Icons.how_to_reg_outlined),
              title: Text(tr('Klaimku')),
              subtitle: Text(tr('Klaim yang kamu ajukan dan terima')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LayarKlaimku()),
              ),
            ),
            ListTile(
              leading: _ikonMenu(Icons.visibility_outlined),
              title: Text(tr('Pantau Kategori')),
              subtitle: Text(tr('Kabar otomatis untuk kategori pilihan')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LayarPantau()),
              ),
            ),
            ListTile(
              leading: _ikonMenu(Icons.emoji_events_outlined),
              title: Text(tr('Papan Pahlawan')),
              subtitle: Text(tr('Peringkat penemu barang bulan ini')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LayarPahlawan()),
              ),
            ),
          ]),
          if (admin) ...[
            _judulSeksi(tr('Admin')),
            _grupMenu([
              ListTile(
                leading: _ikonMenu(Icons.shield_outlined),
                title: Text(tr('Moderasi Postingan')),
                subtitle: Text(tr('Setujui atau tolak postingan yang menunggu')),
                trailing: const Icon(Icons.chevron_right, size: 19),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LayarModerasi()),
                ),
              ),
              ListTile(
                leading: _ikonMenu(Icons.flag_outlined),
                title: Text(tr('Laporan Pengguna')),
                subtitle: Text(tr('Postingan yang dilaporkan bermasalah')),
                trailing: const Icon(Icons.chevron_right, size: 19),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LayarLaporan()),
                ),
              ),
              ListTile(
                leading: _ikonMenu(Icons.bar_chart_outlined),
                title: Text(tr('Statistik')),
                subtitle: Text(tr('Pengguna, keberhasilan, dan aktivitas klaim')),
                trailing: const Icon(Icons.chevron_right, size: 19),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LayarStatistik(admin: true)),
                ),
              ),
              ListTile(
                leading: _ikonMenu(Icons.campaign_outlined),
                title: Text(tr('Pengumuman')),
                subtitle: Text(tr('Buat dan kelola pengumuman komunitas')),
                trailing: const Icon(Icons.chevron_right, size: 19),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LayarPengumuman(admin: true)),
                ),
              ),
            ]),
          ],
          _judulSeksi(tr('Pengaturan')),
          _grupMenu([
            ListTile(
              leading: _ikonMenu(Icons.manage_accounts_outlined),
              title: Text(tr('Edit Profil')),
              subtitle: Text(tr('Nama, foto, dan data kampus')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () async {
                final berubah = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => LayarProfil(profilAwal: profil)),
                );
                if (berubah == true) await onProfilDiubah?.call();
              },
            ),
            ListTile(
              leading: _ikonMenu(Icons.school_outlined),
              title: Text(tr('Verifikasi Mahasiswa')),
              subtitle: Text(
                terverifikasi
                    ? 'NPM ${profil['npm']} · ${profil['prodi'] ?? ''}'
                    : tr('Hubungkan akun SIKA untuk badge terverifikasi'),
              ),
              trailing: terverifikasi
                  ? const LencanaEmas(terverifikasi: true, ukuran: 20)
                  : const Icon(Icons.chevron_right, size: 19),
              onTap: () async {
                final berubah = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => LayarVerifikasiSika(profil: profil)),
                );
                if (berubah == true) await onProfilDiubah?.call();
              },
            ),
            ListTile(
              leading: _ikonMenu(Icons.lock_outline),
              title: Text(tr('Ubah Kata Sandi')),
              subtitle: Text(tr('Berlaku juga untuk akun yang masuk via Google')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LayarUbahSandi()),
              ),
            ),
            ListTile(
              leading: _ikonMenu(Icons.brightness_6_outlined),
              title: Text(tr('Tampilan')),
              subtitle: Text(tr('Ikuti sistem, terang, atau gelap')),
              trailing: const Icon(Icons.chevron_right, size: 19),
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
                          title: Text(tr(o == 'sistem' ? 'Sistem' : o == 'terang' ? 'Terang' : 'Gelap')),
                          onChanged: (v) => Navigator.of(context).pop(v),
                        ),
                    ],
                  ),
                );
                if (pilih != null) await aturTema(pilih);
              },
            ),
            ListTile(
              leading: _ikonMenu(Icons.language_outlined),
              title: Text(tr('Bahasa')),
              subtitle: Text(tr('Indonesia atau English')),
              trailing: const Icon(Icons.chevron_right, size: 19),
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
            ListTile(
              leading: _ikonMenu(Icons.menu_book_outlined),
              title: Text(tr('Panduan Lengkap')),
              subtitle: Text(tr('Cara pakai KutemuKan langkah demi langkah')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(tr('Panduan'))),
                    body: const TabPanduan(),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: _ikonMenu(Icons.download_outlined),
              title: Text(tr('Unduh Data Saya')),
              subtitle: Text(tr('Profil, postingan, klaim, dan notifikasi dalam satu berkas')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => unduhDataSaya(context, profil),
            ),
            ListTile(
              leading: _ikonMenu(Icons.rate_review_outlined),
              title: Text(tr('Kritik & Saran')),
              subtitle: Text(tr('Beri bintang dan tulis ulasanmu')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LayarKritikSaran()),
              ),
            ),
            ListTile(
              leading: _ikonMenu(Icons.system_update_outlined),
              title: Text(tr('Cek Pembaruan')),
              subtitle: Text(tr('Periksa versi aplikasi terbaru')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => cekUpdate(context, manual: true),
            ),
            ListTile(
              leading: _ikonMenu(Icons.info_outline),
              title: Text(tr('Tentang KutemuKan')),
              subtitle: Text(tr('Info aplikasi dan pembuatnya')),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LayarInfo()),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _grupMenu([
            ListTile(
              leading: _ikonMenu(Icons.delete_forever_outlined, warna: Colors.red),
              title: Text(tr('Hapus Akun Saya'), style: const TextStyle(color: Colors.red)),
              subtitle: Text(tr('Hapus permanen akun dan semua datamu')),
              onTap: () => mintaHapusAkun(context),
            ),
            ListTile(
              leading: _ikonMenu(Icons.logout, warna: Colors.red),
              title: Text(tr('Keluar'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              onTap: () async {
                await sb.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const Gerbang()),
                    (_) => false,
                  );
                }
              },
            ),
          ]),
          const SizedBox(height: 10),
        ],
      )
),
          // Perisai status bar: potongan gradasi kepala yang diam di
          // lapisan depan agar isi yang digulir tidak tembus terlihat
          // di area jam/status bar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top,
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: kGradasiKepala),
            ),
          ),
        ],
      ),
    );
  }
}

/// Unduh semua data milik pengguna (profil, postingan, klaim,
/// notifikasi). Pengguna memilih format berkas dulu (JSON, TXT, atau
/// PDF), lalu memilih sendiri tempat menyimpannya lewat dialog simpan
/// sistem. Bila dialog simpan tidak tersedia, berkas dibagikan ke
/// aplikasi lain sebagai cadangan.
Future<void> unduhDataSaya(
  BuildContext context,
  Map<String, dynamic> profil,
) async {
  final id = sb.auth.currentUser?.id;
  if (id == null) return;
  final format = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(tr('Pilih Format Berkas')),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop('json'),
          child: ListTile(
            leading: const Icon(Icons.data_object, color: kBiru),
            title: const Text('JSON'),
            subtitle: Text(tr('Data lengkap mentah, cocok untuk dipindahkan.')),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop('txt'),
          child: ListTile(
            leading: const Icon(Icons.article_outlined, color: kBiru),
            title: const Text('TXT'),
            subtitle: Text(tr('Teks ringkas yang enak dibaca.')),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop('pdf'),
          child: ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined, color: kBiru),
            title: const Text('PDF'),
            subtitle: Text(tr('Dokumen rapi siap dicetak atau diarsipkan.')),
          ),
        ),
      ],
    ),
  );
  if (format == null) return;
  try {
    final postingan = await sb
        .from('lf_posts')
        .select()
        .eq('user_id', id)
        .order('created_at', ascending: false)
        .limit(500);
    final klaim = await sb
        .from('lf_claims')
        .select()
        .eq('user_id', id)
        .order('created_at', ascending: false)
        .limit(500);
    final notif = await sb
        .from('lf_notif')
        .select()
        .eq('user_id', id)
        .order('created_at', ascending: false)
        .limit(500);
    final data = <String, dynamic>{
      'aplikasi': 'KutemuKan',
      'diunduh_pada': DateTime.now().toUtc().toIso8601String(),
      'profil': profil,
      'postingan': postingan,
      'klaim': klaim,
      'notifikasi': notif,
    };
    final Uint8List isi;
    if (format == 'txt') {
      isi = Uint8List.fromList(utf8.encode(_dataKeTeks(data)));
    } else if (format == 'pdf') {
      isi = await _dataKePdf(data);
    } else {
      isi = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
      );
    }
    final now = DateTime.now();
    final tgl =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final namaBerkas = 'kutemukan-data-$tgl.$format';
    String? tersimpan;
    try {
      tersimpan = await FilePicker.platform.saveFile(
        fileName: namaBerkas,
        bytes: isi,
      );
    } catch (_) {
      tersimpan = null;
    }
    if (!context.mounted) return;
    if (tersimpan != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('Data tersimpan')}: $namaBerkas')),
      );
      return;
    }
    // Cadangan: bagikan berkas ke aplikasi lain.
    final dir = await getTemporaryDirectory();
    final berkas = File('${dir.path}/$namaBerkas');
    await berkas.writeAsBytes(isi);
    await Share.shareXFiles([XFile(berkas.path)], subject: 'Data KutemuKan saya');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('Gagal menyiapkan data')}: $e')),
      );
    }
  }
}

/// Susun data unduhan menjadi teks yang enak dibaca manusia.
String _dataKeTeks(Map<String, dynamic> data) {
  final b = StringBuffer();
  b.writeln('DATA SAYA DI KUTEMUKAN');
  b.writeln('Diunduh pada: ${data['diunduh_pada']}');
  b.writeln('');
  final profil = Map<String, dynamic>.from(data['profil'] as Map);
  b.writeln('PROFIL');
  for (final k in [
    'nama',
    'nama_tampilan',
    'npm',
    'prodi',
    'fakultas',
    'kelas',
    'wa',
    'peran',
  ]) {
    final v = (profil[k] ?? '').toString();
    if (v.isNotEmpty) b.writeln('$k: $v');
  }
  b.writeln('');
  void daftar(String judul, String kunci, List<String> kolom) {
    final rows = List<Map<String, dynamic>>.from(data[kunci] as List);
    b.writeln('$judul (${rows.length})');
    for (final r in rows) {
      final isi = kolom
          .map((k) => (r[k] ?? '').toString())
          .where((v) => v.isNotEmpty)
          .join(' | ');
      b.writeln('- $isi');
    }
    b.writeln('');
  }

  daftar('POSTINGAN', 'postingan', ['jenis', 'judul', 'kategori', 'status', 'lokasi', 'created_at']);
  daftar('KLAIM', 'klaim', ['status', 'pesan', 'created_at']);
  daftar('NOTIFIKASI', 'notifikasi', ['judul', 'isi', 'created_at']);
  return b.toString();
}

/// Susun data unduhan menjadi PDF sederhana yang rapi.
Future<Uint8List> _dataKePdf(Map<String, dynamic> data) async {
  final doc = pw.Document();
  final profil = Map<String, dynamic>.from(data['profil'] as Map);
  pw.Widget bagian(String judul, List<List<String>> baris) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 14),
        pw.Text(
          judul,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (baris.isEmpty)
          pw.Text('Tidak ada data.', style: const pw.TextStyle(fontSize: 10))
        else
          pw.TableHelper.fromTextArray(
            headers: null,
            data: baris,
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.topLeft,
          ),
      ],
    );
  }

  List<List<String>> ambil(String kunci, List<String> kolom) {
    return [
      for (final r in List<Map<String, dynamic>>.from(data[kunci] as List))
        [for (final k in kolom) (r[k] ?? '').toString()],
    ];
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        pw.Text(
          'Data Saya di KutemuKan',
          style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Diunduh pada ${data['diunduh_pada']}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        bagian('Profil', [
          for (final k in ['nama', 'nama_tampilan', 'npm', 'prodi', 'fakultas', 'kelas', 'wa', 'peran'])
            if ((profil[k] ?? '').toString().isNotEmpty)
              [k, (profil[k]).toString()],
        ]),
        bagian('Postingan', ambil('postingan', ['jenis', 'judul', 'kategori', 'status', 'lokasi'])),
        bagian('Klaim', ambil('klaim', ['status', 'pesan', 'created_at'])),
        bagian('Notifikasi', ambil('notifikasi', ['judul', 'isi', 'created_at'])),
      ],
    ),
  );
  return doc.save();
}

/// Hapus akun mandiri: konfirmasi ketat (ketik HAPUS), permintaan
/// dicatat server, lalu pengguna dikeluarkan. Worker memproses
/// penghapusan permanen dalam beberapa menit.
Future<void> mintaHapusAkun(BuildContext context) async {
  final kontrol = TextEditingController();
  final jadi = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(tr('Hapus Akun Saya')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                'Akun, profil, postingan, klaim, chat, dan notifikasimu akan dihapus permanen dan tidak bisa dikembalikan. Ketik HAPUS untuk melanjutkan.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kontrol,
              onChanged: (_) => setLocal(() {}),
              decoration: InputDecoration(
                hintText: 'HAPUS',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: kontrol.text.trim() == 'HAPUS'
                ? () => Navigator.of(ctx).pop(true)
                : null,
            child: Text(tr('Hapus Permanen')),
          ),
        ],
      ),
    ),
  );
  if (jadi != true || !context.mounted) return;
  try {
    final ok = await sb.rpc('lf_minta_hapus_akun');
    if (ok != true) throw Exception('ditolak server');
    await sb.auth.signOut();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Permintaan diterima')),
          content: Text(
            tr(
              'Akunmu sedang diproses untuk dihapus permanen. Terima kasih sudah memakai KutemuKan.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Gerbang()),
          (_) => false,
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('Gagal meminta hapus akun')}: $e')),
      );
    }
  }
}
