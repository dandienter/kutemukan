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
            .select('isi, foto_url, audio_url, lat, live, pengirim_id, created_at')
            .eq('percakapan_id', c['id'])
            .order('created_at', ascending: false)
            .limit(1);
        if (terakhir.isNotEmpty) {
          final t = terakhir.first;
          var label = (t['isi'] ?? '').toString();
          if (label.isEmpty) {
            if (t['foto_url'] != null) {
              label = tr('Foto');
            } else if (t['audio_url'] != null) {
              label = tr('Pesan suara');
            } else if (t['lat'] != null) {
              label = t['live'] == true ? tr('Lokasi live') : tr('Lokasi');
            }
          }
          c['pesan_terakhir'] = label;
          c['waktu_terakhir'] = t['created_at'];
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
                return RefreshIndicator(
onRefresh: () async {
              setState(() => _fData = _ambil());
              await _fData;
            },
child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: data.length,
                  itemBuilder: (_, i) {
                    final c = data[i];
                    final foto = (c['foto_lawan'] ?? '').toString();
                    final nama = (c['nama_lawan'] ?? '').toString();
                    final belum = (c['belum_dibaca'] as num?)?.toInt() ?? 0;
                    final ditutup = c['status'] == 'ditutup';
                    return ListTile(
                      leading: AvatarPengguna(nama: nama, foto: foto),
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
                            const LencanaEmas(terverifikasi: true, ukuran: 15),
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
                )
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
  final AudioRecorder _rekam = AudioRecorder();
  bool _sedangRekam = false;
  int _detikRekam = 0;
  Timer? _timerRekam;
  String? _liveId;
  Timer? _timerLive;

  String get _id => (widget.percakapan['id'] ?? '').toString();
  String get _uidSaya => sb.auth.currentUser!.id;
  bool get _ditutup => widget.percakapan['status'] == 'ditutup';
  String get _lawanId =>
      (widget.percakapan['user_a'] == _uidSaya
              ? widget.percakapan['user_b']
              : widget.percakapan['user_a'])
          .toString();


  Map<String, dynamic>? _postMini;

  Future<void> _muatPostMini() async {
    try {
      final pid = (widget.percakapan['post_id'] ?? '').toString();
      if (pid.isEmpty) return;
      final rows = await sb
          .from('lf_posts')
          .select('id, judul, jenis, status, lokasi, kategori, foto_url, foto_urls')
          .eq('id', pid);
      if (rows.isNotEmpty && mounted) {
        setState(() => _postMini = Map<String, dynamic>.from(rows.first));
      }
    } catch (_) {
      // kartu mini hanya pelengkap
    }
  }

  /// Kartu barang mini di atas ruang chat: barang yang sedang
  /// dibicarakan, ketuk untuk membuka rinciannya.
  Widget _kartuBarangMini() {
    final p = _postMini!;
    final foto = daftarFoto(p);
    final status = (p['status'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: ListTile(
        dense: true,
        leading: foto.isEmpty
            ? CircleAvatar(
                backgroundColor: warnaKategori(
                  (p['kategori'] ?? '').toString(),
                ).withOpacity(0.14),
                child: Icon(
                  ikonKategori((p['kategori'] ?? '').toString()),
                  color: warnaKategori((p['kategori'] ?? '').toString()),
                  size: 19,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: foto.first,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.image_not_supported_outlined),
                ),
              ),
        title: Text(
          widget.judulPost.isNotEmpty
              ? widget.judulPost
              : (p['judul'] ?? '').toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          '${p['jenis'] == 'hilang' ? tr('Hilang') : tr('Temuan')} · ${p['lokasi'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Chip(
          label: Text(
            labelStatus(status),
            style: TextStyle(
              fontSize: 10.5,
              color: warnaStatus(status),
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: warnaStatus(status).withOpacity(0.12),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
        onTap: () async {
          final rows = await sb.from('lf_posts').select().eq('id', p['id']);
          if (rows.isEmpty || !mounted) return;
          final post = Map<String, dynamic>.from(rows.first);
          await pasangNama([post]);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LayarDetail(post: post)),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _muatAwal();
    _muatPostMini();
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
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'lf_pesan',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'percakapan_id',
            value: _id,
          ),
          callback: (payload) {
            final ubah = Map<String, dynamic>.from(payload.newRecord);
            if (!mounted) return;
            final i = _pesan.indexWhere((p) => p['id'] == ubah['id']);
            if (i < 0) return;
            setState(() {
              final salin = [..._pesan];
              salin[i] = ubah;
              _pesan = salin;
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_kanal != null) sb.removeChannel(_kanal!);
    _timerRekam?.cancel();
    _timerLive?.cancel();
    _rekam.dispose();
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

  Future<void> _sisipPesan(Map<String, dynamic> isi) async {
    await sb.from('lf_pesan').insert({
      'percakapan_id': _id,
      'pengirim_id': _uidSaya,
      ...isi,
    });
  }

  void _gagal(String pesan) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pesan)));
    }
  }

  Future<void> _kirimFoto(ImageSource sumber) async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: sumber, imageQuality: 88);
      if (x == null) return;
      var berkas = File(x.path);
      try {
        berkas = await kompresKeWebp(berkas);
      } catch (_) {
        // kompres gagal, kirim berkas asli
      }
      final url = await unggahBerkas(berkas);
      await _sisipPesan({'isi': '', 'foto_url': url});
    } catch (e) {
      _gagal('${tr('Foto gagal terkirim')}: $e');
    }
  }

  Future<Position?> _posisi() async {
    try {
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        _gagal(tr('Izin lokasi ditolak. Aktifkan dari pengaturan aplikasi.'));
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _gagal(tr('GPS belum aktif. Nyalakan lokasi di perangkatmu.'));
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      _gagal('${tr('Lokasi gagal diambil')}: $e');
      return null;
    }
  }

  Future<void> _kirimLokasi(bool live) async {
    final pos = await _posisi();
    if (pos == null) return;
    try {
      if (!live) {
        await _sisipPesan({
          'isi': '',
          'lat': pos.latitude,
          'lng': pos.longitude,
          'lokasi_label': tr('Lokasi dibagikan'),
          'live': false,
        });
        return;
      }
      final berakhir = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 30));
      final baris = await sb
          .from('lf_pesan')
          .insert({
            'percakapan_id': _id,
            'pengirim_id': _uidSaya,
            'isi': '',
            'lat': pos.latitude,
            'lng': pos.longitude,
            'lokasi_label': tr('Lokasi live'),
            'live': true,
            'live_berakhir': berakhir.toIso8601String(),
          })
          .select()
          .single();
      _liveId = (baris['id'] ?? '').toString();
      _timerLive?.cancel();
      _timerLive = Timer.periodic(const Duration(seconds: 20), (_) async {
        if (_liveId == null || !mounted) return;
        if (DateTime.now().toUtc().isAfter(berakhir)) {
          await _akhiriLive();
          return;
        }
        try {
          final p2 = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          );
          await sb
              .from('lf_pesan')
              .update({'lat': p2.latitude, 'lng': p2.longitude})
              .eq('id', _liveId!);
        } catch (_) {
          // posisi sesaat gagal, putaran berikut dicoba lagi
        }
      });
    } catch (e) {
      _gagal('${tr('Lokasi gagal terkirim')}: $e');
    }
  }

  Future<void> _akhiriLive() async {
    final id = _liveId;
    _timerLive?.cancel();
    _liveId = null;
    if (id == null || id.isEmpty) return;
    try {
      await sb.from('lf_pesan').update({'live': false}).eq('id', id);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _toggleRekam() async {
    if (_sedangRekam) {
      await _kirimRekaman();
      return;
    }
    try {
      if (!await _rekam.hasPermission()) {
        _gagal(tr('Izin mikrofon ditolak. Aktifkan dari pengaturan aplikasi.'));
        return;
      }
      final path =
          '${Directory.systemTemp.path}/suara_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rekam.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _sedangRekam = true;
        _detikRekam = 0;
      });
      _timerRekam?.cancel();
      _timerRekam = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _detikRekam++);
        if (_detikRekam >= 300) _kirimRekaman();
      });
    } catch (e) {
      _gagal('${tr('Rekaman gagal dimulai')}: $e');
    }
  }

  Future<void> _kirimRekaman() async {
    _timerRekam?.cancel();
    String? path;
    try {
      path = await _rekam.stop();
    } catch (_) {}
    if (mounted) setState(() => _sedangRekam = false);
    if (path == null) return;
    try {
      final url = await unggahAudio(File(path));
      await _sisipPesan({'isi': '', 'audio_url': url});
    } catch (e) {
      _gagal('${tr('Pesan suara gagal terkirim')}: $e');
    }
  }

  Future<void> _batalRekam() async {
    _timerRekam?.cancel();
    try {
      await _rekam.stop();
    } catch (_) {}
    if (mounted) setState(() => _sedangRekam = false);
  }

  void _menuLampiran() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('Foto dari Kamera')),
              onTap: () {
                Navigator.of(ctx).pop();
                _kirimFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Foto dari Galeri')),
              onTap: () {
                Navigator.of(ctx).pop();
                _kirimFoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(tr('Kirim Lokasi')),
              onTap: () {
                Navigator.of(ctx).pop();
                _kirimLokasi(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location_outlined),
              title: Text(tr('Lokasi Live (30 menit)')),
              onTap: () {
                Navigator.of(ctx).pop();
                _kirimLokasi(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDetik(int d) =>
      '${(d ~/ 60).toString().padLeft(2, '0')}:${(d % 60).toString().padLeft(2, '0')}';

  Widget _blokLokasi(Map<String, dynamic> p, bool saya) {
    final skema = Theme.of(context).colorScheme;
    final lat = (p['lat'] as num).toDouble();
    final lng = (p['lng'] as num).toDouble();
    final berakhir = DateTime.tryParse(
      (p['live_berakhir'] ?? '').toString(),
    );
    final masihLive =
        p['live'] == true &&
        (berakhir == null || berakhir.isAfter(DateTime.now()));
    final warnaTeks = saya ? skema.onPrimary : skema.onSurface;
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        ),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place, color: warnaTeks, size: 26),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      (p['lokasi_label'] ?? tr('Lokasi')).toString(),
                      style: TextStyle(
                        color: warnaTeks,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (masihLive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: TextStyle(color: warnaTeks, fontSize: 11),
                ),
                Text(
                  tr('Ketuk untuk membuka di Maps'),
                  style: TextStyle(color: warnaTeks, fontSize: 11),
                ),
                if (saya && masihLive && p['id'] == _liveId)
                  TextButton(
                    onPressed: _akhiriLive,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      tr('Akhiri Live'),
                      style: TextStyle(color: warnaTeks, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
            AvatarPengguna(nama: nama, foto: foto, radius: 17),
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
          if (_postMini != null) _kartuBarangMini(),
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
                                ? skema.primary
                                : skema.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(saya ? 14 : 4),
                              bottomRight: Radius.circular(saya ? 4 : 14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if ((p['foto_url'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: GestureDetector(
                                    onTap: () => lihatFotoBesar(
                                      context,
                                      (p['foto_url']).toString(),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        (p['foto_url']).toString(),
                                        width: 230,
                                        height: 170,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (p['lat'] != null && p['lng'] != null)
                                _blokLokasi(p, saya),
                              if ((p['audio_url'] ?? '').toString().isNotEmpty)
                                _GelembungAudio(
                                  url: (p['audio_url']).toString(),
                                  saya: saya,
                                ),
                              if ((p['isi'] ?? '').toString().isNotEmpty)
                                Text(
                                  (p['isi'] ?? '').toString(),
                                  style: TextStyle(
                                    color: saya
                                        ? skema.onPrimary
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
                                          ? skema.onPrimary.withOpacity(0.75)
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (saya && p['dibaca'] == true) ...[
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.done_all,
                                      size: 13,
                                      color: skema.onPrimary.withOpacity(0.75),
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
                padding: const EdgeInsets.fromLTRB(6, 6, 10, 10),
                child: _sedangRekam
                    ? Row(
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _fmtDetik(_detikRekam),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(tr('Merekam pesan suara...'))),
                          IconButton(
                            onPressed: _batalRekam,
                            icon: const Icon(Icons.delete_outline),
                            tooltip: tr('Batal'),
                          ),
                          IconButton.filled(
                            onPressed: _kirimRekaman,
                            icon: const Icon(Icons.send),
                            tooltip: tr('Kirim'),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: _menuLampiran,
                            icon: const Icon(Icons.attach_file_outlined),
                            tooltip: tr('Lampirkan'),
                          ),
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
                          const SizedBox(width: 6),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _isi,
                            builder: (_, nilai, __) =>
                                nilai.text.trim().isNotEmpty
                                ? IconButton.filled(
                                    onPressed: _kirim ? null : _kirimPesan,
                                    icon: const Icon(Icons.send),
                                  )
                                : IconButton.filledTonal(
                                    onPressed: _toggleRekam,
                                    icon: const Icon(Icons.mic_outlined),
                                  ),
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

// ===========================================================================
// Gelembung pesan suara dengan pemutar sederhana
// ===========================================================================

class _GelembungAudio extends StatefulWidget {
  final String url;
  final bool saya;
  const _GelembungAudio({required this.url, required this.saya});
  @override
  State<_GelembungAudio> createState() => _GelembungAudioState();
}

class _GelembungAudioState extends State<_GelembungAudio> {
  final AudioPlayer _putar = AudioPlayer();
  bool _main = false;
  Duration _durasi = Duration.zero;
  Duration _posisi = Duration.zero;

  @override
  void initState() {
    super.initState();
    _putar.onDurationChanged.listen((d) {
      if (mounted) setState(() => _durasi = d);
    });
    _putar.onPositionChanged.listen((d) {
      if (mounted) setState(() => _posisi = d);
    });
    _putar.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _main = false;
          _posisi = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _putar.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_main) {
      await _putar.pause();
      setState(() => _main = false);
    } else {
      await _putar.play(UrlSource(widget.url));
      setState(() => _main = true);
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final warna = widget.saya ? skema.onPrimary : skema.onSurface;
    final total = _durasi.inMilliseconds;
    final jalan = _posisi.inMilliseconds;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(_main ? Icons.pause_circle : Icons.play_circle, size: 34),
          color: warna,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: LinearProgressIndicator(
                value: total > 0 ? (jalan / total).clamp(0, 1) : 0,
                color: warna,
                backgroundColor: warna.withOpacity(0.3),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _main || jalan > 0
                  ? '${_fmt(_posisi)} / ${_fmt(_durasi)}'
                  : tr('Pesan suara'),
              style: TextStyle(color: warna, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
