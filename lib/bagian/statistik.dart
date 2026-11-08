part of '../main.dart';

// ===========================================================================
// Layar statistik (admin)
// ===========================================================================

class LayarStatistik extends StatefulWidget {
  /// Statistik publik hanya berisi angka gabungan postingan.
  /// Daftar pengguna, kritik & saran, dan laporan hanya untuk admin.
  final bool admin;
  const LayarStatistik({super.key, this.admin = false});

  @override
  State<LayarStatistik> createState() => _LayarStatistikState();
}

class _LayarStatistikState extends State<LayarStatistik> {
  late Future<Map<String, dynamic>> _fData = _hitung();

  Future<Map<String, dynamic>> _hitung() async {
    // Angka gabungan selalu dari lf_stat_lengkap (SECURITY DEFINER,
    // populasi tampil + kembali, sama seperti lf_stat_publik di Beranda)
    // supaya Statistik sinkron dengan kepala Beranda untuk semua peran.
    // Kueri baris langsung terkena RLS lf_posts (pengguna biasa hanya
    // melihat postingan tampil dan miliknya), jadi hanya dipakai untuk
    // seksi admin: peringkat pengguna dan daftar ulasan.
    final stat = Map<String, dynamic>.from(
      await sb.rpc('lf_stat_lengkap') as Map,
    );
    if (!widget.admin) {
      return {
        'stat': stat,
        'posts': <Map<String, dynamic>>[],
        'users': <Map<String, dynamic>>[],
        'klaim': <Map<String, dynamic>>[],
        'ulasan': <Map<String, dynamic>>[],
      };
    }
    final posts = List<Map<String, dynamic>>.from(
      await sb
          .from('lf_posts')
          .select(
            'user_id, jenis, status, up_count, views_count, kategori, created_at',
          ),
    );
    final users = List<Map<String, dynamic>>.from(
      await sb.from('lf_profiles').select('id, nama, foto_url'),
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
    return {
      'posts': posts,
      'users': users,
      'klaim': klaim,
      'ulasan': ulasan,
      'stat': stat,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Statistik'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fData,
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
          final stat = snap.data!['stat'] as Map<String, dynamic>;
          int ang(String k) => (stat[k] as num?)?.toInt() ?? 0;
          final totalUp = ang('total_up');
          final totalDilihat = ang('total_dilihat');
          final rataBintang = (stat['rata_bintang'] as num?)?.toDouble() ?? 0;

          final tampil = ang('tampil');
          final menunggu = ang('menunggu');
          final kembali = ang('kembali');
          final hilangAktif = ang('hilang_aktif');
          final temuanAktif = ang('temuan_aktif');
          final diproses = ang('total');
          final persen = diproses == 0 ? 0 : (kembali * 100 / diproses).round();

          final postBaru7 = ang('post_baru_7');
          final klaimBaru7 = ang('klaim_baru_7');
          final klaimMenunggu = ang('klaim_menunggu');
          final klaimDitolak = ang('klaim_ditolak');
          final rataHariKembali =
              (stat['rata_hari_kembali'] as num?)?.toDouble() ?? 0;
          final lokasiMentah = stat['lokasi_top'] as Map?;
          final lokasiTop = lokasiMentah == null
              ? null
              : MapEntry(
                  (lokasiMentah['lokasi'] ?? '').toString(),
                  (lokasiMentah['jumlah'] as num?)?.toInt() ?? 0,
                );
          final kategoriUrut = <MapEntry<String, int>>[];
          for (final k in (stat['kategori'] as List? ?? const [])) {
            final km = Map<String, dynamic>.from(k as Map);
            kategoriUrut.add(
              MapEntry(
                (km['kategori'] ?? 'Lainnya').toString(),
                (km['jumlah'] as num?)?.toInt() ?? 0,
              ),
            );
          }
          final maksKategori = kategoriUrut.isEmpty
              ? 1
              : kategoriUrut.first.value;

          final namaUser = <String, String>{
            for (final u in users) (u['id'] ?? ''): (u['nama'] ?? '-'),
          };
          final fotoUser = <String, String>{
            for (final u in users)
              (u['id'] ?? ''): (u['foto_url'] ?? '').toString(),
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                child: Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kBiruUtama.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(ikon, color: kBiruUtama, size: 18),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      angka,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
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

          return RefreshIndicator(
onRefresh: () async {
              setState(() => _fData = _hitung());
              await _fData;
            },
child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: const BoxDecoration(gradient: kGradasiKepala),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: (persen / 100).clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 84,
                              height: 84,
                              child: CircularProgressIndicator(
                                value: v,
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white24,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '$persen%',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_outlined,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tr('Tingkat Keberhasilan'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              kBahasa.value == 'en'
                                  ? '$kembali of $diproses fully processed posts ended up back with their owners'
                                  : '$kembali dari $diproses postingan yang selesai diproses berakhir kembali ke pemiliknya',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.92,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (widget.admin) kartu('${ang('jumlah_pengguna')}', 'Pengguna', Icons.people_outline),
                  kartu('$tampil', 'Tampil di Papan', Icons.dashboard_outlined),
                  if (widget.admin)
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
                  if (widget.admin)
                    kartu(
                      rataBintang == 0 ? '-' : rataBintang.toStringAsFixed(1),
                      'Rata-rata Bintang',
                      Icons.star_outline,
                    ),
                  if (widget.admin)
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
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kBiruUtama,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('7 Hari Terakhir'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.92,
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
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kBiruUtama,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('Kategori Terbanyak'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
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
                          borderRadius: BorderRadius.circular(99),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: e.value / maksKategori,
                            ),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 10,
                              color: kBiruUtama,
                              backgroundColor: kBiruUtama.withOpacity(0.12),
                            ),
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
              if (widget.admin) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kBiruUtama,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('Aktivitas Pengguna'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
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
              for (final e in peringkat.take(8))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: AvatarPengguna(nama: namaUser[e.key] ?? 'Pengguna', foto: fotoUser[e.key]),
                    title: Text(namaUser[e.key] ?? 'Pengguna'),
                    subtitle: Text(
                      kBahasa.value == 'en'
                          ? '${e.value['posting']} posts - ${e.value['kembali']} returned - claims approved ${e.value['klaim_ok']} - claims rejected ${e.value['klaim_no']}'
                          : '${e.value['posting']} postingan - ${e.value['kembali']} kembali - klaim disetujui ${e.value['klaim_ok']} - klaim ditolak ${e.value['klaim_no']}',
                    ),
                  ),
                ),
              if (peringkat.length > 8) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LayarPeringkatPengguna(
                        baris: [
                          for (final e in peringkat)
                            <String, dynamic>{
                              'nama': namaUser[e.key] ?? 'Pengguna',
                              'foto': fotoUser[e.key],
                              'posting': e.value['posting'],
                              'kembali': e.value['kembali'],
                              'klaim_ok': e.value['klaim_ok'],
                              'klaim_no': e.value['klaim_no'],
                            },
                        ],
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: Text(
                    '${tr('Lihat Semua')} (${peringkat.length})',
                  ),
                ),
              ],
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
            ],
          )
);
        },
      ),
    );
  }
}

