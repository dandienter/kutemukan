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
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  final _npm = TextEditingController();
  final _sandiSika = TextEditingController();
  bool _modeDaftar = true;
  bool _formSika = false;
  bool _sibuk = false;
  bool _sibukSika = false;
  String? _galat;
  String? _galatSika;

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
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      if (_modeDaftar) {
        await sb.auth.signUp(email: _email.text.trim(), password: _sandi.text);
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 118),
                const SizedBox(height: 4),
                Text(
                  tr('Lost and Found Kampus Unindra'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: skema.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _formSika ? _kartuSika(skema) : _kartuEmail(skema),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(tr('atau')),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 14),
                if (!_formSika) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => setState(() => _formSika = true),
                    icon: const Icon(Icons.school, size: 22),
                    label: Text(tr('Masuk dengan SIKA')),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await sb.auth.signInWithOAuth(
                        OAuthProvider.google,
                        redirectTo: 'kutemukan://login-callback',
                        authScreenLaunchMode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${tr('Login Google gagal')}: $e'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text(tr('Masuk dengan Google')),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _modeDaftar ? tr('Buat akun baru') : tr('Selamat datang kembali'),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _modeDaftar
                  ? tr('Daftar supaya bisa posting dan klaim barang.')
                  : tr('Masuk untuk melanjutkan.'),
              style: TextStyle(color: skema.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 14),
            TextField(
              controller: _sandi,
              obscureText: true,
              decoration: InputDecoration(
                labelText: tr('Kata sandi'),
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_galat != null) ...[
              const SizedBox(height: 14),
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
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
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
                    ? tr('Sudah punya akun? Masuk')
                    : tr('Belum punya akun? Daftar'),
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
        padding: const EdgeInsets.all(16),
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
                'Mahasiswa Unindra? Pakai NPM dan kata sandi SIKA, statusmu langsung terverifikasi.',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _npm,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'NPM',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sandiSika,
              obscureText: true,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: tr('Kata sandi SIKA'),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_galatSika != null) ...[
              const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
                'Kata sandi SIKA hanya diteruskan ke server kampus, tidak disimpan.',
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
