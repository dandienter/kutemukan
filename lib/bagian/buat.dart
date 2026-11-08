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

  // Lapor Cepat: satu kalimat cerita diuraikan menjadi isian formulir.
  final _cepat = TextEditingController();
  HasilLaporCepat? _hasilCepat;
  List<HasilCocok> _kandidatCepat = [];
  bool _sibukCepat = false;

  Future<void> _prosesCepat() async {
    final teks = _cepat.text.trim();
    if (teks.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Ceritakan sedikit lebih panjang dulu ya.')),
        ),
      );
      return;
    }
    final hasil = uraikanLaporCepat(teks);
    setState(() {
      _hasilCepat = hasil;
      _jenis = hasil.jenis;
      if (hasil.kategori != null && kKategori.contains(hasil.kategori)) {
        _kategori = hasil.kategori!;
      }
      if (hasil.judulUsulan != null && _judul.text.trim().isEmpty) {
        _judul.text = hasil.judulUsulan!;
      }
      if (hasil.lokasi != null && _lokasi.text.trim().isEmpty) {
        _lokasi.text = hasil.lokasi!;
      }
      if (_deskripsi.text.trim().isEmpty) _deskripsi.text = teks;
      if (hasil.waktu != null) _waktu = hasil.waktu!;
      _sibukCepat = true;
    });
    getarRingan();
    // Langsung carikan kandidat dari papan yang sedang tampil.
    try {
      final rows = await sb
          .from('lf_posts')
          .select(
            'id, user_id, jenis, status, judul, deskripsi, kategori, lokasi, created_at, foto_urls, foto_url',
          )
          .eq('status', 'tampil')
          .limit(200);
      final korpus = List<Map<String, dynamic>>.from(rows);
      final semu = <String, dynamic>{
        'jenis': hasil.jenis,
        'judul': hasil.judulUsulan ?? teks,
        'deskripsi': teks,
        'kategori': hasil.kategori ?? '',
        'lokasi': hasil.lokasi ?? '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      final mesin = MesinCocok(korpus);
      if (mounted) {
        setState(() {
          _kandidatCepat = mesin.cariCocok(semu, korpus);
          _sibukCepat = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sibukCepat = false);
    }
  }

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
                  'Perubahan tersimpan! Tunggu moderasi admin sebentar ya.',
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
          getarSedang();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Postinganmu terkirim! Tunggu moderasi admin sebentar ya, habis itu langsung tampil.',
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
        title: Text(tr(_modeUbah ? 'Ubah Postingan' : 'Buat Laporan')),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              children: [
                if (!_modeUbah) ...[
                  Card(
                    key: kunciPanduanCepat,
                    color: kBiru.withOpacity(0.07),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: kBiru.withOpacity(0.35)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bolt,
                                size: 19,
                                color: kBiru,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tr('Lapor Cepat'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(
                              'Ceritakan aja kejadiannya, nanti formulirnya kami isikan otomatis.',
                            ),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cepat,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: tr('Teks Bebas'),
                              hintText: tr(
                                'Contoh: dompet kulit cokelat saya hilang di parkiran Gedung B tadi pagi jam 9. Isinya KTP, KTM, sama kartu ATM.',
                              ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _sibukCepat ? null : _prosesCepat,
                              icon: const Icon(Icons.auto_fix_high, size: 18),
                              label: Text(tr('Ubah Jadi Laporan')),
                            ),
                          ),
                          if (_hasilCepat != null) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.flag, size: 15),
                                  label: Text(
                                    _hasilCepat!.jenis == 'hilang'
                                        ? tr('Kehilangan')
                                        : tr('Temuan'),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (_hasilCepat!.barang != null)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.inventory_2,
                                      size: 15,
                                    ),
                                    label: Text(_hasilCepat!.barang!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (_hasilCepat!.warna != null)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.palette,
                                      size: 15,
                                    ),
                                    label: Text(_hasilCepat!.warna!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (_hasilCepat!.lokasi != null)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.place,
                                      size: 15,
                                    ),
                                    label: Text(_hasilCepat!.lokasi!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (_hasilCepat!.waktuTeks != null)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.schedule,
                                      size: 15,
                                    ),
                                    label: Text(_hasilCepat!.waktuTeks!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            Text(
                              tr(
                                'Semua bidang di form ini hasil bacaan otomatis dan bisa langsung kamu ganti sebelum dikirim.',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                          if (_kandidatCepat.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              tr('Kayaknya salah satu ini yang kamu maksud:'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            for (final h in _kandidatCepat)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: daftarFoto(h.post).isEmpty
                                    ? const CircleAvatar(
                                        child: Icon(Icons.search, size: 17),
                                      )
                                    : ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Image.network(
                                          daftarFoto(h.post).first,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                title: Text(
                                  (h.post['judul'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${h.post['kategori'] ?? ''} - ${h.post['lokasi'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Chip(
                                  label: Text(
                                    '${(h.skor * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: kBiru,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LayarDetail(post: h.post),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _jenis = 'hilang'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _jenis == 'hilang' ? const Color(0xFFC62828) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _jenis == 'hilang' ? const Color(0xFFC62828) : Colors.grey.shade400),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 17, color: _jenis == 'hilang' ? Colors.white : Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(
                                tr('Saya Kehilangan'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: _jenis == 'hilang' ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _jenis = 'temuan'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _jenis == 'temuan' ? kBiruUtama : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _jenis == 'temuan' ? kBiruUtama : Colors.grey.shade400),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 17, color: _jenis == 'temuan' ? Colors.white : Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(
                                tr('Saya Menemukan'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: _jenis == 'temuan' ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${tr('Foto Barang')} (${tr('maks')} 5)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
                const SizedBox(height: 14),
                TextField(
                  controller: _judul,
                  decoration: _rapat(
                    tr('Judul (mis. Dompet hitam berisi KTM)'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child:
                DropdownButtonFormField<String>(
                  value: _kategori,
                  items: kKategori
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setState(() => _kategori = v!),
                  decoration: _rapat(tr('Kategori')),
                ),),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child:
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
                ),),
                  ],
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
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        tr('Detail rahasia tidak tampil ke publik. Laporanmu masuk antrean moderasi admin sebelum tayang.'),
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ),
                  ],
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
