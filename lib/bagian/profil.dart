part of '../main.dart';

// ===========================================================================
// Layar edit profil
// ===========================================================================

class LayarProfil extends StatefulWidget {
  final Map<String, dynamic>? profilAwal;
  const LayarProfil({super.key, this.profilAwal});
  @override
  State<LayarProfil> createState() => _LayarProfilState();
}

class _LayarProfilState extends State<LayarProfil> {
  final _nama = TextEditingController();
  final _wa = TextEditingController();
  bool _sibuk = false;
  bool _fotoDihapus = false;
  String? _fotoUrl;
  File? _fotoBaru;

  bool get _modeEdit => widget.profilAwal != null;

  @override
  void initState() {
    super.initState();
    final awal = widget.profilAwal;
    if (awal != null) {
      _nama.text = awal['nama'] ?? '';
      _wa.text = awal['wa'] ?? '';
      _fotoUrl = awal['foto_url'] as String?;
    } else {
      final meta = sb.auth.currentUser?.userMetadata;
      final namaGoogle = meta?['full_name'] ?? meta?['name'];
      if (namaGoogle is String && namaGoogle.isNotEmpty) {
        _nama.text = namaGoogle;
      }
    }
  }

  Future<void> _pilihFoto() async {
    final sumber = await pilihSumberFoto(context);
    if (sumber == null || !mounted) return;
    final x = await ImagePicker().pickImage(source: sumber, imageQuality: 85);
    if (x != null) {
      setState(() {
        _fotoBaru = File(x.path);
        _fotoDihapus = false;
      });
    }
  }

  Future<void> _hapusFoto() async {
    final jadi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Hapus Foto')),
        content: Text(
          tr('Foto profil akan dihapus dan diganti avatar inisial.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Hapus')),
          ),
        ],
      ),
    );
    if (jadi == true) {
      setState(() {
        _fotoBaru = null;
        _fotoDihapus = true;
      });
    }
  }

  ImageProvider? _fotoProfilTampil() {
    if (_fotoBaru != null) return FileImage(_fotoBaru!);
    if (_fotoDihapus) return null;
    if (_fotoUrl != null && _fotoUrl!.isNotEmpty) {
      return NetworkImage(_fotoUrl!);
    }
    return null;
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    var wa = _wa.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (nama.isEmpty || wa.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Isi nama dan nomor WhatsApp yang benar.'))),
      );
      return;
    }
    if (wa.startsWith('0')) wa = '62${wa.substring(1)}';
    setState(() => _sibuk = true);
    try {
      var fotoUrl = _fotoDihapus ? null : _fotoUrl;
      if (_fotoBaru != null) {
        fotoUrl = await unggahBerkas(await kompresKeWebp(_fotoBaru!));
      }
      final id = sb.auth.currentUser!.id;
      if (_modeEdit) {
        await sb
            .from('lf_profiles')
            .update({'nama': nama, 'wa': wa, 'foto_url': fotoUrl})
            .eq('id', id);
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          } else {
            // Dibuka Gerbang sebagai pelengkap profil (mis. akun SIKA
            // yang belum punya nomor WhatsApp), bukan rute yang ditumpuk.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const Gerbang()),
            );
          }
        }
      } else {
        await sb.from('lf_profiles').insert({
          'id': id,
          'nama': nama,
          'wa': wa,
          'foto_url': fotoUrl,
        });
        if (mounted) {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => const Gerbang()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('Gagal menyimpan')}: $e')));
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_modeEdit ? 'Edit Profil' : 'Lengkapi Profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pilihFoto,
              child: CircleAvatar(
                radius: 46,
                backgroundImage: _fotoProfilTampil(),
                child: _fotoProfilTampil() == null
                    ? const Icon(Icons.add_a_photo_outlined, size: 30)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('Ketuk untuk pasang foto profil'),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (_fotoProfilTampil() != null)
              TextButton.icon(
                onPressed: _hapusFoto,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                label: Text(
                  tr('Hapus Foto'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              tr(
                'Nomor WhatsApp hanya dipakai saat ada yang perlu menghubungi soal barang. Nomor tidak tampil terbuka di papan.',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nama,
              decoration: InputDecoration(
                labelText: tr('Nama lengkap'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _wa,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('Nomor WhatsApp (08xx)'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sibuk ? null : _simpan,
                child: Text(
                  _sibuk
                      ? tr('Menyimpan...')
                      : (_modeEdit
                            ? tr('Simpan Perubahan')
                            : tr('Simpan dan Masuk')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
