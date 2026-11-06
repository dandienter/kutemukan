part of '../main.dart';

// ===========================================================================
// Layar rincian postingan, komentar, dan kemungkinan cocok
// ===========================================================================

class LayarDetail extends StatefulWidget {
  final Map<String, dynamic> post;
  const LayarDetail({super.key, required this.post});
  @override
  State<LayarDetail> createState() => _LayarDetailState();
}

class _LayarDetailState extends State<LayarDetail> {
  late Map<String, dynamic> _post = widget.post;
  List<Map<String, dynamic>> _klaimMasuk = [];
  Map<String, dynamic>? _klaimSaya;
  List<Map<String, dynamic>> _komentar = [];
  final TextEditingController _isiKomentar = TextEditingController();
  bool _muatKlaim = true;
  bool _sudahUp = false;
  Future<List<HasilCocok>>? _fCocok;
  int _fotoKe = 0;
  RealtimeChannel? _kanalKomentar;

  bool get _punyaSaya => _post['user_id'] == sb.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _fCocok = _hitungCocok();
    _muat();
    _kanalKomentar = sb
        .channel('komentar-${_post['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'lf_komentar',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: (_post['id'] ?? '').toString(),
          ),
          callback: (_) => _muatKomentar(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_kanalKomentar != null) sb.removeChannel(_kanalKomentar!);
    _isiKomentar.dispose();
    super.dispose();
  }

  Future<void> _muatKomentar() async {
    try {
      final rows = await sb
          .from('lf_komentar')
          .select()
          .eq('post_id', _post['id'])
          .order('created_at', ascending: true);
      final data = List<Map<String, dynamic>>.from(rows);
      await pasangNama(data);
      if (mounted) setState(() => _komentar = data);
    } catch (_) {
      // komentar gagal dimuat, abaikan
    }
  }

  Future<void> _muat() async {
    try {
      final rows = await sb.from('lf_posts').select().eq('id', _post['id']);
      if (rows.isNotEmpty) {
        _post = rows.first;
        await pasangNama([_post]);
      }
      // Catat view asli (server menolak hitungan ganda per hari,
      // dan kunjungan pemilik serta admin tidak dihitung).
      try {
        final v = await sb.rpc(
          'lf_catat_view',
          params: {'p_post_id': _post['id']},
        );
        if (v is num && v >= 0) _post['views_count'] = v.toInt();
      } catch (_) {}
      final klaim = await sb
          .from('lf_claims')
          .select()
          .eq('post_id', _post['id'])
          .order('created_at', ascending: false);
      final daftar = List<Map<String, dynamic>>.from(klaim);
      await pasangNama(daftar);
      if (_punyaSaya) {
        _klaimMasuk = daftar;
      } else {
        final saya = daftar.where(
          (k) => k['user_id'] == sb.auth.currentUser?.id,
        );
        _klaimSaya = saya.isEmpty ? null : saya.first;
      }
      // Cek apakah saya sudah bantu UP postingan ini hari ini, supaya
      // tombolnya langsung tidak tampil sejak halaman dibuka.
      final uidSaya = sb.auth.currentUser?.id;
      if (uidSaya != null && !_punyaSaya) {
        try {
          final now = DateTime.now();
          final tgl =
              '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}';
          final upRows = await sb
              .from('lf_ups')
              .select('id')
              .eq('post_id', _post['id'])
              .eq('user_id', uidSaya)
              .eq('tanggal', tgl);
          if (upRows.isNotEmpty) _sudahUp = true;
        } catch (_) {}
      }
    } catch (_) {
      // klaim gagal dimuat, detail tetap tampil
    }
    await _muatKomentar();
    if (mounted) setState(() => _muatKlaim = false);
  }

  Future<void> _bantuUpDetail() async {
    final sebelum = (_post['up_count'] as num?)?.toInt() ?? 0;
    try {
      final hasil = await sb.rpc('lf_up', params: {'p_post_id': _post['id']});
      final sesudah = (hasil as num?)?.toInt() ?? sebelum;
      if (!mounted) return;
      if (sesudah > sebelum) {
        setState(() {
          _post['up_count'] = sesudah;
          _sudahUp = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Terima kasih sudah bantu UP.'))),
        );
      } else {
        setState(() => _sudahUp = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Kamu sudah bantu UP postingan ini hari ini.')),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Bantu UP gagal, coba lagi sebentar.'))),
        );
      }
    }
  }

  Future<void> _kirimKomentar() async {
    final isi = _isiKomentar.text.trim();
    if (isi.isEmpty) return;
    try {
      await sb.from('lf_komentar').insert({
        'post_id': _post['id'],
        'user_id': sb.auth.currentUser!.id,
        'isi': isi,
      });
      _isiKomentar.clear();
      await _muatKomentar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Komentar gagal terkirim')}: $e')),
        );
      }
    }
  }

  Future<void> _hapusKomentar(Map<String, dynamic> k) async {
    await sb.from('lf_komentar').delete().eq('id', k['id']);
    await _muatKomentar();
  }

  Future<void> _laporkan() async {
    final alasan = TextEditingController();
    final jadi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Laporkan Postingan')),
        content: TextField(
          controller: alasan,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: tr('Kenapa postingan ini bermasalah?'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Kirim Laporan')),
          ),
        ],
      ),
    );
    if (jadi != true) return;
    try {
      await sb.from('lf_laporan').insert({
        'post_id': _post['id'],
        'user_id': sb.auth.currentUser!.id,
        'alasan': alasan.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Laporan terkirim. Admin akan memeriksanya.')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final duplikat = e.toString().contains('23505');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                duplikat
                    ? 'Kamu sudah pernah melaporkan postingan ini.'
                    : 'Laporan gagal terkirim.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _putuskanKlaim(Map<String, dynamic> klaim, String status) async {
    await sb.from('lf_claims').update({'status': status}).eq('id', klaim['id']);
    await _muat();
  }

  Future<void> _tandaiSelesai() async {
    await sb
        .from('lf_posts')
        .update({
          'status': 'kembali',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', _post['id']);
    await _muat();
  }

  Future<void> _bukaWa(String wa, String sapaan) async {
    final teks = Uri.encodeComponent(sapaan);
    await launchUrl(
      Uri.parse('https://wa.me/$wa?text=$teks'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _hubungiPemilik() async {
    try {
      final hasil = await sb.rpc(
        'lf_kontak',
        params: {'p_post_id': _post['id']},
      );
      final wa = hasil?.toString() ?? '';
      if (wa.isEmpty) throw 'Klaim belum disetujui';
      await _bukaWa(
        wa,
        'Halo, klaim saya soal "${_post['judul']}" sudah disetujui. ',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Belum bisa menghubungi')}: $e')),
        );
      }
    }
  }

  Future<void> _hubungiPengklaim(Map<String, dynamic> klaim) async {
    try {
      final hasil = await sb.rpc(
        'lf_kontak_klaim',
        params: {'p_claim_id': klaim['id']},
      );
      final wa = hasil?.toString() ?? '';
      if (wa.isEmpty) throw 'Nomor tidak tersedia';
      await _bukaWa(
        wa,
        'Halo, soal klaim "${_post['judul']}" yang sudah saya setujui. ',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Belum bisa menghubungi')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hilang = _post['jenis'] == 'hilang';
    final foto = daftarFoto(_post);
    final namaPemilik = _post['nama_pemilik'] ?? 'Pengguna KutemuKan';
    final dilihat = (_post['views_count'] as num?)?.toInt() ?? 0;
    final ups = (_post['up_count'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(hilang ? 'Barang Hilang' : 'Barang Temuan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: tr('Bagikan'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LayarBagikan(post: _post)),
            ),
          ),
          if (!_punyaSaya)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: tr('Laporkan'),
              onPressed: _laporkan,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (foto.isNotEmpty) ...[
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: foto.length,
                onPageChanged: (i) => setState(() => _fotoKe = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => lihatFotoBesar(context, foto[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      foto[i],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (foto.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    foto.length,
                    (i) => Container(
                      margin: const EdgeInsets.all(3),
                      width: _fotoKe == i ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _fotoKe == i ? kBiru : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
          ],
          Text(
            _post['judul'] ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('${tr('Kategori')}: ${_post['kategori']}'),
          Text('${tr('Lokasi')}: ${_post['lokasi']}'),
          Text(
            '${tr('Waktu kejadian')}: ${fmtTanggal(_post['waktu_kejadian'])}',
          ),
          if (_post['penitipan'] != null &&
              (_post['penitipan'] as String).isNotEmpty)
            Text('${tr('Dititipkan di')}: ${_post['penitipan']}'),
          Text('${tr('Dilaporkan oleh')}: $namaPemilik'),
          const SizedBox(height: 6),
          BarisBadge(userId: (_post['user_id'] ?? '').toString()),
          const SizedBox(height: 6),
          Text('Status: ${labelStatus(_post['status'] ?? '')}'),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 18,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                kBahasa.value == 'en'
                    ? 'Viewed $dilihat times'
                    : 'Dilihat $dilihat kali',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(width: 18),
              const Icon(Icons.arrow_upward, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$ups UP', style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              if (!_punyaSaya && _post['status'] == 'tampil' && !_sudahUp)
                FilledButton.tonalIcon(
                  onPressed: _bantuUpDetail,
                  icon: const Icon(Icons.arrow_circle_up_outlined, size: 18),
                  label: Text(tr('Bantu UP')),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_post['deskripsi'] ?? ''),
          _bagianCocok(),
          const Divider(height: 32),
          if (_muatKlaim)
            const Center(child: CircularProgressIndicator())
          else if (_punyaSaya)
            ..._bagianPemilik()
          else
            ..._bagianPengunjung(),
          const Divider(height: 32),
          ..._bagianKomentar(),
        ],
      ),
    );
  }

  Future<List<HasilCocok>> _hitungCocok() async {
    try {
      final rows = await sb
          .from('lf_posts')
          .select(
            'id, user_id, jenis, status, judul, deskripsi, kategori, lokasi, created_at, foto_urls, foto_url',
          )
          .eq('status', 'tampil')
          .limit(200);
      final korpus = List<Map<String, dynamic>>.from(rows);
      final mesin = MesinCocok(korpus);
      return mesin.cariCocok(_post, korpus);
    } catch (_) {
      return [];
    }
  }

  Widget _bagianCocok() {
    if (_post['status'] != 'tampil') return const SizedBox.shrink();
    return FutureBuilder<List<HasilCocok>>(
      future: _fCocok,
      builder: (context, snap) {
        final hasil = snap.data ?? [];
        if (hasil.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 19, color: kBiru),
                const SizedBox(width: 6),
                Text(
                  tr('Kemungkinan Cocok'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Dihitung otomatis dari kemiripan isi, kategori, lokasi, dan waktu.',
              ),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (final h in hasil)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: daftarFoto(h.post).isEmpty
                      ? const CircleAvatar(child: Icon(Icons.search, size: 18))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            daftarFoto(h.post).first,
                            width: 44,
                            height: 44,
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
                      style: const TextStyle(fontSize: 11, color: Colors.white),
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
              ),
          ],
        );
      },
    );
  }

  List<Widget> _bagianKomentar() {
    final saya = sb.auth.currentUser?.id;
    return [
      Text(
        '${tr('Komentar')} (${_komentar.length})',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (_komentar.isEmpty)
        Text(
          tr(
            'Belum ada komentar. Tanya ciri barang di sini dulu sebelum mengajukan klaim juga boleh.',
          ),
        ),
      for (final k in _komentar)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                child: Text(
                  ((k['nama_pemilik'] ?? '?').toString().isNotEmpty
                          ? (k['nama_pemilik'] ?? '?').toString()[0]
                          : '?')
                      .toUpperCase(),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            k['nama_pemilik'] ?? tr('Pengguna'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          fmtTanggal(k['created_at']),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        if (k['user_id'] == saya)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _hapusKomentar(k),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text((k['isi'] ?? '').toString()),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (_post['status'] == 'tampil') ...[
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _isiKomentar,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: tr('Tulis komentar...'),
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: kBiru),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _kirimKomentar,
              icon: const Icon(Icons.send, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    ];
  }

  List<Widget> _bagianPemilik() {
    final menunggu = _klaimMasuk
        .where((k) => k['status'] == 'menunggu')
        .toList();
    return [
      if (_post['status'] == 'tampil') ...[
        if (menunggu.isNotEmpty)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                tr(
                  'Ada klaim menunggu keputusanmu. Periksa ciri khususnya baik-baik sebelum menyetujui.',
                ),
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _tandaiSelesai,
            icon: const Icon(Icons.verified_outlined),
            label: Text(tr('Tandai Sudah Selesai')),
          ),
        ),
        const SizedBox(height: 16),
      ],
      Text(
        tr('Klaim Masuk'),
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (_klaimMasuk.isEmpty) Text(tr('Belum ada klaim untuk postingan ini.')),
      for (final k in _klaimMasuk) _kartuKlaim(k),
    ];
  }

  Widget _kartuKlaim(Map<String, dynamic> k) {
    final nama = k['nama_pemilik'] ?? 'Pengguna';
    final status = k['status'] ?? 'menunggu';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nama,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    status,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: status == 'disetujui'
                      ? Colors.green
                      : status == 'ditolak'
                      ? Colors.red
                      : Colors.orange,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            BarisBadge(userId: (k['user_id'] ?? '').toString()),
            const SizedBox(height: 4),
            Text('"${k['pesan'] ?? ''}"'),
            if (k['bukti_url'] != null)
              TextButton.icon(
                onPressed: () =>
                    lihatFotoBesar(context, (k['bukti_url']).toString()),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(tr('Lihat foto bukti')),
              ),
            Text(
              fmtTanggal(k['created_at']),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (status == 'menunggu')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _putuskanKlaim(k, 'ditolak'),
                    child: Text(
                      tr('Tolak'),
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _putuskanKlaim(k, 'disetujui'),
                    child: Text(tr('Setujui')),
                  ),
                ],
              ),
            if (status == 'disetujui')
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _hubungiPengklaim(k),
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(tr('Hubungi Pengklaim')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _bagianPengunjung() {
    if (_post['status'] != 'tampil') return [];
    final k = _klaimSaya;
    if (k == null) {
      return [
        Card(
          color: const Color(0xFFE6F4F1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              tr(
                'Ini barangmu? Ajukan klaim dan sebutkan ciri khususnya. Nomor WhatsApp baru terbuka sesudah klaimmu disetujui yang memposting.',
              ),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final terkirim = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => LayarKlaim(post: _post)),
              );
              if (terkirim == true) await _muat();
            },
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(tr('Ajukan Klaim')),
          ),
        ),
      ];
    }
    final status = k['status'] ?? 'menunggu';
    if (status == 'menunggu') {
      return [
        Card(
          color: Colors.orange,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              tr(
                'Klaimmu sudah terkirim dan menunggu keputusan yang memposting. Kamu akan mendapat notif begitu ada keputusan.',
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ];
    }
    if (status == 'ditolak') {
      return [
        Card(
          color: Colors.red,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              tr(
                'Klaimmu belum bisa disetujui. Pastikan ciri khusus yang kamu sebutkan benar-benar hanya diketahui pemilik aslinya.',
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ];
    }
    return [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _hubungiPemilik,
          icon: const Icon(Icons.chat),
          label: Text(tr('Hubungi via WhatsApp')),
        ),
      ),
    ];
  }
}
