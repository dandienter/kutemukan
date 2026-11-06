part of '../main.dart';

// ===========================================================================
// Layar laporan barang (admin): saringan + unduh PDF
// ===========================================================================

class LayarLaporanBarang extends StatefulWidget {
  const LayarLaporanBarang({super.key});
  @override
  State<LayarLaporanBarang> createState() => _LayarLaporanBarangState();
}

class _LayarLaporanBarangState extends State<LayarLaporanBarang> {
  List<Map<String, dynamic>> _semua = [];
  bool _muat = true;
  bool _buatPdf = false;
  DateTime? _bulan;
  String _jenis = 'semua';
  String _status = 'semua';
  String _kategori = 'semua';

  static const _namaBulanId = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  static const _namaBulanEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<DateTime> get _pilihanBulan {
    final kini = DateTime.now();
    return List.generate(12, (i) => DateTime(kini.year, kini.month - i));
  }

  String _labelBulan(DateTime d) {
    final nama = (kBahasa.value == 'en' ? _namaBulanEn : _namaBulanId)[d.month - 1];
    return '$nama ${d.year}';
  }

  @override
  void initState() {
    super.initState();
    _ambil();
  }

  Future<void> _ambil() async {
    try {
      final data = await sb
          .from('lf_posts')
          .select(
            'judul, jenis, kategori, lokasi, waktu_kejadian, penitipan, status, created_at',
          )
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _semua = List<Map<String, dynamic>>.from(data);
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
    return _semua.where((p) {
      if (_bulan != null) {
        final d = DateTime.tryParse((p['created_at'] ?? '').toString());
        if (d == null || d.year != _bulan!.year || d.month != _bulan!.month) {
          return false;
        }
      }
      if (_jenis != 'semua' && p['jenis'] != _jenis) return false;
      if (_status != 'semua' && p['status'] != _status) return false;
      if (_kategori != 'semua' && p['kategori'] != _kategori) return false;
      return true;
    }).toList();
  }

  String _labelJenis(String j) => j == 'hilang' ? tr('Kehilangan') : tr('Temuan');

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
      default:
        return s;
    }
  }

  String _tanggal(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    if (d == null) return '-';
    final l = d.toLocal();
    String dua(int x) => x.toString().padLeft(2, '0');
    return '${dua(l.day)}/${dua(l.month)}/${l.year}';
  }

  Future<void> _unduhPdf() async {
    final hasil = _hasil;
    if (hasil.isEmpty) return;
    setState(() => _buatPdf = true);
    try {
      final hilang = hasil.where((p) => p['jenis'] == 'hilang').length;
      final temuan = hasil.length - hilang;
      final kembali = hasil.where((p) => p['status'] == 'kembali').length;
      final periode = _bulan == null ? tr('Semua bulan') : _labelBulan(_bulan!);
      final saringan =
          '${tr('Periode')}: $periode | ${tr('Jenis')}: ${_jenis == 'semua' ? tr('Semua') : _labelJenis(_jenis)} | '
          '${tr('Status')}: ${_status == 'semua' ? tr('Semua') : _labelStatus(_status)} | '
          '${tr('Kategori')}: ${_kategori == 'semua' ? tr('Semua') : _kategori}';
      final doc = pw.Document();
      final gayaJudulSel = pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8.5,
        color: PdfColors.white,
      );
      final gayaSel = const pw.TextStyle(fontSize: 8.5);
      pw.Widget sel(String teks, {pw.TextStyle? gaya}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(teks, style: gaya ?? gayaSel),
      );
      final baris = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            sel('No', gaya: gayaJudulSel),
            sel(tr('Tanggal'), gaya: gayaJudulSel),
            sel(tr('Barang'), gaya: gayaJudulSel),
            sel(tr('Jenis'), gaya: gayaJudulSel),
            sel(tr('Kategori'), gaya: gayaJudulSel),
            sel(tr('Lokasi'), gaya: gayaJudulSel),
            sel(tr('Status'), gaya: gayaJudulSel),
          ],
        ),
      ];
      for (var i = 0; i < hasil.length; i++) {
        final p = hasil[i];
        final lokasi = (p['lokasi'] ?? '-').toString();
        final titip = (p['penitipan'] ?? '').toString().trim();
        baris.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? PdfColors.grey100 : PdfColors.white,
            ),
            children: [
              sel('${i + 1}'),
              sel(_tanggal(p['waktu_kejadian'] ?? p['created_at'])),
              sel((p['judul'] ?? '-').toString()),
              sel(_labelJenis((p['jenis'] ?? '').toString())),
              sel((p['kategori'] ?? '-').toString()),
              sel(titip.isEmpty ? lokasi : '$lokasi\n${tr('Dititipkan')}: $titip'),
              sel(_labelStatus((p['status'] ?? '').toString())),
            ],
          ),
        );
      }
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${tr('Halaman')} ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (_) => [
            pw.Text(
              'KutemuKan',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.Text(
              tr('Laporan Barang - Lost and Found Kampus UNINDRA'),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(saringan, style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
              '${tr('Dibuat')}: ${_tanggal(DateTime.now().toIso8601String())} | '
              '${tr('Total')}: ${hasil.length} (${tr('Kehilangan')} $hilang, ${tr('Temuan')} $temuan, ${tr('Sudah Kembali')} $kembali)',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FixedColumnWidth(56),
                2: pw.FlexColumnWidth(3),
                3: pw.FixedColumnWidth(58),
                4: pw.FixedColumnWidth(72),
                5: pw.FlexColumnWidth(2),
                6: pw.FixedColumnWidth(56),
              },
              children: baris,
            ),
          ],
        ),
      );
      final bytes = await doc.save();
      final labelPeriode = _bulan == null
          ? 'semua'
          : '${_bulan!.year}-${_bulan!.month.toString().padLeft(2, '0')}';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'laporan-kutemukan-$labelPeriode.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('PDF gagal dibuat')}: $e')),
        );
      }
    }
    if (mounted) setState(() => _buatPdf = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasil = _hasil;
    final hilang = hasil.where((p) => p['jenis'] == 'hilang').length;
    final kembali = hasil.where((p) => p['status'] == 'kembali').length;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Laporan Barang'))),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<DateTime?>(
                              value: _bulan,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: tr('Bulan'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem<DateTime?>(
                                  value: null,
                                  child: Text(tr('Semua bulan')),
                                ),
                                for (final b in _pilihanBulan)
                                  DropdownMenuItem<DateTime?>(
                                    value: b,
                                    child: Text(_labelBulan(b)),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _bulan = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _jenis,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: tr('Jenis'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'semua',
                                  child: Text(tr('Semua')),
                                ),
                                DropdownMenuItem(
                                  value: 'hilang',
                                  child: Text(tr('Kehilangan')),
                                ),
                                DropdownMenuItem(
                                  value: 'temuan',
                                  child: Text(tr('Temuan')),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _jenis = v ?? 'semua'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: tr('Status'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'semua',
                                  child: Text(tr('Semua')),
                                ),
                                for (final s in [
                                  'tampil',
                                  'menunggu',
                                  'kembali',
                                  'ditolak',
                                  'arsip',
                                ])
                                  DropdownMenuItem(
                                    value: s,
                                    child: Text(_labelStatus(s)),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _status = v ?? 'semua'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _kategori,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: tr('Kategori'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'semua',
                                  child: Text(tr('Semua')),
                                ),
                                for (final k in kKategori)
                                  DropdownMenuItem(value: k, child: Text(k)),
                              ],
                              onChanged: (v) =>
                                  setState(() => _kategori = v ?? 'semua'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${hasil.length} ${tr('barang sesuai saringan')} ($hilang ${tr('Kehilangan')}, ${hasil.length - hilang} ${tr('Temuan')}, $kembali ${tr('Sudah Kembali')})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (_buatPdf || hasil.isEmpty)
                              ? null
                              : _unduhPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(
                            _buatPdf ? tr('Membuat PDF...') : tr('Unduh PDF'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: hasil.isEmpty
                      ? Center(child: Text(tr('Tidak ada barang yang cocok.')))
                      : ListView.builder(
                          itemCount: hasil.length,
                          itemBuilder: (_, i) {
                            final p = hasil[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                p['jenis'] == 'hilang'
                                    ? Icons.search_off
                                    : Icons.find_in_page_outlined,
                                color: kBiru,
                              ),
                              title: Text((p['judul'] ?? '-').toString()),
                              subtitle: Text(
                                '${_labelJenis((p['jenis'] ?? '').toString())} - ${(p['kategori'] ?? '-').toString()} - ${(p['lokasi'] ?? '-').toString()}',
                              ),
                              trailing: Text(
                                _labelStatus((p['status'] ?? '').toString()),
                                style: const TextStyle(fontSize: 11),
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
