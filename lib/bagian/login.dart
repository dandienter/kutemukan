part of '../main.dart';

// ===========================================================================
// Layar masuk dan daftar (email, SIKA, Google)
// ===========================================================================

class LayarLogin extends StatefulWidget {
  const LayarLogin({super.key});
  @override
  State<LayarLogin> createState() => _LayarLoginState();
}

class _LayarLoginState extends State<LayarLogin> {
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  final _npm = TextEditingController();
  final _sandiSika = TextEditingController();
  bool _modeDaftar = true;
  bool _formSika = false;
  bool _lihatSandi = false;
  bool _lihatSandiSika = false;
  bool _sibuk = false;
  bool _sibukSika = false;
  String? _galat;
  String? _galatSika;
  String? _versiApp;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _versiApp = info.version);
    });
  }

  Future<void> _masukGoogle() async {
    // Jalur utama: pemilih akun Google native di dalam aplikasi,
    // tanpa membuka peramban. Token ID ditukar menjadi sesi Supabase.
    try {
      final google = GoogleSignIn(
        serverClientId: kGoogleWebClientId,
        scopes: const ['email', 'profile'],
      );
      final akun = await google.signIn();
      if (akun == null) return; // pengguna membatalkan pilihan akun
      final auth = await akun.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('Token Google kosong');
      await sb.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
      return; // sesi terbuka, Gerbang akan mengarahkan masuk
    } catch (e) {
      // Jalur native gagal (layanan Google tidak ada atau token
      // ditolak): tampilkan sebabnya sebentar supaya bisa dilaporkan,
      // lalu jatuh ke alur OAuth peramban yang sudah terbukti.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr('Login Google di aplikasi gagal')}: $e',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF37474F),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
    try {
      await sb.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'kutemukan://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Login Google gagal')}: $e')),
        );
      }
    }
  }

  Future<void> _masukSika() async {
    final npm = _npm.text.trim();
    if (npm.isEmpty || _sandiSika.text.isEmpty) {
      setState(() => _galatSika = tr('Isi NPM dan kata sandi SIKA dulu.'));
      return;
    }
    setState(() {
      _sibukSika = true;
      _galatSika = null;
    });
    try {
      await masukDenganSika(npm, _sandiSika.text);
      // Sesi terbuka, Gerbang akan mengarahkan masuk.
    } catch (e) {
      _galatSika = e.toString();
    }
    if (mounted) setState(() => _sibukSika = false);
  }

  Future<void> _kirim() async {
    if (_modeDaftar && _nama.text.trim().length < 3) {
      setState(() => _galat = tr('Isi nama lengkap dulu ya.'));
      return;
    }
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      if (_modeDaftar) {
        await sb.auth.signUp(
          email: _email.text.trim(),
          password: _sandi.text,
          data: {'nama': _nama.text.trim()},
        );
      } else {
        await sb.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _sandi.text,
        );
      }
    } on AuthException catch (e) {
      _galat = e.message;
    } catch (e) {
      _galat = 'Gagal tersambung: $e';
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 84),
                const SizedBox(height: 6),
                Text(
                  tr('Yang Hilang Dicariin, Yang Ketemu Dibalikin'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: kBiru,
                  ),
                ),
                const SizedBox(height: 10),
                _formSika ? _kartuSika(skema) : _kartuEmail(skema),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        tr('atau lanjutkan dengan'),
                        style: TextStyle(
                          fontSize: 12,
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_formSika) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => setState(() => _formSika = true),
                    icon: const Icon(Icons.school, size: 22, color: kBiru),
                    label: Text(tr('Masuk dengan SIKA')),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _masukGoogle,
                  icon: Image.asset(
                    'assets/icons/google.png',
                    width: 22,
                    height: 22,
                  ),
                  label: Text(tr('Masuk dengan Google')),
                ),
                const SizedBox(height: 14),
                Text(
                  '© 2026 KutemuKan',
                  style: TextStyle(
                    color: skema.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (_versiApp != null)
                  Text(
                    'v$_versiApp',
                    style: TextStyle(
                      color: skema.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kartuEmail(ColorScheme skema) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _modeDaftar ? tr('Yuk, bikin akun baru') : tr('Selamat Datang'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _modeDaftar
                  ? tr('Daftar dulu biar bisa posting dan klaim barang.')
                  : tr('Masuk untuk mulai mencari dan menemukan'),
              style: TextStyle(color: skema.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_modeDaftar) ...[
              TextField(
                controller: _nama,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: tr('Nama lengkap'),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.mail_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sandi,
              obscureText: !_lihatSandi,
              decoration: InputDecoration(
                labelText: tr('Kata sandi'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _lihatSandi
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: tr('Lihat kata sandi'),
                  onPressed: () =>
                      setState(() => _lihatSandi = !_lihatSandi),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_galat != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: skema.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _galat!,
                  style: TextStyle(color: skema.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _sibuk ? null : _kirim,
              child: Text(
                _sibuk
                    ? tr('Memproses...')
                    : (_modeDaftar ? tr('Daftar') : tr('Masuk')),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _modeDaftar = !_modeDaftar),
              child: Text(
                _modeDaftar
                    ? tr('Sudah punya akun? Masuk aja')
                    : tr('Belum punya akun? Daftar yuk'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuSika(ColorScheme skema) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: kBiru,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  tr('Masuk dengan SIKA'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Anak Unindra? Masuk pakai NPM dan kata sandi SIKA, statusmu langsung terverifikasi.',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'NPM',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _npm,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: tr('Masukkan NPM kamu'),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Kata sandi SIKA'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _sandiSika,
              obscureText: !_lihatSandiSika,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: tr('Masukkan kata sandi SIKA'),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _lihatSandiSika
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: tr('Lihat kata sandi'),
                  onPressed: () =>
                      setState(() => _lihatSandiSika = !_lihatSandiSika),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_galatSika != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: skema.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _galatSika!,
                  style: TextStyle(color: skema.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kBiru,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _sibukSika ? null : _masukSika,
              child: Text(
                _sibukSika ? tr('Memproses...') : tr('Masuk'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Tenang, kata sandi SIKA kamu cuma diteruskan ke server kampus, tidak disimpan di sini.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            TextButton(
              onPressed: () => setState(() => _formSika = false),
              child: Text(
                tr('Pakai email saja'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
