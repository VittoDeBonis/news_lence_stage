import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:news_lens/services/firebase_auth_services.dart';
import 'package:news_lens/presentation/screens/auth/login.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Register extends StatefulWidget {
  final TextEditingController? controller;

  const Register({super.key, this.controller});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  bool _isSigningUp = false;
  String _emailError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';

  final FirebaseAuthService _auth = FirebaseAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Register',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: Center(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          obscureText: false,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: 'Email',
                            errorText: _emailError.isNotEmpty ? _emailError : null,
                          ),
                          onChanged: (value) => _validateFields(),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Password',
                              errorText: _passwordError.isNotEmpty ? _passwordError : null),
                          onChanged: (value) => _validateFields(),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Confirm Password',
                              errorText: _confirmPasswordError.isNotEmpty ? _confirmPasswordError : null),
                          onChanged: (value) => _validateFields(),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                            onPressed: _signUp,
                            child: _isSigningUp
                                ? const CircularProgressIndicator(
                                    color: Colors.black,
                                  )
                                : const Text('Sign Up')),
                        TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const Login()));
                            },
                            child: const Text(
                                'Have you already an account? Login'))
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Funzione per validare i campi
  void _validateFields() {
    setState(() {
      // Validazione email
      String email = _emailController.text.trim();
      if (email.isEmpty) {
        _emailError = 'Insert an email.';
      } else if (!RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$').hasMatch(email)) {
        _emailError = 'Insert a valid email.';
      } else {
        _emailError = ''; // Rimuovi l'errore se l'email è valida
      }

      // Validazione password
      String password = _passwordController.text.trim();
      if (password.isEmpty) {
        _passwordError = 'Insert a password.';
      } else if (password.length < 8) {
        _passwordError = 'The password must contain at least 8 characters.';
      } else {
        _passwordError = ''; 
      }

      // Validazione conferma password
      String confirmPassword = _confirmPasswordController.text.trim();
      if (password != confirmPassword) {
        _confirmPasswordError = 'The passwords do not match.';
      } else {
        _confirmPasswordError = ''; 
      }
    });
  }

  /// Funzione per gestire la registrazione
  void _signUp() async {
    // Prima validazione completa dei campi
    _validateFields();

    // Se ci sono errori, interrompi la procedura
    if (_emailError.isNotEmpty || _passwordError.isNotEmpty || _confirmPasswordError.isNotEmpty) {
      return;
    }

    setState(() {
      _isSigningUp = true;
    });

    try {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();

      User? user = await _auth.signUpWithEmailAndPassword(email, password, context);

      setState(() {
        _isSigningUp = false;
      });

      if (user != null) {
        if (kDebugMode) {
          print('User is successfully created');
        }
        
        Navigator.pushNamed(context, "/pre_settings");
      }
    } catch (e) {
      setState(() {
        _isSigningUp = false;
      });
      // Gli errori sono già gestiti dentro la funzione signUpWithEmailAndPassword
      // con la Snackbar, quindi non è necessario fare altro qui
    }
  }
}