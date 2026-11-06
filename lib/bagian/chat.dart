part of '../main.dart';

// ===========================================================================
// Secure Contact: chat in-app terikat klaim. Hanya pemosting dan
// pengklaim yang bisa membaca. Tidak ada nomor WA, email, atau NPM
// yang dipertukarkan di sini.
// ===========================================================================

Future<void> bukaChatKlaim(
  BuildContext context,
  Map<String, dynamic> klaim,
  String judulPost,
) async {
  try {
    final id = await sb.rpc(
      'lf_buka_percakapan',
      params: {'p_claim_id': klaim['id']},
    );
    if (id == null || !context.mounted) return;
    final rows = await sb
        .from('lf_percakapan')
        .select()
        .eq('id', id.toString());
    if (rows.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LayarChat(
          percakapan: Map<String, dynamic>.from(rows.first),
          judulPost: judulPost,
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Chat belum bisa dibuka, coba lagi.'))),
      );
    }
  }
}

class LayarDaftarChat extends StatefulWidget {
  const LayarDaftarChat({super.key});
  @override
  State<LayarDaftarChat> createState() => _LayarDaftarChatState();
}

class _LayarDaftarChatState extends State<LayarDaftarChat> {
  bool _tabArsip = false;
  late Future<List<Map<String, dynamic>>> _fData;

  @override
  void initState() {
    super.initState();
    _fData = _ambil();
  }

  Future<List<Map<String, dynamic>>> _ambil() async {
    final uid = sb.auth.currentUser!.id;
    final rows = await sb
        .from('lf_percakapan')
        .select()
        .or('user_a.eq.$uid,user_b.eq.$uid')
        .order('created_at', ascending: false);
    final data = List<Map<String, dynamic>>.from(rows);
    if (data.isEmpty) return data;
    final peta = await ambilProfilPublik(
      data.map((c) => c['user_a'] == uid ? c['user_b'] : c['user_a']),
    );
    final postIds = data.map((c) => c['post_id']).toSet().toList();
    final prows = await sb
        .from('lf_posts')
        .select('id, judul')
        .inFilter('id', postIds);
    final judulPost = {
      for (final p in prows) (p['id'] ?? '').toString(): (p['judul'] ?? ''),
    };
    for (final c in data) {
      final lawanId = (c['user_a'] == uid ? c['user_b'] : c['user_a'])
          .toString();
      final pub = peta[lawanId];
      final tampilan = (pub?['nama_tampilan'] ?? '').toString().trim();
      c['nama_lawan'] = tampilan.isNotEmpty
          ? tampilan
          : (pub?['nama'] ?? 'Pengguna');
      c['foto_lawan'] = pub?['foto_url'];
      c['terverifikasi_lawan'] = pub?['terverifikasi'];
      c['judul_post'] = judulPost[(c['post_id'] ?? '').toString()] ?? '';
      try {
        final terakhir = await sb
            .from('lf_pesan')
            .select('isi, pengirim_id, created_at')
            .eq('percakapan_id', c['id'])
            .order('created_at', ascending: false)
            .limit(1);
        if (terakhir.isNotEmpty) {
          c['pesan_terakhir'] = terakhir.first['isi'];
          c['waktu_terakhir'] = terakhir.first['created_at'];
        }
        final belum = await sb
            .from('lf_pesan')
            .select('id')
            .eq('percakapan_id', c['id'])
            .eq('dibaca', false)
            .neq('pengirim_id', uid);
        c['belum_dibaca'] = belum.length;
      } catch (_) {
        c['belum_dibaca'] = 0;
      }
    }
    return data;
  }

  bool _terarsip(Map<String, dynamic> c) {
    final uid = sb.auth.currentUser!.id;
    return c['user_a'] == uid ? c['arsip_a'] == true : c['arsip_b'] == true;
  }

