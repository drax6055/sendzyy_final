import 'package:encrypt/encrypt.dart';

class EncryptionService {
  final _key = Key.fromUtf8(
    'my32lengthsupersecretnooneknows1',
  ); // Must be 32 chars
  final _iv = IV.fromLength(16);

  String encrypt(String text) {
    if (text.isEmpty) return '';
    final encrypter = Encrypter(AES(_key));
    final encrypted = encrypter.encrypt(text, iv: _iv);
    return encrypted.base64;
  }

  String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    final encrypter = Encrypter(AES(_key));
    final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
    return decrypted;
  }
}
