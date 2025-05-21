import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class PreSettingsProvider extends ChangeNotifier {
  File? image;
  String? userId;
  String userEmail = '';
  String nickname = '';
  String? localImagePath; 
  List<String> languageList = ['EN', 'IT', 'DE', 'FR'];
  String selectedLanguage = 'EN';
  List<String> interestsList = ['Politics', 'Sports', 'Science', 'Technology'];
  
  // Mappa gli interessi localizzati ai valori standard
  final Map<String, String> _interestToStandardMap = {
    // Inglese (standard)
    'Politics': 'politics',
    'Sports': 'sports',
    'Science': 'science',
    'Technology': 'technology',
    
    'Politica': 'politics',
    'Sport': 'sports',
    'Scienza': 'science',
    'Tecnologia': 'technology',
    
    'Politik': 'politics',
    'Sport': 'sports',
    'Wissenschaft': 'science',
    'Technologie': 'technology',
    
    'Politique': 'politics',
    'Sports': 'sports',
    'Science': 'science',
    'Technologie': 'technology',
  };
  
  Map<String, bool> selectedInterests = {};
  bool dataLoaded = false;
  bool isUploadingImage = false; 
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; 

  PreSettingsProvider() {
    getUserInfo();
  }

  void getUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userEmail = user.email ?? '';
      userId = user.uid;
      loadUserData();
    }
  }

  String getUserNameFromEmail() {
    if (userEmail.isNotEmpty && userEmail.contains('@')) {
      return userEmail.split('@')[0];
    }
    return '';
  }

  // Metodo per ottenere il path locale dell'immagine salvato in SharedPreferences
  Future<String?> getLocalImagePath() async {
    if (userId == null) return null;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_image_path_$userId');
  }

  // Metodo per salvare il path locale dell'immagine in SharedPreferences
  Future<void> saveLocalImagePath(String path) async {
    if (userId == null) return;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path_$userId', path);
    localImagePath = path;
  }

  // Metodo per rimuovere il path locale dell'immagine da SharedPreferences
  Future<void> removeLocalImagePath() async {
    if (userId == null) return;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path_$userId');
    localImagePath = null;
  }

  Future<void> loadUserData() async {
    if (userId == null) return;

    try {
      // Carica il path locale dell'immagine
      localImagePath = await getLocalImagePath();
      if (localImagePath != null && File(localImagePath!).existsSync()) {
        image = File(localImagePath!);
      }

      // Ottieni il documento dell'utente da Firestore
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        // Carica nickname
        nickname = userData['nickname'] ?? '';
        
        // Carica lingua selezionata
        if (userData['language'] != null && languageList.contains(userData['language'])) {
          selectedLanguage = userData['language'];
        }
        
        // Carica interessi
        if (userData['interests'] != null) {
          List<dynamic> interests = userData['interests'];
          
          // Inizializza tutti gli interessi a false
          for (var interest in interestsList) {
            selectedInterests[interest] = false;
          }
          
          // Imposta quelli salvati a true (converte da id standard a nomi localizzati)
          for (var interest in interests) {
            // Trova l'interesse localizzato corrispondente all'id standard
            String? localizedInterest = _findLocalizedInterest(interest.toString());
            if (localizedInterest != null && selectedInterests.containsKey(localizedInterest)) {
              selectedInterests[localizedInterest] = true;
            }
          }
        } else {
          // Inizializza tutti a false
          for (var interest in interestsList) {
            selectedInterests[interest] = true;
          }
        }
        
        // Se non c'è un'immagine locale ma c'è un URL su Firestore,
        // scarica l'immagine e salvala localmente
        if (image == null && userData['profileImageUrl'] != null) {
          await _downloadAndSaveImage(userData['profileImageUrl']);
        }
      } else {
        // Se l'utente non esiste, inizializza i valori di default
        for (var interest in interestsList) {
          selectedInterests[interest] = true;
        }
        
        // Se è la prima volta, imposta il nickname dall'email
        if (nickname.isEmpty) {
          nickname = getUserNameFromEmail();
          // Crea il documento utente con il nickname di default
          await _firestore.collection('users').doc(userId).set({
            'nickname': nickname,
            'language': 'EN',
            'interests': [],
            'email': userEmail,
            'createdAt': FieldValue.serverTimestamp()
          });
        }
      }
      
      dataLoaded = true;
      notifyListeners();
      
    } catch (e) {
      if (kDebugMode) {
        print('Errore nel caricamento dei dati: $e');
      }
    }
  }

  // Metodo per trovare l'interesse localizzato corrispondente all'id standard
  String? _findLocalizedInterest(String standardId) {
    for (var entry in interestsList) {
      if (_interestToStandardMap[entry]?.toLowerCase() == standardId.toLowerCase()) {
        return entry;
      }
    }
    return null;
  }

  // Metodo per scaricare l'immagine da Firebase Storage e salvarla localmente
  Future<void> _downloadAndSaveImage(String imageUrl) async {
    try {
      // Ottieni la directory dei documenti dell'app
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String localPath = path.join(appDocDir.path, 'profile_images', 'profile_$userId.jpg');
      
      // Crea la directory se non esiste
      Directory(path.dirname(localPath)).createSync(recursive: true);
      
      // Scarica l'immagine (questo è un esempio semplificato, 
      // potresti voler usare una libreria come http per il download)
      Reference storageRef = _storage.refFromURL(imageUrl);
      await storageRef.writeToFile(File(localPath));
      
      // Salva il path locale
      await saveLocalImagePath(localPath);
      image = File(localPath);
      
    } catch (e) {
      if (kDebugMode) {
        print('Errore nel download dell\'immagine: $e');
      }
    }
  }

  Future<void> updateNickname(String newNickname) async {
    if (newNickname.isNotEmpty && userId != null) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'nickname': newNickname
        });
        nickname = newNickname;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Errore nell\'aggiornamento del nickname: $e');
        }
      }
    }
  }

  // Modificata per consentire l'aggiornamento senza notificare
  void updateInterests(List<String> newInterests, [bool notify = true]) {
    // Verifica se la lista è effettivamente cambiata per evitare rebuild non necessari
    bool hasChanged = false;
    
    if (interestsList.length != newInterests.length) {
      hasChanged = true;
    } else {
      for (int i = 0; i < interestsList.length; i++) {
        if (interestsList[i] != newInterests[i]) {
          hasChanged = true;
          break;
        }
      }
    }
    
    if (!hasChanged) return; // Se non ci sono cambiamenti, esci
    
    interestsList = newInterests;
    
    // Aggiorna la mappa degli interessi mantenendo lo stato precedente
    Map<String, bool> updatedInterests = {};
    for (var interest in interestsList) {
      updatedInterests[interest] = selectedInterests[interest] ?? true;
    }
    selectedInterests = updatedInterests;
    
    if (notify) {
      notifyListeners();
    }
  }

  void setLanguage(String language) {
    if (languageList.contains(language) && selectedLanguage != language) {
      selectedLanguage = language;
      notifyListeners();
    }
  }

  void toggleInterest(String interest, bool value) {
    if (selectedInterests.containsKey(interest) && selectedInterests[interest] != value) {
      selectedInterests[interest] = value;
      notifyListeners();
    }
  }

  Future<void> savePreferences() async {
    if (userId == null) return;
    
    try {
      // Converti gli interessi localizzati in ID standard
      List<String> userInterests = [];
      selectedInterests.forEach((interest, isSelected) {
        if (isSelected) {
          String standardId = _interestToStandardMap[interest] ?? interest.toLowerCase();
          userInterests.add(standardId);
        }
      });
      
      // Prepara i dati da salvare
      Map<String, dynamic> userData = {
        'nickname': nickname.isEmpty ? getUserNameFromEmail() : nickname,
        'language': selectedLanguage,
        'interests': userInterests,
        'updatedAt': FieldValue.serverTimestamp()
      };
      
      // Salva i dati su Firestore
      await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));
      
      if (nickname.isEmpty) {
        nickname = getUserNameFromEmail();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore nel salvataggio delle preferenze: $e');
      }
    }
  }

  Future<void> getImage(BuildContext context) async {
    final picker = ImagePicker();
    
    try {
      final XFile? pickedFile = await showDialog<XFile?>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Seleziona immagine'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Scatta una foto'),
                  onTap: () async {
                    Navigator.pop(context, await picker.pickImage(source: ImageSource.camera));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Scegli dalla galleria'),
                  onTap: () async {
                    Navigator.pop(context, await picker.pickImage(source: ImageSource.gallery));
                  },
                ),
              ],
            ),
          );
        },
      );

      if (pickedFile != null && userId != null) {
        // Imposta lo stato di caricamento
        isUploadingImage = true;
        notifyListeners();
        
        // Aggiorna immediatamente l'immagine locale senza aspettare il caricamento
        // Questo consentirà di vedere subito l'immagine nell'interfaccia
        image = File(pickedFile.path);
        notifyListeners();
        
        try {
          // Ottieni la directory dei documenti dell'app
          Directory appDocDir = await getApplicationDocumentsDirectory();
          String localPath = path.join(appDocDir.path, 'profile_images', 'profile_$userId.jpg');
          
          // Crea la directory se non esiste
          Directory(path.dirname(localPath)).createSync(recursive: true);
          
          // Copia l'immagine selezionata nella directory locale
          
          // Copia l'immagine selezionata nella directory locale
          File imageFile = File(pickedFile.path);
          File localImageFile = await imageFile.copy(localPath);
          
          // Salva il path locale
          await saveLocalImagePath(localPath);
          
          // Carica l'immagine su Firebase Storage in background
          String fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
          Reference storageRef = _storage.ref().child('profile_images/$fileName');
          
          // Inizia il caricamento
          await storageRef.putFile(localImageFile);
          
          // Ottiene l'URL dell'immagine
          String imageUrl = await storageRef.getDownloadURL();
          
          // Aggiorna Firestore con l'URL dell'immagine
          await _firestore.collection('users').doc(userId).update({
            'profileImageUrl': imageUrl
          });
          
          // Aggiorna l'immagine locale con il file salvato localmente
          image = localImageFile;
        } catch (e) {
          if (kDebugMode) {
            print('Errore nel caricamento dell\'immagine: $e');
          }
        } finally {
          isUploadingImage = false;
          notifyListeners();
        }
      } else {
        if (kDebugMode) {
          print('Nessuna immagine selezionata.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Errore nella selezione dell\'immagine: $e');
      }
      isUploadingImage = false;
      notifyListeners();
    }
  }

  Future<void> removeImage() async {
    if (userId == null) return;
    
    try {
      // Rimuove l'immagine locale
      if (localImagePath != null && File(localImagePath!).existsSync()) {
        await File(localImagePath!).delete();
      }
      await removeLocalImagePath();
      
      // Ottiene il documento utente per verificare se ha un'immagine
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        if (userData['profileImageUrl'] != null) {
          // Estrae il percorso dell'immagine dall'URL
          String imageUrl = userData['profileImageUrl'];
          
          // Crea un riferimento all'immagine in Firebase Storage
          Reference storageRef = _storage.refFromURL(imageUrl);
          
          // Elimina l'immagine da Firebase Storage
          await storageRef.delete();
          
          // Aggiorna Firestore rimuovendo l'URL dell'immagine
          await _firestore.collection('users').doc(userId).update({
            'profileImageUrl': FieldValue.delete()
          });
        }
      }
      
      // Rimuove l'immagine locale
      image = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Errore nella rimozione dell\'immagine: $e');
      }
    }
  }

  // Metodo getter per ottenere l'immagine corrente
  File? getCurrentImage() {
    return image;
  }

  // Metodo per verificare se esiste un'immagine del profilo
  bool hasProfileImage() {
    return image != null && image!.existsSync();
  }
}