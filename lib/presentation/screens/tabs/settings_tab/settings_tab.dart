import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:news_lens/presentation/screens/onboarding/pre_settings/pre_settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:news_lens/providers/theme_provider.dart';
import 'package:news_lens/providers/locale_provider.dart';
import 'package:news_lens/l10n.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late PreSettingsProvider _preSettingsProvider;
  final FirebaseAuth  _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _preSettingsProvider = Provider.of<PreSettingsProvider>(context, listen: false);
    _preSettingsProvider.getUserInfo(); // Carica le informazioni dell'utente
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.settings),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<PreSettingsProvider>(
          builder: (context, preSettings, _) {             
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                GestureDetector(
                  onTap: () => preSettings.getImage(),
                  onLongPress: () => preSettings.removeImage(),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    child: preSettings.image != null
                        ? ClipOval(
                            child: Image.file(
                              preSettings.image!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.camera_alt,
                            size: 50,
                            color: Theme.of(context).iconTheme.color,
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nickname
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      preSettings.nickname.isNotEmpty
                          ? preSettings.nickname
                          : 'Default Nickname',
                      style: const TextStyle(fontSize: 16),
                    ),
                    IconButton(
                      onPressed: _editNickname,
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 16),

                // Dark Mode Toggle
                ListTile(
                  leading: Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(l10n.darkMode),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme(value);
                    },
                  ),
                ),

                // Language Selection
                ListTile(
                  leading: Icon(
                    Icons.language,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(l10n.language),
                  trailing: DropdownButton<String>(
                    value: preSettings.selectedLanguage,
                    icon: const Icon(Icons.arrow_drop_down),
                    underline: Container(),
                    onChanged: (String? value) {
                      if (value != null) {
                        preSettings.setLanguage(value);
                        localeProvider.setLocale(value);
                      }
                    },
                    items: preSettings.languageList.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Interests Section
                Text(
                  l10n.interest,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),

                // Interests Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 4,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                  ),
                  itemCount: preSettings.interestsList.length,
                  itemBuilder: (context, index) {
                    final interest = preSettings.interestsList[index];
                    return Card(
                      elevation: 0,
                      color: preSettings.selectedInterests[interest] == true
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: InkWell(
                        onTap: () {
                          preSettings.toggleInterest(interest, !(preSettings.selectedInterests[interest] ?? false));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              Checkbox(
                                value: preSettings.selectedInterests[interest] ?? false,
                                onChanged: (bool? value) {
                                  preSettings.toggleInterest(interest, value!);
                                },
                              ),
                              Expanded(
                                child: Text(
                                  interest,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: preSettings.selectedInterests[interest] == true
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
                const SizedBox(height: 30),
                
                // Save Button
                ElevatedButton(
                  onPressed: () async {
                    await preSettings.savePreferences();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('settingsSaved'), // Replace with an existing key
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    minimumSize: const Size(200, 48),
                  ),
                  child: Text(l10n.saveSettings),
                ),
                const SizedBox(height: 10),

                // Logout Button
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushNamedAndRemoveUntil(context, "/", (Route<dynamic> route) => false);
                    } catch (e) {
                      if (kDebugMode) {
                        print('Error signing out: $e');
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error signing out. Please try again.')),
                      );
                    }
                  },
                  child: Text(l10n.logout),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: (){
                    _showConfirmDeleteAccountDialog(context);
                  },
                  child: const Text(
                    'Delete account',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )             
              ],
            );
          },
        ),
      ),
    );
    
  }

  void _editNickname() async {
    final preSettings = Provider.of<PreSettingsProvider>(context, listen: false);
    TextEditingController controller = TextEditingController(text: preSettings.nickname);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.editNickname),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.enterNickname,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await preSettings.updateNickname(controller.text);
                  Navigator.of(context).pop();
                }
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
  }
  
  void _showConfirmDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context, 
      builder: (BuildContext context){
        return AlertDialog(
          title: const Text('Confirmation of deletion'),
          content: const Text('Are you sure you want to delete your account? This action is irreversible.'),
          actions: [
            TextButton(
              onPressed: (){
                Navigator.of(context).pop();
              },
              child: const Text('No')
              ), 
              
              TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteAccount(context);
              }, 
              child: const Text('Yes')
              ),
          ],
        );
      }
      );
  }
  
  Future<void> _deleteAccount(BuildContext context) async {
  try {
    User? user = _auth.currentUser;
    if (user != null) {
      
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.resetTheme();
      
      print("Account deleted with success");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted with success')),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        "/",
        (Route<dynamic> route) => false,
      );
      await user.delete();
    }
  } catch (e) {
    print("Error during the elimination of account: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error during the elimination of account. Retry.')),
    );
  }
}
}