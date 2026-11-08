part of '../main.dart';

// ===========================================================================
// Layar papan pahlawan
// ===========================================================================

class LayarPahlawan extends StatelessWidget {
  const LayarPahlawan({super.key});

  int _skor(Map<String, dynamic> r) =>
      ((r['kembali_bulan_ini'] as num?)?.toInt() ?? 0) * 3 +
      ((r['klaim_ok_bulan_ini'] as num?)?.toInt() ?? 0) * 2 +
      ((r['up_bulan_ini'] as num?)?.toInt() ?? 0);

  Future<List<Map<String, dynamic>>> _ambil() async {
    final rows = await sb.from('lf_stat_bulanan').select();
    final data = List<Map<String, dynamic>>.from(rows);
    await pasangNama(data);
    data.sort((a, b) => _skor(b).compareTo(_skor(a)));
    return data.where((r) => _skor(r) > 0).take(50).toList();
  }

  Widget _avatar(Map<String, dynamic> r, double radius) {
    final foto = (r['foto_pemilik'] ?? '').toString();
    final nama = (r['nama_pemilik'] ?? 'P').toString();
    return AvatarPengguna(nama: nama, foto: foto, radius: radius);
  }

  Widget _kolomPodium(Map<String, dynamic> r, int peringkat, double tinggi) {
    final warna = peringkat == 1
        ? const Color(0xFFFFD54F)
        : peringkat == 2
        ? const Color(0xFFCFD8DC)
        : const Color(0xFFFFAB91);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (peringkat == 1)
            const Icon(Icons.emoji_events, color: Color(0xFFB8860B), size: 30),
          _avatar(r, peringkat == 1 ? 34 : 27),
          const SizedBox(height: 6),
          Text(
            (r['nama_pemilik'] ?? 'Pengguna').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: peringkat == 1 ? 15 : 13,
            ),
          ),
          Text(
            '${_skor(r)} ${tr('poin')}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Container(
            height: tinggi,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: warna,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$peringkat',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
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
          final uidSaya = sb.auth.currentUser?.id;
          final idxSaya = data.indexWhere((r) => r['user_id'] == uidSaya);
          final adaPodium = data.length >= 3;
          final sisa = adaPodium ? data.sublist(3) : data;
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
              if (adaPodium) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _kolomPodium(data[1], 2, 56),
                    _kolomPodium(data[0], 1, 88),
                    _kolomPodium(data[2], 3, 40),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (idxSaya >= 0)
                Card(
                  color: kBiru.withOpacity(0.08),
                  child: ListTile(
                    leading: const Icon(Icons.person_pin_circle, color: kBiru),
                    title: Text(
                      '${tr('Peringkatmu bulan ini')}: #${idxSaya + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${_skor(data[idxSaya])} ${tr('poin')}'),
                  ),
                ),
              if (idxSaya >= 0) const SizedBox(height: 8),
              for (int i = 0; i < sisa.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${(adaPodium ? i + 4 : i + 1)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        _avatar(sisa[i], 20),
                      ],
                    ),
                    title: Text(sisa[i]['nama_pemilik'] ?? 'Pengguna'),
                    subtitle: Text(
                      kBahasa.value == 'en'
                          ? '${sisa[i]['kembali_bulan_ini']} items returned - ${sisa[i]['klaim_ok_bulan_ini']} good claims - ${sisa[i]['up_bulan_ini']} boosts given'
                          : '${sisa[i]['kembali_bulan_ini']} barang kembali - ${sisa[i]['klaim_ok_bulan_ini']} klaim baik - ${sisa[i]['up_bulan_ini']} UP diberikan',
                    ),
                    trailing: Chip(
                      label: Text(
                        '${_skor(sisa[i])} ${tr('poin')}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
