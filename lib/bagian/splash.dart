part of '../main.dart';

// ===========================================================================
// Layar splash dan panduan pembuka
// ===========================================================================

class LayarSplash extends StatefulWidget {
  const LayarSplash({super.key});
  @override
  State<LayarSplash> createState() => _LayarSplashState();
}

class _LayarSplashState extends State<LayarSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const Pembuka()));
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Satu titik penanda memuat: membesar dan menyala bergantian
  /// mengikuti putaran pengendali animasi.
  Widget _titik(int i) {
    final fase = (_ctrl.value + i * 0.22) % 1.0;
    final gelombang = fase < 0.5 ? fase * 2 : (1 - fase) * 2;
    final uk = 7 + 4 * gelombang;
    return Container(
      width: uk,
      height: uk,
      margin: const EdgeInsets.symmetric(horizontal: 3.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.35 + 0.65 * gelombang),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kGradasiKepala),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.scale(
                scale: 0.82 + 0.18 * Curves.easeOutBack.transform(v),
                child: child,
              ),
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/icon.png', height: 108),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'KutemuKan',
                    style: TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('Yang Hilang Dicariin, Yang Ketemu Dibalikin'),
                    style: const TextStyle(fontSize: 13.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 26),
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++) _titik(i),
                        ],
                      );
                    },
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }
}

/// Sesudah splash: tampilkan panduan sekali, sesudah itu langsung Gerbang.
class Pembuka extends StatelessWidget {
  const Pembuka({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance().then(
        (p) => p.getBool('panduan_v1') ?? false,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == false) return const LayarPanduan();
        return const Gerbang();
      },
    );
  }
}

class LayarPanduan extends StatefulWidget {
  const LayarPanduan({super.key});
  @override
  State<LayarPanduan> createState() => _LayarPanduanState();
}

class _LayarPanduanState extends State<LayarPanduan> {
  final _ctrl = PageController();
  int _hal = 0;

  static const _slides = [
    (
      'Barangmu hilang?',
      'Buat laporan kehilangan lengkap dengan foto, lokasi, dan ciri-cirinya. Makin jelas, makin besar peluang ketemu.',
    ),
    (
      'Menemukan barang?',
      'Umumkan sebagai temuan dan isi ciri khusus rahasianya. Hanya pemilik asli yang bisa menjawabnya saat mengklaim.',
    ),
    (
      'Klaim yang aman',
      'Nomor WhatsApp tidak terbuka sembarangan. Klaim harus disetujui dulu oleh yang memposting, baru kalian terhubung.',
    ),
  ];

  Future<void> _selesai() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('panduan_v1', true);
    if (mounted) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const Gerbang()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _selesai, child: Text(tr('Lewati'))),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _hal = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo.png', height: 210),
                      const SizedBox(height: 26),
                      Text(
                        tr(_slides[i].$1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(tr(_slides[i].$2), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.all(4),
                  width: _hal == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _hal == i ? kBiru : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_hal < _slides.length - 1) {
                      _ctrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    } else {
                      _selesai();
                    }
                  },
                  child: Text(_hal < _slides.length - 1 ? 'Lanjut' : 'Mulai'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menentukan layar awal: login, lengkapi profil, atau beranda.
