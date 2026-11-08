part of '../main.dart';

// ===========================================================================
// Pengumuman komunitas (Broadcast). Admin membuat dari panel Akun;
// semua pengguna membaca di sini dan menerima push lewat worker.
// ===========================================================================

class LayarPengumuman extends StatefulWidget {
  final bool admin;
  final bool sematkan;
  const LayarPengumuman({super.key, this.admin = false, this.sematkan = false});
  @override
  State<LayarPengumuman> createState() => _LayarPengumumanState();
}

class _LayarPengumumanState extends State<LayarPengumuman> {
  late Future<List<Map<String, dynamic>>> _fData;
  final Map<String, Map<String, int>> _reaksiHitung = {};
  final Map<String, Set<String>> _reaksiSaya = {};

  @override
  void initState() {
    super.initState();
    _fData = _ambil();
  }

  Future<List<Map<String, dynamic>>> _ambil() async {
    var q = sb.from('lf_pengumuman').select();
    if (!widget.admin) {
      q = q.eq('aktif', true);
    }
    final rows = await q.order('created_at', ascending: false);
    final data = List<Map<String, dynamic>>.from(rows);
    await _muatReaksi(data);
    return data;
  }

  /// Muat hitungan reaksi (SQL 23) untuk semua pengumuman yang tampil,
  /// sekaligus reaksi milik pengguna ini agar pilnya menyala.
  Future<void> _muatReaksi(List<Map<String, dynamic>> data) async {
    _reaksiHitung.clear();
    _reaksiSaya.clear();
    if (data.isEmpty) return;
    try {
      final ids = data.map((p) => p['id']).toList();
      final rows = await sb
          .from('lf_reaksi_pengumuman')
          .select('pengumuman_id, user_id, jenis')
          .inFilter('pengumuman_id', ids);
      final saya = sb.auth.currentUser?.id;
      for (final r in rows) {
        final pid = (r['pengumuman_id'] ?? '').toString();
        final jenis = (r['jenis'] ?? '').toString();
        if (pid.isEmpty || jenis.isEmpty) continue;
        final peta = _reaksiHitung.putIfAbsent(
          pid,
          () => {'bintang': 0, 'api': 0, 'suka': 0},
        );
        peta[jenis] = (peta[jenis] ?? 0) + 1;
        if (r['user_id'] == saya) {
          _reaksiSaya.putIfAbsent(pid, () => <String>{}).add(jenis);
        }
      }
    } catch (_) {
      // Tabel reaksi belum tersedia: kartu tetap tampil tanpa pil.
    }
  }

