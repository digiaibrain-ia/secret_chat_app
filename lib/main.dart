import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto_service.dart';
import 'whatsapp_service.dart';

void main() {
  runApp(const SecretChatApp());
}

class SecretChatApp extends StatelessWidget {
  const SecretChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mensagens Secretas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF075E54), // verde do WhatsApp
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF075E54),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Campo da chave secreta, compartilhado pelas duas abas.
  final TextEditingController _secretKeyController = TextEditingController();
  bool _obscureKey = true;

  // Aba "Enviar"
  final TextEditingController _plainTextController = TextEditingController();

  // Aba "Receber"
  final TextEditingController _cipherTextController = TextEditingController();
  String _decryptedResult = '';
  String? _decryptError;

  static const _prefsKeySecret = 'secret_key_local_only';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedKey();
  }

  // A chave fica salva apenas localmente no aparelho (SharedPreferences),
  // apenas para não precisar redigitar toda vez que o app abre.
  // Ela nunca é transmitida para nenhum servidor.
  Future<void> _loadSavedKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKeySecret);
    if (saved != null && mounted) {
      setState(() => _secretKeyController.text = saved);
    }
  }

  Future<void> _saveKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeySecret, value);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _secretKeyController.dispose();
    _plainTextController.dispose();
    _cipherTextController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _handleEncryptAndSend() async {
    final passphrase = _secretKeyController.text;
    final message = _plainTextController.text;

    if (passphrase.trim().isEmpty) {
      _showSnack('Defina a Chave Secreta antes de continuar.', isError: true);
      return;
    }
    if (message.trim().isEmpty) {
      _showSnack('Digite uma mensagem para criptografar.', isError: true);
      return;
    }

    try {
      final cipherText = CryptoService.encryptMessage(message, passphrase);
      await WhatsAppService.sendViaWhatsApp(cipherText);
    } catch (e) {
      _showSnack('Erro ao criptografar: $e', isError: true);
    }
  }

  void _handleDecrypt() {
    final passphrase = _secretKeyController.text;
    final cipherText = _cipherTextController.text;

    setState(() {
      _decryptError = null;
      _decryptedResult = '';
    });

    if (passphrase.trim().isEmpty) {
      _showSnack('Defina a Chave Secreta antes de continuar.', isError: true);
      return;
    }
    if (cipherText.trim().isEmpty) {
      _showSnack('Cole o código recebido para decifrar.', isError: true);
      return;
    }

    try {
      final result = CryptoService.decryptMessage(cipherText, passphrase);
      setState(() => _decryptedResult = result);
    } catch (e) {
      setState(
        () => _decryptError = e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens Secretas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.lock_outline), text: 'Enviar'),
            Tab(icon: Icon(Icons.lock_open), text: 'Receber'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSecretKeyField(),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSendTab(),
                _buildReceiveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecretKeyField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _secretKeyController,
        obscureText: _obscureKey,
        onChanged: _saveKey,
        decoration: InputDecoration(
          labelText: 'Chave Secreta (deve ser igual nos dois celulares)',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.vpn_key),
          suffixIcon: IconButton(
            icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureKey = !_obscureKey),
          ),
        ),
      ),
    );
  }

  Widget _buildSendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _plainTextController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mensagem (texto normal)',
              hintText: 'Digite aqui o que quer enviar...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _handleEncryptAndSend,
            icon: const Icon(Icons.send),
            label: const Text('Criptografar e Enviar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'O texto é cifrado localmente (AES-256) e o WhatsApp abre com o '
            'código pronto para envio. Nada é enviado a servidores externos.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _cipherTextController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Cole aqui o código recebido',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _handleDecrypt,
            icon: const Icon(Icons.lock_open),
            label: const Text('Descriptografar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          if (_decryptError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _decryptError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          if (_decryptedResult.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mensagem revelada:',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _decryptedResult,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _decryptedResult),
                        );
                        _showSnack('Copiado!');
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