/// Halaman penuh peringkat pengguna untuk admin: seluruh pengguna
/// beserta hitungan aktivitasnya, bisa dicari berdasarkan nama.
class LayarPeringkatPengguna extends StatefulWidget {
  final List<Map<String, dynamic>> baris;
  const LayarPeringkatPengguna({super.key, required this.baris});

  @override
  State<LayarPeringkatPengguna> createState() =>
      _LayarPeringkatPenggunaState();
}

class _LayarPeringkatPenggunaState extends State<LayarPeringkatPengguna> {
  String _cari = '';

  @override
  Widget build(BuildContext context) {
    final tampil = widget.baris
        .where(
          (b) => (b['nama'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_cari.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Peringkat Pengguna'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _cari = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('Cari nama pengguna'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: tampil.isEmpty
                ? Center(child: Text(tr('Tidak ada pengguna yang cocok.')))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: tampil.length,
                    itemBuilder: (_, i) {
                      final b = tampil[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: AvatarPengguna(
                            nama: (b['nama'] ?? 'Pengguna').toString(),
                            foto: b['foto']?.toString(),
                          ),
                          title: Text((b['nama'] ?? 'Pengguna').toString()),
                          subtitle: Text(
                            kBahasa.value == 'en'
                                ? '${b['posting']} posts - ${b['kembali']} returned - claims approved ${b['klaim_ok']} - claims rejected ${b['klaim_no']}'
                                : '${b['posting']} postingan - ${b['kembali']} kembali - klaim disetujui ${b['klaim_ok']} - klaim ditolak ${b['klaim_no']}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
