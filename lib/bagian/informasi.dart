part of '../main.dart';

// ===========================================================================
// Layar Informasi: satu tab berisi Notifikasi, Pengumuman, dan Panduan,
// sesuai mockup redesign v1.9.0 yang disetujui.
// ===========================================================================

class LayarInformasi extends StatefulWidget {
  const LayarInformasi({super.key});
  @override
  State<LayarInformasi> createState() => _LayarInformasiState();
}

class _LayarInformasiState extends State<LayarInformasi>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final _kunciNotif = GlobalKey<_LayarNotifState>();
  bool _notifPilih = false;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('Informasi Terkini'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_tab.index == 0 && !_notifPilih) ...[
            IconButton(
              key: kunciPanduanNotif,
              icon: const Icon(Icons.done_all),
              tooltip: tr('Tandai semua dibaca'),
              onPressed: () => _kunciNotif.currentState?._tandaiSemuaDibaca(),
            ),
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: tr('Pilih'),
              onPressed: () => _kunciNotif.currentState?._masukModePilih(null),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: kEmas,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.88),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            letterSpacing: 0,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          tabs: [
            Tab(text: tr('NOTIFIKASI')),
            Tab(text: tr('PENGUMUMAN')),
            Tab(text: tr('PANDUAN')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TetapHidup(
            child: LayarNotif(
              sematkan: true,
              key: _kunciNotif,
              onModePilihBerubah: (v) {
                if (mounted) setState(() => _notifPilih = v);
              },
            ),
          ),
          const _TetapHidup(child: LayarPengumuman(sematkan: true)),
          const _TetapHidup(child: TabPanduan()),
        ],
      ),
    );
  }
}

/// Isi tab Panduan: ringkasan cara pakai yang selalu bisa dibaca,
/// plus tombol memulai tur interaktif.
class TabPanduan extends StatelessWidget {
  const TabPanduan({super.key});

  @override
  Widget build(BuildContext context) {
    final langkah = <(IconData, String, String)>[
      (
        Icons.post_add_outlined,
        tr('Buat laporan'),
        tr(
          'Kehilangan atau menemukan barang? Buat laporan lewat tombol Lapor di tengah bawah. Isi foto, lokasi, dan ciri khusus rahasia barangmu.',
        ),
      ),
      (
        Icons.bolt_outlined,
        tr('Atau pakai Lapor Cepat'),
        tr(
          'Ceritakan kejadiannya dalam teks bebas, formulir terisi otomatis. Tinggal periksa, ganti yang kurang pas, lalu kirim.',
        ),
      ),
      (
        Icons.shield_outlined,
        tr('Melewati moderasi'),
        tr(
          'Admin memeriksa setiap laporan sebelum tampil di papan, jadi papan bersih dari laporan asal-asalan.',
        ),
      ),
      (
        Icons.auto_awesome_outlined,
        tr('Pencocokan otomatis'),
        tr(
          'Sistem membandingkan laporan hilang dan temuan (teks, kategori, dan foto). Kalau ada yang mirip, kamu langsung dikabari.',
        ),
      ),
      (
        Icons.how_to_reg_outlined,
        tr('Klaim dengan verifikasi'),
        tr(
          'Untuk mengklaim, jawab pertanyaan tentang ciri khusus yang cuma diketahui pemiliknya. Pemilik yang menyetujui atau menolak.',
        ),
      ),
      (
        Icons.qr_code_2_outlined,
        tr('Serah terima berkode'),
        tr(
          'Sesudah klaim disetujui, chat terbuka dan ada kode 6 digit plus QR untuk ditunjukkan saat barang berpindah tangan.',
        ),
      ),
    ];
    return RefreshIndicator(
onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: kGradasiKepala,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Image.asset('assets/burung.png', width: 54, height: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Panduan KutemuKan'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      tr('Yang Hilang Dicariin, Yang Ketemu Dibalikin'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => pemicuPanduan?.call(),
          icon: const Icon(Icons.play_circle_outline),
          label: Text(tr('Mulai Tur Interaktif')),
          style: FilledButton.styleFrom(
            backgroundColor: kBiruUtama,
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
        const SizedBox(height: 8),
        for (final (ikon, judul, isi) in langkah)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: kBiruUtama.withOpacity(0.12),
                child: Icon(ikon, color: kBiruUtama, size: 20),
              ),
              title: Text(
                judul,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(isi),
              isThreeLine: true,
            ),
          ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.info_outline, color: kBiruUtama),
          title: Text(tr('Tentang KutemuKan')),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LayarInfo())),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, color: kBiruUtama),
          title: Text(tr('Kebijakan Privasi')),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LayarPrivasi())),
        ),
      ],
    )
);
  }
}

/// Pembungkus penahan state: PageView di balik TabBarView membuang
/// state anak yang keluar layar bila tidak ditahan seperti ini,
/// akibatnya notifikasi dan pengumuman dimuat ulang tiap ganti tab.
class _TetapHidup extends StatefulWidget {
  final Widget child;
  const _TetapHidup({required this.child});

  @override
  State<_TetapHidup> createState() => _TetapHidupState();
}

class _TetapHidupState extends State<_TetapHidup>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
