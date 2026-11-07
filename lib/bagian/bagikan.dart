part of '../main.dart';

// ===========================================================================
// Layar bagikan kartu postingan
// ===========================================================================

class LayarBagikan extends StatefulWidget {
  final Map<String, dynamic> post;
  const LayarBagikan({super.key, required this.post});
  @override
  State<LayarBagikan> createState() => _LayarBagikanState();
}

class _LayarBagikanState extends State<LayarBagikan> {
  final GlobalKey _kunciKartu = GlobalKey();
  bool _sibuk = false;

  Future<void> _bagikan() async {
    setState(() => _sibuk = true);
    try {
      final batas =
          _kunciKartu.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final gambar = await batas.toImage(pixelRatio: 3.0);
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final p = widget.post;
      final teks = StringBuffer()
        ..writeln(
          '${p['jenis'] == 'hilang' ? 'BARANG HILANG' : 'BARANG TEMUAN'}: ${p['judul']}',
        )
        ..writeln('Kategori: ${p['kategori']} - Lokasi: ${p['lokasi']}')
        ..writeln('Waktu: ${fmtTanggal(p['waktu_kejadian'])}')
        ..writeln()
        ..writeln(
          'Kenali barang ini? Klaim atau bantu sebarkan lewat aplikasi KutemuKan, Lost and Found Kampus Unindra.',
        )
        ..write(
          'Lihat detailnya: http://demo.43-130-228-96.sslip.io/kutemukan-web/?post=${p['id']}',
        );
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          name: 'kutemukan-${p['id']}.png',
          mimeType: 'image/png',
        ),
      ], text: teks.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Gagal menyiapkan kartu')}: $e')),
        );
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final hilang = p['jenis'] == 'hilang';
    final foto = daftarFoto(p);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Bagikan Postingan'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: RepaintBoundary(
              key: _kunciKartu,
              child: Container(
                width: 340,
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: kBiru,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Image.asset('assets/icon.png', height: 30),
                          const SizedBox(width: 8),
                          const Text(
                            'KutemuKan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: hilang ? Colors.red : Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hilang ? 'HILANG' : 'TEMUAN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (foto.isNotEmpty)
                      Image.network(
                        foto.first,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 60,
                          child: Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['judul'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${p['kategori']} - ${p['lokasi']}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          Text(
                            '${tr('Waktu')}: ${fmtTanggal(p['waktu_kejadian'])}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (p['deskripsi'] ?? '').toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87),
                          ),
                          const Divider(height: 22),
                          Text(
                            tr(
                              'Lost and Found Kampus Unindra - buka aplikasi KutemuKan untuk klaim atau bantu UP',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sibuk ? null : _bagikan,
            icon: const Icon(Icons.share),
            label: Text(_sibuk ? 'Menyiapkan...' : 'Bagikan Sekarang'),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Kartu ini tidak memuat ciri khusus rahasia dan nomor WhatsApp siapa pun.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
