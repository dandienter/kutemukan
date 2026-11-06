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

  @override
  void initState() {
    super.initState();
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
      body: IndexedStack(index: _tab, children: halaman),
      bottomNavigationBar: NavigationBar(
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
