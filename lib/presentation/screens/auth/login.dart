import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:news_lens/providers/theme_provider.dart';
import 'package:news_lens/services/firebase_auth_services.dart';
import 'package:news_lens/presentation/screens/auth/register.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _isSigning = false;

  final FirebaseAuthService _auth = FirebaseAuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Login',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Center(
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Padding( 
                    padding: const EdgeInsets.all(20.0),
                    child: Column( 
                      children: [
                        TextField(
                          controller: _emailController,
                          obscureText: false,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Email',
                          ),
                        ),
                        const SizedBox(height: 15), 
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Password',
                          ),
                        ),
                        const SizedBox(height: 15), 
                        ElevatedButton(
                          onPressed: _signIn, 
                          child: _isSigning 
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text('Login')
                        ),
                        TextButton(
                          onPressed: (){
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const Register()),
                            );
                          },
                          child: const Text('You dont have an account? Register'),
                        ), 
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _signIn() async{
    setState(() {
      _isSigning = true;
    });
    
    String email = _emailController.text;
    String password = _passwordController.text;

    User? user = await _auth.signInWithEmailAndPassword(email, password, context);

    setState(() {
      _isSigning = false;
    });

    if(user != null){
      if (kDebugMode) {
        print('User is successfully signedIn');
      }

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      await themeProvider.updateUserId(user.uid);
      
      Navigator.pushNamed(context, "/home");
    } else {
      if (kDebugMode) {
        print("Some error happened");
      }
    }
  }
}