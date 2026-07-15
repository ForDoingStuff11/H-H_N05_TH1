import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Đăng ký tài khoản
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

  }

  /// Đăng nhập
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Người dùng hiện tại
  User? get currentUser => _auth.currentUser;

  /// Theo dõi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}