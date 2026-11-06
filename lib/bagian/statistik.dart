part of '../main.dart';

// ===========================================================================
// Layar statistik (admin)
// ===========================================================================

class LayarStatistik extends StatelessWidget {
  const LayarStatistik({super.key});

  Future<Map<String, dynamic>> _hitung() async {
    final posts = List<Map<String, dynamic>>.from(
      await sb
          .from('lf_posts')
          .select(
            'user_id, jenis, status, up_count, views_count, kategori, created_at',
          ),
    );
    final users = List<Map<String, dynamic>>.from(
      await sb.from('lf_profiles').select('id, nama'),
    );
    final klaim = List<Map<String, dynamic>>.from(
      await sb.from('lf_claims').select('user_id, status, created_at'),
    );
    final ulasan = List<Map<String, dynamic>>.from(
      await sb
          .from('lf_feedback')
          .select('user_id, bintang, isi, created_at')
          .order('created_at', ascending: false)
          .limit(30),
    );
    return {'posts': posts, 'users': users, 'klaim': klaim, 'ulasan': ulasan};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Statistik'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _hitung(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${tr('Gagal memuat')}: ${snap.error}'));
          }
          final posts = snap.data!['posts'] as List<Map<String, dynamic>>;
          final users = snap.data!['users'] as List<Map<String, dynamic>>;
          final klaim = snap.data!['klaim'] as List<Map<String, dynamic>>;
          final ulasan = snap.data!['ulasan'] as List<Map<String, dynamic>>;
          final totalUp = posts.fold<int>(
            0,
            (a, p) => a + ((p['up_count'] as num?)?.toInt() ?? 0),
          );
          final totalDilihat = posts.fold<int>(
            0,
            (a, p) => a + ((p['views_count'] as num?)?.toInt() ?? 0),
          );
          final rataBintang = ulasan.isEmpty
              ? 0.0
              : ulasan.fold<int>(
                      0,
                      (a, u) => a + ((u['bintang'] as num?)?.toInt() ?? 0),
                    ) /
                    ulasan.length;

          int hitungPost(bool Function(Map<String, dynamic>) f) =>
              posts.where(f).length;
          final tampil = hitungPost((p) => p['status'] == 'tampil');
          final menunggu = hitungPost((p) => p['status'] == 'menunggu');
          final kembali = hitungPost((p) => p['status'] == 'kembali');
          final hilangAktif = hitungPost(
            (p) => p['status'] == 'tampil' && p['jenis'] == 'hilang',
          );
          final temuanAktif = hitungPost(
            (p) => p['status'] == 'tampil' && p['jenis'] == 'temuan',
          );
          final diproses = posts.length - menunggu;
          final persen = diproses == 0 ? 0 : (kembali * 100 / diproses).round();

          final batas7 = DateTime.now().subtract(const Duration(days: 7));
          bool baru7(dynamic v) {
            final d = DateTime.tryParse((v ?? '').toString());
            return d != null && d.isAfter(batas7);
          }

          final postBaru7 = posts.where((x) => baru7(x['created_at'])).length;
          final klaimBaru7 = klaim.where((x) => baru7(x['created_at'])).length;
          final klaimMenunggu = klaim
              .where((x) => x['status'] == 'menunggu')
              .length;
          final klaimDitolak = klaim
              .where((x) => x['status'] == 'ditolak')
              .length;
          final sudahKembali = posts.where((x) => x['status'] == 'kembali');
          double rataHariKembali = 0;
          if (sudahKembali.isNotEmpty) {
            var totalJam = 0.0;
            var terhitung = 0;
            for (final x in sudahKembali) {
              final a = DateTime.tryParse((x['created_at'] ?? '').toString());
              final b = DateTime.tryParse((x['updated_at'] ?? '').toString());
              if (a != null && b != null) {
                totalJam += b.difference(a).inMinutes / 60.0;
                terhitung++;
              }
            }
            if (terhitung > 0) rataHariKembali = totalJam / terhitung / 24;
          }
          final perLokasi = <String, int>{};
          for (final x in posts) {
            final l = (x['lokasi'] ?? '').toString().trim();
            if (l.isNotEmpty) perLokasi[l] = (perLokasi[l] ?? 0) + 1;
          }
          final lokasiUrut = perLokasi.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final lokasiTop = lokasiUrut.isEmpty ? null : lokasiUrut.first;
          final perKategori = <String, int>{};
          for (final x in posts) {
            final k = (x['kategori'] ?? 'Lainnya').toString();
            perKategori[k] = (perKategori[k] ?? 0) + 1;
          }
          final kategoriUrut = perKategori.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final maksKategori = kategoriUrut.isEmpty
              ? 1
              : kategoriUrut.first.value;

          final namaUser = <String, String>{
            for (final u in users) (u['id'] ?? ''): (u['nama'] ?? '-'),
          };
          final perUser = <String, Map<String, int>>{};
          for (final p in posts) {
            final id = (p['user_id'] ?? '').toString();
            final m = perUser.putIfAbsent(
              id,
              () => {'posting': 0, 'kembali': 0, 'klaim_ok': 0, 'klaim_no': 0},
            );
            m['posting'] = m['posting']! + 1;
            if (p['status'] == 'kembali') m['kembali'] = m['kembali']! + 1;
          }
          for (final k in klaim) {
            final id = (k['user_id'] ?? '').toString();
            final m = perUser.putIfAbsent(
              id,
              () => {'posting': 0, 'kembali': 0, 'klaim_ok': 0, 'klaim_no': 0},
            );
            if (k['status'] == 'disetujui') {
              m['klaim_ok'] = m['klaim_ok']! + 1;
            } else if (k['status'] == 'ditolak') {
              m['klaim_no'] = m['klaim_no']! + 1;
            }
          }
          final peringkat = perUser.entries.toList()
            ..sort(
              (a, b) => (b.value['kembali']! + b.value['klaim_ok']!).compareTo(
                a.value['kembali']! + a.value['klaim_ok']!,
              ),
            );

          Widget kartu(String angka, String label, IconData ikon) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Icon(ikon, color: kBiru),
                    const SizedBox(height: 6),
                    Text(
                      angka,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      tr(label),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: kBiru,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(
                        '$persen%',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        tr('Tingkat Keberhasilan'),
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        kBahasa.value == 'en'
                            ? '$kembali of $diproses fully processed posts ended up back with their owners'
                            : '$kembali dari $diproses postingan yang selesai diproses berakhir kembali ke pemiliknya',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  kartu('${users.length}', 'Pengguna', Icons.people_outline),
                  kartu('$tampil', 'Tampil di Papan', Icons.dashboard_outlined),
                  kartu(
                    '$menunggu',
                    'Menunggu Moderasi',
                    Icons.hourglass_empty,
                  ),
                  kartu('$kembali', 'Sudah Kembali', Icons.verified_outlined),
                  kartu('$hilangAktif', 'Hilang Aktif', Icons.search_off),
                  kartu(
                    '$temuanAktif',
                    'Temuan Aktif',
                    Icons.find_in_page_outlined,
                  ),
                  kartu(
                    '$totalUp',
                    'Total Bantu UP',
                    Icons.arrow_circle_up_outlined,
                  ),
                  kartu(
                    '$totalDilihat',
                    'Total Dilihat',
                    Icons.visibility_outlined,
                  ),
                  kartu(
                    rataBintang == 0 ? '-' : rataBintang.toStringAsFixed(1),
                    'Rata-rata Bintang',
                    Icons.star_outline,
                  ),
                  kartu(
                    '$klaimDitolak',
                    'Klaim Ditolak',
                    Icons.block_outlined,
                  ),
                  kartu(
                    rataHariKembali == 0
                        ? '-'
                        : rataHariKembali.toStringAsFixed(1),
                    'Rata-rata Hari Kembali',
                    Icons.timelapse_outlined,
                  ),
                  kartu(
                    lokasiTop == null ? '-' : '${lokasiTop.value}',
                    lokasiTop == null
                        ? 'Lokasi Tersering'
                        : 'di ${lokasiTop.key}',
                    Icons.place_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tr('7 Hari Terakhir'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  kartu(
                    '$postBaru7',
                    'Postingan Baru',
                    Icons.post_add_outlined,
                  ),
                  kartu('$klaimBaru7', 'Klaim Baru', Icons.how_to_reg_outlined),
                  kartu(
                    '$klaimMenunggu',
                    'Klaim Menunggu',
                    Icons.pending_actions_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tr('Kategori Terbanyak'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (kategoriUrut.isEmpty) Text(tr('Belum ada aktivitas.')),
              for (final e in kategoriUrut.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 128,
                        child: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: e.value / maksKategori,
                            minHeight: 12,
                            color: kBiru,
                            backgroundColor: kBiru.withOpacity(0.12),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${e.value}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                tr('Aktivitas Pengguna'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  'Diurutkan dari yang paling banyak menghasilkan pengembalian barang.',
                ),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (peringkat.isEmpty) Text(tr('Belum ada aktivitas.')),
              for (final e in peringkat)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (namaUser[e.key] ?? '?').isNotEmpty
                            ? (namaUser[e.key] ?? '?')[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(namaUser[e.key] ?? 'Pengguna'),
                    subtitle: Text(
                      kBahasa.value == 'en'
                          ? '${e.value['posting']} posts - ${e.value['kembali']} returned - claims approved ${e.value['klaim_ok']} - claims rejected ${e.value['klaim_no']}'
                          : '${e.value['posting']} postingan - ${e.value['kembali']} kembali - klaim disetujui ${e.value['klaim_ok']} - klaim ditolak ${e.value['klaim_no']}',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined, color: kBiru),
                  title: Text(tr('Laporan Barang (PDF)')),
                  subtitle: Text(
                    tr('Semua barang dengan saringan bulan, jenis, status, dan kategori.'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LayarLaporanBarang()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('Kritik & Saran Terbaru'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (ulasan.isEmpty) Text(tr('Belum ada ulasan masuk.')),
              for (final u in ulasan)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(' ${u['bintang']}'),
                      ],
                    ),
                    title: Text(u['isi'] ?? ''),
                    subtitle: Text(
                      '${namaUser[(u['user_id'] ?? '').toString()] ?? 'Pengguna'} - ${fmtTanggal(u['created_at'])}',
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
