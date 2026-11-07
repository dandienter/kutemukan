// Konfigurasi KutemuKan.
// anon key adalah kunci publik Supabase, aman tertanam di aplikasi.
const String kSupabaseUrl = 'https://shbtcywgluswxaemdvhf.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNoYnRjeXdnbHVzd3hhZW1kdmhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM5MDQ3NjQsImV4cCI6MjEwOTQ4MDc2NH0.I7NK0gCRXY7ldcL3IadY3Q0Nr62lrZ1PzwLekhO_oOs';

// Endpoint unggah foto lewat API MySIKA (backend VPS), yang meneruskan
// berkas ke Cloudflare R2. Autentikasi memakai token login Supabase
// pengguna, jadi tidak ada kunci bersama tertanam di aplikasi.
const String kUploadUrl = 'https://api.mysika.my.id/api/lf/upload';
const String kUploadAudioUrl = 'https://api.mysika.my.id/api/lf/upload-audio';

// Login dan verifikasi SIKA lewat API MySIKA (backend VPS). NPM dan kata
// sandi SIKA hanya diteruskan ke server kampus untuk diverifikasi,
// tidak pernah disimpan di aplikasi maupun database KutemuKan.
const String kMasukSikaUrl = 'https://api.mysika.my.id/api/lf/masuk-sika';
const String kVerifikasiSikaUrl =
    'https://api.mysika.my.id/api/lf/verifikasi-sika';

// Client ID OAuth web untuk login Google native (pemilih akun di dalam
// aplikasi). Token ID dari alur native ditukar menjadi sesi Supabase.
// Client ID bersifat publik, aman tertanam di aplikasi.
const String kGoogleWebClientId =
    '654645757975-dp0q4t8ei0ole5abnbst3u5s7ca6plia.apps.googleusercontent.com';

// Berkas penanda versi terbaru untuk fitur cek pembaruan.
const String kVersionJsonUrl =
    'https://temubalik.43-130-228-96.sslip.io/kutemukan-version.json';
