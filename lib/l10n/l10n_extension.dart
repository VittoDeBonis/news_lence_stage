import 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension AppLocalizationsExtensions on AppLocalizations {
  String localize(String key) {
    switch (key) {
      case 'politics':
        return politics;
      case 'sports':
        return sports;
      case 'science':
        return science;
      case 'technology':
        return technology;
      case 'business':
        return business;
      case 'health':
        return health;
      default:
        return key; // fallback
    }
  }
}