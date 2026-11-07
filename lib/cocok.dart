// Mesin pencocokan otomatis antara laporan kehilangan dan pengumuman
// temuan. Kemiripan teks dihitung dengan TF-IDF dan cosine similarity,
// lalu digabung dengan skor kategori, kemiripan lokasi (Jaccard), dan
// kedekatan waktu menjadi satu skor akhir 0..1.
//
// Rumus skor akhir:
//   0.55 * teks + 0.20 * kategori + 0.15 * lokasi + 0.10 * waktu
import 'dart:math' as math;

/// Kata umum Bahasa Indonesia yang tidak membantu pencocokan.
const Set<String> kStopwords = {
  'yang',
  'dan',
  'di',
  'ke',
  'dari',
  'ini',
  'itu',
  'ada',
  'saya',
  'aku',
  'dengan',
  'untuk',
  'pada',
  'adalah',
  'atau',
  'tidak',
  'tak',
  'nya',
  'dalam',
  'oleh',
  'akan',
  'sudah',
  'telah',
  'juga',
  'bisa',
  'dapat',
  'saat',
  'ketika',
  'setelah',
  'sesudah',
  'sebelum',
  'sekitar',
  'dekat',
  'antara',
  'kepada',
  'terhadap',
  'sebagai',
  'karena',
  'namun',
  'tapi',
  'lalu',
  'kemudian',
  'masih',
  'lagi',
  'sangat',
  'sekali',
  'lebih',
  'paling',
  'para',
  'setiap',
  'tiap',
  'bagi',
  'tentang',
  'seperti',
  'yaitu',
  'yakni',
  'ialah',
  'merupakan',
  'dimana',
  'kemana',
  'kapan',
  'siapa',
  'mengapa',
  'bagaimana',
  'berapa',
  'mana',
  'apa',
  'apakah',
  'jika',
  'kalau',
  'bila',
  'agar',
  'supaya',
  'hingga',
  'sampai',
  'atas',
  'bawah',
  'luar',
  'belakang',
  'depan',
  'samping',
  'tengah',
  'hari',
  'kemarin',
  'besok',
  'tadi',
  'nanti',
  'pagi',
  'siang',
  'sore',
  'malam',
  'tolong',
  'mohon',
  'harap',
  'kemungkinan',
  'hilang',
  'ditemukan',
  'menemukan',
  'kehilangan',
  'barang',
  'milik',
  'punya',
};

/// Pecah teks menjadi token bersih tanpa stopwords.
List<String> tokenisasi(String teks) {
  final bersih = teks.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return bersih
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 3 && !kStopwords.contains(t))
      .toList();
}

/// Teks dokumen satu postingan. Judul diulang dua kali karena bobotnya
/// paling menentukan, kategori ikut masuk sebagai kata biasa.
String teksDokumen(Map<String, dynamic> post) {
  final judul = (post['judul'] ?? '').toString();
  final deskripsi = (post['deskripsi'] ?? '').toString();
  final kategori = (post['kategori'] ?? '').toString();
  return '$judul $judul $deskripsi $kategori';
}

class HasilCocok {
  final Map<String, dynamic> post;
  final double skor;

  /// True bila pasangan ini ditemukan atau diperkuat pencocokan AI
  /// semantik di server (embedding), bukan kata kunci saja.
  final bool dariAi;
  HasilCocok(this.post, this.skor, {this.dariAi = false});
}

class MesinCocok {
  final Map<String, double> _idf = {};

  /// Bangun tabel IDF dari seluruh korpus postingan yang tampil.
  MesinCocok(List<Map<String, dynamic>> korpus) {
    final df = <String, int>{};
    for (final p in korpus) {
      for (final t in tokenisasi(teksDokumen(p)).toSet()) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = korpus.length;
    df.forEach((kata, jumlah) {
      _idf[kata] = math.log((n + 1) / (jumlah + 1)) + 1;
    });
  }

  Map<String, double> _vektor(Map<String, dynamic> post) {
    final token = tokenisasi(teksDokumen(post));
    if (token.isEmpty) return {};
    final tf = <String, int>{};
    for (final t in token) {
      tf[t] = (tf[t] ?? 0) + 1;
    }
    return tf.map(
      (kata, jumlah) =>
          MapEntry(kata, (jumlah / token.length) * (_idf[kata] ?? 1)),
    );
  }

  static double _cosine(Map<String, double> a, Map<String, double> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var titik = 0.0;
    var na = 0.0;
    var nb = 0.0;
    a.forEach((k, v) {
      na += v * v;
      final w = b[k];
      if (w != null) titik += v * w;
    });
    b.forEach((_, v) => nb += v * v);
    if (na == 0 || nb == 0) return 0;
    return titik / (math.sqrt(na) * math.sqrt(nb));
  }

  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final gabung = a.union(b).length;
    if (gabung == 0) return 0;
    return a.intersection(b).length / gabung;
  }

  /// Skor kecocokan dua postingan (0..1) beserta rincian tidak dipakai
  /// di tampilan, skor akhir saja yang dikembalikan.
  double skorPasangan(Map<String, dynamic> a, Map<String, dynamic> b) {
    final teks = _cosine(_vektor(a), _vektor(b));
    final kategori = (a['kategori'] ?? '') == (b['kategori'] ?? '') ? 1.0 : 0.0;
    final lokasi = _jaccard(
      tokenisasi((a['lokasi'] ?? '').toString()).toSet(),
      tokenisasi((b['lokasi'] ?? '').toString()).toSet(),
    );
    var waktu = 0.0;
    final ta = DateTime.tryParse((a['created_at'] ?? '').toString());
    final tb = DateTime.tryParse((b['created_at'] ?? '').toString());
    if (ta != null && tb != null) {
      final hari = ta.difference(tb).inHours.abs() / 24.0;
      waktu = math.max(0, 1 - hari / 30);
    }
    return 0.55 * teks + 0.20 * kategori + 0.15 * lokasi + 0.10 * waktu;
  }

  /// Cari pasangan paling cocok untuk satu postingan dari korpus:
  /// jenis berlawanan, status tampil, bukan milik sendiri.
  List<HasilCocok> cariCocok(
    Map<String, dynamic> post,
    List<Map<String, dynamic>> korpus, {
    double ambang = 0.30,
    int maks = 3,
  }) {
    final hasil = <HasilCocok>[];
    for (final lain in korpus) {
      if (lain['id'] == post['id']) continue;
      if (lain['jenis'] == post['jenis']) continue;
      if (lain['status'] != 'tampil') continue;
      if (lain['user_id'] == post['user_id']) continue;
      final skor = skorPasangan(post, lain);
      if (skor >= ambang) hasil.add(HasilCocok(lain, skor));
    }
    hasil.sort((x, y) => y.skor.compareTo(x.skor));
    return hasil.take(maks).toList();
  }
}
