import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:news_lens/l10n.dart';
import 'package:news_lens/presentation/screens/home_page.dart';
import 'package:news_lens/presentation/screens/onboarding/pre_settings/pre_settings_provider.dart';
import 'package:news_lens/providers/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class PreSettings extends StatefulWidget {
  const PreSettings({super.key});

  @override
  State<PreSettings> createState() => _PreSettingsState();
}

class _PreSettingsState extends State<PreSettings> {
  late PreSettingsProvider _provider;
  Widget? _cachedProfileImageWidget;
  String? _lastImagePath;
  String? _lastProfileUrl;

  @override
  void initState() {
    super.initState();
    _provider = PreSettingsProvider();
    _provider.addListener(_syncLanguage);
  }

  @override
  void dispose() {
    _provider.removeListener(_syncLanguage);
    super.dispose();
  }

  void _syncLanguage() {
    if (_provider.dataLoaded) {
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      localeProvider.setLocale(_provider.selectedLanguage);
    }
  }

  void _editNickname() {
    final l10n = AppLocalizations.of(context)!;
    TextEditingController controller =
        TextEditingController(text: _provider.nickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editNickname),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await _provider.updateNickname(controller.text);
              Navigator.of(context).pop();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<PreSettingsProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(l10n.preSettingsTitle),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Immagine Profilo
                  GestureDetector(
                    onTap: () => provider.getImage(context),
                    onLongPress: () => provider.removeImage(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          child: _buildProfileImage(provider, context),
                        ),
                        if (provider.isUploadingImage)
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.7),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.touchToChangeImage,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  // Nome Utente
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.nickname.isNotEmpty
                              ? provider.nickname
                              : provider.getUserNameFromEmail().isNotEmpty
                                  ? provider.getUserNameFromEmail()
                                  : '',
                          style: const TextStyle(fontSize: 16),
                        ),
                        IconButton(
                          onPressed: _editNickname,
                          icon: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                  const SizedBox(height: 16),
                  // Selezione Lingua
                  ListTile(
                    leading: Icon(
                      Icons.language,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(l10n.language),
                    trailing: DropdownButton<String>(
                      value: provider.selectedLanguage,
                      icon: const Icon(Icons.arrow_drop_down),
                      underline: Container(),
                      onChanged: (value) {
                        if (value != null) {
                          provider.setLanguage(value);
                          localeProvider.setLocale(value);
                        }
                      },
                      items: provider.languageList
                          .map((lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(lang),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Interessi
                  Text(
                    l10n.interests,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 4,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                    ),
                    itemCount: provider.getInterestsList().length,
                    itemBuilder: (context, index) {
                      final localizedInterest = provider.getInterestsList()[index];
                      final standardInterest = provider.standardInterests[index];
                      final isSelected = provider.selectedInterests[standardInterest] ?? false;
                      
                      return Card(
                        elevation: 0,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        child: InkWell(
                          onTap: () =>
                              provider.toggleInterest(standardInterest, !isSelected),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    if (value != null) {
                                      provider.toggleInterest(standardInterest, value);
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    localizedInterest,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                  ElevatedButton(
                    onPressed: () async {
                      await provider.savePreferences();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      minimumSize: const Size(200, 48),
                    ),
                    child: Text(l10n.saveSettings),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImage(PreSettingsProvider provider, BuildContext context) {
    bool shouldRebuild = false;
    if (provider.image != null) {
      String currentPath = provider.image!.path;
      if (_lastImagePath != currentPath) {
        _lastImagePath = currentPath;
        shouldRebuild = true;
      }
    }
    if (provider.userId != null && !shouldRebuild) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(provider.userId)
          .get()
          .then((snapshot) {
        if (snapshot.exists) {
          Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
          String? profileUrl = userData['profileImageUrl'];
          if (profileUrl != _lastProfileUrl) {
            _lastProfileUrl = profileUrl;
            _cachedProfileImageWidget = null;
          }
        }
      });
    }
    if (_cachedProfileImageWidget != null && !shouldRebuild && !provider.isUploadingImage) {
      return _cachedProfileImageWidget!;
    }
    Widget profileWidget;
    if (provider.image != null) {
      profileWidget = ClipOval(
        child: Image.file(
          provider.image!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } else if (_lastProfileUrl != null && _lastProfileUrl!.isNotEmpty) {
      profileWidget = ClipOval(
        child: CachedNetworkImage(
          imageUrl: _lastProfileUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: (_, __) => Icon(
            Icons.camera_alt,
            size: 50,
            color: Theme.of(context).iconTheme.color,
          ),
          errorWidget: (_, __, ___) => Icon(
            Icons.error,
            size: 50,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    } else if (provider.userId != null && provider.dataLoaded) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(provider.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData &&
                snapshot.data!.exists &&
                (snapshot.data!.data() as Map<String, dynamic>)['profileImageUrl'] !=
                    null) {
              _lastProfileUrl = (snapshot.data!.data()
                  as Map<String, dynamic>)['profileImageUrl'];
              _cachedProfileImageWidget = ClipOval(
                child: CachedNetworkImage(
                  imageUrl: _lastProfileUrl!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Icon(
                    Icons.camera_alt,
                    size: 50,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.error,
                    size: 50,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
              return _cachedProfileImageWidget!;
            } else {
              _cachedProfileImageWidget = Icon(
                Icons.camera_alt,
                size: 50,
                color: Theme.of(context).iconTheme.color,
              );
              return _cachedProfileImageWidget!;
            }
          }
          if (_cachedProfileImageWidget != null) {
            return _cachedProfileImageWidget!;
          }
          _cachedProfileImageWidget = Icon(
            Icons.camera_alt,
            size: 50,
            color: Theme.of(context).iconTheme.color,
          );
          return _cachedProfileImageWidget!;
        },
      );
    } else {
      profileWidget = Icon(
        Icons.camera_alt,
        size: 50,
        color: Theme.of(context).iconTheme.color,
      );
    }
    _cachedProfileImageWidget = profileWidget;
    return profileWidget;
  }
}