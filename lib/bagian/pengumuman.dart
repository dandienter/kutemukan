part of '../main.dart';

// ===========================================================================
// Pengumuman komunitas (Broadcast). Admin membuat dari panel Akun;
// semua pengguna membaca di sini dan menerima push lewat worker.
// ===========================================================================

class LayarPengumuman extends StatefulWidget {
  final bool admin;
  const LayarPengumuman({super.key, this.admin = false});
  @override
  State<LayarPengumuman> createState() => _LayarPengumumanState();
}

class _LayarPengumumanState extends State<LayarPengumuman> {
  late Future<List<Map<String, dynamic>>> _fData;

  @override
  void initState() {
    super.initState();
    _fData = _ambil();
  }

  Future<List<Map<String, dynamic>>> _ambil() async {
    var q = sb.from('lf_pengumuman').select();
    if (!widget.admin) {
      q = q.eq('aktif', true);
    }
    final rows = await q.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _form([Map<String, dynamic>? awal]) async {
    final judul = TextEditingController(text: awal?['judul'] ?? '');
    final isi = TextEditingController(text: awal?['isi'] ?? '');
    final kategori = TextEditingController(
      text: awal?['kategori'] ?? 'Umum',
    );
    bool aktif = awal?['aktif'] != false;
    final simpan = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(tr(awal == null ? 'Pengumuman Baru' : 'Ubah Pengumuman')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judul,
                  decoration: InputDecoration(
                    labelText: tr('Judul'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: isi,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: tr('Isi pengumuman'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kategori,
                  decoration: InputDecoration(
                    labelText: tr('Kategori'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  title: Text(tr('Aktif')),
                  value: aktif,
                  onChanged: (v) => setDlg(() => aktif = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Batal')),
            ),
            FilledButton(
              onPressed: () {
                if (judul.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: Text(tr('Simpan')),
            ),
          ],
        ),
      ),
    );
    if (simpan != true) return;
    final data = <String, dynamic>{
      'judul': judul.text.trim(),
      'isi': isi.text.trim(),
      'kategori': kategori.text.trim().isEmpty ? 'Umum' : kategori.text.trim(),
      'aktif': aktif,
    };
    if (awal == null) {
      data['admin_id'] = sb.auth.currentUser!.id;
      await sb.from('lf_pengumuman').insert(data);
    } else {
      await sb.from('lf_pengumuman').update(data).eq('id', awal['id']);
    }
    setState(() => _fData = _ambil());
  }

  Future<void> _hapus(Map<String, dynamic> p) async {
    await sb.from('lf_pengumuman').delete().eq('id', p['id']);
    setState(() => _fData = _ambil());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pengumuman'))),
      floatingActionButton: widget.admin
          ? FloatingActionButton(
              onPressed: () => _form(),
              child: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fData,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return Center(child: Text(tr('Belum ada pengumuman baru nih.')));
          }
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (_, i) {
              final p = data[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text((p['kategori'] ?? 'Umum').toString()),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmtTanggal(p['created_at']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          if (widget.admin && p['aktif'] == false)
                            Chip(
                              label: Text(tr('Nonaktif')),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (widget.admin)
                            PopupMenuButton<String>(
                              onSelected: (a) {
                                if (a == 'ubah') _form(p);
                                if (a == 'hapus') _hapus(p);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'ubah',
                                  child: Text(tr('Ubah')),
                                ),
                                PopupMenuItem(
                                  value: 'hapus',
                                  child: Text(tr('Hapus')),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (p['judul'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((p['isi'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text((p['isi'] ?? '').toString()),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
