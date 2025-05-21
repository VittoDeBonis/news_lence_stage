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
  // Memorizza il widget dell'immagine del profilo per evitare ricostruzioni
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
      // Sincronizza la lingua con il LocaleProvider quando i dati sono caricati
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      localeProvider.setLocale(_provider.selectedLanguage);
    }
  }

  String getTranslatedInterest(AppLocalizations l10n, String interestKey) {
    switch (interestKey) {
      case 'sports':
        return l10n.sports;
      case 'technology':
        return l10n.technology;
      case 'politics':
        return l10n.politics;
      case 'entertainment':
        return l10n.science; 
      default:
        return interestKey;
    }
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
    ], false); // Non notificare qui per evitare rebuild non necessari
    
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
                        // Indicatore di caricamento - mostra solo durante upload effettivo
                        if (provider.isUploadingImage)
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Usa una stringa diretta finché non viene aggiunta nei file di localizzazione
                  Text(
                    'Tocca per cambiare immagine', // Sostituisci con l10n.tapToChangeImage quando disponibile
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
                      final translatedInterest = getTranslatedInterest(l10n, interest);
                      bool isSelected = provider.selectedInterests[interest] ?? false;

                      return Card(
                        elevation: 0,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: InkWell(
                          onTap: () {
                            provider.toggleInterest(interest, !isSelected);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      provider.toggleInterest(interest, value);
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    translatedInterest,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    // Verifica se qualcosa è cambiato per evitare rebuilds inutili
    bool shouldRebuild = false;
    
    if (provider.image != null) {
      // Controlla se è cambiata l'immagine locale rispetto all'ultima volta
      String currentPath = provider.image!.path;
      if (_lastImagePath != currentPath) {
        _lastImagePath = currentPath;
        shouldRebuild = true;
      }
    }
    
    // Controlla se l'URL del profilo è cambiato (nel caso di upload/download)
    if (provider.userId != null && shouldRebuild == false) {
      // Controlla il profilo URL solo se necessario
      DocumentSnapshot? userDoc;
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
            _cachedProfileImageWidget = null; // Forza rebuild solo quando cambia l'URL
          }
        }
      });
    }

    // Se il widget è già in cache e non deve essere aggiornato, restituiscilo
    if (_cachedProfileImageWidget != null && !shouldRebuild && !provider.isUploadingImage) {
      return _cachedProfileImageWidget!;
    }
    
    // Altrimenti, crea un nuovo widget
    Widget profileWidget;
    
    // PRIMA: Se c'è un'immagine locale (appena selezionata o caricata), usala
    if (provider.image != null) {
      profileWidget = ClipOval(
        child: Image.file(
          provider.image!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } 
    // SECONDA: Se non c'è immagine locale ma abbiamo già verificato l'URL del profilo
    else if (_lastProfileUrl != null && _lastProfileUrl!.isNotEmpty) {
      profileWidget = ClipOval(
        child: CachedNetworkImage(
          imageUrl: _lastProfileUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: (context, url) => Icon(
            Icons.camera_alt,
            size: 50,
            color: Theme.of(context).iconTheme.color,
          ),
          errorWidget: (context, url, error) => Icon(
            Icons.error,
            size: 50,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    }
    // TERZA: Se non c'è un'immagine locale ma c'è un userId, controlla Firestore ma in background
    else if (provider.userId != null && provider.dataLoaded) {
      // Solo se non stiamo già caricando un'immagine, usa FutureBuilder
      // Questo viene eseguito solo la prima volta, poi usiamo il cache
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
              
              _lastProfileUrl = (snapshot.data!.data() as Map<String, dynamic>)['profileImageUrl'];
              
              _cachedProfileImageWidget = ClipOval(
                child: CachedNetworkImage(
                  imageUrl: _lastProfileUrl!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Icon(
                    Icons.camera_alt,
                    size: 50,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  errorWidget: (context, url, error) => Icon(
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
          
          // Se è già in cache, usa quello invece di mostrare loading
          if (_cachedProfileImageWidget != null) {
            return _cachedProfileImageWidget!;
          }
          
          // Se sta ancora caricando, mostra l'icona della fotocamera
          _cachedProfileImageWidget = Icon(
            Icons.camera_alt,
            size: 50,
            color: Theme.of(context).iconTheme.color,
          );
          return _cachedProfileImageWidget!;
        },
      );
    }
    // Default: nessuna immagine
    else {
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