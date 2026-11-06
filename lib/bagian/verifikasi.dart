part of '../main.dart';

// ===========================================================================
// Layar verifikasi mahasiswa via SIKA
// ===========================================================================

class LayarVerifikasiSika extends StatefulWidget {
  final Map<String, dynamic> profil;
  const LayarVerifikasiSika({super.key, required this.profil});
  @override
  State<LayarVerifikasiSika> createState() => _LayarVerifikasiSikaState();
}

class _LayarVerifikasiSikaState extends State<LayarVerifikasiSika> {
  final _npm = TextEditingController();
  final _sandi = TextEditingController();
  bool _sibuk = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _npm.text = (widget.profil['npm'] ?? '').toString();
  }

  Future<void> _kirim() async {
    if (_npm.text.trim().isEmpty || _sandi.text.isEmpty) {
      setState(() => _galat = tr('Isi NPM dan kata sandi SIKA dulu.'));
      return;
    }
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      await verifikasiSika(_npm.text.trim(), _sandi.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Berhasil terverifikasi sebagai mahasiswa.')),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _galat = e.toString());
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final sudah = widget.profil['terverifikasi'] == true;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Verifikasi Mahasiswa'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'SIKA',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: kBiru,
            ),
          ),
          Text(
            tr('Sistem Informasi Akademik Unindra'),
            style: TextStyle(color: skema.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              'Masukkan NPM dan kata sandi SIKA. Bila cocok, akunmu naik status jadi Mahasiswa Terverifikasi dan nama, prodi, serta NPM resmi dari SIKA tampil di profilmu.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Kata sandi SIKA hanya diteruskan ke server kampus untuk verifikasi, tidak disimpan di KutemuKan.',
            ),
            style: TextStyle(color: skema.onSurfaceVariant, fontSize: 12),
          ),
          if (sudah) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: skema.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: kBiru),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'NPM ${widget.profil['npm']} • ${widget.profil['prodi'] ?? ''}',
                      style: TextStyle(color: skema.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _npm,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'NPM',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _sandi,
            obscureText: true,
            decoration: InputDecoration(
              labelText: tr('Kata sandi SIKA'),
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: skema.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _galat!,
                style: TextStyle(color: skema.onErrorContainer),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _sibuk ? null : _kirim,
            child: Text(
              _sibuk
                  ? tr('Memproses...')
                  : (sudah ? tr('Perbarui Data SIKA') : tr('Verifikasi')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kepala tab Akun: ringkas secara bawaan. NPM, prodi, nomor WhatsApp,
/// dan email hanya tampil sesudah kepala diketuk, sesuai permintaan user
/// (jangan menumpuk dan tanpa ikon mata).
