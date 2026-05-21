import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'customer_home_screen.dart';
import 'admin_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // 1. Firebase bağlantısı bekleniyor
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
        }
        
        // 2. Kullanıcı giriş yapmışsa rolünü kontrol et
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                 return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
              }
              
              if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                String role = roleSnapshot.data!.get('role');
                
                // Role göre gerçek sayfalara yönlendir
                if (role == 'Toptancı') {
                  return const AdminHomeScreen();
                } else {
                  return const CustomerHomeScreen();
                }
              }
              
              // Hata anında çıkış butonu göster
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Kullanıcı bilgileri alınamadı.'),
                      ElevatedButton(
                        onPressed: () => AuthService().signOut(),
                        child: const Text('Çıkış Yap'),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        }
        
        // 3. Kullanıcı giriş yapmamışsa Login ekranına at
        return const LoginScreen();
      },
    );
  }
}