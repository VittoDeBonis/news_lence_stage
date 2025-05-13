import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class PreSettingsProvider extends ChangeNotifier {
  File? image;
  String? userId;
  String userEmail = '';
  String nickname = '';
  List<String> languageList = ['EN', 'IT', 'DE', 'FR'];
  String selectedLanguage = 'EN';
  List<String> interestsList = ['Politics', 'Sports', 'Science', 'Technology'];
  Map<String, bool> selectedInterests = {};
  bool dataLoaded = false;
  
  // Riferimenti a Firestore
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

  Future<void> loadUserData() async {
    if (userId == null) return;

    try {
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
          
          // Imposta quelli salvati a true
          for (var interest in interests) {
            if (selectedInterests.containsKey(interest)) {
              selectedInterests[interest] = true;
            }
          }
        } else {
          // Inizializza tutti a false
          for (var interest in interestsList) {
            selectedInterests[interest] = true;
          }
        }
        
        // Carica immagine profilo
        if (userData['profileImageUrl'] != null) {
          String imageUrl = userData['profileImageUrl'];
          // Per caricare l'immagine effettivamente bisognerebbe utilizzare
          // un approccio diverso, ad esempio salvarla temporaneamente o usare CachedNetworkImage
          // Qui andresti a recuperare l'immagine da Firebase Storage, ma per ora
          // lasciamo questo commento per indicare che andrebbe implementato
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

  void updateInterests(List<String> newInterests) {
    interestsList = newInterests;
    
    // Assicurati che selectedInterests contenga tutti gli interessi
    for (var interest in interestsList) {
      selectedInterests[interest] = true;
    }
    notifyListeners();
  }

  void setLanguage(String language) {
    if (languageList.contains(language)) {
      selectedLanguage = language;
      notifyListeners();
    }
  }

  void toggleInterest(String interest, bool value) {
    if (selectedInterests.containsKey(interest)) {
      selectedInterests[interest] = value;
      notifyListeners();
    }
  }

  Future<void> savePreferences() async {
  if (userId == null) return;
  
  try {
    // Prepara la lista degli interessi selezionati
    List<String> userInterests = [];
    selectedInterests.forEach((interest, isSelected) {
      if (isSelected) {
        userInterests.add(interest);
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

  Future<void> getImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null && userId != null) {
      try {
        // Carica l'immagine su Firebase Storage
        File imageFile = File(pickedFile.path);
        String fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
        Reference storageRef = _storage.ref().child('profile_images/$fileName');
        
        // Inizia il caricamento
        await storageRef.putFile(imageFile);
        
        // Ottieni l'URL dell'immagine
        String imageUrl = await storageRef.getDownloadURL();
        
        // Aggiorna Firestore con l'URL dell'immagine
        await _firestore.collection('users').doc(userId).update({
          'profileImageUrl': imageUrl
        });
        
        // Aggiorna l'immagine locale
        image = imageFile;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Errore nel caricamento dell\'immagine: $e');
        }
      }
    } else {
      if (kDebugMode) {
        print('Nessuna immagine selezionata.');
      }
    }
  }

  Future<void> removeImage() async {
    if (userId == null) return;
    
    try {
      // Ottieni il documento utente per verificare se ha un'immagine
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        if (userData['profileImageUrl'] != null) {
          // Estrai il percorso dell'immagine dall'URL
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
      
      // Rimuovi l'immagine locale
      image = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Errore nella rimozione dell\'immagine: $e');
      }
    }
  }
}