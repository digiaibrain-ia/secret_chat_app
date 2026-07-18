import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Serviço responsável por enviar o texto já cifrado através do WhatsApp.
class WhatsAppService {
  /// Tenta abrir o WhatsApp diretamente com o texto pré-preenchido, usando
  /// o deep link `whatsapp://send?text=...`.
  ///
  /// Se o deep link não puder ser aberto (WhatsApp não instalado, restrição
  /// de sistema operacional, etc.), cai automaticamente no menu de
  /// compartilhamento nativo do sistema como alternativa (fallback), onde
  /// o usuário pode escolher o WhatsApp manualmente.
  static Future<void> sendViaWhatsApp(String text) async {
    final encodedText = Uri.encodeComponent(text);
    final whatsappUri = Uri.parse('whatsapp://send?text=$encodedText');

    try {
      final canOpen = await canLaunchUrl(whatsappUri);
      if (canOpen) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // Segue para o fallback abaixo.
    }

    await Share.share(text);
  }
}
