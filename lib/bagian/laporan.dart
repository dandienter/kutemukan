part of '../main.dart';

// ===========================================================================
// Layar laporan pengguna (admin)
// ===========================================================================

class LayarLaporan extends StatefulWidget {
  const LayarLaporan({super.key});
  @override
  State<LayarLaporan> createState() => _LayarLaporanState();
}

class _LayarLaporanState extends State<LayarLaporan> {
  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_laporan')
        .select()
        .order('created_at', ascending: false);
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    for (final r in data) {
      try {
        final p = await sb
            .from('lf_posts')
            .select('judul, status')
            .eq('id', r['post_id']);
        if (p.isNotEmpty) {
          r['judul_post'] = p.first['judul'];
          r['status_post'] = p.first['status'];
        }
      } catch (_) {}
    }
    return data;
  }

  Future<void> _turunkan(Map<String, dynamic> r) async {
    await sb
        .from('lf_posts')
        .update({
          'status': 'ditolak',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', r['post_id']);
    await sb.from('lf_laporan').delete().eq('post_id', r['post_id']);
    setState(() {});
  }

  Future<void> _abaikan(Map<String, dynamic> r) async {
    await sb.from('lf_laporan').delete().eq('id', r['id']);
    setState(() {});
  }

  Future<void> _buka(Map<String, dynamic> r) async {
    final rows = await sb.from('lf_posts').select().eq('id', r['post_id']);
    if (rows.isEmpty || !mounted) return;
    final post = rows.first;
    await pasangNama([post]);
    if (mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => LayarDetail(post: post)));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Laporan Pengguna'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambil(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${tr('Gagal memuat')}: ${snap.error}'));
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(child: Text(tr('Tidak ada laporan masuk.')));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: data.length,
              itemBuilder: (_, i) {
                final r = data[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['judul_post'] ?? 'Postingan',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dilaporkan oleh ${r['nama_pemilik'] ?? 'Pengguna'} - ${fmtTanggal(r['created_at'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        if ((r['alasan'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('"${r['alasan']}"'),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _abaikan(r),
                              child: Text(tr('Abaikan')),
                            ),
                            TextButton(
                              onPressed: () => _buka(r),
                              child: Text(tr('Buka')),
                            ),
                            FilledButton(
                              onPressed: () => _turunkan(r),
                              child: Text(tr('Turunkan')),
                            ),
                          ],
                        ),
                      ],
                    ),
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

/// Layar verifikasi mahasiswa: pengguna yang masuk lewat email/Google
/// mengaitkan akun SIKA-nya di sini. Backend menulis identitas resmi
/// (NPM, prodi, fakultas, kelas, angkatan) langsung ke database.
