import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:news_lens/l10n.dart';
import 'package:news_lens/presentation/screens/auth/splash_screen.dart';
import 'package:news_lens/presentation/screens/onboarding/pre_settings/pre_settings_provider.dart';
import 'package:news_lens/presentation/screens/tabs/settings_tab/settings_tab.dart';
import 'package:news_lens/providers/locale_provider.dart';
import 'package:news_lens/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:news_lens/presentation/screens/auth/login.dart';
import 'package:news_lens/presentation/screens/onboarding/pre_settings/pre_settings.dart';
import 'package:news_lens/presentation/screens/auth/register.dart';
import 'package:news_lens/presentation/screens/home_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  await dotenv.load();
  WidgetsFlutterBinding.ensureInitialized();

  if(kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAWSSdb2OhsuTXnlGqSv0owFmDsCiP-i1A",
        appId: "1:383226017741:web:2334cf886c6af8ec543684",
        messagingSenderId: "383226017741",
        projectId: "newslens-7f292",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  final themeProvider = ThemeProvider();
  await themeProvider.loadFromPrefs();

  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await themeProvider.updateUserId(currentUser.uid);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => PreSettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'News Lens',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: localeProvider.locale,
      supportedLocales: L10n.all,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/', 
      routes: {
        '/': (context) => const SplashScreen(), 
        "/login": (context) => const Login(),
        "/home": (context) => const HomePage(),
        "/pre_settings": (context) => const PreSettings(),
        "/settings": (context) => const SettingsTab(),
      },
    );
  }
}