part of '../main.dart';

// ===========================================================================
// Layar pantau kategori
// ===========================================================================

class LayarPantau extends StatefulWidget {
  const LayarPantau({super.key});
  @override
  State<LayarPantau> createState() => _LayarPantauState();
}

class _LayarPantauState extends State<LayarPantau> {
  Set<String> _aktif = {};
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _ambil();
  }

  Future<void> _ambil() async {
    final rows = await sb
        .from('lf_pantau')
        .select('kategori')
        .eq('user_id', sb.auth.currentUser!.id);
    if (mounted) {
      setState(() {
        _aktif = rows.map((r) => (r['kategori'] ?? '').toString()).toSet();
        _muat = false;
      });
    }
  }

  Future<void> _ubah(String kategori, bool nyala) async {
    if (nyala) {
      await sb.from('lf_pantau').insert({
        'user_id': sb.auth.currentUser!.id,
        'kategori': kategori,
      });
    } else {
      await sb
          .from('lf_pantau')
          .delete()
          .eq('user_id', sb.auth.currentUser!.id)
          .eq('kategori', kategori);
    }
    setState(() {
      if (nyala) {
        _aktif.add(kategori);
      } else {
        _aktif.remove(kategori);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pantau Kategori'))),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr(
                      'Nyalakan kategori yang mau kamu pantau. Setiap ada postingan baru tampil di kategori itu, kamu menerima notif dan push, walau belum pernah posting kehilangan.',
                    ),
                  ),
                ),
                for (final k in kKategori)
                  SwitchListTile(
                    title: Text(k),
                    value: _aktif.contains(k),
                    onChanged: (v) => _ubah(k, v),
                  ),
              ],
            ),
    );
  }
}
