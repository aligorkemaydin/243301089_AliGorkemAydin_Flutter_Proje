import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Veritabanı bağlantısı

  // Anlık kullanıcı durumunu dinleyen stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;

  // Giriş Yapma
  Future<User?> signIn({required String email, required String password}) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Kayıt Olma ve Firestore'a Rol Yazma
  Future<User?> signUp({required String email, required String password, required String role}) async {
    try {
      // 1. Firebase Auth üzerinde kullanıcıyı oluştur
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Oluşan kullanıcının ID'si ile veritabanına rolünü kaydet
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role, // 'Müşteri' veya 'Toptancı'
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Çıkış Yapma
  Future<void> signOut() async {
    await _auth.signOut();
  }
}