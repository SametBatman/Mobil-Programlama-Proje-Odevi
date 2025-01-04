import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobil_proje/event_discovery_page.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User?> _googleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
      
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        _showDialog('Başarılı', 'Google ile giriş başarılı!');
      }
      return user;
    } catch (e) {
      _showDialog('Hata', 'Google ile giriş başarısız: ${e.toString()}');
      return null;
    }
  }

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: _emailController.text, password: _passwordController.text);
       Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => EventDiscoveryPage()),
      );
    } catch (e) {
      _showDialog('Hata', 'Giriş başarısız: ${e.toString()}');
    }
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showDialog('Başarılı', 'Şifre sıfırlama e-postası gönderildi!');
    } catch (e) {
      _showDialog('Hata', 'E-posta gönderilemedi: ${e.toString()}');
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Şifremi Unuttum'),
          content: TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'E-posta adresinizi girin',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                _sendPasswordResetEmail(_emailController.text);
                Navigator.of(context).pop();
              },
              child: Text('Gönder'),
            ),
          ],
        );
      },
    );
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Giriş Yap')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Giriş Yap'),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await _googleLogin();
              },
              icon: Image.asset(
                'assets/google_logo.png',
                width: 24.0,
                height: 24.0,
              ),
              label: Text('Google ile Giriş Yap'),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text('Şifremi Unuttum?'),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                );
              },
              child: Text('Hesabınız yok mu? Kayıt Ol'),
            ),
            SizedBox(height: 40),
          
          ],
        ),
      ),
    );
  }
}
