part of '../main.dart';

// ===========================================================================
// Jembatan SIKA: masuk dan verifikasi memakai akun SIKA
// ===========================================================================

Future<Map<String, dynamic>> _panggilSika(
  String url,
  String npm,
  String kataSandi, {
  bool pakaiToken = false,
}) async {
  final res = await http
      .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (pakaiToken)
            'Authorization':
                'Bearer ${sb.auth.currentSession?.accessToken ?? ''}',
        },
        body: jsonEncode({'npm': npm, 'password': kataSandi}),
      )
      .timeout(const Duration(seconds: 30));
  Map<String, dynamic> data = {};
  try {
    data = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {}
  if (res.statusCode != 200) {
    // Bila badan balasan bukan JSON dari server kami (misal halaman galat
    // perantara), pakai pesan yang sesuai kode statusnya.
    final cadangan = switch (res.statusCode) {
      401 => 'NPM atau kata sandi SIKA salah',
      502 || 503 || 504 => 'SIKA sedang sulit dihubungi, coba lagi sebentar',
      _ => 'Server SIKA menolak permintaan',
    };
    throw (data['detail'] ?? cadangan).toString();
  }
  return data;
}

/// Masuk memakai akun SIKA: backend memverifikasi ke server kampus,
/// menyiapkan akun aplikasi, lalu fungsi ini membuka sesi Supabase-nya.
/// Mengembalikan biodata resmi dari SIKA.
Future<Map<String, dynamic>> masukDenganSika(
  String npm,
  String kataSandi,
) async {
  final data = await _panggilSika(kMasukSikaUrl, npm, kataSandi);
  await sb.auth.signInWithPassword(
    email: data['email'] as String,
    password: data['kata_sandi_sesi'] as String,
  );
  return (data['biodata'] as Map).cast<String, dynamic>();
}

/// Kaitkan verifikasi SIKA ke akun yang sedang masuk (email/Google).
/// Mengembalikan biodata resmi dari SIKA.
Future<Map<String, dynamic>> verifikasiSika(
  String npm,
  String kataSandi,
) async {
  final data = await _panggilSika(
    kVerifikasiSikaUrl,
    npm,
    kataSandi,
    pakaiToken: true,
  );
  return (data['biodata'] as Map).cast<String, dynamic>();
}
