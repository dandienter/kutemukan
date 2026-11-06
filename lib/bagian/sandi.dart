part of '../main.dart';

// ===========================================================================
// Layar ubah kata sandi
// ===========================================================================

class LayarUbahSandi extends StatefulWidget {
  const LayarUbahSandi({super.key});
  @override
  State<LayarUbahSandi> createState() => _LayarUbahSandiState();
}

class _LayarUbahSandiState extends State<LayarUbahSandi> {
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool _sibuk = false;

  Future<void> _simpan() async {
    final b = _baru.text;
    if (b.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Kata sandi minimal 6 karakter.'))),
      );
      return;
    }
    if (b != _ulang.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Konfirmasi kata sandi tidak sama.'))),
      );
      return;
    }
    setState(() => _sibuk = true);
    try {
      await sb.auth.updateUser(UserAttributes(password: b));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Kata sandi terpasang. Sekarang kamu juga bisa masuk memakai email dan sandi ini.',
              ),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('Gagal mengubah sandi')}: $e')),
        );
      }
    }
    if (mounted) setState(() => _sibuk = false);
  }

  @override
  Widget build(BuildContext context) {
    final email = sb.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ubah Kata Sandi'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kBahasa.value == 'en'
                  ? 'Account: $email\n\nOnce a password is set, you can sign in two ways: the Google button, or the email and password form. Both lead to the same account.'
                  : 'Akun: $email\n\nSesudah sandi terpasang, kamu bisa masuk dengan dua cara: tombol Google, atau formulir email dan sandi. Keduanya masuk ke akun yang sama.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _baru,
              obscureText: true,
              decoration: InputDecoration(
                labelText: tr('Kata sandi baru'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ulang,
              obscureText: true,
              decoration: InputDecoration(
                labelText: tr('Ulangi kata sandi baru'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _sibuk ? null : _simpan,
              child: Text(_sibuk ? 'Menyimpan...' : 'Simpan Kata Sandi'),
            ),
          ],
        ),
      ),
    );
  }
}
