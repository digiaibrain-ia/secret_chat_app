import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;

/// Serviço responsável por toda a lógica de criptografia/decriptografia.
///
/// Formato do dado transportado (após Base64):
///   [ IV — 16 bytes ] + [ texto cifrado AES-256-CBC ]
///
/// O IV (vetor de inicialização) é gerado aleatoriamente a cada mensagem e
/// vai junto com o pacote cifrado — isso é seguro e é a prática padrão,
/// pois o IV não precisa ser secreto, só precisa ser único por mensagem.
class CryptoService {
  /// Deriva uma chave AES de 256 bits (32 bytes) a partir da senha em texto puro.
  ///
  /// Usamos SHA-256 como função de derivação simples: qualquer senha digitada
  /// vira sempre uma chave de exatamente 32 bytes, do jeito que o AES-256 exige.
  ///
  /// Nota de segurança: para o uso pretendido (canal privado entre pai e filho)
  /// isso é suficiente. Em um cenário de produção com adversários mais fortes,
  /// o recomendado seria uma KDF com salt + iterações (ex: PBKDF2 ou Argon2)
  /// para dificultar ataques de força bruta contra a senha.
  static encrypt.Key _deriveKey(String passphrase) {
    final bytes = utf8.encode(passphrase);
    final hash = crypto.sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  /// Criptografa [plainText] usando a senha compartilhada [passphrase].
  /// Retorna uma string Base64 pronta para ser colada no WhatsApp.
  static String encryptMessage(String plainText, String passphrase) {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError('A chave secreta não pode estar vazia.');
    }

    final key = _deriveKey(passphrase);
    // 16 bytes = tamanho de bloco do AES, exigido para o IV em modo CBC.
    final iv = encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Concatena IV + ciphertext antes de codificar em Base64, para que o
    // destinatário consiga separar e usar o IV correto ao decifrar.
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64.encode(combined);
  }

  /// Decriptografa uma string Base64 (gerada por [encryptMessage]) usando [passphrase].
  /// Lança uma exceção com mensagem amigável caso a senha esteja errada
  /// ou o texto colado esteja incompleto/corrompido.
  static String decryptMessage(String cipherTextBase64, String passphrase) {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError('A chave secreta não pode estar vazia.');
    }

    try {
      final combined = base64.decode(cipherTextBase64.trim());

      if (combined.length <= 16) {
        throw const FormatException('Dado cifrado inválido ou incompleto.');
      }

      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);

      final key = _deriveKey(passphrase);
      final iv = encrypt.IV(Uint8List.fromList(ivBytes));

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(Uint8List.fromList(cipherBytes)),
        iv: iv,
      );

      return decrypted;
    } catch (_) {
      // Não expomos detalhes técnicos do erro original (podem vazar
      // informação sobre a implementação); damos uma mensagem clara ao usuário.
      throw Exception(
        'Não foi possível decifrar. Verifique se a Chave Secreta é a mesma '
        'usada para cifrar e se o código foi colado por completo.',
      );
    }
  }
}
