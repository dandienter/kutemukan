part of '../main.dart';

// ===========================================================================
// Layar utama: rangka navigasi bawah
// ===========================================================================

class LayarUtama extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarUtama({super.key, required this.profil});
  @override
  State<LayarUtama> createState() => _LayarUtamaState();
}

class _LayarUtamaState extends State<LayarUtama> {
  int _tab = 0;
  late Map<String, dynamic> _profil = widget.profil;
  int _belumDibaca = 0;
  int _chatBelum = 0;
  RealtimeChannel? _kanalNotif;
  RealtimeChannel? _kanalPesan;
  StreamSubscription<Uri>? _tautanSub;

  /// Tautan dalam kutemukan://post/<id> membuka detail postingan itu,
  /// misalnya dari tombol Buka di Aplikasi di versi web.
  Future<void> _tanganiTautan(Uri uri) async {
    if (uri.scheme != 'kutemukan' || uri.host != 'post') return;
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (id.isEmpty) return;
    try {
      final rows = await sb.from('lf_posts').select().eq('id', id).limit(1);
      if (rows.isEmpty || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              LayarDetail(post: Map<String, dynamic>.from(rows.first)),
        ),
      );
    } catch (_) {}
  }

  /// Tur panduan interaktif: keliling lima tab dengan sorotan di
  /// tombol aslinya, ditemani maskot.
  void _mulaiTur() {
    mulaiTurPanduan(
      context,
      [
        LangkahTur(
          kunci: kunciPanduanCari,
          tab: 0,
          judul: tr('Cari barang di sini'),
          isi: tr(
            'Ketik nama barang, kategori, atau lokasi. Papan menampilkan semua laporan hilang dan temuan terbaru di kampus.',
          ),
        ),
        LangkahTur(
          kunci: kunciPanduanNotif,
          tab: 1,
          judul: tr('Semua kabar masuk ke sini'),
          isi: tr(
            'Notifikasi klaim dan kandidat cocok, pengumuman admin, dan panduan pemakaian sekarang berkumpul di tab Informasi ini.',
          ),
        ),
        LangkahTur(
          kunci: kunciPanduanCepat,
          tab: 2,
          judul: tr('Lapor Cepat, tanpa ribet'),
          isi: tr(
            'Ceritakan kejadiannya dalam satu kalimat, formulir terisi otomatis plus kandidat barang yang mirip langsung dicarikan.',
          ),
        ),
        LangkahTur(
          tab: 3,
          judul: tr('Ngobrol langsung di Chat'),
          isi: tr(
            'Sesudah klaim disetujui, kamu dan pemilik barang bisa chat di sini, kirim foto, bahkan bagikan lokasi langsung.',
          ),
        ),
        LangkahTur(
          tab: 4,
          judul: tr('Akun dan Pantau di sini'),
          isi: tr(
            'Profilmu, Pantau Kategori untuk barang incaran, unduh data, dan pengaturan ada di halaman Akun. Ketuk namamu untuk melihat profil lengkap.',
          ),
        ),
        LangkahTur(
          kunci: kunciPanduanNav,
          tab: 0,
          judul: tr('Pindah halaman dari sini'),
          isi: tr(
            'Lima tab utama KutemuKan ada di bawah ini. Tombol biru besar di tengah untuk membuat laporan baru.',
          ),
        ),
      ],
      keTab: (t) {
        if (mounted) setState(() => _tab = t);
      },
      selesai: () async {
        final p = await SharedPreferences.getInstance();
        await p.setBool('panduan_v190_selesai', true);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    pemicuPanduan = _mulaiTur;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await SharedPreferences.getInstance();
      if (p.getBool('panduan_v190_selesai') != true && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted) _mulaiTur();
      }
    });
    final appLinks = AppLinks();
    _tautanSub = appLinks.uriLinkStream.listen(_tanganiTautan);
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _tanganiTautan(uri);
    });
    _hitungBelumDibaca();
    final id = sb.auth.currentUser?.id;
    if (id != null) {
      _kanalNotif = sb
          .channel('notif-saya')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'lf_notif',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: id,
            ),
            callback: (_) => _hitungBelumDibaca(),
          )
          .subscribe();
      _kanalPesan = sb
          .channel('pesan-saya')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'lf_pesan',
            callback: (_) => _hitungChatBelum(),
          )
          .subscribe();
    }
    _hitungChatBelum();
  }

  Future<void> _hitungChatBelum() async {
    final id = sb.auth.currentUser?.id;
    if (id == null) return;
    try {
      final convs = await sb
          .from('lf_percakapan')
          .select('id')
          .or('user_a.eq.$id,user_b.eq.$id');
      if (convs.isEmpty) {
        if (mounted) setState(() => _chatBelum = 0);
        return;
      }
      final ids = convs.map((c) => c['id']).toList();
      final rows = await sb
          .from('lf_pesan')
          .select('id')
          .inFilter('percakapan_id', ids)
          .eq('dibaca', false)
          .neq('pengirim_id', id);
      if (mounted) setState(() => _chatBelum = rows.length);
    } catch (_) {
      // abaikan, badge hanya pelengkap
    }
  }

  @override
  void dispose() {
    pemicuPanduan = null;
    _tautanSub?.cancel();
    if (_kanalNotif != null) sb.removeChannel(_kanalNotif!);
    if (_kanalPesan != null) sb.removeChannel(_kanalPesan!);
    super.dispose();
  }

  Future<void> _hitungBelumDibaca() async {
    final id = sb.auth.currentUser?.id;
    if (id == null) return;
    try {
      final rows = await sb
          .from('lf_notif')
          .select('id')
          .eq('user_id', id)
          .eq('dibaca', false);
      if (mounted) setState(() => _belumDibaca = rows.length);
    } catch (_) {
      // abaikan, badge hanya pelengkap
    }
  }

  Future<void> _segarkanProfil() async {
    final id = sb.auth.currentUser?.id;
    if (id == null) return;
    final rows = await sb.from('lf_profiles').select().eq('id', id);
    if (rows.isNotEmpty && mounted) {
      setState(() => _profil = rows.first);
    }
  }

  void _pilihTab(int i) {
    setState(() => _tab = i);
    if (i == 4) _segarkanProfil();
    if (i == 1) {
      Future.delayed(const Duration(seconds: 2), _hitungBelumDibaca);
    }
    if (i == 3) {
      Future.delayed(const Duration(seconds: 2), _hitungChatBelum);
    }
  }

  Widget _itemNav(
    int idx,
    IconData ikon,
    IconData ikonAktif,
    String label, {
    int badge = 0,
  }) {
    final aktif = _tab == idx;
    final warna = aktif ? kBiruUtama : Colors.grey.shade500;
    return Expanded(
      child: InkWell(
        onTap: () => _pilihTab(idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(aktif ? ikonAktif : ikon, color: warna, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: aktif ? FontWeight.w800 : FontWeight.w500,
                color: warna,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombolLapor() {
    final aktif = _tab == 2;
    return Expanded(
      child: InkWell(
        onTap: () => _pilihTab(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Transform.translate(
              offset: const Offset(0, -12),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: kGradasiKepala,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: kBiruUtama.withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 29),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Text(
                tr('Lapor'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                  color: aktif ? kBiruUtama : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final halaman = <Widget>[
      LayarBeranda(profil: _profil),
      const LayarInformasi(),
      LayarBuat(profil: _profil),
      const LayarDaftarChat(),
      LayarAkun(profil: _profil),
    ];
    if (_tab >= halaman.length) _tab = 0;
    return Scaffold(
      // Tanpa animasi pembungkus berkunci per tab: kunci yang berubah
      // tiap pindah tab dulu menghancurkan state semua halaman,
      // sehingga semua data dimuat ulang setiap berpindah.
      body: IndexedStack(index: _tab, children: halaman),
      bottomNavigationBar: Container(
        key: kunciPanduanNav,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _itemNav(0, Icons.home_outlined, Icons.home, tr('Beranda')),
                _itemNav(
                  1,
                  Icons.newspaper_outlined,
                  Icons.newspaper,
                  tr('Info'),
                  badge: _belumDibaca,
                ),
                _tombolLapor(),
                _itemNav(
                  3,
                  Icons.forum_outlined,
                  Icons.forum,
                  tr('Chat'),
                  badge: _chatBelum,
                ),
                _itemNav(4, Icons.person_outline, Icons.person, tr('Akun')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
