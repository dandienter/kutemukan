part of '../main.dart';

// ===========================================================================
// Layar menu admin: pintu khusus admin ke semua alat pengelolaan.
// Hanya dirender untuk akun berperan admin (dari halaman Akun).
// ===========================================================================

class LayarMenuAdmin extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarMenuAdmin({super.key, required this.profil});
  @override
  State<LayarMenuAdmin> createState() => _LayarMenuAdminState();
}

class _LayarMenuAdminState extends State<LayarMenuAdmin> {
  int _antreModerasi = 0;
  int _jumlahLaporan = 0;
  int _jumlahBarang = 0;
  int _jumlahPengguna = 0;

  @override
  void initState() {
    super.initState();
    _ambilRingkasan();
  }

  Future<int> _hitung(String tabel, {String? kolom, String? nilai}) async {
    try {
      var q = sb.from(tabel).select('id');
      if (kolom != null) q = q.eq(kolom, nilai!);
      final rows = await q;
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _ambilRingkasan() async {
    final m = await _hitung('lf_posts', kolom: 'status', nilai: 'menunggu');
    final l = await _hitung('lf_laporan');
    final b = await _hitung('lf_posts');
    final u = await _hitung('lf_profiles');
    if (mounted) {
      setState(() {
        _antreModerasi = m;
        _jumlahLaporan = l;
        _jumlahBarang = b;
        _jumlahPengguna = u;
      });
    }
  }

  void _buka(Widget layar) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => layar))
        .then((_) => _ambilRingkasan());
  }

  Widget _kartuMenu({
    required IconData ikon,
    required Color warna,
    required String judul,
    required String sub,
    required VoidCallback aksi,
    int lencana = 0,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: warna.withOpacity(0.13),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(ikon, color: warna, size: 23),
        ),
        title: Text(judul, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12.5)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lencana > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$lencana',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, size: 19, color: Colors.grey),
          ],
        ),
        onTap: aksi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profil = widget.profil;
    final nama = (profil['nama'] ?? 'Admin').toString();
    final inisial = nama.trim().isEmpty
        ? 'A'
        : nama.trim().split(' ').map((k) => k[0]).take(2).join().toUpperCase();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Menu Admin'))),
      body: RefreshIndicator(
        onRefresh: _ambilRingkasan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC53D),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      inisial,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('Akses penuh ke semua data KutemuKan'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      border: Border.all(color: Colors.white38),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: Color(0xFFFFC53D),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tr('Admin'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              tr('Kelola Aplikasi').toUpperCase(),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            _kartuMenu(
              ikon: Icons.inventory_2_outlined,
              warna: kBiruUtama,
              judul: tr('Semua Barang'),
              sub:
                  '$_jumlahBarang ${tr('postingan')} - ${tr('ubah status, sunting, hapus')}',
              aksi: () => _buka(LayarSemuaBarang(profil: profil)),
            ),
            _kartuMenu(
              ikon: Icons.description_outlined,
              warna: const Color(0xFFE65100),
              judul: tr('Laporan'),
              sub: tr('Rekap barang dan cetak PDF'),
              aksi: () => _buka(const LayarLaporanBarang()),
            ),
            _kartuMenu(
              ikon: Icons.people_alt_outlined,
              warna: const Color(0xFF2E7D32),
              judul: tr('Pengguna'),
              sub:
                  '$_jumlahPengguna ${tr('akun')} - ${tr('verifikasi, peran, nonaktifkan')}',
              aksi: () => _buka(const LayarPenggunaAdmin()),
            ),
            _kartuMenu(
              ikon: Icons.shield_outlined,
              warna: const Color(0xFFC2185B),
              judul: tr('Moderasi'),
              sub: tr('Antrean laporan dan sengketa klaim'),
              lencana: _antreModerasi,
              aksi: () => _buka(const LayarModerasi()),
            ),
            _kartuMenu(
              ikon: Icons.flag_outlined,
              warna: const Color(0xFF6A1B9A),
              judul: tr('Laporan Pengguna'),
              sub: tr('Postingan yang dilaporkan bermasalah'),
              lencana: _jumlahLaporan,
              aksi: () => _buka(const LayarLaporan()),
            ),
            _kartuMenu(
              ikon: Icons.bar_chart_outlined,
              warna: const Color(0xFF5E35B1),
              judul: tr('Statistik'),
              sub: tr('Pengguna, keberhasilan, dan aktivitas klaim'),
              aksi: () => _buka(const LayarStatistik(admin: true)),
            ),
            _kartuMenu(
              ikon: Icons.campaign_outlined,
              warna: const Color(0xFFF9A825),
              judul: tr('Pengumuman'),
              sub: tr('Buat dan kelola pengumuman komunitas'),
              aksi: () => _buka(const LayarPengumuman(admin: true)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tr(
                  'Menu ini hanya muncul di akun berperan admin. Pengguna biasa tidak melihatnya.',
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF7A5B12),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
