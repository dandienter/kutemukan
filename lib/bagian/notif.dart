part of '../main.dart';

// ===========================================================================
// Layar notifikasi
// ===========================================================================

class LayarNotif extends StatefulWidget {
  final bool sematkan;
  const LayarNotif({super.key, this.sematkan = false});
  @override
  State<LayarNotif> createState() => _LayarNotifState();
}

class _LayarNotifState extends State<LayarNotif> {
  late Future<List<Map<String, dynamic>>> _fNotif;
  List<Map<String, dynamic>> _terbaru = [];
  bool _modePilih = false;
  final Set<String> _dipilih = {};
  RealtimeChannel? _kanalRt;

  @override
  void initState() {
    super.initState();
    _fNotif = _ambil();
    // Pembaruan instan: notifikasi baru, terbaca, atau terhapus di
    // perangkat lain langsung tercermin di layar ini.
    final id = sb.auth.currentUser?.id;
    if (id != null) {
      _kanalRt = sb
          .channel('notif-layar')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'lf_notif',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: id,
            ),
            callback: (_) => _segarkanNotif(),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    if (_kanalRt != null) sb.removeChannel(_kanalRt!);
    super.dispose();
  }

  void _segarkanNotif() {
    _fNotif = _ambil();
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_notif')
        .select()
        .eq('user_id', sb.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .limit(100);
    final data = List<Map<String, dynamic>>.from(rows);
    _terbaru = data;
    return data;
  }

  void _masukModePilih(String? idAwal) {
    setState(() {
      _modePilih = true;
      if (idAwal != null) _dipilih.add(idAwal);
    });
  }

  void _keluarModePilih() {
    setState(() {
      _modePilih = false;
      _dipilih.clear();
    });
  }

  void _togglePilih(String id) {
    setState(() {
      if (_dipilih.contains(id)) {
        _dipilih.remove(id);
      } else {
        _dipilih.add(id);
      }
    });
  }

  void _pilihSemua() {
    setState(() {
      if (_dipilih.length == _terbaru.length) {
        _dipilih.clear();
      } else {
        _dipilih.addAll(_terbaru.map((n) => (n['id'] ?? '').toString()));
      }
    });
  }

  Future<void> _hapusTerpilih() async {
    if (_dipilih.isEmpty) return;
    final jumlah = _dipilih.length;
    await sb.from('lf_notif').delete().inFilter('id', _dipilih.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kBahasa.value == 'en'
                ? '$jumlah notifications deleted.'
                : '$jumlah notifikasi dihapus.',
          ),
        ),
      );
    }
    _keluarModePilih();
    _segarkanNotif();
  }

  Color _warna(String jenis) {
    switch (jenis) {
      case 'cocok':
        return const Color(0xFFEA580C);
      case 'disetujui':
      case 'klaim_disetujui':
      case 'kembali':
        return const Color(0xFF16A34A);
      case 'ditolak':
      case 'klaim_ditolak':
        return const Color(0xFFDC2626);
      case 'moderasi':
        return const Color(0xFF7C3AED);
      case 'dihubungi':
        return const Color(0xFF0D9488);
      case 'up':
        return const Color(0xFFDB2777);
      case 'komentar':
        return const Color(0xFF0891B2);
      case 'pantau':
        return const Color(0xFFD97706);
      case 'basi':
        return const Color(0xFF92400E);
      case 'pesan':
        return const Color(0xFF2563EB);
      case 'pengumuman':
        return const Color(0xFFB45309);
      default:
        return kBiru;
    }
  }

  IconData _ikon(String jenis) {
    switch (jenis) {
      case 'cocok':
        return Icons.find_in_page;
      case 'disetujui':
      case 'klaim_disetujui':
        return Icons.check_circle_outline;
      case 'ditolak':
      case 'klaim_ditolak':
        return Icons.block_outlined;
      case 'moderasi':
        return Icons.shield_outlined;
      case 'dihubungi':
        return Icons.how_to_reg_outlined;
      case 'up':
        return Icons.arrow_circle_up_outlined;
      case 'komentar':
        return Icons.comment_outlined;
      case 'pantau':
        return Icons.notifications_active_outlined;
      case 'basi':
        return Icons.schedule_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _tandaiSemuaDibaca() async {
    await sb
        .from('lf_notif')
        .update({'dibaca': true})
        .eq('user_id', sb.auth.currentUser!.id)
        .eq('dibaca', false);
    _segarkanNotif();
  }

  Future<void> _hapus(Map<String, dynamic> n) async {
    // Optimistis: hilang dari layar seketika, server menyusul. Bila
    // server gagal, daftar dipulihkan seperti semula.
    final cadangan = List<Map<String, dynamic>>.from(_terbaru);
    setState(() {
      _terbaru = _terbaru.where((x) => x['id'] != n['id']).toList();
      _fNotif = Future.value(_terbaru);
    });
    try {
      await sb.from('lf_notif').delete().eq('id', n['id']);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('Notifikasi dihapus.'))));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _terbaru = cadangan;
          _fNotif = Future.value(_terbaru);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Gagal menghapus, coba lagi.'))),
        );
      }
    }
  }

  Future<void> _buka(Map<String, dynamic> n) async {
    await sb.from('lf_notif').update({'dibaca': true}).eq('id', n['id']);
    if (n['jenis'] == 'moderasi' && mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LayarModerasi()));
      _segarkanNotif();
      return;
    }
    if (n['post_id'] != null && mounted) {
      final rows = await sb.from('lf_posts').select().eq('id', n['post_id']);
      if (rows.isNotEmpty) await pasangNama([rows.first]);
      if (rows.isNotEmpty && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LayarDetail(post: rows.first)),
        );
      }
    }
    _segarkanNotif();
  }

  /// Bilah alat ringkas saat layar ini disematkan sebagai tab
  /// Informasi: isinya sama dengan tindakan di AppBar versi mandiri.
  Widget _alatTanam() {
    if (_modePilih) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _keluarModePilih,
          ),
          Text(
            kBahasa.value == 'en'
                ? '${_dipilih.length} selected'
                : '${_dipilih.length} dipilih',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: tr('Pilih semua'),
            onPressed: _pilihSemua,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: tr('Hapus'),
            onPressed: _dipilih.isEmpty ? null : _hapusTerpilih,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          key: kunciPanduanNotif,
          icon: const Icon(Icons.done_all),
          tooltip: tr('Tandai semua dibaca'),
          onPressed: _tandaiSemuaDibaca,
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: tr('Pilih'),
          onPressed: () => _masukModePilih(null),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
        title: Text(
          _modePilih
              ? (kBahasa.value == 'en'
                    ? '${_dipilih.length} selected'
                    : '${_dipilih.length} dipilih')
              : tr('Notifikasi'),
        ),
        leading: _modePilih
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _keluarModePilih,
              )
            : null,
        actions: [
          if (_modePilih) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: tr('Pilih semua'),
              onPressed: _pilihSemua,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('Hapus'),
              onPressed: _dipilih.isEmpty ? null : _hapusTerpilih,
            ),
          ] else ...[
            IconButton(
              key: kunciPanduanNotif,
              icon: const Icon(Icons.done_all),
              tooltip: tr('Tandai semua dibaca'),
              onPressed: _tandaiSemuaDibaca,
            ),
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: tr('Pilih'),
              onPressed: () => _masukModePilih(null),
            ),
            const TombolAkun(),
          ],
        ],
      );
    final isi = FutureBuilder<List<Map<String, dynamic>>>(
        future: _fNotif,
        builder: (context, snap) {
          if (snap.hasError && snap.data == null) {
            return Center(child: Text('${tr('Gagal memuat')}: ${snap.error}'));
          }
          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(child: Text(tr('Belum ada notifikasi nih. Nanti kalau ada kabar, muncul di sini.')));
          }
          return RefreshIndicator(
            onRefresh: () async {
              _segarkanNotif();
              await _fNotif;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: data.length,
              itemBuilder: (_, i) {
                final n = data[i];
                final belum = n['dibaca'] != true;
                return Dismissible(
                  key: ValueKey('${n['id']}-$_modePilih'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _hapus(n),
                  child: ListTile(
                    leading: _modePilih
                        ? Checkbox(
                            value: _dipilih.contains(
                              (n['id'] ?? '').toString(),
                            ),
                            onChanged: (_) =>
                                _togglePilih((n['id'] ?? '').toString()),
                          )
                        : CircleAvatar(
                            backgroundColor: _warna(
                              n['jenis'] ?? '',
                            ).withOpacity(belum ? 0.22 : 0.12),
                            child: Icon(
                              _ikon(n['jenis'] ?? ''),
                              color: _warna(n['jenis'] ?? ''),
                            ),
                          ),
                    title: Text(
                      n['judul'] ?? '',
                      style: TextStyle(
                        fontWeight: belum ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${n['isi'] ?? ''}\n${fmtTanggal(n['created_at'])}',
                    ),
                    isThreeLine: true,
                    onTap: () => _modePilih
                        ? _togglePilih((n['id'] ?? '').toString())
                        : _buka(n),
                    onLongPress: _modePilih
                        ? null
                        : () => _masukModePilih((n['id'] ?? '').toString()),
                  ),
                );
              },
            ),
          );
        },
      );
    if (widget.sematkan) {
      return Column(children: [_alatTanam(), Expanded(child: isi)]);
    }
    return Scaffold(appBar: appBar, body: isi);
  }
}
