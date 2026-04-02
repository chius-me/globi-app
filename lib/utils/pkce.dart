import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class Pkce {
  final String codeVerifier;
  final String codeChallenge;
  final String state;
  final String nonce;

  Pkce._({
    required this.codeVerifier,
    required this.codeChallenge,
    required this.state,
    required this.nonce,
  });

  factory Pkce.fromStored({
    required String codeVerifier,
    required String codeChallenge,
    required String state,
    required String nonce,
  }) {
    return Pkce._(
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      state: state,
      nonce: nonce,
    );
  }

  factory Pkce.generate() {
    final verifier = _generateRandomString(128);
    final challenge = _computeCodeChallenge(verifier);
    final state = _generateRandomString(32);
    final nonce = _generateRandomString(32);
    return Pkce._(
      codeVerifier: verifier,
      codeChallenge: challenge,
      state: state,
      nonce: nonce,
    );
  }

  static String _generateRandomString(int length) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _computeCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes);
  }
}
