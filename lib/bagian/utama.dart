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
          kunci: kunciPanduanPantau,
          tab: 1,
          judul: tr('Pantau barang incaranmu'),
          isi: tr(
            'Tekan tombol Baru untuk menyimpan barang yang kamu cari. Sistem otomatis mengabari kalau ada temuan yang mirip.',
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
          kunci: kunciPanduanNotif,
          tab: 3,
          judul: tr('Semua kabar masuk ke sini'),
          isi: tr(
            'Klaim disetujui, kandidat cocok, dan pengingat arsip muncul di Notifikasi. Tombol ini menandai semua notifikasi sudah dibaca.',
          ),
        ),
        LangkahTur(
          tab: 4,
          judul: tr('Ngobrol langsung di Chat'),
          isi: tr(
            'Sesudah klaim disetujui, kamu dan pemilik barang bisa chat di sini, kirim foto, bahkan bagikan lokasi langsung.',
          ),
        ),
        LangkahTur(
          kunci: kunciPanduanNav,
          tab: 0,
          judul: tr('Pindah halaman dari sini'),
          isi: tr(
            'Lima tab utama KutemuKan ada di bawah ini. Tombol Akun ada di pojok kanan atas tiap halaman untuk profil, unduh data, dan pengaturan.',
          ),
        ),
      ],
      keTab: (t) {
        if (mounted) setState(() => _tab = t);
      },
      selesai: () async {
        final p = await SharedPreferences.getInstance();
        await p.setBool('panduan_v174_selesai', true);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    pemicuPanduan = _mulaiTur;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await SharedPreferences.getInstance();
      if (p.getBool('panduan_v174_selesai') != true && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final halaman = <Widget>[
      LayarBeranda(profil: _profil),
      const LayarPantau(),
      LayarBuat(profil: _profil),
      const LayarNotif(),
      const LayarDaftarChat(),
    ];
    final tujuan = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        label: tr('Beranda'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.visibility_outlined),
        label: tr('Pantau'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.add_circle_outline),
        label: tr('Buat'),
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _belumDibaca > 0,
          label: Text('$_belumDibaca'),
          child: const Icon(Icons.notifications_outlined),
        ),
        label: tr('Notif'),
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _chatBelum > 0,
          label: Text('$_chatBelum'),
          child: const Icon(Icons.forum_outlined),
        ),
        label: tr('Chat'),
      ),
    ];
    if (_tab >= halaman.length) _tab = 0;
    return Scaffold(
      body: TweenAnimationBuilder<double>(
        key: ValueKey(_tab),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: 0.55 + 0.45 * t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        ),
        child: IndexedStack(index: _tab, children: halaman),
      ),
      bottomNavigationBar: NavigationBar(
        key: kunciPanduanNav,
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 3) {
            Future.delayed(const Duration(seconds: 2), _hitungBelumDibaca);
          }
          if (i == 4) {
            Future.delayed(const Duration(seconds: 2), _hitungChatBelum);
          }
        },
        destinations: tujuan,
      ),
    );
  }
}
