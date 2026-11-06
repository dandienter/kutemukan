part of '../main.dart';

// ===========================================================================
// Layar beranda: papan postingan dan kartu postingan
// ===========================================================================

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
                    child: Image.network(
                      foto.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported_outlined),
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: hilang
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    child: Icon(
                      hilang ? Icons.search_off : Icons.find_in_page_outlined,
                      color: hilang ? Colors.red : Colors.green,
                    ),
                  ),
            title: Text(
              post['judul'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                    label: Text(
                      labelStatus(post['status'] ?? ''),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: warnaStatus(post['status'] ?? ''),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Chip(
                    label: Text(
                      hilang ? 'HILANG' : 'TEMUAN',
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
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
                          child: Text(tr('Tandai sudah selesai')),
                        ),
                      PopupMenuItem(value: 'hapus', child: Text(tr('Hapus'))),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '$dilihat',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_upward, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$ups UP',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                if (onUp != null && !sudahUp)
                  TextButton.icon(
                    onPressed: onUp,
                    icon: const Icon(Icons.arrow_circle_up_outlined, size: 18),
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
    final baruTampil =
        rec['status'] == 'tampil' &&
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Terima kasih sudah bantu UP.'))),
        );
      } else {
        setState(() => _upHariIni.add((p['id'] ?? '').toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Kamu sudah bantu UP postingan ini hari ini.')),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Bantu UP gagal, coba lagi sebentar.'))),
        );
      }
    }
  }

  Future<void> _muatUpHariIni() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final now = DateTime.now();
      final tgl =
          '${now.year.toString().padLeft(4, '0')}-'
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
            lokal.day == kini.day))
          return false;
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
      await sb
          .from('lf_posts')
          .update({
            'status': 'kembali',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', p['id']);
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
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Image.asset('assets/burung.png'),
        ),
        title: const Text('KutemuKan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: tr('Pantau Kategori'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LayarPantau())),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: tr('Papan Pahlawan'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LayarPahlawan())),
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
                      label: Text(
                        tr(
                          j == 'semua'
                              ? 'Semua'
                              : (j == 'hilang' ? 'Kehilangan' : 'Ditemukan'),
                        ),
                      ),
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
                      checked: _rentangCustom == null && _rentang == 'semua',
                      child: Text(tr('Semua waktu')),
                    ),
                    CheckedPopupMenuItem(
                      value: 'r_hari_ini',
                      checked: _rentangCustom == null && _rentang == 'hari_ini',
                      child: Text(tr('Hari ini')),
                    ),
                    CheckedPopupMenuItem(
                      value: 'r_7_hari',
                      checked: _rentangCustom == null && _rentang == '7_hari',
                      child: Text(tr('7 hari terakhir')),
                    ),
                    CheckedPopupMenuItem(
                      value: 'r_30_hari',
                      checked: _rentangCustom == null && _rentang == '30_hari',
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
                  return Center(
                    child: Text('${tr('Gagal memuat')}: ${snap.error}'),
                  );
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
                    final a = DateTime.tryParse(
                      (p['last_up_at'] ?? '').toString(),
                    );
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
                        Image.asset('assets/burung.png', height: 120),
                        const SizedBox(height: 12),
                        Text(
                          tr(
                            saya
                                ? 'Kamu belum punya postingan.'
                                : 'Belum ada postingan yang cocok.',
                          ),
                        ),
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
                          onAksi: saya ? (a) => _aksiSaya(data[i], a) : null,
                          onUp:
                              (!saya &&
                                  data[i]['user_id'] != sb.auth.currentUser?.id)
                              ? () => _bantuUp(data[i])
                              : null,
                          sudahUp: _upHariIni.contains(
                            (data[i]['id'] ?? '').toString(),
                          ),
                          onTap: () => Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => LayarDetail(post: data[i]),
                                ),
                              )
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
                                _gulir.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOut,
                                );
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
