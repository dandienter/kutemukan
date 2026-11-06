part of '../main.dart';

// ===========================================================================
// Layar klaim masuk untuk pemilik postingan
// ===========================================================================

class LayarKlaim extends StatefulWidget {
  final Map<String, dynamic> post;
  const LayarKlaim({super.key, required this.post});
  @override
  State<LayarKlaim> createState() => _LayarKlaimState();
}

class _LayarKlaimState extends State<LayarKlaim> {
  final _pesan = TextEditingController();
  File? _bukti;
  bool _sibuk = false;

  Future<void> _kirim() async {
    if (_pesan.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Sebutkan ciri khusus barangnya lebih jelas (minimal 10 karakter).',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _sibuk = true);
    try {
      String? buktiUrl;
      if (_bukti != null) {
        buktiUrl = await unggahBerkas(await kompresKeWebp(_bukti!));
      }
      await sb.from('lf_claims').insert({
        'post_id': widget.post['id'],
        'user_id': sb.auth.currentUser!.id,
        'pesan': _pesan.text.trim(),
        'bukti_url': buktiUrl,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Gagal mengirim klaim')}: $e')),
        );
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ajukan Klaim'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '${tr('Postingan')}: ${widget.post['judul']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              'Sebutkan ciri khusus yang hanya diketahui pemilik asli barang ini, misalnya isi di dalamnya, tanda unik, atau nomor serinya. Jawabanmu dibaca yang memposting untuk memutuskan klaim ini benar atau bukan.',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pesan,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: tr('Ciri khusus barang'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final sumber = await pilihSumberFoto(context);
              if (sumber == null) return;
              final x = await ImagePicker().pickImage(
                source: sumber,
                imageQuality: 85,
              );
              if (x != null && mounted) {
                setState(() => _bukti = File(x.path));
              }
            },
            icon: const Icon(Icons.image_outlined),
            label: Text(
              tr(
                _bukti == null
                    ? 'Tambah Foto Bukti (opsional)'
                    : 'Ganti Foto Bukti',
              ),
            ),
          ),
          if (_bukti != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_bukti!, height: 150, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _sibuk ? null : _kirim,
            child: Text(_sibuk ? tr('Mengirim...') : tr('Kirim Klaim')),
          ),
        ],
      ),
    );
  }
}
