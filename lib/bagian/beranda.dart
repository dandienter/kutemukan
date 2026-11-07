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
    case 'arsip':
      return Colors.grey;
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
    case 'arsip':
      return tr('Diarsipkan');
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
    final skema = Theme.of(context).colorScheme;
    final warnaMeta = skema.onSurfaceVariant;
    final warnaTitip = Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade400
        : Colors.green.shade700;
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
                    backgroundColor: warnaKategori(
                      (post['kategori'] ?? '').toString(),
                    ).withOpacity(0.14),
                    child: Icon(
                      ikonKategori((post['kategori'] ?? '').toString()),
                      color: warnaKategori(
                        (post['kategori'] ?? '').toString(),
                      ),
                    ),
                  ),
            title: Text(
              post['judul'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              (post['kategori'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: warnaKategori((post['kategori'] ?? '').toString()),
                fontWeight: FontWeight.w600,
              ),
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
                      if (post['status'] != 'kembali')
                        PopupMenuItem(value: 'ubah', child: Text(tr('Ubah'))),
                      if (post['status'] == 'tampil')
                        PopupMenuItem(
                          value: 'kembali',
                          child: Text(tr('Tandai sudah selesai')),
                        ),
                      if (post['status'] == 'tampil' || post['status'] == 'arsip')
                        PopupMenuItem(
                          value: 'perpanjang',
                          child: Text(
                            post['status'] == 'arsip'
                                ? tr('Perpanjang dan Tampilkan Lagi')
                                : tr('Perpanjang 30 Hari'),
                          ),
                        ),
                      PopupMenuItem(value: 'hapus', child: Text(tr('Hapus'))),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 15, color: warnaMeta),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    (post['lokasi'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.schedule_outlined, size: 14, color: warnaMeta),
                const SizedBox(width: 3),
                Text(
                  fmtRelatif(post['waktu_kejadian'] ?? post['created_at']),
                  style: TextStyle(fontSize: 12, color: warnaMeta),
                ),
              ],
            ),
          ),
          if ((post['deskripsi'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
              child: Text(
                (post['deskripsi'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: warnaMeta),
              ),
            ),
          if (nama.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
              child: InkWell(
                onTap:
                    (post['nama_disamarkan'] == true ||
                        (post['user_id'] ?? '').toString() ==
                            (sb.auth.currentUser?.id ?? ''))
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LayarProfilPublik(
                            userId: (post['user_id'] ?? '').toString(),
                          ),
                        ),
                      ),
                child: Row(
                children: [
                  Text(
                    kBahasa.value == 'en' ? 'by $nama' : 'oleh $nama',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: warnaMeta),
                  ),
                  if (post['terverifikasi_pemilik'] == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 14, color: kBiru),
                  ],
                ],
                ),
              ),
            ),
          if ((post['penitipan'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.security_outlined,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${tr('Dititipkan di')}: ${post['penitipan']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: warnaTitip,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, size: 16, color: warnaMeta),
                const SizedBox(width: 4),
                Text(
                  '$dilihat',
                  style: TextStyle(fontSize: 12, color: warnaMeta),
                ),
                const SizedBox(width: 16),
                Icon(Icons.arrow_upward, size: 16, color: warnaMeta),
                const SizedBox(width: 4),
                Text(
                  '$ups UP',
                  style: TextStyle(fontSize: 12, color: warnaMeta),
                ),
                if (post['diklaim'] == true && post['status'] == 'tampil') ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.how_to_reg_outlined,
                    size: 15,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    tr('Telah Diklaim'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
  late Future<Map<String, dynamic>> _fStat;
  late Future<Map<String, dynamic>?> _fPengumuman;
  bool _bannerTutup = false;

  void _segarkan() {
    _fSemua = _ambilSemua();
    _fSaya = _ambilSaya();
    _fStat = _ambilStat();
    _fPengumuman = _ambilPengumuman();
    _muatUpHariIni();
    if (mounted) setState(() {});
  }

  Future<Map<String, dynamic>?> _ambilPengumuman() async {
    try {
      final rows = await sb
          .from('lf_pengumuman')
          .select()
          .eq('aktif', true)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (_) {
      return null;
    }
  }

  Widget _bannerPengumuman() {
    if (_bannerTutup) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fPengumuman,
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return const SizedBox.shrink();
        return Card(
          color: Colors.amber.shade100,
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 2),
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined, color: Colors.black87),
            title: Text(
              (p['judul'] ?? '').toString(),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              tr('Pengumuman komunitas'),
              style: const TextStyle(color: Colors.black54),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.black54),
              onPressed: () => setState(() => _bannerTutup = true),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LayarPengumuman()),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fSemua = _ambilSemua();
    _fSaya = _ambilSaya();
    _fStat = _ambilStat();
    _fPengumuman = _ambilPengumuman();
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
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'lf_posts',
          callback: (_) => _segarkanTertunda(),
        )
        .subscribe();
  }

  Timer? _tundaSegar;

  /// Segarkan papan dengan jeda singkat, untuk perubahan yang harus
  /// langsung tercermin (postingan saya berubah status, ada yang
  /// dihapus) tanpa menunggu pengguna menarik layar.
  void _segarkanTertunda() {
    _tundaSegar?.cancel();
    _tundaSegar = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _segarkan();
    });
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
    // Postingan milik saya yang berubah (disetujui, diarsipkan,
    // dikembalikan) langsung menyegarkan daftar.
    final saya = sb.auth.currentUser?.id;
    if (saya != null && rec['user_id'] == saya) _segarkanTertunda();
  }

  @override
  void dispose() {
    _tundaSegar?.cancel();
    if (_kanal != null) sb.removeChannel(_kanal!);
    _gulir.dispose();
    super.dispose();
  }

  bool _dariCache = false;

  Future<List<Map<String, dynamic>>> _ambilSemua() async {
    try {
      final rows = await sb
          .from('lf_posts')
          .select()
          .eq('status', 'tampil')
          .order('created_at', ascending: false)
          .limit(100);
      final data = List<Map<String, dynamic>>.from(rows);
      await pasangNama(data);
      _dariCache = false;
      // Simpan salinan terakhir untuk papan offline.
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('papan_cache_v1', jsonEncode(data));
      } catch (_) {}
      return data;
    } catch (_) {
      // Tanpa sinyal: tampilkan papan terakhir yang tersimpan di HP.
      try {
        final p = await SharedPreferences.getInstance();
        final mentah = p.getString('papan_cache_v1');
        if (mentah != null && mentah.isNotEmpty) {
          _dariCache = true;
          return List<Map<String, dynamic>>.from(jsonDecode(mentah) as List);
        }
      } catch (_) {}
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _ambilStat() async {
    try {
      final hasil = await sb.rpc('lf_stat_publik');
      return Map<String, dynamic>.from(hasil as Map);
    } catch (_) {
      return const {};
    }
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
    if (aksi == 'ubah') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LayarBuat(profil: widget.profil, post: p),
        ),
      );
      _segarkan();
      return;
    }
    if (aksi == 'kembali') {
      await sb
          .from('lf_posts')
          .update({
            'status': 'kembali',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', p['id']);
    } else if (aksi == 'perpanjang') {
      final kini = DateTime.now().toUtc().toIso8601String();
      await sb
          .from('lf_posts')
          .update({
            'diperpanjang_pada': kini,
            'updated_at': kini,
            if (p['status'] == 'arsip') 'status': 'menunggu',
          })
          .eq('id', p['id']);
      if (mounted && p['status'] == 'arsip') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('Postingan diajukan lagi dan menunggu moderasi.'),
            ),
          ),
        );
      }
    } else if (aksi == 'hapus') {
      if (!await konfirmasiHapusPost(context)) return;
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
        title: const Text(
          'KutemuKan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: tr('Papan Pahlawan'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LayarPahlawan())),
          ),
          TombolAkun(profil: widget.profil),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0061C9), Color(0xFF00A3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tr('Halo')}, ${(widget.profil['nama'] ?? '').toString().split(' ').first}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    'Kehilangan barang atau nemu sesuatu? Laporkan di sini, biar cepat balik ke pemiliknya.',
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
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
              key: kunciPanduanCari,
              onChanged: (v) => setState(() => _cari = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: tr('Cari dompet, kunci, KTM...'),
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
          if (!saya) _bannerPengumuman(),
          if (!saya)
            FutureBuilder<Map<String, dynamic>>(
              future: _fStat,
              builder: (context, snap) {
                final s = snap.data ?? const {};
                if (s.isEmpty) return const SizedBox.shrink();
                final meta = Theme.of(context).colorScheme.onSurfaceVariant;
                int angka(String k) => (s[k] as num?)?.toInt() ?? 0;
                Widget sel(String label, int nilai, Color warna) => Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$nilai',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: warna,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(fontSize: 11, color: meta),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        sel(tr('Total Barang'), angka('total'), kBiru),
                        sel(tr('Hilang'), angka('hilang'), Colors.red),
                        sel(tr('Ditemukan'), angka('temuan'), Colors.green),
                        sel(tr('Sudah kembali'), angka('kembali'), Colors.blueGrey),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_dariCache)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                tr(
                  'Kamu sedang offline. Ini data terakhir yang tersimpan di HP.',
                ),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
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
                  return const DaftarKerangka();
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
                                : 'Belum ada postingan yang cocok nih. Coba kata kunci lain ya.',
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