  Future<void> _ketukReaksi(Map<String, dynamic> p, String jenis) async {
    final pid = (p['id'] ?? '').toString();
    final uid = sb.auth.currentUser?.id;
    if (pid.isEmpty || uid == null) return;
    final saya = _reaksiSaya.putIfAbsent(pid, () => <String>{});
    final hitung = _reaksiHitung.putIfAbsent(
      pid,
      () => {'bintang': 0, 'api': 0, 'suka': 0},
    );
    final sudah = saya.contains(jenis);
    setState(() {
      if (sudah) {
        saya.remove(jenis);
        hitung[jenis] = ((hitung[jenis] ?? 1) - 1).clamp(0, 1 << 30);
      } else {
        saya.add(jenis);
        hitung[jenis] = (hitung[jenis] ?? 0) + 1;
      }
    });
    try {
      if (sudah) {
        await sb
            .from('lf_reaksi_pengumuman')
            .delete()
            .eq('pengumuman_id', pid)
            .eq('user_id', uid)
            .eq('jenis', jenis);
      } else {
        await sb.from('lf_reaksi_pengumuman').insert({
          'pengumuman_id': pid,
          'user_id': uid,
          'jenis': jenis,
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fData = _ambil());
    }
  }

  Widget _pilReaksi(Map<String, dynamic> p, String jenis) {
    final pid = (p['id'] ?? '').toString();
    final aktif = _reaksiSaya[pid]?.contains(jenis) ?? false;
    final jumlah = _reaksiHitung[pid]?[jenis] ?? 0;
    final (ikon, ikonAktif, warna) = switch (jenis) {
      'api' => (
        Icons.local_fire_department_outlined,
        Icons.local_fire_department,
        const Color(0xFFEA580C),
      ),
      'suka' => (
        Icons.thumb_up_outlined,
        Icons.thumb_up,
        kBiruUtama,
      ),
      _ => (Icons.star_outline, Icons.star, const Color(0xFFD97706)),
    };
    return InkWell(
      onTap: () => _ketukReaksi(p, jenis),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: aktif ? warna.withOpacity(0.13) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: aktif ? warna.withOpacity(0.45) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(aktif ? ikonAktif : ikon, size: 16, color: warna),
            const SizedBox(width: 5),
            Text(
              '$jumlah',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: aktif ? warna : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _form([Map<String, dynamic>? awal]) async {
    final judul = TextEditingController(text: awal?['judul'] ?? '');
    final isi = TextEditingController(text: awal?['isi'] ?? '');
    final kategori = TextEditingController(
      text: awal?['kategori'] ?? 'Umum',
    );
    bool aktif = awal?['aktif'] != false;
    final simpan = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(tr(awal == null ? 'Pengumuman Baru' : 'Ubah Pengumuman')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judul,
                  decoration: InputDecoration(
                    labelText: tr('Judul'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: isi,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: tr('Isi pengumuman'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kategori,
                  decoration: InputDecoration(
                    labelText: tr('Kategori'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  title: Text(tr('Aktif')),
                  value: aktif,
                  onChanged: (v) => setDlg(() => aktif = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Batal')),
            ),
            FilledButton(
              onPressed: () {
                if (judul.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: Text(tr('Simpan')),
            ),
          ],
        ),
      ),
    );
    if (simpan != true) return;
    final data = <String, dynamic>{
      'judul': judul.text.trim(),
      'isi': isi.text.trim(),
      'kategori': kategori.text.trim().isEmpty ? 'Umum' : kategori.text.trim(),
      'aktif': aktif,
    };
    if (awal == null) {
      data['admin_id'] = sb.auth.currentUser!.id;
      await sb.from('lf_pengumuman').insert(data);
    } else {
      await sb.from('lf_pengumuman').update(data).eq('id', awal['id']);
    }
    setState(() => _fData = _ambil());
  }

  Future<void> _hapus(Map<String, dynamic> p) async {
    await sb.from('lf_pengumuman').delete().eq('id', p['id']);
    setState(() => _fData = _ambil());
  }

  @override
  Widget build(BuildContext context) {
    final isi = FutureBuilder<List<Map<String, dynamic>>>(
        future: _fData,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(child: Text(tr('Belum ada pengumuman baru nih.')));
          }
          return ListView.builder(
            padding: EdgeInsets.only(top: widget.sematkan ? 6 : 0, bottom: 12),
            itemCount: data.length,
            itemBuilder: (_, i) {
              final p = data[i];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: widget.sematkan ? 4 : 5),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text((p['kategori'] ?? 'Umum').toString()),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmtTanggal(p['created_at']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          if (widget.admin && p['aktif'] == false)
                            Chip(
                              label: Text(tr('Nonaktif')),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (widget.admin)
                            PopupMenuButton<String>(
                              onSelected: (a) {
                                if (a == 'ubah') _form(p);
                                if (a == 'hapus') _hapus(p);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'ubah',
                                  child: Text(tr('Ubah')),
                                ),
                                PopupMenuItem(
                                  value: 'hapus',
                                  child: Text(tr('Hapus')),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (p['judul'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((p['isi'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text((p['isi'] ?? '').toString()),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _pilReaksi(p, 'bintang'),
                          const SizedBox(width: 8),
                          _pilReaksi(p, 'api'),
                          const SizedBox(width: 8),
                          _pilReaksi(p, 'suka'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    if (widget.sematkan) return isi;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pengumuman'))),
      floatingActionButton: widget.admin
          ? FloatingActionButton(
              onPressed: () => _form(),
              child: const Icon(Icons.add),
            )
          : null,
      body: isi,
    );
  }
}
