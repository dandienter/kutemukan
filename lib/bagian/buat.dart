part of '../main.dart';

// ===========================================================================
// Layar buat dan ubah postingan
// ===========================================================================

class LayarBuat extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarBuat({super.key, required this.profil});
  @override
  State<LayarBuat> createState() => _LayarBuatState();
}

class _LayarBuatState extends State<LayarBuat> {
  String _jenis = 'hilang';
  String _kategori = kKategori.first;
  final _judul = TextEditingController();
  final _deskripsi = TextEditingController();
  final _lokasi = TextEditingController();
  final _penitipan = TextEditingController();
  final _rahasia = TextEditingController();
  DateTime _waktu = DateTime.now();
  final List<File> _foto = [];
  bool _sibuk = false;

  Future<void> _pilihFoto() async {
    if (_foto.length >= 5) return;
    final xs = await ImagePicker().pickMultiImage(imageQuality: 78, limit: 5);
    if (xs.isEmpty) return;
    setState(() {
      for (final x in xs) {
        if (_foto.length < 5) _foto.add(File(x.path));
      }
    });
  }

  Future<void> _kirim() async {
    if (_judul.text.trim().isEmpty || _lokasi.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Judul dan lokasi wajib diisi.'))),
      );
      return;
    }
    setState(() => _sibuk = true);
    try {
      final urls = <String>[];
      for (final f in _foto) {
        urls.add(await unggahBerkas(await kompresKeWebp(f)));
      }
      await sb.from('lf_posts').insert({
        'user_id': sb.auth.currentUser!.id,
        'jenis': _jenis,
        'judul': _judul.text.trim(),
        'kategori': _kategori,
        'deskripsi': _deskripsi.text.trim(),
        'lokasi': _lokasi.text.trim(),
        'waktu_kejadian': _waktu.toUtc().toIso8601String(),
        'foto_url': urls.isEmpty ? null : urls.first,
        'foto_urls': urls,
        'detail_rahasia': _rahasia.text.trim().isEmpty
            ? null
            : _rahasia.text.trim(),
        'penitipan': _jenis == 'temuan' ? _penitipan.text.trim() : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Postingan terkirim. Menunggu moderasi admin sebelum tampil.',
            ),
          ),
        );
        _judul.clear();
        _deskripsi.clear();
        _lokasi.clear();
        _penitipan.clear();
        _rahasia.clear();
        setState(() => _foto.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('Gagal mengirim')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  InputDecoration _rapat(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Buat Postingan'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'hilang',
                      label: Text(tr('Saya Kehilangan')),
                    ),
                    ButtonSegment(
                      value: 'temuan',
                      label: Text(tr('Saya Menemukan')),
                    ),
                  ],
                  selected: {_jenis},
                  onSelectionChanged: (s) => setState(() => _jenis = s.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _judul,
                  decoration: _rapat(
                    tr('Judul (mis. Dompet hitam berisi KTM)'),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _kategori,
                  items: kKategori
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setState(() => _kategori = v!),
                  decoration: _rapat(tr('Kategori')),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final tgl = await showDatePicker(
                      context: context,
                      initialDate: _waktu,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now(),
                    );
                    if (tgl == null || !mounted) return;
                    final jam = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_waktu),
                    );
                    if (!mounted) return;
                    setState(
                      () => _waktu = DateTime(
                        tgl.year,
                        tgl.month,
                        tgl.day,
                        jam?.hour ?? _waktu.hour,
                        jam?.minute ?? _waktu.minute,
                      ),
                    );
                  },
                  child: InputDecorator(
                    decoration: _rapat(tr('Waktu')),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(fmtTanggal(_waktu.toIso8601String())),
                        ),
                        const Icon(
                          Icons.edit_calendar_outlined,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _lokasi,
                  decoration: _rapat(tr('Lokasi (hilang / ditemukan)')),
                ),
                if (_jenis == 'temuan') ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _penitipan,
                    decoration: _rapat(
                      tr('Barang dititipkan di (mis. pos satpam)'),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _deskripsi,
                  maxLines: 2,
                  decoration: _rapat(
                    tr('Deskripsi dan ciri-ciri (tampil publik)'),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _rahasia,
                  maxLines: 2,
                  decoration: _rapat(
                    tr('Ciri khusus rahasia'),
                    hint: tr('Tidak tampil publik, untuk verifikasi klaim'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 78,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < _foto.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _foto[i],
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _foto.removeAt(i)),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.red,
                                    child: Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (i == 0)
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: Chip(
                                    label: Text(
                                      tr('Sampul'),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: kBiru,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      InkWell(
                        onTap: _foto.length >= 5 ? null : _pilihFoto,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tr('Foto')} ${_foto.length}/5',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sibuk ? null : _kirim,
                child: Text(
                  _sibuk ? tr('Mengirim...') : tr('Kirim untuk Moderasi'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
