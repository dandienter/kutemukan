part of '../main.dart';

// ===========================================================================
// Layar privasi dan info aplikasi
// ===========================================================================

class LayarPrivasi extends StatelessWidget {
  const LayarPrivasi({super.key});
  @override
  Widget build(BuildContext context) {
    const isiId = '''
KutemuKan mengumpulkan data yang kamu berikan sendiri: nama, nomor WhatsApp, alamat email, foto profil, dan isi postingan (judul, deskripsi, lokasi, foto barang, serta ciri khusus rahasia yang hanya dipakai untuk mencocokkan klaim dan tidak ditampilkan ke publik).

Nomor WhatsApp tidak pernah ditampilkan terbuka di papan. Nomor hanya diteruskan sistem kepada pengguna yang klaimnya sudah disetujui oleh pemilik postingan, agar keduanya bisa mengatur pengembalian barang.

Data disimpan di Supabase (database dan autentikasi) dan foto disimpan di Cloudflare R2. Token perangkat disimpan untuk keperluan notifikasi push.

Kamu bisa meminta penghapusan akun dan datamu dengan menghubungi pengelola lewat email dandieoffice@gmail.com. Penghapusan akun menghapus profil dan postingan yang terkait.

KutemuKan adalah aplikasi komunitas independen untuk mahasiswa UNINDRA dan bukan aplikasi resmi Universitas Indraprasta PGRI.''';
    const isiEn = '''
KutemuKan collects the data you provide yourself: your name, WhatsApp number, email address, profile photo, and post contents (title, description, location, item photos, and secret characteristics that are used only to verify claims and are never shown publicly).

Your WhatsApp number is never displayed openly on the board. The system passes it only to a user whose claim has been approved by the post owner, so both sides can arrange the item's return.

Data is stored in Supabase (database and authentication) and photos are stored in Cloudflare R2. Device tokens are stored for push notifications.

You can request deletion of your account and data by contacting the maintainer at dandieoffice@gmail.com. Deleting an account removes the related profile and posts.

KutemuKan is an independent community app for UNINDRA students and is not an official app of Universitas Indraprasta PGRI.''';
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kebijakan Privasi'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          kBahasa.value == 'en' ? isiEn : isiId,
          style: const TextStyle(height: 1.55),
        ),
      ),
    );
  }
}

class LayarInfo extends StatelessWidget {
  const LayarInfo({super.key});

  static const List<String> _langkah = [
    'Buat laporan kehilangan atau pengumuman temuan, lengkap dengan foto dan ciri khusus rahasia.',
    'Admin memeriksa postingan sebelum menampilkannya di papan.',
    'Sistem mencocokkan kategori dan mengabari lewat notifikasi dan push.',
    'Pemilik mengajukan klaim dengan menyebut ciri khususnya.',
    'Sesudah klaim disetujui, kedua pihak terhubung ke WhatsApp dan barang ditandai selesai saat sudah kembali.',
  ];

  Widget _tombolSosial(
    BuildContext context,
    String aset,
    String url,
    String nama,
  ) {
    final warna = Theme.of(context).iconTheme.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          icon: Image.asset(aset, width: 20, height: 20, color: warna),
        ),
        const SizedBox(height: 2),
        Text(nama, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Info Aplikasi'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/icon.png', height: 96),
                ),
                const SizedBox(height: 14),
                const Text(
                  'KutemuKan',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                Text(
                  tr('Lost and Found Kampus Unindra'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    tr('Versi 1.7.0'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 16),
                Text(
                  tr(
                    'Papan lost and found untuk civitas kampus Unindra. Laporkan barang hilang, umumkan barang temuan, dan terima kabar otomatis saat ada yang cocok. Setiap postingan melewati moderasi admin dan setiap klaim harus disetujui pemilik postingan, jadi nomor WhatsApp tidak pernah terbuka sembarangan.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route_outlined, color: kBiru),
                      SizedBox(width: 8),
                      Text(
                        tr('Cara Kerja'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _langkah.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: kBiru,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tr(_langkah[i]))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: kBiru,
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ahmad Dandi Subhani',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    tr('Pengembang KutemuKan'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    tr(
                      'Mahasiswa Teknik Informatika, Universitas Indraprasta PGRI',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tombolSosial(
                        context,
                        'assets/icons/instagram.png',
                        'https://instagram.com/dandisubhani_',
                        'Instagram',
                      ),
                      const SizedBox(width: 18),
                      _tombolSosial(
                        context,
                        'assets/icons/whatsapp.png',
                        'https://wa.me/628563000126',
                        'WhatsApp',
                      ),
                      const SizedBox(width: 18),
                      _tombolSosial(
                        context,
                        'assets/icons/github.png',
                        'https://github.com/dandienter',
                        'GitHub',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(tr('Kebijakan Privasi')),
            subtitle: Text(tr('Cara data kamu dikelola di KutemuKan')),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LayarPrivasi())),
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'KutemuKan adalah aplikasi komunitas independen dan bukan aplikasi resmi Universitas Indraprasta PGRI.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              '© 2026 KutemuKan',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
