part of '../main.dart';

// ===========================================================================
// Layar akun dan kepala profil
// ===========================================================================

class _KepalaAkun extends StatefulWidget {
  final Map<String, dynamic> profil;
  final Future<void> Function()? onProfilDiubah;
  const _KepalaAkun({required this.profil, this.onProfilDiubah});

  @override
  State<_KepalaAkun> createState() => _KepalaAkunState();
}

class _KepalaAkunState extends State<_KepalaAkun> {
  bool _terbuka = false;

  Widget _barisDetail(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(child: Text(nilai, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profil = widget.profil;
    final foto = profil['foto_url'] as String?;
    final admin = profil['peran'] == 'admin';
    final email = sb.auth.currentUser?.email ?? '';
    final npm = (profil['npm'] ?? '').toString();
    final prodi = (profil['prodi'] ?? '').toString();
    final wa = (profil['wa'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _terbuka = !_terbuka),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final berubah = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => LayarProfil(profilAwal: profil),
                      ),
                    );
                    if (berubah == true) await widget.onProfilDiubah?.call();
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: (foto != null && foto.isNotEmpty)
                        ? NetworkImage(foto)
                        : null,
                    child: (foto == null || foto.isEmpty)
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profil['nama'] ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (admin) ...[
                            const SizedBox(width: 6),
                            const Tooltip(
                              message: 'Admin KutemuKan',
                              child: Icon(
                                Icons.verified,
                                size: 18,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  _terbuka ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          if (_terbuka) ...[
            const SizedBox(height: 6),
            if (profil['terverifikasi'] == true) ...[
              Chip(
                avatar: const Icon(Icons.verified, size: 14, color: kBiru),
                label: Text(
                  tr('Mahasiswa Terverifikasi'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: kBiru,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(height: 6),
            ],
            if (npm.isNotEmpty) _barisDetail('NPM', npm),
            if (prodi.isNotEmpty) _barisDetail('Prodi', prodi),
            _barisDetail(
              'WhatsApp',
              wa.isEmpty ? tr('Nomor WhatsApp belum diisi') : '+$wa',
            ),
            if (email.isNotEmpty) _barisDetail('Email', email),
            const SizedBox(height: 8),
            BarisBadge(userId: (profil['id'] ?? '').toString()),
          ],
        ],
      ),
    );
  }
}

Widget _judulSeksi(String teks) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    child: Text(
      teks.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: kBiru,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class LayarAkun extends StatelessWidget {
  final Map<String, dynamic> profil;
  final Future<void> Function()? onProfilDiubah;
  const LayarAkun({super.key, required this.profil, this.onProfilDiubah});

  @override
  Widget build(BuildContext context) {
    final admin = profil['peran'] == 'admin';
    return Scaffold(
      appBar: AppBar(title: Text(tr('Akun'))),
      body: ListView(
        children: [
          _KepalaAkun(profil: profil, onProfilDiubah: onProfilDiubah),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(tr('Edit Profil')),
            subtitle: Text(tr('Nama, nomor WhatsApp, dan foto profil')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final berubah = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => LayarProfil(profilAwal: profil),
                ),
              );
              if (berubah == true) await onProfilDiubah?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(tr('Verifikasi Mahasiswa')),
            subtitle: Text(
              profil['terverifikasi'] == true
                  ? 'NPM ${profil['npm']} • ${profil['prodi'] ?? ''}'
                  : tr('Hubungkan akun SIKA untuk badge terverifikasi'),
            ),
            trailing: profil['terverifikasi'] == true
                ? const Icon(Icons.verified, color: kBiru)
                : const Icon(Icons.chevron_right),
            onTap: () async {
              final berubah = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => LayarVerifikasiSika(profil: profil),
                ),
              );
              if (berubah == true) await onProfilDiubah?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(tr('Ubah Kata Sandi')),
            subtitle: Text(tr('Berlaku juga untuk akun yang masuk via Google')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LayarUbahSandi())),
          ),
          _judulSeksi(tr('Pengaturan')),
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
                        title: Text(
                          tr(
                            o == 'sistem'
                                ? 'Sistem'
                                : o == 'terang'
                                ? 'Terang'
                                : 'Gelap',
                          ),
                        ),
                        onChanged: (v) => Navigator.of(context).pop(v),
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
            _judulSeksi(tr('Admin')),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(tr('Moderasi Postingan')),
              subtitle: Text(tr('Setujui atau tolak postingan yang menunggu')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LayarModerasi())),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(tr('Laporan Pengguna')),
              subtitle: Text(tr('Postingan yang dilaporkan bermasalah')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LayarLaporan())),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: Text(tr('Statistik')),
              subtitle: Text(tr('Pengguna, keberhasilan, dan aktivitas klaim')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LayarStatistik())),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text(tr('Pengumuman')),
              subtitle: Text(tr('Buat dan kelola pengumuman komunitas')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LayarPengumuman(admin: true),
                ),
              ),
            ),
          ],
          _judulSeksi(tr('Lainnya')),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text(tr('Papan Pahlawan')),
            subtitle: Text(tr('Peringkat penolong kampus bulan ini')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LayarPahlawan())),
          ),
          ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: Text(tr('Kritik & Saran')),
            subtitle: Text(tr('Beri bintang dan tulis ulasanmu')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LayarKritikSaran())),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text(tr('Cek Pembaruan')),
            subtitle: Text(tr('Periksa versi aplikasi terbaru')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => cekUpdate(context, manual: true),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(tr('Info Aplikasi')),
            subtitle: Text(tr('Tentang KutemuKan dan pembuatnya')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const LayarInfo())),
          ),
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: Text(tr('Panduan Interaktif')),
            subtitle: Text(tr('Tur keliling fitur ditemani maskot')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pop();
              Future<void>.delayed(
                const Duration(milliseconds: 350),
                () => pemicuPanduan?.call(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(tr('Unduh Data Saya')),
            subtitle: Text(tr('Profil, postingan, klaim, dan notifikasi dalam satu berkas')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unduhDataSaya(context, profil),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: Text(
              tr('Hapus Akun Saya'),
              style: const TextStyle(color: Colors.red),
            ),
            subtitle: Text(tr('Hapus permanen akun dan semua datamu')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => mintaHapusAkun(context),
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
                    (_) => false,
                  );
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

/// Unduh semua data milik pengguna (profil, postingan, klaim,
/// notifikasi) sebagai satu berkas JSON yang dibagikan ke aplikasi lain.
Future<void> unduhDataSaya(
  BuildContext context,
  Map<String, dynamic> profil,
) async {
  final id = sb.auth.currentUser?.id;
  if (id == null) return;
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
    final data = {
      'aplikasi': 'KutemuKan',
      'diunduh_pada': DateTime.now().toUtc().toIso8601String(),
      'profil': profil,
      'postingan': postingan,
      'klaim': klaim,
      'notifikasi': notif,
    };
    await Share.share(
      const JsonEncoder.withIndent('  ').convert(data),
      subject: 'Data KutemuKan saya',
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('Gagal menyiapkan data')}: $e')),
      );
    }
  }
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
