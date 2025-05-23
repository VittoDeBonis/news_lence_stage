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
  
  // Lista completa degli interessi in inglese (valori standard)
  final List<String> standardInterests = ['politics', 'sports', 'science', 'technology', 'business', 'health'];
  
  // Mappa per la localizzazione degli interessi
  final Map<String, Map<String, String>> localizedInterests = {
    'EN': {
      'politics': 'Politics',
      'sports': 'Sports',
      'science': 'Science',
      'technology': 'Technology',
      'business': 'Business',
      'health': 'Health',
    },
    'IT': {
      'politics': 'Politica',
      'sports': 'Sport',
      'science': 'Scienza',
      'technology': 'Tecnologia',
      'business': 'Affari',
      'health': 'Salute',
    },
    'DE': {
      'politics': 'Politik',
      'sports': 'Sport',
      'science': 'Wissenschaft',
      'technology': 'Technologie',
      'business': 'Geschäft',
      'health': 'Gesundheit',
    },
    'FR': {
      'politics': 'Politique',
      'sports': 'Sports',
      'science': 'Science',
      'technology': 'Technologie',
      'business': 'Affaires',
      'health': 'Santé',
    },
  };
  
  // Interessi selezionati (usiamo gli ID standard)
  Map<String, bool> selectedInterests = {};
  
  bool dataLoaded = false;
  bool isUploadingImage = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  PreSettingsProvider() {
    getUserInfo();
  }

  // Ottieni la lista degli interessi localizzati per la lingua corrente
  List<String> getInterestsList() {
    return standardInterests.map((interest) => 
      localizedInterests[selectedLanguage]?[interest] ?? interest
    ).toList();
  }

  // Ottieni l'ID standard da un interesse localizzato
  String? getStandardInterestId(String localizedInterest) {
    for (var entry in localizedInterests[selectedLanguage]!.entries) {
      if (entry.value == localizedInterest) {
        return entry.key;
      }
    }
    return null;
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

  Future<String?> getLocalImagePath() async {
    if (userId == null) return null;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_image_path_$userId');
  }

  Future<void> saveLocalImagePath(String path) async {
    if (userId == null) return;
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path_$userId', path);
    localImagePath = path;
  }

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
          for (var interest in standardInterests) {
            selectedInterests[interest] = false;
          }
          
          // Imposta a true solo quelli presenti nel documento
          for (var interest in interests) {
            if (standardInterests.contains(interest)) {
              selectedInterests[interest] = true;
            }
          }
        } else {
          // Default: tutti falsi
          for (var interest in standardInterests) {
            selectedInterests[interest] = false;
          }
        }
        
        // Se non c'è un'immagine locale ma c'è un URL su Firestore,
        // scarica l'immagine e salvala localmente
        if (image == null && userData['profileImageUrl'] != null) {
          await _downloadAndSaveImage(userData['profileImageUrl']);
        }
      } else {
        // Se l'utente non esiste, inizializza i valori di default
        for (var interest in standardInterests) {
          selectedInterests[interest] = true; // Default: tutti selezionati
        }
        
        // Se è la prima volta, imposta il nickname dall'email
        if (nickname.isEmpty) {
          nickname = getUserNameFromEmail();
          // Crea il documento utente con il nickname di default
          await _firestore.collection('users').doc(userId).set({
            'nickname': nickname,
            'language': 'EN',
            'interests': standardInterests, // Default: tutti selezionati
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

  Future<void> _downloadAndSaveImage(String imageUrl) async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String localPath = path.join(appDocDir.path, 'profile_images', 'profile_$userId.jpg');
      
      Directory(path.dirname(localPath)).createSync(recursive: true);
      
      Reference storageRef = _storage.refFromURL(imageUrl);
      await storageRef.writeToFile(File(localPath));
      
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

  void setLanguage(String language) {
    if (languageList.contains(language) && selectedLanguage != language) {
      selectedLanguage = language;
      notifyListeners();
    }
  }

  void toggleInterest(String standardInterestId, bool value) {
    if (selectedInterests.containsKey(standardInterestId) && selectedInterests[standardInterestId] != value) {
      selectedInterests[standardInterestId] = value;
      notifyListeners();
    }
  }

  Future<void> savePreferences() async {
    if (userId == null) return;
    try {
      // Prepara la lista degli interessi selezionati (solo gli ID standard)
      List<String> userInterests = selectedInterests.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Salva i dati su Firestore
      await _firestore.collection('users').doc(userId).set({
        'language': selectedLanguage,
        'interests': userInterests,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      print('Errore nel salvataggio delle preferenze: $e');
    }
  }

  Future<void> getImage(BuildContext context) async {
    final picker = ImagePicker();
    
    try {
      final XFile? pickedFile = await showDialog<XFile?>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Seleziona immagine'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Scatta una foto'),
                  onTap: () async {
                    Navigator.pop(context, await picker.pickImage(source: ImageSource.camera));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Scegli dalla galleria'),
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
        isUploadingImage = true;
        notifyListeners();
        
        image = File(pickedFile.path);
        notifyListeners();
        
        try {
          Directory appDocDir = await getApplicationDocumentsDirectory();
          String localPath = path.join(appDocDir.path, 'profile_images', 'profile_$userId.jpg');
          Directory(path.dirname(localPath)).createSync(recursive: true);
          
          File imageFile = File(pickedFile.path);
          File localImageFile = await imageFile.copy(localPath);
          
          await saveLocalImagePath(localPath);
          
          String fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
          Reference storageRef = _storage.ref().child('profile_images/$fileName');
          
          await storageRef.putFile(localImageFile);
          String imageUrl = await storageRef.getDownloadURL();
          
          await _firestore.collection('users').doc(userId).update({
            'profileImageUrl': imageUrl
          });
          
          image = localImageFile;
        } catch (e) {
          if (kDebugMode) {
            print('Errore nel caricamento dell\'immagine: $e');
          }
        } finally {
          isUploadingImage = false;
          notifyListeners();
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
      if (localImagePath != null && File(localImagePath!).existsSync()) {
        await File(localImagePath!).delete();
      }
      await removeLocalImagePath();
      
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        if (userData['profileImageUrl'] != null) {
          String imageUrl = userData['profileImageUrl'];
          Reference storageRef = _storage.refFromURL(imageUrl);
          await storageRef.delete();
          
          await _firestore.collection('users').doc(userId).update({
            'profileImageUrl': FieldValue.delete()
          });
        }
      }
      
      image = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Errore nella rimozione dell\'immagine: $e');
      }
    }
  }

  File? getCurrentImage() {
    return image;
  }

  bool hasProfileImage() {
    return image != null && image!.existsSync();
  }

  void updateInterests(List<String> list, bool bool) {}
}