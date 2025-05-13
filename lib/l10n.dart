import 'dart:ui';

class L10n {
  static final all = [
    const Locale('en'),
    const Locale('it'),
    const Locale('de'),
    const Locale('fr'),
  ];
  
  static String getLanguageCode (String languageLabel) {
    switch(languageLabel){
      case 'En':
        return 'en';
      case 'IT':
        return 'it';
      case 'DE':
        return 'de';
      case 'FR':
        return 'fr';
      default:
        return 'en';
    }
  }
}

  