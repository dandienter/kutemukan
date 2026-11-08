-- KutemuKan 22: status akhir postingan "Dimusnahkan / Dihibahkan"
-- untuk barang temuan yang sudah melewati batas waktu penyimpanan,
-- sesuai dokumen Arsitektur dan Fitur Utama (Modul Admin / Petugas).
-- Semua aditif dan aman dijalankan ulang.

alter table public.lf_posts drop constraint if exists lf_posts_status_check;
alter table public.lf_posts add constraint lf_posts_status_check
  check (status in ('menunggu', 'tampil', 'kembali', 'ditolak', 'arsip',
                    'musnah_hibah'));
