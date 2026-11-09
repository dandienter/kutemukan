part of '../main.dart';

// ===========================================================================
// Layar semua barang (admin): kelola seluruh postingan pengguna.
// Admin bisa mengubah status, menyunting, dan menghapus postingan siapa
// pun (haknya diatur kebijakan lf_posts_update/delete untuk admin).
// ===========================================================================

class LayarSemuaBarang extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarSemuaBarang({super.key, required this.profil});
  @override
  State<LayarSemuaBarang> createState() => _LayarSemuaBarangState();
}

class _LayarSemuaBarangState extends State<LayarSemuaBarang> {
  List<Map<String, dynamic>> _semua = [];
  bool _muat = true;
  String _status = 'semua';
  final _cari = TextEditingController();

  static const _daftarStatus = [
    'tampil',
    'menunggu',
    'kembali',
    'ditolak',
    'arsip',
    'musnah_hibah',
  ];

  @override
  void initState() {
    super.initState();
    _ambil();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  String _labelStatus(String s) {
    switch (s) {
      case 'tampil':
        return tr('Tampil');
      case 'menunggu':
        return tr('Menunggu');
      case 'kembali':
        return tr('Sudah Kembali');
      case 'ditolak':
        return tr('Ditolak');
      case 'arsip':
        return tr('Arsip');
      case 'musnah_hibah':
        return tr('Musnah/Hibah');
      default:
        return s;
    }
  }

  Color _warnaStatus(String s) {
    switch (s) {
      case 'tampil':
        return const Color(0xFF1565C0);
      case 'menunggu':
        return const Color(0xFFE65100);
      case 'kembali':
        return const Color(0xFF2E7D32);
      case 'ditolak':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Future<void> _ambil() async {
    setState(() => _muat = true);
    try {
      final rows = await sb
          .from('lf_posts')
          .select()
          .order('created_at', ascending: false);
      final data = List<Map<String, dynamic>>.from(rows);
      // Admin melihat nama asli pemilik, abaikan penyamaran nama.
      var terpasang = false;
      try {
        final ids = data
            .map((r) => (r['user_id'] ?? '').toString())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        if (ids.isNotEmpty) {
          final pr = await sb
              .from('lf_profiles')
              .select('id, nama, nama_tampilan, foto_url')
              .inFilter('id', ids);
          final peta = {
            for (final p in pr) (p['id'] ?? '').toString(): p,
          };
          for (final r in data) {
            final pub = peta[(r['user_id'] ?? '').toString()];
            if (pub != null) {
              final t = (pub['nama_tampilan'] ?? '').toString().trim();
              r['nama_pemilik'] = t.isNotEmpty ? t : pub['nama'];
              r['foto_pemilik'] = pub['foto_url'];
              terpasang = true;
            }
          }
        }
      } catch (_) {}
      if (!terpasang) await pasangNama(data);
      if (mounted) {
        setState(() {
          _semua = data;
          _muat = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _muat = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('Gagal memuat')}: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _hasil {
    final kata = _cari.text.trim().toLowerCase();
    return _semua.where((p) {
      if (_status != 'semua' && p['status'] != _status) return false;
      if (kata.isEmpty) return true;
      final gabung =
          '${p['judul'] ?? ''} ${p['nama_pemilik'] ?? ''} ${p['lokasi'] ?? ''}'
              .toLowerCase();
      return gabung.contains(kata);
    }).toList();
  }

  String _tanggal(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    if (d == null) return '-';
    final l = d.toLocal();
    String dua(int x) => x.toString().padLeft(2, '0');
    return '${dua(l.day)}/${dua(l.month)}/${l.year}';
  }

  Future<void> _ubahStatus(Map<String, dynamic> p) async {
    final sekarang = (p['status'] ?? '').toString();
    final pilih = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('Ubah Status'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            for (final s in _daftarStatus)
              ListTile(
                leading: Icon(
                  s == sekarang
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _warnaStatus(s),
                ),
                title: Text(_labelStatus(s)),
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );
    if (pilih == null || pilih == sekarang || !mounted) return;
    try {
      await sb.from('lf_posts').update({
        'status': pilih,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', p['id']);
      setState(() => p['status'] = pilih);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('Status diubah ke')} ${_labelStatus(pilih)}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('Gagal')}: $e')));
      }
    }
  }

  Future<void> _sunting(Map<String, dynamic> p) async {
    final berubah = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LayarBuat(profil: widget.profil, post: p, olehAdmin: true),
      ),
    );
    if (berubah == true) _ambil();
  }

  Future<void> _hapus(Map<String, dynamic> p) async {
    final jadi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Hapus postingan ini?')),
        content: Text(
          '${p['judul'] ?? ''}\n\n${tr('Postingan yang dihapus tidak bisa dikembalikan. Klaim dan komentar terkait ikut terhapus.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Hapus')),
          ),
        ],
      ),
    );
    if (jadi != true) return;
    try {
      await sb.from('lf_posts').delete().eq('id', p['id']);
      setState(() => _semua.removeWhere((x) => x['id'] == p['id']));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('Postingan dihapus.'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('Gagal')}: $e')));
      }
    }
  }

  Widget _miniStat(String label, int nilai, Color warna) {
    final aktif = _status == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('${_labelChip(label)} ($nilai)'),
        selected: aktif,
        onSelected: (_) => setState(() => _status = label),
        labelStyle: TextStyle(
          color: aktif ? Colors.white : warna,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        selectedColor: warna,
        side: BorderSide(color: warna.withOpacity(0.4)),
      ),
    );
  }

