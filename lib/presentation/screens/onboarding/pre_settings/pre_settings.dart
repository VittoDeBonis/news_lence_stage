import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:news_lens/l10n.dart';
import 'package:news_lens/presentation/screens/onboarding/pre_settings/pre_settings_provider.dart';
import 'package:news_lens/providers/locale_provider.dart';
import 'package:news_lens/presentation/screens/home_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';


class PreSettings extends StatefulWidget {
  const PreSettings({super.key});

  @override
  State<PreSettings> createState() => _PreSettingsState();
}

class _PreSettingsState extends State<PreSettings> {
  late PreSettingsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = PreSettingsProvider();
  }

  void _editNickname() {
    TextEditingController controller = TextEditingController(text: _provider.nickname);
    
    showDialog(   
      context: context,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.editNickname),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    // Imposta gli interessi nella lingua corretta
    _provider.updateInterests([
      l10n.politics,
      l10n.sports,
      l10n.science,
      l10n.technology
    ]);
    
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Immagine del profilo
                  GestureDetector(
                    onTap: () => provider.getImage(),
                    onLongPress: () => provider.removeImage(),
                    child: Container(
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
                  ),
                  Text(
                    '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  // Nome utente
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
                              : (provider.getUserNameFromEmail().isNotEmpty
                                  ? provider.getUserNameFromEmail()
                                  : ''),
                          style: const TextStyle(fontSize: 16),
                        ),
                        IconButton(
                          onPressed: _editNickname,
                          icon: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                  ),                 
                  Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
                  const SizedBox(height: 16),               
                  // Selezione lingua
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
                      onChanged: (String? value) {
                        if (value != null) {
                          provider.setLanguage(value);
                          localeProvider.setLocale(value);
                        }
                      },
                      items: provider.languageList.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),             
                  // Sezione Interessi
                  Text(
                    l10n.interest, 
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),                 
                  // Griglia Interessi
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 4,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                    ),
                    itemCount: provider.interestsList.length,
                    itemBuilder: (context, index) {
                      final interest = provider.interestsList[index];
                      return Card(
                        elevation: 0,
                        color: provider.selectedInterests[interest] == true 
                            ? Theme.of(context).colorScheme.primaryContainer 
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: InkWell(
                          onTap: () {
                            provider.toggleInterest(interest, !(provider.selectedInterests[interest] ?? false));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: provider.selectedInterests[interest] ?? false,
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      provider.toggleInterest(interest, value);
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    interest, 
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: provider.selectedInterests[interest] == true 
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
                        MaterialPageRoute(builder: (context) => const HomePage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    // PRIMO: Se c'è un'immagine locale (appena selezionata), usala
    if (provider.image != null && provider.image!.existsSync()) {
      return ClipOval(
        child: Image.file(
          provider.image!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } 
    
    // SECONDO: Se non c'è immagine locale, prova a caricare da Firestore
    // Solo se i dati sono stati caricati completamente
    if (!provider.dataLoaded) {
      return const CircularProgressIndicator();
    }
    
    // Se non c'è un'immagine locale ma c'è un userId, controlla Firestore
    if (provider.userId != null) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(provider.userId)
            .get(),
        builder: (context, snapshot) {
          // Se il documento è stato caricato
          if (snapshot.connectionState == ConnectionState.done) {
            // Controlla se esiste un URL dell'immagine
            if (snapshot.hasData && 
                snapshot.data!.exists && 
                (snapshot.data!.data() as Map<String, dynamic>)['profileImageUrl'] != null) {
              
              String profileImageUrl = (snapshot.data!.data() as Map<String, dynamic>)['profileImageUrl'];
              
              return ClipOval(
                child: CachedNetworkImage(
                  imageUrl: profileImageUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => Icon(
                    Icons.error,
                    size: 50,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }
          }
          
          // Se sta ancora caricando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          
          // Se non c'è nessuna immagine, mostra l'icona della fotocamera
          return Icon(
            Icons.camera_alt,
            size: 50,
            color: Theme.of(context).iconTheme.color,
          );
        },
      );
    }
    
    // Default: nessuna immagine
    return Icon(
      Icons.camera_alt,
      size: 50,
      color: Theme.of(context).iconTheme.color,
    );
  }
}