import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Avaliação NATIVA do Google (In-App Review): mostra o cartão de nota POR CIMA
/// do app, sem tirar o usuário dele, já traduzido no idioma do aparelho. O
/// Google controla a frequência (cota) — por isso só pedimos num bom momento
/// (depois de o usuário já ter compartilhado algumas vezes = sinal de que está
/// gostando) e UMA única vez. Se a API nativa não estiver disponível, abre a
/// ficha na Play como reserva.
///
/// Self-contained (usa SharedPreferences direto, sem BuildContext) para poder
/// ser chamado de qualquer lugar e replicado igual em todos os apps.
class RatePrompt {
  RatePrompt._();

  static final InAppReview _review = InAppReview.instance;

  static const String _kCount = 'rate_positive_actions';
  static const String _kDone = 'rate_prompt_done';
  static const int _threshold = 3;

  /// Chame após uma AÇÃO POSITIVA (compartilhar/salvar imagem). Ao atingir o
  /// limite, pede a avaliação nativa uma única vez.
  static Future<void> registerPositiveAction() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kDone) ?? false) return;
    final n = (prefs.getInt(_kCount) ?? 0) + 1;
    await prefs.setInt(_kCount, n);
    if (n < _threshold) return;
    await prefs.setBool(_kDone, true); // não insiste
    await _request();
  }

  /// Botão manual "Avaliar" (aba Mais): tenta o cartão nativo; se indisponível,
  /// abre a ficha do app na Play.
  static Future<void> openReview() => _request();

  static Future<void> _request() async {
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
        return;
      }
    } catch (_) {
      // cai no fallback
    }
    try {
      await _review.openStoreListing();
    } catch (_) {}
  }
}
