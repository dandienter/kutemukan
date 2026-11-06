part of '../main.dart';

// ===========================================================================
// Layar moderasi postingan (admin)
// ===========================================================================

class LayarModerasi extends StatefulWidget {
  const LayarModerasi({super.key});
  @override
  State<LayarModerasi> createState() => _LayarModerasiState();
}

class _LayarModerasiState extends State<LayarModerasi> {
  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb
        .from('lf_posts')
        .select()
        .eq('status', 'menunggu')
        .order('created_at', ascending: true);
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    return data;
  }

  Future<List<Map<String, dynamic>>> _ambilSengketa() async {
    try {
      final rows = await sb
          .from('lf_claims')
          .select()
          .eq('sengketa', true)
          .order('sengketa_pada', ascending: true);
      final data = List<Map<String, dynamic>>.from(rows);
      if (data.isEmpty) return data;
      await pasangNama(data);
      final postIds = data.map((k) => k['post_id']).toSet().toList();
      final prows =
          await sb.from('lf_posts').select('id, judul').inFilter('id', postIds);
      final judul = {
        for (final p in prows) (p['id'] ?? '').toString(): p['judul'],
      };
      for (final k in data) {
        k['judul_post'] = judul[(k['post_id'] ?? '').toString()] ?? '';
      }
      return data;
    } catch (_) {
      return [];
    }
  }

  Future<void> _putuskanSengketa(
      Map<String, dynamic> klaim, bool setujui) async {
    await sb.from('lf_claims').update({
      'sengketa': false,
      if (setujui) 'status': 'disetujui',
      if (setujui) 'alasan_tolak': null,
    }).eq('id', klaim['id']);
    setState(() {});
  }

  Future<void> _putuskan(Map<String, dynamic> post, String status) async {
    await sb.from('lf_posts').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', post['id']);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Moderasi'))),
      body: Column(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _ambilSengketa(),
            builder: (context, snap) {
              final data = snap.data ?? [];
              if (data.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      tr('Sengketa Klaim'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final k in data)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (k['judul_post'] ?? '').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tr('Pengklaim')}: ${k['nama_pemilik'] ?? ''}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${tr('Ciri khusus')}: ${k['pesan'] ?? ''}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            if ((k['alasan_tolak'] ?? '').toString().isNotEmpty)
                              Text(
                                '${tr('Alasan penolakan')}: ${k['alasan_tolak']}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _putuskanSengketa(k, false),
                                  child: Text(tr('Tetap Tolak')),
                                ),
                                FilledButton(
                                  onPressed: () => _putuskanSengketa(k, true),
                                  child: Text(tr('Setujui Klaim')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: 20),
                ],
              );
            },
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _ambil(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snap.data ?? [];
                if (data.isEmpty) {
                  return Center(
                    child: Text(tr('Tidak ada postingan menunggu moderasi.')),
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: data.length,
                  itemBuilder: (_, i) {
                    final p = data[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KartuPostingan(
                              post: p,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LayarDetail(post: p),
                                ),
                              ),
                            ),
                            if (p['detail_rahasia'] != null &&
                                (p['detail_rahasia'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Text(
                                  'Ciri rahasia (khusus admin): ${p['detail_rahasia']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _putuskan(p, 'ditolak'),
                                  child: Text(
                                    tr('Tolak'),
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _putuskan(p, 'kembali'),
                                  child: Text(tr('Tandai Selesai')),
                                ),
                                FilledButton(
                                  onPressed: () => _putuskan(p, 'tampil'),
                                  child: Text(tr('Setujui dan Tampilkan')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
