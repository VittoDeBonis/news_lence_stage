
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Verifica lo stato dell'utente
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // Utente loggato
        Future.delayed(Duration.zero, () {
          Navigator.pushReplacementNamed(context, '/home');
        });
      } else {
        // Nessun utente loggato
        Future.delayed(Duration.zero, () {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}