/// Lapor Cepat: uraikan satu kalimat bebas menjadi atribut postingan.
///
/// Pengguna cukup bercerita seperti biasa, misalnya "Gue kehilangan
/// dompet warna cokelat kayaknya di sekitar kantin kemarin sore", lalu
/// parser pola lokal ini menebak jenis laporan, barang, kategori, warna,
/// lokasi, dan waktu. Semua berjalan di perangkat, tanpa API, dan hasil
/// tebakannya selalu bisa diedit pengguna sebelum postingan terkirim.
library;

/// Hasil uraian Lapor Cepat. Field yang null berarti tidak dikenali
/// dari kalimat dan dibiarkan kosong untuk diisi manual.
class HasilLaporCepat {
  final String jenis; // 'hilang' atau 'temuan'
  final String? barang; // kata barang, mis. 'dompet'
  final String? kategori; // salah satu kategori aplikasi
  final String? warna;
  final String? lokasi;
  final String? waktuTeks; // frasa waktu asli, mis. 'kemarin sore'
  final DateTime? waktu; // perkiraan waktu kejadian

  const HasilLaporCepat({
    required this.jenis,
    this.barang,
    this.kategori,
    this.warna,
    this.lokasi,
    this.waktuTeks,
    this.waktu,
  });

  /// Judul usulan: barang + warna, huruf pertama kapital.
  String? get judulUsulan {
    if (barang == null) return null;
    final b = barang!;
    final kapital = b[0].toUpperCase() + b.substring(1);
    return warna == null ? kapital : '$kapital $warna';
  }
}

/// Pasangan kata barang ke kategori aplikasi. Urutan penting: frasa
/// yang lebih khusus harus diuji lebih dulu.
const List<(List<String>, String, String)> _kamusBarang = [
  (['kartu tanda mahasiswa', 'kartu mahasiswa'], 'KTM & Dokumen', 'KTM'),
  (['ktm'], 'KTM & Dokumen', 'KTM'),
  (['ktp', 'sim', 'stnk', 'ijazah', 'dokumen', 'kartu'], 'KTM & Dokumen', 'kartu'),
  (['dompet'], 'Dompet & Uang', 'dompet'),
  (['uang', 'duit'], 'Dompet & Uang', 'uang'),
  (['kunci motor', 'kunci mobil', 'kunci kos', 'kunci'], 'Kunci', 'kunci'),
  (['handphone', 'hand phone', 'telepon genggam', 'smartphone'], 'HP & Elektronik', 'HP'),
  (['hp'], 'HP & Elektronik', 'HP'),
  (['iphone', 'samsung', 'xiaomi', 'redmi', 'oppo', 'vivo', 'realme', 'infinix', 'poco'], 'HP & Elektronik', 'HP'),
  (['laptop', 'macbook', 'notebook'], 'HP & Elektronik', 'laptop'),
  (['tablet', 'ipad'], 'HP & Elektronik', 'tablet'),
  (['headset', 'earphone', 'earbuds', 'airpods', 'tws'], 'HP & Elektronik', 'headset'),
  (['charger', 'powerbank', 'power bank', 'flashdisk', 'flash disk', 'mouse'], 'HP & Elektronik', 'charger'),
  (['helm'], 'Helm & Kendaraan', 'helm'),
  (['ransel', 'backpack', 'tas'], 'Tas & Pakaian', 'tas'),
  (['jaket', 'hoodie', 'baju', 'kaos', 'kemeja', 'celana', 'topi', 'kerudung', 'jilbab', 'sepatu', 'sandal'], 'Tas & Pakaian', 'pakaian'),
  (['buku', 'catatan', 'novel', 'modul', 'pulpen', 'pensil', 'penggaris', 'kalkulator'], 'Buku & Alat Tulis', 'buku'),
  (['botol minum', 'tumbler', 'tumblr', 'botol'], 'Lainnya', 'botol minum'),
  (['payung'], 'Lainnya', 'payung'),
  (['jam tangan'], 'Lainnya', 'jam tangan'),
  (['kacamata'], 'Lainnya', 'kacamata'),
];

const List<String> _kamusWarna = [
  'hitam', 'putih', 'merah', 'biru', 'hijau', 'kuning', 'cokelat',
  'coklat', 'abu-abu', 'abu', 'pink', 'ungu', 'oranye', 'jingga',
  'emas', 'silver', 'perak', 'krem', 'marun', 'navy', 'tosca',
  'dongker', 'bening', 'transparan',
];

