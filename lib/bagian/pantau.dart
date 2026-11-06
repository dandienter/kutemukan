part of '../main.dart';

// ===========================================================================
// Layar pantau: kategori yang dipantau + watchlist barang yang dicari
// ===========================================================================

class LayarPantau extends StatefulWidget {
  const LayarPantau({super.key});
  @override
  State<LayarPantau> createState() => _LayarPantauState();
}

class _LayarPantauState extends State<LayarPantau> {
  Set<String> _aktif = {};
  List<Map<String, dynamic>> _watchlist = [];
  Map<String, int> _jumlahKandidat = {};
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _ambil();
  }

  Future<void> _ambil() async {
    final uid = sb.auth.currentUser!.id;
    final rows =
        await sb.from('lf_pantau').select('kategori').eq('user_id', uid);
    List<Map<String, dynamic>> wl = [];
    final hitung = <String, int>{};
    try {
      final wrows = await sb
          .from('lf_watchlist')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      wl = List<Map<String, dynamic>>.from(wrows);
      if (wl.isNotEmpty) {
        final krows = await sb
            .from('lf_watchlist_cocok')
            .select('watchlist_id')
            .inFilter('watchlist_id', wl.map((w) => w['id']).toList());
        for (final k in krows) {
          final id = (k['watchlist_id'] ?? '').toString();
          hitung[id] = (hitung[id] ?? 0) + 1;
        }
      }
    } catch (_) {
      // tabel watchlist belum tersedia, bagian kategori tetap jalan
    }
    if (mounted) {
      setState(() {
        _aktif = rows.map((r) => (r['kategori'] ?? '').toString()).toSet();
        _watchlist = wl;
        _jumlahKandidat = hitung;
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

  Future<void> _formWatchlist([Map<String, dynamic>? awal]) async {
    final judul = TextEditingController(text: awal?['judul'] ?? '');
    final deskripsi = TextEditingController(text: awal?['deskripsi'] ?? '');
    final warna = TextEditingController(text: awal?['warna'] ?? '');
    final lokasi = TextEditingController(text: awal?['lokasi'] ?? '');
    String kategori = (awal?['kategori'] ?? kKategori.first).toString();
    if (!kKategori.contains(kategori)) kategori = kKategori.first;
    double ambang = (awal?['ambang'] as num?)?.toDouble() ?? 0.45;
    DateTime? dari =
        DateTime.tryParse((awal?['dari_tanggal'] ?? '').toString());
    DateTime? sampai =
        DateTime.tryParse((awal?['sampai_tanggal'] ?? '').toString());
    final simpan = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(tr(awal == null ? 'Watchlist Baru' : 'Ubah Watchlist')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judul,
                  decoration: InputDecoration(
                    labelText: tr('Nama barang yang dicari'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: kategori,
                  decoration: InputDecoration(
                    labelText: tr('Kategori'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final k in kKategori)
                      DropdownMenuItem(value: k, child: Text(k)),
                  ],
                  onChanged: (v) => setDlg(() => kategori = v ?? kategori),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deskripsi,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: tr('Deskripsi'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: warna,
                  decoration: InputDecoration(
                    labelText: tr('Warna dan ciri khas'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lokasi,
                  decoration: InputDecoration(
                    labelText: tr('Lokasi kehilangan'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tr('Kepekaan')}: ${(ambang * 100).round()}%',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: ambang,
                  min: 0.30,
                  max: 0.80,
                  divisions: 10,
                  label: '${(ambang * 100).round()}%',
                  onChanged: (v) => setDlg(() => ambang = v),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: dari ?? DateTime.now(),
                            firstDate: DateTime(2025, 1, 1),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setDlg(() => dari = d);
                        },
                        child: Text(
                          dari == null
                              ? tr('Dari tanggal')
                              : fmtTanggal(dari!.toIso8601String()),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: sampai ?? DateTime.now(),
                            firstDate: DateTime(2025, 1, 1),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setDlg(() => sampai = d);
                        },
                        child: Text(
                          sampai == null
                              ? tr('Sampai tanggal')
                              : fmtTanggal(sampai!.toIso8601String()),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
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
    String? tgl(DateTime? d) => d == null
        ? null
        : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final isi = <String, dynamic>{
      'judul': judul.text.trim(),
      'kategori': kategori,
      'deskripsi': deskripsi.text.trim(),
      'warna': warna.text.trim(),
      'lokasi': lokasi.text.trim(),
      'ambang': ambang,
      'dari_tanggal': tgl(dari),
      'sampai_tanggal': tgl(sampai),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (awal == null) {
      isi['user_id'] = sb.auth.currentUser!.id;
      await sb.from('lf_watchlist').insert(isi);
    } else {
      await sb.from('lf_watchlist').update(isi).eq('id', awal['id']);
    }
    await _ambil();
  }

  Future<void> _setWatchlist(
    Map<String, dynamic> w,
    String kolom,
    bool nilai,
  ) async {
    await sb.from('lf_watchlist').update({kolom: nilai}).eq('id', w['id']);
    await _ambil();
  }

  Future<void> _hapusWatchlist(Map<String, dynamic> w) async {
    final jadi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Hapus Watchlist')),
        content: Text(
          '${tr('Watchlist ini beserta riwayat kandidatnya akan dihapus.')}: ${w['judul']}',
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
    if (jadi != true) return;
    await sb.from('lf_watchlist').delete().eq('id', w['id']);
    await _ambil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pantau')), actions: const [TombolAkun()]),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('Watchlist Barang'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _formWatchlist(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(tr('Baru')),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    tr(
                      'Simpan barang yang sedang kamu cari. Sistem memeriksa setiap temuan baru dan mengabarimu bila ada kandidat yang cocok. Kandidat adalah dugaan awal, bukan kepastian.',
                    ),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                if (_watchlist.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      tr('Belum ada watchlist.'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                for (final w in _watchlist)
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(w['judul'] ?? ''),
                      subtitle: Text(
                        [
                          (w['kategori'] ?? '').toString(),
                          if (w['selesai'] == true)
                            tr('Selesai')
                          else if (w['aktif'] == true)
                            tr('Aktif')
                          else
                            tr('Nonaktif'),
                          '${_jumlahKandidat[(w['id'] ?? '').toString()] ?? 0} ${tr('kandidat')}',
                        ].join(' - '),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (aksi) {
                          if (aksi == 'ubah') _formWatchlist(w);
                          if (aksi == 'aktif') {
                            _setWatchlist(w, 'aktif', w['aktif'] != true);
                          }
                          if (aksi == 'selesai') {
                            _setWatchlist(w, 'selesai', w['selesai'] != true);
                          }
                          if (aksi == 'hapus') _hapusWatchlist(w);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'ubah',
                            child: Text(tr('Ubah')),
                          ),
                          PopupMenuItem(
                            value: 'aktif',
                            child: Text(
                              w['aktif'] == true
                                  ? tr('Nonaktifkan')
                                  : tr('Aktifkan'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'selesai',
                            child: Text(
                              w['selesai'] == true
                                  ? tr('Belum Selesai')
                                  : tr('Tandai Selesai'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'hapus',
                            child: Text(tr('Hapus')),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LayarKandidatWatchlist(watchlist: w),
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 28),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    tr('Pantau Kategori'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    tr(
                      'Nyalakan kategori yang mau kamu pantau. Setiap ada postingan baru tampil di kategori itu, kamu menerima notif dan push, walau belum pernah posting kehilangan.',
                    ),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
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

// ===========================================================================
// Kandidat cocok untuk satu watchlist, urut skor tertinggi
// ===========================================================================

class LayarKandidatWatchlist extends StatelessWidget {
  final Map<String, dynamic> watchlist;
  const LayarKandidatWatchlist({super.key, required this.watchlist});

  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_watchlist_cocok')
        .select('post_id, skor')
        .eq('watchlist_id', watchlist['id'])
        .order('skor', ascending: false);
    if (rows.isEmpty) return [];
    final skor = {
      for (final r in rows) (r['post_id'] ?? '').toString(): r['skor'],
    };
    final prows =
        await sb.from('lf_posts').select().inFilter('id', skor.keys.toList());
    final data = List<Map<String, dynamic>>.from(prows);
    for (final p in data) {
      p['skor_cocok'] = skor[(p['id'] ?? '').toString()];
    }
    data.sort(
      (a, b) => ((b['skor_cocok'] as num?) ?? 0).compareTo(
        (a['skor_cocok'] as num?) ?? 0,
      ),
    );
    await pasangNama(data);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${tr('Kandidat')}: ${watchlist['judul']}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambil(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'Belum ada kandidat yang cocok. Sistem terus memeriksa setiap temuan baru.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (_, i) {
              final p = data[i];
              final persen = (((p['skor_cocok'] as num?) ?? 0) * 100).round();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Chip(
                      avatar: const Icon(Icons.radar_outlined, size: 16),
                      label: Text('${tr('Kecocokan')} $persen%'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  KartuPostingan(
                    post: p,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => LayarDetail(post: p)),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
