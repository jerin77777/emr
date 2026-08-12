import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoHelper {
  /// Hashes a password using SHA-256 and returns a 64-character hex string.
  static String hashPassword(String password) {
    if (password.isEmpty) return '';
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies a password against a stored hash.
  /// Handles legacy plain-text passwords gracefully if the stored hash is not 64-chars.
  static bool verifyPassword(String inputPassword, String storedPasswordOrHash) {
    if (storedPasswordOrHash.length == 64) {
      return hashPassword(inputPassword) == storedPasswordOrHash;
    }
    // Backward compatibility for legacy/seed passwords
    return inputPassword == storedPasswordOrHash;
  }
}