  String _labelChip(String s) =>
      s == 'semua' ? tr('Semua') : _labelStatus(s);

  @override
  Widget build(BuildContext context) {
    final hasil = _hasil;
    final hitung = <String, int>{
      'semua': _semua.length,
      for (final s in _daftarStatus)
        s: _semua.where((p) => p['status'] == s).length,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Semua Barang')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _muat ? null : _ambil,
          ),
        ],
      ),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: TextField(
                    controller: _cari,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: tr('Cari nama barang atau pelapor'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      _miniStat('semua', hitung['semua']!, kBiruUtama),
                      for (final s in _daftarStatus)
                        _miniStat(s, hitung[s]!, _warnaStatus(s)),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: Text(
                      '${tr('Menampilkan')} ${hasil.length} ${tr('barang dari semua pengguna')}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  child: hasil.isEmpty
                      ? Center(child: Text(tr('Tidak ada barang yang cocok.')))
                      : ListView.builder(
                          itemCount: hasil.length,
                          padding: const EdgeInsets.only(bottom: 12),
                          itemBuilder: (_, i) {
                            final p = hasil[i];
                            final foto = daftarFoto(p);
                            final status = (p['status'] ?? '').toString();
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(11),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                LayarDetail(post: p),
                                          ),
                                        );
                                        _ambil();
                                      },
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: foto.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: foto.first,
                                                    width: 62,
                                                    height: 62,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        _kotakIkon(p),
                                                    placeholder: (_, __) =>
                                                        _kotakIkon(p),
                                                  )
                                                : _kotakIkon(p),
                                          ),
                                          const SizedBox(width: 11),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (p['judul'] ?? '-').toString(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${p['nama_pemilik'] ?? '-'} - ${(p['lokasi'] ?? '-').toString()}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                Text(
                                                  _tanggal(
                                                    p['waktu_kejadian'] ??
                                                        p['created_at'],
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _warnaStatus(
                                                status,
                                              ).withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _labelStatus(status),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: _warnaStatus(status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Row(
                                      children: [
                                        _tombolAksi(
                                          Icons.refresh,
                                          tr('Status'),
                                          kBiruUtama,
                                          () => _ubahStatus(p),
                                        ),
                                        const SizedBox(width: 8),
                                        _tombolAksi(
                                          Icons.edit_outlined,
                                          tr('Sunting'),
                                          const Color(0xFF455A64),
                                          () => _sunting(p),
                                        ),
                                        const SizedBox(width: 8),
                                        _tombolAksi(
                                          Icons.delete_outline,
                                          tr('Hapus'),
                                          const Color(0xFFC62828),
                                          () => _hapus(p),
                                        ),
                                      ],
                                    ),
                                  ],
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

  Widget _kotakIkon(Map<String, dynamic> p) {
    return Container(
      width: 62,
      height: 62,
      color: kBiruUtama.withOpacity(0.12),
      alignment: Alignment.center,
      child: Icon(
        p['jenis'] == 'hilang'
            ? Icons.search_off
            : Icons.find_in_page_outlined,
        color: kBiruUtama,
        size: 28,
      ),
    );
  }

  Widget _tombolAksi(
    IconData ikon,
    String label,
    Color warna,
    VoidCallback aksi,
  ) {
    return TextButton.icon(
      onPressed: aksi,
      icon: Icon(ikon, size: 16, color: warna),
      label: Text(label, style: TextStyle(color: warna, fontSize: 12.5)),
      style: TextButton.styleFrom(
        backgroundColor: warna.withOpacity(0.09),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