const List<String> _kamusLokasi = [
  'kantin', 'perpustakaan', 'perpus', 'parkiran', 'parkir motor',
  'parkir mobil', 'masjid', 'mushola', 'aula', 'lapangan', 'lobi',
  'laboratorium', 'lab komputer', 'lab', 'ruang kelas', 'kelas',
  'tangga', 'toilet', 'wc', 'sekretariat', 'ruang dosen',
  'fotokopian', 'fotocopy', 'gedung', 'koridor', 'selasar',
  'warung', 'halte', 'gerbang', 'pos satpam',
];

HasilLaporCepat uraikanLaporCepat(String teksAsli, {DateTime? sekarang}) {
  final kini = sekarang ?? DateTime.now();
  final teks = ' ${teksAsli.toLowerCase()} ';

  // Jenis laporan: temuan hanya bila ada kata kerja menemukan yang
  // jelas, selain itu anggap kehilangan (kasus paling umum).
  var jenis = 'hilang';
  if (RegExp(
    r'\b(nemu|nemuin|menemukan|ditemukan|ketemu barang|mengambil barang)\b',
  ).hasMatch(teks)) {
    jenis = 'temuan';
  }
  if (RegExp(
    r'\b(kehilangan|kehilanganku|hilang|kececer|ketinggalan|kehilangan barang)\b',
  ).hasMatch(teks)) {
    jenis = 'hilang';
  }

  String? barang;
  String? kategori;
  for (final (kataKata, kat, label) in _kamusBarang) {
    var ketemu = false;
    for (final k in kataKata) {
      if (teks.contains(' $k ') || teks.contains(' $k,') || teks.contains(' $k.')) {
        ketemu = true;
        break;
      }
      if (RegExp('\\b${RegExp.escape(k)}\\b').hasMatch(teks)) {
        ketemu = true;
        break;
      }
    }
    if (ketemu) {
      kategori = kat;
      barang = label;
      break;
    }
  }

  String? warna;
  for (final w in _kamusWarna) {
    if (RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(teks)) {
      warna = w == 'coklat' ? 'cokelat' : w;
      break;
    }
  }

  // Lokasi, dari yang paling spesifik ke yang paling umum:
  // 1) pola beridentitas: gedung 6, lantai 2, ruang 3.2, kelas 7. Kata
  //    kamus yang menempel tepat di depannya ikut dibawa (parkiran
  //    gedung b, tangga gedung 6), tapi kata umum yang jauh tidak
  //    boleh menang melawan pola ini.
  // 2) frasa sesudah kata depan (di sekitar X, di dekat X, di X):
  //    ambil kata kamus pertama di frasa itu plus identitas sesudahnya.
  // 3) kata kamus yang muncul paling awal di kalimat.
  String rapikanLokasi(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .map(
        (w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1)}',
      )
      .join(' ');
  bool identitas(String w) =>
      RegExp(r'^([0-9]+([.,][0-9]+)?[a-z]?|[a-z])$').hasMatch(w);
  String? lokasi;
  final mSpesifik = RegExp(
    r'\b(gedung|lantai|lt|ruang|ruangan|kelas)\s+([a-z]?[0-9]+([.,][0-9]+)?[a-z]?|[a-z])\b',
  ).firstMatch(teks);
  if (mSpesifik != null) {
    var inti = '${mSpesifik.group(1)} ${mSpesifik.group(2)}';
    if (inti.startsWith('lt ')) inti = 'lantai ${inti.substring(3)}';
    final sebelum = teks
        .substring(0, mSpesifik.start)
        .trim()
        .split(RegExp(r'\s+'));
    final kataSebelum = sebelum.isEmpty ? '' : sebelum.last;
    if (_kamusLokasi.contains(kataSebelum) &&
        !inti.startsWith(kataSebelum)) {
      inti = '$kataSebelum $inti';
    }
    lokasi = rapikanLokasi(inti);
  }
  if (lokasi == null) {
    final m = RegExp(
      r'\bdi (?:sekitar |dekat |area |seberang |belakang |depan |samping |pinggir )?([a-z0-9]+(?: [a-z0-9]+){0,2})',
    ).firstMatch(teks);
    if (m != null) {
      final kata = m.group(1)!.trim().split(RegExp(r'\s+'));
      const stop = {'sana', 'situ', 'dalam', 'atas', 'luar', 'kampus'};
      if (!stop.contains(kata.first)) {
        var idxKamus = -1;
        var panjangKamus = 0;
        for (var i = 0; i < kata.length; i++) {
          for (final l in _kamusLokasi) {
            final bagian = l.split(' ');
            if (i + bagian.length <= kata.length &&
                kata.sublist(i, i + bagian.length).join(' ') == l &&
                bagian.length > panjangKamus) {
              idxKamus = i;
              panjangKamus = bagian.length;
            }
          }
          if (idxKamus >= 0) break;
        }
        if (idxKamus >= 0) {
          final ambil = kata.sublist(idxKamus, idxKamus + panjangKamus);
          final sesudah = idxKamus + panjangKamus;
          if (sesudah < kata.length && identitas(kata[sesudah])) {
            ambil.add(kata[sesudah]);
          }
          lokasi = rapikanLokasi(ambil.join(' '));
        } else {
          lokasi = rapikanLokasi(kata.join(' '));
        }
      }
    }
  }
  if (lokasi == null) {
    var idxTerbaik = -1;
    String? frasaTerbaik;
    for (final l in _kamusLokasi) {
      final i = teks.indexOf(l);
      if (i >= 0 &&
          (idxTerbaik < 0 ||
              i < idxTerbaik ||
              (i == idxTerbaik && l.length > (frasaTerbaik?.length ?? 0)))) {
        idxTerbaik = i;
        frasaTerbaik = l;
      }
    }
    if (frasaTerbaik != null) {
      var hasil = frasaTerbaik;
      final sisa = teks
          .substring(idxTerbaik + frasaTerbaik.length)
          .trim()
          .split(RegExp(r'\s+'));
      if (sisa.isNotEmpty && identitas(sisa.first)) {
        hasil = '$hasil ${sisa.first}';
      }
      lokasi = rapikanLokasi(hasil);
    }
  }

  // Waktu: frasa umum diterjemahkan menjadi perkiraan tanggal jam.
  String? waktuTeks;
  DateTime? waktu;
  final polaWaktu = <(RegExp, String, DateTime Function())>[
    (RegExp(r'\bkemarin lusa\b'), 'kemarin lusa', () => kini.subtract(const Duration(days: 2))),
    (RegExp(r'\bkemarin sore\b'), 'kemarin sore', () => DateTime(kini.year, kini.month, kini.day - 1, 16)),
    (RegExp(r'\bkemarin malam\b'), 'kemarin malam', () => DateTime(kini.year, kini.month, kini.day - 1, 20)),
    (RegExp(r'\bkemarin\b'), 'kemarin', () => kini.subtract(const Duration(days: 1))),
    (RegExp(r'\bsemalam\b'), 'semalam', () => DateTime(kini.year, kini.month, kini.day - 1, 20)),
    (RegExp(r'\btadi malam\b'), 'tadi malam', () => DateTime(kini.year, kini.month, kini.day - 1, 20)),
    (RegExp(r'\btadi pagi\b'), 'tadi pagi', () => DateTime(kini.year, kini.month, kini.day, 8)),
    (RegExp(r'\btadi siang\b'), 'tadi siang', () => DateTime(kini.year, kini.month, kini.day, 12, 30)),
    (RegExp(r'\btadi sore\b'), 'tadi sore', () => DateTime(kini.year, kini.month, kini.day, 16)),
    (RegExp(r'\btadi\b'), 'tadi', () => kini.subtract(const Duration(hours: 2))),
    (RegExp(r'\bbarusan\b'), 'barusan', () => kini),
    (RegExp(r'\bminggu lalu\b'), 'minggu lalu', () => kini.subtract(const Duration(days: 7))),
    (RegExp(r'\bhari ini\b'), 'hari ini', () => kini),
  ];
  for (final (pola, label, buat) in polaWaktu) {
    if (pola.hasMatch(teks)) {
      waktuTeks = label;
      waktu = buat();
      break;
    }
  }

  return HasilLaporCepat(
    jenis: jenis,
    barang: barang,
    kategori: kategori,
    warna: warna,
    lokasi: lokasi,
    waktuTeks: waktuTeks,
    waktu: waktu,
  );
}
