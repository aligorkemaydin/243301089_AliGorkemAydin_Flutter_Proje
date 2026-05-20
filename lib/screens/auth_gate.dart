import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Firebase bağlantısı bekleniyorsa yükleme ikonu göster
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.orange)),
          );
        }
        
        // Kullanıcı oturumu açık ise doğrudan Ana Liste Ekranına gönder
        if (snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Kömür Dağıtım Otomasyonu'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => AuthService().signOut(),
                )
              ],
            ),
            body: const Center(
              child: Text('Ana Liste Ekranı (Giriş Başarılı!)'),
            ),
          );
        }
        
        // Kullanıcı oturumu kapalı ise Giriş Ekranına gönder
        return const LoginScreen();
      },
    );
  }
}