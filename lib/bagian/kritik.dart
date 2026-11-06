part of '../main.dart';

// ===========================================================================
// Layar kritik dan saran
// ===========================================================================

class LayarKritikSaran extends StatefulWidget {
  const LayarKritikSaran({super.key});
  @override
  State<LayarKritikSaran> createState() => _LayarKritikSaranState();
}

class _LayarKritikSaranState extends State<LayarKritikSaran> {
  int _bintang = 5;
  final TextEditingController _isi = TextEditingController();
  bool _sibuk = false;

  Future<List<Map<String, dynamic>>> _ulasanSaya() async {
    final rows = await sb
        .from('lf_feedback')
        .select()
        .eq('user_id', sb.auth.currentUser!.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _kirim() async {
    if (_isi.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Tulis dulu kritik atau saranmu.'))),
      );
      return;
    }
    setState(() => _sibuk = true);
    try {
      await sb.from('lf_feedback').insert({
        'user_id': sb.auth.currentUser!.id,
        'bintang': _bintang,
        'isi': _isi.text.trim(),
      });
      _isi.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Terima kasih, ulasanmu terkirim.'))),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kritik & Saran'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(tr('Seberapa puas kamu dengan KutemuKan?')),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _bintang = i),
                  icon: Icon(
                    i <= _bintang ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 34,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _isi,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: tr(
                'Fitur apa yang kurang, apa yang mengganggu, apa yang mau kamu minta ditambah...',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _sibuk ? null : _kirim,
            child: Text(_sibuk ? tr('Mengirim...') : tr('Kirim Ulasan')),
          ),
          const Divider(height: 36),
          Text(
            tr('Ulasanku sebelumnya'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _ulasanSaya(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data ?? [];
              if (data.isEmpty) {
                return Text(tr('Belum ada ulasan. Jadilah yang pertama.'));
              }
              return Column(
                children: [
                  for (final u in data)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                            Text(' ${u['bintang']}'),
                          ],
                        ),
                        title: Text(u['isi'] ?? ''),
                        subtitle: Text(fmtTanggal(u['created_at'])),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
