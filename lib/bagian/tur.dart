part of '../main.dart';

// ===========================================================================
// Panduan interaktif: tur keliling fitur dengan sorotan tombol asli,
// ditemani maskot. Jalan otomatis sekali untuk pengguna baru dan bisa
// dibuka lagi kapan pun dari menu Akun.
// ===========================================================================

/// Satu langkah tur: target widget (boleh kosong untuk gelembung di
/// tengah layar), tab utama yang harus aktif, judul, dan penjelasan.
class LangkahTur {
  final GlobalKey? kunci;
  final int? tab;
  final String judul;
  final String isi;

  const LangkahTur({this.kunci, this.tab, required this.judul, required this.isi});
}

void mulaiTurPanduan(
  BuildContext context,
  List<LangkahTur> langkah, {
  void Function(int tab)? keTab,
  VoidCallback? selesai,
}) {
  if (langkah.isEmpty) return;
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) =>
          LayarTur(langkah: langkah, keTab: keTab, selesai: selesai),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class LayarTur extends StatefulWidget {
  final List<LangkahTur> langkah;
  final void Function(int tab)? keTab;
  final VoidCallback? selesai;

  const LayarTur({super.key, required this.langkah, this.keTab, this.selesai});

  @override
  State<LayarTur> createState() => _LayarTurState();
}

class _LayarTurState extends State<LayarTur> {
  int _i = 0;
  Rect? _lubang;
  bool _mengukur = true;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    final langkah = widget.langkah[_i];
    if (langkah.tab != null) widget.keTab?.call(langkah.tab!);
    // Beri waktu tab berganti dan transisinya selesai sebelum mengukur.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Rect? ukur() {
      final ctx = langkah.kunci?.currentContext;
      if (ctx == null) return null;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      final pos = box.localToGlobal(Offset.zero);
      return (pos & box.size).inflate(6);
    }

    Rect? r = ukur();
    final ctxTur = langkah.kunci?.currentContext;
    if (ctxTur != null) {
      // Target bisa sedang tergulir keluar layar (mis. Beranda digulir
      // ke bawah): gulir dulu sampai terlihat, baru ukur ulang.
      final layar = MediaQuery.of(ctxTur).size;
      if (r == null || r.bottom < 0 || r.top > layar.height) {
        await Scrollable.ensureVisible(
          ctxTur,
          duration: const Duration(milliseconds: 300),
          alignment: 0.22,
        );
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        r = ukur();
      }
    }
    setState(() {
      _lubang = r;
      _mengukur = false;
    });
  }

  void _pindah(int ke) {
    if (ke < 0 || ke >= widget.langkah.length) return;
    setState(() {
      _i = ke;
      _lubang = null;
      _mengukur = true;
    });
    _siapkan();
  }

  void _tutup() {
    widget.selesai?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final langkah = widget.langkah[_i];
    final layar = MediaQuery.of(context).size;
    final terakhir = _i >= widget.langkah.length - 1;

    final gelembung = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/maskot.png', width: 52, height: 52),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        langkah.judul,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(langkah.isi, style: const TextStyle(fontSize: 13.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${_i + 1} / ${widget.langkah.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _tutup,
                  child: Text(tr('Lewati')),
                ),
                if (_i > 0)
                  TextButton(
                    onPressed: () => _pindah(_i - 1),
                    child: Text(tr('Kembali')),
                  ),
                FilledButton(
                  onPressed: terakhir ? _tutup : () => _pindah(_i + 1),
                  child: Text(tr(terakhir ? 'Selesai' : 'Berikutnya')),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Posisi gelembung: di bawah sorotan bila muat, di atasnya bila
    // tidak, dan di tengah untuk langkah tanpa target.
    Widget posisi;
    if (_mengukur || _lubang == null) {
      posisi = Center(child: gelembung);
    } else if (_lubang!.bottom + 210 < layar.height) {
      posisi = Positioned(
        top: _lubang!.bottom + 12,
        left: 0,
        right: 0,
        child: gelembung,
      );
    } else {
      posisi = Positioned(
        bottom: layar.height - _lubang!.top + 12,
        left: 0,
        right: 0,
        child: gelembung,
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: CustomPaint(painter: _Pelubang(_mengukur ? null : _lubang)),
            ),
          ),
          posisi,
        ],
      ),
    );
  }
}

/// Pelukis latar gelap dengan lubang terang di area target.
class _Pelubang extends CustomPainter {
  final Rect? rect;

  _Pelubang(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()..color = Colors.black.withValues(alpha: 0.72);
    if (rect == null) {
      canvas.drawRect(Offset.zero & size, cat);
      return;
    }
    final luar = Path()..addRect(Offset.zero & size);
    final dalam = Path()
      ..addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(14)));
    canvas.drawPath(Path.combine(PathOperation.difference, luar, dalam), cat);
    final tepi = Paint()
      ..color = kBiru
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect!, const Radius.circular(14)),
      tepi,
    );
  }

  @override
  bool shouldRepaint(covariant _Pelubang lama) => lama.rect != rect;
}
