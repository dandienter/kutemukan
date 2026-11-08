part of '../main.dart';

// ===========================================================================
// Gerbang auth: menentukan layar masuk atau layar utama
// ===========================================================================

class Gerbang extends StatefulWidget {
  const Gerbang({super.key});
  @override
  State<Gerbang> createState() => _GerbangState();
}

class _GerbangState extends State<Gerbang> {
  StreamSubscription<AuthState>? _sub;
  Future<Map<String, dynamic>?>? _fProfil;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _sub = sb.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
      daftarkanTokenFcm();
    });
    daftarkanTokenFcm();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = sb.auth.currentUser;
    if (user == null) {
      _fProfil = null;
      _uid = null;
      return const LayarLogin();
    }
    // Future profil disimpan per pengguna. Membuat future baru pada setiap
    // build akan me-reset FutureBuilder, membongkar LayarUtama, dan membuat
    // Beranda memuat ulang dari nol setiap ada peristiwa auth atau tema.
    if (_uid != user.id) {
      _uid = user.id;
      _fProfil = _ambilProfil(user.id);
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fProfil,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && !snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profil = snap.data;
        if (profil == null) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const LayarProfil();
        }
        // Akun dari jembatan SIKA belum punya nomor WhatsApp. Minta
        // dilengkapi dulu supaya fitur hubungi saat klaim bisa jalan.
        if ((profil['wa'] ?? '').toString().isEmpty) {
          return LayarProfil(profilAwal: profil);
        }
        return LayarUtama(profil: profil);
      },
    );
  }

  Future<Map<String, dynamic>?> _ambilProfil(String id) async {
    final rows = await sb.from('lf_profiles').select().eq('id', id);
    if (rows.isNotEmpty &&
        ((rows.first['foto_url'] ?? '').toString().isEmpty)) {
      // Profil belum punya foto: pakai foto akun Google bila ada, supaya
      // avatar tidak tampil inisial terus di semua tab.
      final meta = sb.auth.currentUser?.userMetadata ?? {};
      final fotoMeta = (meta['avatar_url'] ?? meta['picture'])?.toString();
      if (fotoMeta != null && fotoMeta.isNotEmpty) {
        rows.first['foto_url'] = fotoMeta;
        try {
          await sb
              .from('lf_profiles')
              .update({'foto_url': fotoMeta})
              .eq('id', id);
        } catch (_) {}
      }
    }
    if (rows.isEmpty) return null;
    return rows.first;
  }
}
