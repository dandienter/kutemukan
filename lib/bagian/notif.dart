part of '../main.dart';

// ===========================================================================
// Layar notifikasi
// ===========================================================================

class LayarNotif extends StatefulWidget {
  const LayarNotif({super.key});
  @override
  State<LayarNotif> createState() => _LayarNotifState();
}

class _LayarNotifState extends State<LayarNotif> {
  late Future<List<Map<String, dynamic>>> _fNotif;

  @override
  void initState() {
    super.initState();
    _fNotif = _ambil();
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
    return List<Map<String, dynamic>>.from(rows);
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
    await sb.from('lf_notif').delete().eq('id', n['id']);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Notifikasi dihapus.'))));
    }
    _segarkanNotif();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Notifikasi')),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: tr('Tandai semua dibaca'),
            onPressed: _tandaiSemuaDibaca,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
            return Center(child: Text(tr('Belum ada notifikasi.')));
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
                  key: ValueKey(n['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _hapus(n),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: belum
                          ? kBiru.withOpacity(0.15)
                          : Colors.grey.shade100,
                      child: Icon(
                        _ikon(n['jenis'] ?? ''),
                        color: belum ? kBiru : Colors.grey,
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
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: tr('Hapus'),
                      onPressed: () => _hapus(n),
                    ),
                    onTap: () => _buka(n),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
