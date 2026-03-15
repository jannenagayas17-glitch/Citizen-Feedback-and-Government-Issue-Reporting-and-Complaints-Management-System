import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static const String _defaultWebClientId =
      '130270115060-c326ng56qbjfvt9lt4c3jfl8afasphje.apps.googleusercontent.com';
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
  );

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return await _auth.signInWithPopup(provider);
    }

    await _googleSignIn.signOut();
    await _auth.signOut();

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      throw Exception("Google sign-in cancelled");
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
      throw Exception(
        'Google Sign-In is missing an ID token. Configure the Firebase Google provider, add your Android SHA keys, and pass GOOGLE_WEB_CLIENT_ID.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