  Future<void> _arsipkan(Map<String, dynamic> c, bool arsip) async {
    final uid = sb.auth.currentUser!.id;
    final kolom = c['user_a'] == uid ? 'arsip_a' : 'arsip_b';
    await sb.from('lf_percakapan').update({kolom: arsip}).eq('id', c['id']);
    setState(() => _fData = _ambil());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pesan'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(tr('Aktif'))),
                ButtonSegment(value: true, label: Text(tr('Arsip'))),
              ],
              selected: {_tabArsip},
              onSelectionChanged: (s) => setState(() => _tabArsip = s.first),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fData,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final semua = snap.data ?? [];
                final data = semua.where((c) => _terarsip(c) == _tabArsip).toList();
                if (data.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tr(
                          _tabArsip
                              ? 'Belum ada percakapan yang diarsipkan.'
                              : 'Belum ada percakapan. Chat terbuka dari halaman klaim pada rincian postingan.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (_, i) {
                    final c = data[i];
                    final foto = (c['foto_lawan'] ?? '').toString();
                    final nama = (c['nama_lawan'] ?? '').toString();
                    final belum = (c['belum_dibaca'] as num?)?.toInt() ?? 0;
                    final ditutup = c['status'] == 'ditutup';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: foto.isNotEmpty
                            ? NetworkImage(foto)
                            : null,
                        child: foto.isEmpty
                            ? Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: belum > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (c['terverifikasi_lawan'] == true)
                            const Icon(Icons.verified, size: 15, color: kBiru),
                        ],
                      ),
                      subtitle: Text(
                        [
                          (c['judul_post'] ?? '').toString(),
                          if (ditutup) tr('Ditutup') else (c['pesan_terakhir'] ?? ''),
                        ].where((e) => e.toString().isNotEmpty).join(' - '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (belum > 0)
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: kBiru,
                              child: Text(
                                '$belum',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          PopupMenuButton<String>(
                            onSelected: (a) => _arsipkan(c, a == 'arsip'),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: _tabArsip ? 'keluar' : 'arsip',
                                child: Text(
                                  _tabArsip
                                      ? tr('Keluarkan dari Arsip')
                                      : tr('Arsipkan'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LayarChat(
                              percakapan: c,
                              judulPost: (c['judul_post'] ?? '').toString(),
                            ),
                          ),
                        );
                        setState(() => _fData = _ambil());
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LayarChat extends StatefulWidget {
  final Map<String, dynamic> percakapan;
  final String judulPost;
  const LayarChat({super.key, required this.percakapan, required this.judulPost});
  @override
  State<LayarChat> createState() => _LayarChatState();
}

class _LayarChatState extends State<LayarChat> {
  final _isi = TextEditingController();
  final _gulir = ScrollController();
  List<Map<String, dynamic>> _pesan = [];
  Map<String, dynamic> _lawan = {};
  bool _muat = true;
  bool _kirim = false;
  RealtimeChannel? _kanal;

  String get _id => (widget.percakapan['id'] ?? '').toString();
  String get _uidSaya => sb.auth.currentUser!.id;
  bool get _ditutup => widget.percakapan['status'] == 'ditutup';
  String get _lawanId =>
      (widget.percakapan['user_a'] == _uidSaya
              ? widget.percakapan['user_b']
              : widget.percakapan['user_a'])
          .toString();

  @override
  void initState() {
    super.initState();
    _muatAwal();
    _kanal = sb
        .channel('chat-$_id')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'lf_pesan',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'percakapan_id',
            value: _id,
          ),
          callback: (payload) {
            final baru = Map<String, dynamic>.from(payload.newRecord);
            if (!mounted) return;
            if (_pesan.any((p) => p['id'] == baru['id'])) return;
            setState(() => _pesan = [..._pesan, baru]);
            _keBawah();
            if (baru['pengirim_id'] != _uidSaya) _tandaiDibaca();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_kanal != null) sb.removeChannel(_kanal!);
    _isi.dispose();
    _gulir.dispose();
    super.dispose();
  }

  Future<void> _muatAwal() async {
    final peta = await ambilProfilPublik([_lawanId]);
    final rows = await sb
        .from('lf_pesan')
        .select()
        .eq('percakapan_id', _id)
        .order('created_at', ascending: true)
        .limit(300);
    if (!mounted) return;
    setState(() {
      _lawan = peta[_lawanId] ?? {};
      _pesan = List<Map<String, dynamic>>.from(rows);
      _muat = false;
    });
    _keBawah();
    await _tandaiDibaca();
  }

  Future<void> _tandaiDibaca() async {
    try {
      await sb
          .from('lf_pesan')
          .update({'dibaca': true})
          .eq('percakapan_id', _id)
          .eq('dibaca', false)
          .neq('pengirim_id', _uidSaya);
    } catch (_) {}
  }

  void _keBawah() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_gulir.hasClients) {
        _gulir.jumpTo(_gulir.position.maxScrollExtent);
      }
    });
  }

  Future<void> _kirimPesan() async {
    final teks = _isi.text.trim();
    if (teks.isEmpty || _kirim) return;
    setState(() => _kirim = true);
    try {
      await sb.from('lf_pesan').insert({
        'percakapan_id': _id,
        'pengirim_id': _uidSaya,
        'isi': teks,
      });
      _isi.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Pesan gagal terkirim')}: $e')),
        );
      }
    }
    if (mounted) setState(() => _kirim = false);
  }

  @override
  Widget build(BuildContext context) {
    final tampilan = (_lawan['nama_tampilan'] ?? '').toString().trim();
    final nama = tampilan.isNotEmpty
        ? tampilan
        : (_lawan['nama'] ?? tr('Pengguna')).toString();
    final foto = (_lawan['foto_url'] ?? '').toString();
    final skema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
              child: foto.isEmpty
                  ? Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nama,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_lawan['terverifikasi'] == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 15, color: kBiru),
                      ],
                    ],
                  ),
                  Text(
                    widget.judulPost,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_ditutup)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(10),
              child: Text(
                tr(
                  'Percakapan ini sudah ditutup karena transaksinya selesai atau klaimnya ditolak. Riwayatnya tetap bisa dibaca.',
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _muat
                ? const Center(child: CircularProgressIndicator())
                : _pesan.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tr(
                          'Belum ada pesan. Sapa dulu dan bicarakan ciri barang serta rencana serah terimanya di sini.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _gulir,
                    padding: const EdgeInsets.all(12),
                    itemCount: _pesan.length,
                    itemBuilder: (_, i) {
                      final p = _pesan[i];
                      final saya = p['pengirim_id'] == _uidSaya;
                      return Align(
                        alignment: saya
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: saya
                                ? kBiru
                                : skema.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                (p['isi'] ?? '').toString(),
                                style: TextStyle(
                                  color: saya
                                      ? Colors.white
                                      : skema.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fmtRelatif(p['created_at']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: saya
                                          ? Colors.white70
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (saya && p['dibaca'] == true) ...[
                                    const SizedBox(width: 3),
                                    const Icon(
                                      Icons.done_all,
                                      size: 13,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_ditutup)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _isi,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          hintText: tr('Tulis pesan...'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        onSubmitted: (_) => _kirimPesan(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _kirim ? null : _kirimPesan,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
