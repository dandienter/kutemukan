// Konfigurasi KutemuKan.
// anon key adalah kunci publik Supabase, aman tertanam di aplikasi.
const String kSupabaseUrl = 'https://shbtcywgluswxaemdvhf.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNoYnRjeXdnbHVzd3hhZW1kdmhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM5MDQ3NjQsImV4cCI6MjEwOTQ4MDc2NH0.I7NK0gCRXY7ldcL3IadY3Q0Nr62lrZ1PzwLekhO_oOs';

// Endpoint unggah foto lewat API MySIKA (backend VPS), yang meneruskan
// berkas ke Cloudflare R2. Autentikasi memakai token login Supabase
// pengguna, jadi tidak ada kunci bersama tertanam di aplikasi.
const String kUploadUrl = 'https://api.mysika.my.id/api/lf/upload';

// Login dan verifikasi SIKA lewat API MySIKA (backend VPS). NPM dan kata
// sandi SIKA hanya diteruskan ke server kampus untuk diverifikasi,
// tidak pernah disimpan di aplikasi maupun database KutemuKan.
const String kMasukSikaUrl = 'https://api.mysika.my.id/api/lf/masuk-sika';
const String kVerifikasiSikaUrl =
    'https://api.mysika.my.id/api/lf/verifikasi-sika';

// Berkas penanda versi terbaru untuk fitur cek pembaruan.
const String kVersionJsonUrl =
    'https://temubalik.43-130-228-96.sslip.io/kutemukan-version.json';
