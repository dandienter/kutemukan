import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cocok.dart';
import 'config.dart';
import 'i18n.dart';

@pragma('vm:entry-point')
part 'bagian/sika.dart';
part 'bagian/bersama.dart';
part 'bagian/splash.dart';
part 'bagian/gerbang.dart';
part 'bagian/login.dart';
part 'bagian/utama.dart';
part 'bagian/beranda.dart';
part 'bagian/detail.dart';
part 'bagian/klaim.dart';
part 'bagian/buat.dart';
part 'bagian/bagikan.dart';
part 'bagian/pantau.dart';
part 'bagian/chat.dart';
part 'bagian/pengumuman.dart';
part 'bagian/notif.dart';
part 'bagian/akun.dart';
part 'bagian/profil.dart';
part 'bagian/verifikasi.dart';
part 'bagian/sandi.dart';
part 'bagian/kritik.dart';
part 'bagian/pahlawan.dart';
part 'bagian/statistik.dart';
part 'bagian/moderasi.dart';
part 'bagian/laporan.dart';
part 'bagian/info.dart';

Future<void> _fcmLatar(RemoteMessage pesan) async {
  // Pesan berkategori notification ditampilkan sistem secara otomatis.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  await muatPreferensi();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_fcmLatar);
  } catch (_) {
    // Firebase belum terpasang sempurna: aplikasi tetap jalan tanpa push.
  }
  runApp(const KutemuKanApp());
}

/// Daftarkan token FCM perangkat ini untuk pengguna yang sedang masuk.
Future<void> daftarkanTokenFcm() async {
  try {
    final user = sb.auth.currentUser;
    if (user == null) return;
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission();
    final token = await fm.getToken();
    if (token != null) {
      await sb.from('lf_devices').delete().eq('user_id', user.id);
      await sb.from('lf_devices').insert({
        'user_id': user.id,
        'token': token,
        'platform': 'android',
      });
    }
  } catch (_) {
    // Token gagal tercatat: notif dalam aplikasi tetap berfungsi.
  }
}

/// Kompres foto apa pun menjadi WebP ringan sebelum diunggah.

class KutemuKanApp extends StatelessWidget {
  const KutemuKanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: kTemaMode,
      builder: (_, mode, __) => ValueListenableBuilder<String>(
        valueListenable: kBahasa,
        builder: (_, bahasa, __) => MaterialApp(
          title: 'KutemuKan',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          locale: Locale(bahasa),
          supportedLocales: const [Locale('id'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: kBiru),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: kBiru,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const LayarSplash(),
        ),
      ),
    );
  }
}

/// Splash pembuka beranimasi: maskot memudar masuk, nama dan gelar menyusul.
