part of '../main.dart';

// ===========================================================================
// Layar papan pahlawan
// ===========================================================================

class LayarPahlawan extends StatelessWidget {
  const LayarPahlawan({super.key});

  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb.from('lf_stat_bulanan').select();
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    int skor(Map<String, dynamic> r) =>
        ((r['kembali_bulan_ini'] as num?)?.toInt() ?? 0) * 3 +
        ((r['klaim_ok_bulan_ini'] as num?)?.toInt() ?? 0) * 2 +
        ((r['up_bulan_ini'] as num?)?.toInt() ?? 0);
    data.sort((a, b) => skor(b).compareTo(skor(a)));
    return data.where((r) => skor(r) > 0).take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Papan Pahlawan Kampus'))),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: kBiru,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr(
                      'Peringkat bulan ini dihitung dari data asli: barang yang kembali, klaim baik yang disetujui, dan Bantu UP yang diberikan. Direset tiap awal bulan.',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (data.isEmpty)
                Text(
                  tr(
                    'Belum ada aktivitas bulan ini. Jadilah pahlawan pertama.',
                  ),
                ),
              for (int i = 0; i < data.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: i == 0
                          ? const Color(0xFFFFD54F)
                          : i == 1
                          ? const Color(0xFFCFD8DC)
                          : i == 2
                          ? const Color(0xFFFFAB91)
                          : Colors.grey.shade200,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(data[i]['nama_pemilik'] ?? 'Pengguna'),
                    subtitle: Text(
                      kBahasa.value == 'en'
                          ? '${data[i]['kembali_bulan_ini']} items returned - ${data[i]['klaim_ok_bulan_ini']} good claims - ${data[i]['up_bulan_ini']} boosts given'
                          : '${data[i]['kembali_bulan_ini']} barang kembali - ${data[i]['klaim_ok_bulan_ini']} klaim baik - ${data[i]['up_bulan_ini']} UP diberikan',
                    ),
                    trailing: i < 3
                        ? const Icon(
                            Icons.emoji_events,
                            color: Color(0xFFB8860B),
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
