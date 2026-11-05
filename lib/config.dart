// Konfigurasi KutemuKan.
// anon key adalah kunci publik Supabase, aman tertanam di aplikasi.
const String kSupabaseUrl = 'https://xeosmpukjxisgvqcaqml.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhlb3NtcHVranhpc2d2cWNhcW1sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkwMTIxODMsImV4cCI6MjA4NDU4ODE4M30.gQ_X465JqOeDe8TyR4oKk3JRlTJScXCcM2xH3wD_1Ds';

// Kunci gerbang endpoint unggah (nilai rendah, hanya penahan penyalahgunaan kasual).
const String kUploadKey = '98b7d0b5706de126052068d279954b5537b5';

// Endpoint unggah foto di VPS (kredensial R2 hanya ada di server).
const String kUploadUrl =
    'https://temubalik.43-130-228-96.sslip.io/upload.php';
