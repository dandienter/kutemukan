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
  final void Function(String aksi)? onAksi;
  final VoidCallback? onUp;
  final bool sudahUp;
  const KartuPostingan({
    super.key,
    required this.post,
    this.onTap,
    this.onAksi,
    this.onUp,
    this.sudahUp = false,
  });
  @override
  Widget build(BuildContext context) {
    final sudahKembali = post['status'] == 'kembali';
    final foto = daftarFoto(post);
    final nama = (post['nama_pemilik'] ?? '').toString();
    final dilihat = (post['views_count'] as num?)?.toInt() ?? 0;
    final ups = (post['up_count'] as num?)?.toInt() ?? 0;
    final skema = Theme.of(context).colorScheme;
    final warnaMeta = skema.onSurfaceVariant;
    final warnaTitip = Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade400
        : Colors.green.shade700;
    final warnaKat = warnaKategori((post['kategori'] ?? '').toString());
    final bisaProfil =
        nama.isNotEmpty &&
        post['nama_disamarkan'] != true &&
        (post['user_id'] ?? '').toString() !=
            (sb.auth.currentUser?.id ?? '');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kepala kartu: pemilik di kiri, chip status dan menu di kanan.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                InkWell(
                  onTap: bisaProfil
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LayarProfilPublik(
                              userId: (post['user_id'] ?? '').toString(),
                            ),
                          ),
                        )
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarPengguna(nama: nama, foto: (post['foto_pemilik'] ?? '').toString(), radius: 17),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          nama.isEmpty ? tr('Pengguna') : nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      if (post['terverifikasi_pemilik'] == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 16, color: kBiru),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
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
                      if (post['status'] == 'tampil' ||
                          post['status'] == 'arsip')
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
          if (foto.isNotEmpty)
            Stack(
              children: [
                if (sudahKembali)
                  ColorFiltered(
                    colorFilter: kFilterFotoRedup,
                    child: _PagerFoto(urls: foto, onTap: onTap),
                  )
                else
                  _PagerFoto(urls: foto, onTap: onTap),
                if (sudahKembali)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: StempelKembali(ukuran: 17)),
                    ),
                  ),
              ],
            )
          else
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: warnaKat.withOpacity(0.14),
                      child: Icon(
                        ikonKategori((post['kategori'] ?? '').toString()),
                        color: warnaKat,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['judul'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                            ),
                          ),
                          Text(
                            (post['kategori'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: warnaKat,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sudahKembali) ...[
                      const SizedBox(width: 10),
                      const StempelKembali(ukuran: 9),
                    ],
                  ],
                ),
              ),
            ),
          InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (foto.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Text(
                      post['judul'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                    child: Text(
                      (post['kategori'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: warnaKat,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
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
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                    child: Text(
                      (post['deskripsi'] ?? '').toString(),
                      maxLines: foto.isNotEmpty ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: warnaMeta),
                    ),
                  ),
                if ((post['penitipan'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
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
                // Postingan yang sudah diklaim tidak perlu didorong lagi.
                if (onUp != null && !sudahUp && post['diklaim'] != true)
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

/// Foto postingan lebar penuh yang bisa digeser bila lebih dari satu,
/// dengan titik penanda halus di tengah bawah foto. Gambar dimuat
/// lewat cache disk supaya tidak mengunduh ulang saat digulir.
class _PagerFoto extends StatefulWidget {
  final List<String> urls;
  final VoidCallback? onTap;
  const _PagerFoto({required this.urls, this.onTap});
  @override
  State<_PagerFoto> createState() => _PagerFotoState();
}

class _PagerFotoState extends State<_PagerFoto> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: widget.onTap,
              child: CachedNetworkImage(
                imageUrl: widget.urls[i],
                fit: BoxFit.cover,
                width: double.infinity,
                errorWidget: (_, __, ___) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 40,
                  ),
                ),
                placeholder: (_, __) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.urls.length,
                  (i) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _idx
                          ? Colors.white
                          : Colors.white.withOpacity(0.45),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 3),
                      ],
                    ),
                  ),
                ),
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
  final TextEditingController _cariCtrl = TextEditingController();
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
    _cariCtrl.dispose();
    super.dispose();
  }

  bool _dariCache = false;

  Future<List<Map<String, dynamic>>> _ambilSemua() async {
    try {
      final rows = await sb
          .from('lf_posts')
          .select()
          .inFilter('status', ['tampil', 'kembali'])
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
    if (_jenis == 'kembali') {
      if (p['status'] != 'kembali') return false;
    } else if (_jenis == 'hilang' || _jenis == 'temuan') {
      if (p['status'] != 'tampil' || p['jenis'] != _jenis) return false;
    }
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
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -350 && _segmen != 1) setState(() => _segmen = 1);
          if (v > 350 && _segmen != 0) setState(() => _segmen = 0);
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: saya ? _fSaya : _fSemua,
          builder: (context, snap) {
            List<Map<String, dynamic>>? data;
            if (snap.data != null) {
              data = (snap.data ?? []).where(_lolos).toList();
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
            }
            final daftar = data ?? const <Map<String, dynamic>>[];
            final namaSapaan = namaRapi(
              (widget.profil['nama'] ?? '').toString(),
            );
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    _segarkan();
                    await (saya ? _fSaya : _fSemua);
                  },
                  child: CustomScrollView(
                    controller: _gulir,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Container(
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
                                namaSapaan.isEmpty
                                    ? tr('Halo')
                                    : '${tr('Halo')}, $namaSapaan',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr(
                                  'Kehilangan barang atau nemu sesuatu? Laporkan di sini, biar cepat balik ke pemiliknya.',
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              FutureBuilder<Map<String, dynamic>>(
                                future: _fStat,
                                builder: (context, s2) {
                                  final s = s2.data ?? const {};
                                  if (s.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  int angka(String k) =>
                                      (s[k] as num?)?.toInt() ?? 0;
                                  Widget sel(
                                    String label,
                                    int nilai,
                                    String saring,
                                  ) => Expanded(
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _jenis = saring),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Column(
                                          children: [
                                            TweenAnimationBuilder<int>(
                                              tween: IntTween(
                                                begin: 0,
                                                end: nilai,
                                              ),
                                              duration: const Duration(
                                                milliseconds: 800,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              builder: (_, v, __) => Text(
                                                '$v',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: _jenis == saring
                                                    ? FontWeight.w800
                                                    : FontWeight.w400,
                                                color: _jenis == saring
                                                    ? Colors.white
                                                    : Colors.white70,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  final totalS = angka('total');
                                  final kembaliS = angka('kembali');
                                  final rasioS = totalS == 0
                                      ? 0.0
                                      : kembaliS / totalS;
                                  return Column(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: Divider(
                                          color: Colors.white24,
                                          height: 1,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          sel(
                                            tr('Total Barang'),
                                            totalS,
                                            'semua',
                                          ),
                                          sel(
                                            tr('Hilang'),
                                            angka('hilang'),
                                            'hilang',
                                          ),
                                          sel(
                                            tr('Ditemukan'),
                                            angka('temuan'),
                                            'temuan',
                                          ),
                                          sel(
                                            tr('Sudah kembali'),
                                            kembaliS,
                                            'kembali',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.verified_outlined,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            tr(
                                              'Tingkat keberhasilan pengembalian',
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${(rasioS * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(
                                          begin: 0,
                                          end: rasioS,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 900,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        builder: (_, v, __) => ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          child: LinearProgressIndicator(
                                            value: v,
                                            minHeight: 6,
                                            backgroundColor: Colors.white24,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: SegmentedButton<int>(
                            segments: [
                              ButtonSegment(
                                value: 0,
                                label: Text(tr('Semua')),
                              ),
                              ButtonSegment(
                                value: 1,
                                label: Text(tr('Saya')),
                              ),
                            ],
                            selected: {_segmen},
                            onSelectionChanged: (s) =>
                                setState(() => _segmen = s.first),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: TextField(
                            key: kunciPanduanCari,
                            controller: _cariCtrl,
                            onChanged: (v) =>
                                setState(() => _cari = v.trim().toLowerCase()),
                            decoration: InputDecoration(
                              hintText: tr('Cari dompet, kunci, KTM...'),
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final j in [
                                        'semua',
                                        'hilang',
                                        'temuan',
                                        'kembali',
                                      ])
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(
                                              tr(
                                                j == 'semua'
                                                    ? 'Semua'
                                                    : (j == 'hilang'
                                                          ? 'Kehilangan'
                                                          : (j == 'temuan'
                                                                ? 'Ditemukan'
                                                                : 'Sudah Kembali')),
                                              ),
                                            ),
                                            selected: _jenis == j,
                                            onSelected: (_) =>
                                                setState(() => _jenis = j),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: tr('Urutkan dan saring waktu'),
                                icon: const Icon(
                                  Icons.calendar_month_outlined,
                                ),
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
                                        _rentangCustom == null &&
                                        _rentang == 'semua',
                                    child: Text(tr('Semua waktu')),
                                  ),
                                  CheckedPopupMenuItem(
                                    value: 'r_hari_ini',
                                    checked:
                                        _rentangCustom == null &&
                                        _rentang == 'hari_ini',
                                    child: Text(tr('Hari ini')),
                                  ),
                                  CheckedPopupMenuItem(
                                    value: 'r_7_hari',
                                    checked:
                                        _rentangCustom == null &&
                                        _rentang == '7_hari',
                                    child: Text(tr('7 hari terakhir')),
                                  ),
                                  CheckedPopupMenuItem(
                                    value: 'r_30_hari',
                                    checked:
                                        _rentangCustom == null &&
                                        _rentang == '30_hari',
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
                      ),
                      if (!saya)
                        SliverToBoxAdapter(child: _bannerPengumuman()),
                      if (_dariCache)
                        SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                            color: Colors.orange.shade100,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              tr(
                                'Kamu sedang offline. Ini data terakhir yang tersimpan di HP.',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      if (snap.hasError && snap.data == null)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text('${tr('Gagal memuat')}: ${snap.error}'),
                          ),
                        )
                      else if (snap.data == null)
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 520, child: DaftarKerangka()),
                        )
                      else if (daftar.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/burung.png', height: 120),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 36,
                                  ),
                                  child: Text(
                                    tr(
                                      saya
                                          ? 'Kamu belum punya postingan.'
                                          : 'Belum ada postingan yang cocok nih. Coba kata kunci lain ya.',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: daftar.length,
                          itemBuilder: (_, i) => KartuPostingan(
                            post: daftar[i],
                            onAksi: saya
                                ? (a) => _aksiSaya(daftar[i], a)
                                : null,
                            onUp:
                                (!saya &&
                                    daftar[i]['user_id'] !=
                                        sb.auth.currentUser?.id)
                                ? () => _bantuUp(daftar[i])
                                : null,
                            sudahUp: _upHariIni.contains(
                              (daftar[i]['id'] ?? '').toString(),
                            ),
                            onTap: () => Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LayarDetail(post: daftar[i]),
                                  ),
                                )
                                .then((_) => _segarkan()),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    ],
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
    );
  }
}
