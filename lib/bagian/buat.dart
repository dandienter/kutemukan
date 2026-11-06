part of '../main.dart';

// ===========================================================================
// Layar buat dan ubah postingan
// ===========================================================================

class LayarBuat extends StatefulWidget {
  final Map<String, dynamic> profil;
  final Map<String, dynamic>? post;
  const LayarBuat({super.key, required this.profil, this.post});
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
  final List<String> _fotoLama = [];
  bool _sibuk = false;
  bool _samarkan = false;

  bool get _modeUbah => widget.post != null;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    if (p != null) {
      _jenis = (p['jenis'] ?? 'hilang').toString();
      final kat = (p['kategori'] ?? '').toString();
      if (kKategori.contains(kat)) _kategori = kat;
      _judul.text = (p['judul'] ?? '').toString();
      _deskripsi.text = (p['deskripsi'] ?? '').toString();
      _lokasi.text = (p['lokasi'] ?? '').toString();
      _penitipan.text = (p['penitipan'] ?? '').toString();
      _rahasia.text = (p['detail_rahasia'] ?? '').toString();
      _samarkan = p['samarkan_nama'] == true;
      final w = DateTime.tryParse((p['waktu_kejadian'] ?? '').toString());
      if (w != null) _waktu = w.toLocal();
      _fotoLama.addAll(daftarFoto(p));
    }
  }

  Future<void> _pilihFoto() async {
    if (_fotoLama.length + _foto.length >= 5) return;
    final sumber = await pilihSumberFoto(context);
    if (sumber == null || !mounted) return;
    if (sumber == ImageSource.camera) {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 78,
      );
      if (x == null) return;
      setState(() {
        if (_fotoLama.length + _foto.length < 5) _foto.add(File(x.path));
      });
      return;
    }
    final xs = await ImagePicker().pickMultiImage(imageQuality: 78, limit: 5);
    if (xs.isEmpty) return;
    setState(() {
      for (final x in xs) {
        if (_fotoLama.length + _foto.length < 5) _foto.add(File(x.path));
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
      final urls = <String>[..._fotoLama];
      for (final f in _foto) {
        urls.add(await unggahBerkas(await kompresKeWebp(f)));
      }
      final isi = <String, dynamic>{
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
        'samarkan_nama':
            _samarkan && widget.profil['terverifikasi'] == true,
      };
      if (_modeUbah) {
        final statusLama = (widget.post!['status'] ?? '').toString();
        if (statusLama == 'tampil' || statusLama == 'ditolak') {
          isi['status'] = 'menunggu';
        }
        isi['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await sb.from('lf_posts').update(isi).eq('id', widget.post!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'Perubahan tersimpan. Menunggu moderasi admin sebelum tampil.',
                ),
              ),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        isi['user_id'] = sb.auth.currentUser!.id;
        await sb.from('lf_posts').insert(isi);
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
          setState(() {
            _foto.clear();
            _fotoLama.clear();
          });
        }
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
      appBar: AppBar(
        title: Text(tr(_modeUbah ? 'Ubah Postingan' : 'Buat Postingan')),
      ),
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
                if (widget.profil['terverifikasi'] == true) ...[
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Samarkan nama saya')),
                    subtitle: Text(
                      tr(
                        'Nama dan foto profil tidak ditampilkan pada postingan ini. Identitas terverifikasi tetap tercatat untuk keamanan.',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _samarkan,
                    onChanged: (v) => setState(() => _samarkan = v),
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
                      for (var i = 0; i < _fotoLama.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _fotoLama[i],
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 78,
                                    height: 78,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _fotoLama.removeAt(i)),
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
                              if (i == 0 && _fotoLama.isEmpty)
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
                        onTap: _fotoLama.length + _foto.length >= 5
                            ? null
                            : _pilihFoto,
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
                                '${tr('Foto')} ${_fotoLama.length + _foto.length}/5',
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
                  _sibuk
                      ? tr('Mengirim...')
                      : _modeUbah
                      ? tr('Simpan Perubahan')
                      : tr('Kirim untuk Moderasi'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
