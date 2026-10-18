import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'services/rate_prompt.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App de figurinhas roda só em retrato (evita quebra de layout em paisagem).
  await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await Prefs.load();
  MobileAds.instance.initialize();
  Iap.instance.init();
  runApp(const FigurinhasApp());
}

// ---------- Monetização ----------
// IDs reais da conta AdMob (banner único por enquanto).
const _admobBannerUnit = 'ca-app-pub-5880219350817278/4990080098';
// ID de teste do Google (fallback em debug p/ não arriscar a conta real).
const _admobBannerTest = 'ca-app-pub-3940256099942544/6300978111';
// Produto de compra única na Play Store.
const _noAdsProductId = 'no_ads';

/// Compra única "remover anúncios" via Google Play Billing (in_app_purchase).
class Iap {
  Iap._();
  static final Iap instance = Iap._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final ValueNotifier<String?> price = ValueNotifier<String?>(null);
  ProductDetails? _product;
  bool _available = false;

  Future<void> init() async {
    try {
      _available = await _iap.isAvailable();
    } catch (_) {
      _available = false;
    }
    if (!_available) return;
    _iap.purchaseStream.listen(_onUpdate, onError: (_) {});
    try {
      final resp = await _iap.queryProductDetails({_noAdsProductId});
      if (resp.productDetails.isNotEmpty) {
        _product = resp.productDetails.first;
        price.value = _product!.price;
      }
    } catch (_) {}
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  /// Inicia a compra. Retorna false se a loja não está disponível.
  Future<bool> buy() async {
    if (!_available || _product == null) return false;
    try {
      await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: _product!));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  void _onUpdate(List<PurchaseDetails> purchases) {
    for (final pd in purchases) {
      if (pd.productID == _noAdsProductId &&
          (pd.status == PurchaseStatus.purchased ||
              pd.status == PurchaseStatus.restored)) {
        Prefs.setNoAds(true);
      }
      if (pd.pendingCompletePurchase) {
        _iap.completePurchase(pd);
      }
    }
  }
}

// ---------- Tema ----------
const _bg = Color(0xFF0D0E12);
const _surface = Color(0xFF181A21);
const _surface2 = Color(0xFF20232C);
const _txt = Color(0xFFF3F4F8);
const _mut = Color(0xFF9AA0AE);
const _txtDim = _mut;
const _accentA = Color(0xFF8B5CF6);
const _accentB = Color(0xFFEC4899);
const _wa = Color(0xFF25D366);

Color _hex(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));

// apps publicados (vitrine / cross-promo)
const _ourApps = <(String, String, String)>[
  ('Frases de Amor', '❤️', 'com.frasesdeamor.amor'),
  ('Frases de Amizade', '🫂', 'com.frasesdeamizade.amizade'),
  ('Frases para Status', '💬', 'com.frasesstatus.frases_status'),
  ('Versículo do Dia', '✝️', 'com.frasesbiblicas.frases_biblicas'),
  ('Bom Dia e Boa Noite', '☀️', 'com.mensagens.mensagens'),
  ('Frases de Motivação', '🚀', 'com.frasesmotivacao.frasesmotivacao'),
  ('Frases Bonitas', '🌸', 'com.frasesbonitas.bonitas'),
  ('Frases para Fotos', '📸', 'com.frasesparafotos.fotos'),
  ('Orações e Salmos', '🙏', 'com.oracoesesalmos.oracoes'),
  ('Frases Engraçadas', '😂', 'com.frasesengracadas.humor'),
  ('Frases Tristes', '💔', 'com.frasestristes.tristes'),
];
const _storeDevUrl =
    'https://play.google.com/store/apps/developer?id=Phantom%20Tecnologia';

// ---------- Canal nativo ----------
const _ch = MethodChannel('figurinhas/whatsapp');
final customVersion = ValueNotifier<int>(0);

Future<Uint8List> _assetBytes(String p) async =>
    (await rootBundle.load(p)).buffer.asUint8List();

Future<void> shareAsset(String assetPath) async {
  try {
    await _ch.invokeMethod('shareImage', {'png': await _assetBytes(assetPath)});
  } catch (_) {}
}

// "Montar meu pacote": guarda uma figurinha do catalogo dentro do pacote "Minhas".
Future<void> addAssetToMinhas(BuildContext context, String assetPath) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final n = await _ch.invokeMethod<int>(
            'saveCustomSticker', {'png': await _assetBytes(assetPath)}) ??
        0;
    customVersion.value++;
    messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface2,
        content: Text(
            n < 3
                ? 'Salva em Minhas · faltam ${3 - n} pra virar pacote ($n/3)'
                : 'Salva em Minhas ($n figurinhas)',
            style: const TextStyle(color: _txt))));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface2,
        content:
            Text('Não deu pra salvar em Minhas', style: TextStyle(color: _txt))));
  }
}

Future<void> shareFile(String filePath) async {
  try {
    await _ch.invokeMethod('shareImage', {'png': await File(filePath).readAsBytes()});
  } catch (_) {}
}

Future<void> saveAsset(BuildContext context, String assetPath) async {
  final m = ScaffoldMessenger.of(context);
  try {
    await _ch.invokeMethod('saveToGallery', {'png': await _assetBytes(assetPath)});
    m.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface2,
        content: Text('Salva na galeria 📥', style: TextStyle(color: _txt))));
  } catch (e) {
    m.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface2,
        content: Text('Não deu pra salvar: $e', style: const TextStyle(color: _txt))));
  }
}

Future<void> openUrl(String url) async {
  try {
    await _ch.invokeMethod('openUrl', {'url': url});
  } catch (_) {}
}

Future<void> addPackToWhatsApp(BuildContext context, Pack pack) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final installed = await _ch.invokeMethod<bool>('isWhatsAppInstalled') ?? false;
    if (!installed) {
      messenger.showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _surface2,
          content: Text('WhatsApp não está instalado neste aparelho',
              style: TextStyle(color: _txt))));
      return;
    }
    // Pacote de catalogo ja adicionado: evita jogar o usuario na tela de
    // "Remover" do WhatsApp. So avisa que ja esta la.
    if (pack.id != 'minhas' && installedPacks.value.contains(pack.id)) {
      messenger.showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _surface2,
          content: Text(
              'Esse pacote já está no WhatsApp ✓  ·  abra uma conversa e toque no ícone de figurinha',
              style: TextStyle(color: _txt))));
      return;
    }
    if (pack.id != 'minhas') {
      messenger.showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _surface2,
          duration: Duration(seconds: 40),
          content: Row(children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _accentB)),
            SizedBox(width: 14),
            Text('Preparando figurinhas...', style: TextStyle(color: _txt)),
          ])));
      await _ch.invokeMethod('prepareWhatsAppPack', {'identifier': pack.id});
      messenger.hideCurrentSnackBar();
    }
    await _ch.invokeMethod('addToWhatsApp', {'identifier': pack.id, 'name': pack.name});
    // Adicionou um pacote = ótimo momento: pede a avaliação nativa.
    await RatePrompt.registerPositiveAction();
  } on PlatformException catch (e) {
    messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface2,
        content: Text('Não deu pra abrir o WhatsApp: ${e.message}',
            style: const TextStyle(color: _txt))));
  }
}

// Pacotes que o proprio WhatsApp confirma ja terem sido adicionados.
final installedPacks = ValueNotifier<Set<String>>({});

Future<void> refreshInstalledPacks(Iterable<String> ids) async {
  final s = <String>{};
  for (final id in ids) {
    try {
      final added =
          await _ch.invokeMethod<bool>('isPackAdded', {'identifier': id}) ?? false;
      if (added) s.add(id);
    } catch (_) {}
  }
  installedPacks.value = s;
}

// ---------- Preferências (favoritos + sem anúncios) ----------
class Prefs {
  static SharedPreferences? _p;
  static final favs = ValueNotifier<Set<String>>({});
  static final noAds = ValueNotifier<bool>(false);
  static Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    favs.value = (_p!.getStringList('favs') ?? []).toSet();
    noAds.value = _p!.getBool('noAds') ?? false;
  }

  static void toggleFav(String key) {
    final s = {...favs.value};
    if (!s.add(key)) s.remove(key);
    favs.value = s;
    _p?.setStringList('favs', s.toList());
  }

  static void setNoAds(bool v) {
    noAds.value = v;
    _p?.setBool('noAds', v);
  }
}

// ---------- Modelo ----------
class Sticker {
  Sticker(this.packId, this.file, this.text);
  final String packId, file, text;
  String get key => '$packId|$file';
}

class Pack {
  Pack(this.id, this.name, this.emoji, this.c1, this.c2, this.stickers);
  final String id, name, emoji;
  final Color c1, c2;
  final List<Sticker> stickers;
  factory Pack.fromJson(Map<String, dynamic> j) {
    final files = (j['stickers'] as List).cast<String>();
    final texts = (j['texts'] as List?)?.cast<String>() ?? const [];
    final id = j['id'] as String;
    return Pack(id, j['name'], j['emoji'], _hex(j['c1']), _hex(j['c2']), [
      for (var i = 0; i < files.length; i++)
        Sticker(id, files[i], i < texts.length ? texts[i] : '')
    ]);
  }
}

Future<List<Pack>> _loadPacks() async {
  final raw = await rootBundle.loadString('assets/stickers/packs.json');
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return list.map(Pack.fromJson).toList();
}

class FigurinhasApp extends StatelessWidget {
  const FigurinhasApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Figurinhas de Frases',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(surface: _surface, primary: _accentA),
        fontFamily: 'Roboto',
      ),
      home: const RootShell(),
    );
  }
}

// ---------- Shell (topo fixo + abas + banner) ----------
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _idx = 0;
  late Future<List<Pack>> _future;
  List<String> _packIds = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _loadPacks()
      ..then((packs) {
        _packIds = [for (final p in packs) p.id];
        refreshInstalledPacks(_packIds);
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ao voltar do WhatsApp, reconfere quais pacotes ficaram adicionados.
    if (state == AppLifecycleState.resumed && _packIds.isNotEmpty) {
      refreshInstalledPacks(_packIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pack>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: _accentA)));
        }
        final packs = snap.data!;
        final tabs = [
          InicioTab(packs: packs),
          BuscarTab(packs: packs),
          const EditorTab(),
          const MinhasTab(),
        ];
        return Scaffold(
          appBar: _topBar(context),
          body: SafeArea(
              bottom: false, child: IndexedStack(index: _idx, children: tabs)),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: Prefs.noAds,
                builder: (_, off, __) => off ? const SizedBox.shrink() : const BannerSlot(),
              ),
              NavigationBar(
                backgroundColor: _surface,
                indicatorColor: _accentA.withValues(alpha: 0.25),
                selectedIndex: _idx,
                onDestinationSelected: (i) {
                  setState(() => _idx = i);
                  if (i == 3) customVersion.value++;
                },
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_rounded, color: _mut),
                      selectedIcon: Icon(Icons.home_rounded, color: _accentB),
                      label: 'Início'),
                  NavigationDestination(
                      icon: Icon(Icons.search_rounded, color: _mut),
                      selectedIcon: Icon(Icons.search_rounded, color: _accentB),
                      label: 'Buscar'),
                  NavigationDestination(
                      icon: Icon(Icons.brush_rounded, color: _mut),
                      selectedIcon: Icon(Icons.brush_rounded, color: _accentB),
                      label: 'Criar'),
                  NavigationDestination(
                      icon: Icon(Icons.collections_rounded, color: _mut),
                      selectedIcon: Icon(Icons.collections_rounded, color: _accentB),
                      label: 'Minhas'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _topBar(BuildContext context) {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: _bg,
      elevation: 0,
      titleSpacing: 14,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accentA, _accentB]),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: ShaderMask(
            shaderCallback: (r) =>
                const LinearGradient(colors: [_accentA, _accentB]).createShader(r),
            child: const Text('Figurinhas',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: Prefs.noAds,
          builder: (_, off, __) => IconButton(
            tooltip: off ? 'Sem anúncios ativo' : 'Remover anúncios',
            onPressed: off ? null : () => _removerAnuncios(context),
            icon: Icon(off ? Icons.verified_rounded : Icons.block_flipped,
                color: off ? _wa : _accentB),
          ),
        ),
        IconButton(
          tooltip: 'Nossos apps',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AppsShowcase())),
          icon: const Icon(Icons.home_rounded, color: _txt),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

void _removerAnuncios(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.workspace_premium_rounded, color: _accentB, size: 40),
        const SizedBox(height: 12),
        const Text('Remover anúncios',
            style: TextStyle(color: _txt, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Use o app sem banners. Pagamento único.',
            textAlign: TextAlign.center, style: TextStyle(color: _mut)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ValueListenableBuilder<String?>(
            valueListenable: Iap.instance.price,
            builder: (_, price, __) => FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _accentA,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(ctx);
                final started = await Iap.instance.buy();
                if (started) {
                  Navigator.pop(ctx);
                } else {
                  messenger.showSnackBar(const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _surface2,
                      content: Text('Compra indisponível agora. Tente mais tarde.',
                          style: TextStyle(color: _txt))));
                }
              },
              child: Text('Remover anúncios · ${price ?? 'R\$ 8,90'}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () {
            Iap.instance.restore();
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: _surface2,
                content: Text('Restaurando compra…', style: TextStyle(color: _txt))));
          },
          child: const Text('Já comprei — restaurar',
              style: TextStyle(color: _mut, fontSize: 12.5)),
        ),
        const SizedBox(height: 2),
        const Text('Pagamento único. Todo o resto é grátis.',
            style: TextStyle(color: _mut, fontSize: 11)),
      ]),
    ),
  );
}

/// Banner real do AdMob (adaptativo ancorado: preenche a largura da tela).
/// Some quando o usuário comprou "remover anúncios". Em debug usa o ID de teste
/// do Google; em release usa o bloco real da conta.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});
  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || Prefs.noAds.value) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
            Orientation.portrait, width) ??
        AdSize.banner;
    if (!mounted) return;
    final unit = kReleaseMode ? _admobBannerUnit : _admobBannerTest;
    final ad = BannerAd(
      size: size,
      adUnitId: unit,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    if (_ad == null || !_loaded) return const SizedBox(height: 56);
    return SizedBox(
      width: double.infinity,
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

// ---------- Vitrine de apps ----------
class AppsShowcase extends StatelessWidget {
  const AppsShowcase({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _txt,
        elevation: 0,
        title: const Text('Nossos apps',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _accentA,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: () => openUrl(_storeDevUrl),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Ver todos na Play Store',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          for (final a in _ourApps)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _surface, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: _surface2, borderRadius: BorderRadius.circular(13)),
                    child: Text(a.$2, style: const TextStyle(fontSize: 24))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(a.$1,
                      style: const TextStyle(
                          color: _txt, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: _surface2,
                      foregroundColor: _txt,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  onPressed: () => openUrl(
                      'https://play.google.com/store/apps/details?id=${a.$3}'),
                  child: const Text('Abrir',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

// ---------- Aba Início ----------
class InicioTab extends StatelessWidget {
  const InicioTab({super.key, required this.packs});
  final List<Pack> packs;

  Sticker _stickerOfDay() {
    final all = [for (final p in packs) ...p.stickers];
    final d = DateTime.now();
    final idx = DateTime(d.year, d.month, d.day)
        .difference(DateTime(2024, 1, 1))
        .inDays
        .abs();
    return all[(idx * 7919) % all.length];
  }

  Pack _packOf(String id) => packs.firstWhere((p) => p.id == id);

  @override
  Widget build(BuildContext context) {
    final sod = _stickerOfDay();
    return ListView(
      padding: const EdgeInsets.only(top: 6),
      children: [
        _DayCard(sticker: sod, pack: _packOf(sod.packId)),
        ValueListenableBuilder<Set<String>>(
          valueListenable: Prefs.favs,
          builder: (context, favSet, _) {
            final favs = [
              for (final p in packs)
                for (final s in p.stickers)
                  if (favSet.contains(s.key)) (p, s)
            ];
            if (favs.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('❤️  Favoritas',
                    style: TextStyle(
                        color: _txt, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: favs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => openPreview(context, favs[i].$1, favs[i].$2),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(favs[i].$2.file, width: 108, height: 108)),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Pacotes de figurinhas',
              style: TextStyle(
                  color: _txt, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        for (final p in packs) PackCard(pack: p),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.sticker, required this.pack});
  final Sticker sticker;
  final Pack pack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [pack.c1, pack.c2]),
            borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(sticker.file, width: 92, height: 92)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('FIGURINHA DO DIA',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(sticker.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                _MiniBtn(icon: Icons.send_rounded, label: 'Enviar 1', onTap: () => shareAsset(sticker.file)),
                const SizedBox(width: 8),
                _MiniBtn(icon: Icons.download_rounded, label: 'Salvar', onTap: () => saveAsset(context, sticker.file)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

/// Card compacto de um pacote (estilo dos grandes apps de figurinhas):
/// prévia horizontal + botões claros "Ver todas" e "Adicionar ao WhatsApp".
/// Tocar no card abre a [PackScreen] com todas as figurinhas.
class PackCard extends StatelessWidget {
  const PackCard({super.key, required this.pack});
  final Pack pack;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PackScreen(pack: pack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = pack.stickers.take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [pack.c1, pack.c2]),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(pack.emoji, style: const TextStyle(fontSize: 20))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pack.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _txt,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        Text('${pack.stickers.length} figurinhas',
                            style: const TextStyle(
                                color: _txtDim, fontSize: 12.5)),
                      ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: _txtDim),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: preview.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: _bg,
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(preview[i].file, width: 76, height: 76),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _txt,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13))),
                    onPressed: () => _open(context),
                    icon: const Icon(Icons.grid_view_rounded, size: 17),
                    label: const Text('Ver todas',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ValueListenableBuilder<Set<String>>(
                    valueListenable: installedPacks,
                    builder: (_, inst, __) {
                      final added = inst.contains(pack.id);
                      return FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: added ? _surface2 : _wa,
                            foregroundColor: added ? _wa : Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13))),
                        onPressed: () => addPackToWhatsApp(context, pack),
                        icon: Icon(
                            added ? Icons.check_rounded : Icons.add_rounded,
                            size: 18),
                        label: Text(added ? 'Adicionado' : 'Adicionar',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      );
                    },
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Tela do pacote: todas as figurinhas num grid. Tocar numa figurinha abre a
/// prévia para enviar/salvar/favoritar UMA por vez. Botão fixo embaixo
/// adiciona o pacote inteiro ao WhatsApp.
class PackScreen extends StatelessWidget {
  const PackScreen({super.key, required this.pack});
  final Pack pack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        title: Row(children: [
          Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [pack.c1, pack.c2]),
                  borderRadius: BorderRadius.circular(9)),
              child: Text(pack.emoji, style: const TextStyle(fontSize: 15))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(pack.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _txt, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(14)),
          child: const Row(children: [
            Icon(Icons.touch_app_rounded, color: _accentA, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text('Toque numa figurinha para enviar ou salvar uma por uma',
                  style: TextStyle(color: _txtDim, fontSize: 12.5)),
            ),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10),
            itemCount: pack.stickers.length,
            itemBuilder: (context, i) =>
                StickerTile(pack: pack, sticker: pack.stickers[i]),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: SizedBox(
          height: 52,
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: installedPacks,
            builder: (_, inst, __) {
              final added = inst.contains(pack.id);
              return FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: added ? _surface2 : _wa,
                    foregroundColor: added ? _wa : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: () => addPackToWhatsApp(context, pack),
                icon: Icon(
                    added ? Icons.check_circle_rounded : Icons.add_circle_rounded,
                    size: 20),
                label: Text(
                    added ? 'Adicionado ao WhatsApp' : 'Adicionar ao WhatsApp',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class StickerTile extends StatelessWidget {
  const StickerTile({super.key, required this.pack, required this.sticker});
  final Pack pack;
  final Sticker sticker;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openPreview(context, pack, sticker),
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10)),
          padding: const EdgeInsets.all(6),
          child: Image.asset(sticker.file),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: Prefs.favs,
            builder: (_, favSet, __) => favSet.contains(sticker.key)
                ? const Icon(Icons.favorite_rounded, color: _accentB, size: 18)
                : const SizedBox.shrink(),
          ),
        ),
      ]),
    );
  }
}

void openPreview(BuildContext context, Pack pack, Sticker sticker) {
  showModalBottomSheet(
    context: context,
    backgroundColor: _surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final imgSize = media.size.height < 640 ? 130.0 : 200.0;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: 26 + media.viewPadding.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: _surface2, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration:
              BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(24)),
          child: Image.asset(sticker.file, width: imgSize, height: imgSize),
        ),
        const SizedBox(height: 18),
        Row(children: [
          _PreviewAction(
              icon: Icons.favorite_rounded,
              label: 'Favoritar',
              listenFav: sticker.key,
              onTap: () => Prefs.toggleFav(sticker.key)),
          const SizedBox(width: 10),
          _PreviewAction(
              icon: Icons.download_rounded,
              label: 'Salvar',
              onTap: () {
                Navigator.pop(context);
                saveAsset(context, sticker.file);
              }),
          const SizedBox(width: 10),
          _PreviewAction(
              icon: Icons.send_rounded,
              label: 'Enviar 1',
              onTap: () {
                Navigator.pop(context);
                shareAsset(sticker.file);
              }),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Toque em "Enviar 1" para mandar esta figurinha agora. O botão verde adiciona o pacote inteiro ao teclado do WhatsApp.',
              style: TextStyle(fontSize: 11.5, height: 1.25, color: Colors.white.withOpacity(0.55)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _wa,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () {
              Navigator.pop(context);
              addPackToWhatsApp(context, pack);
            },
            icon: const Icon(Icons.chat_rounded, size: 20),
            label: Text('Adicionar pacote "${pack.name}"',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _accentB,
                side: const BorderSide(color: Colors.white24),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () {
              Navigator.pop(context);
              addAssetToMinhas(context, sticker.file);
            },
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 19),
            label: const Text('Guardar em "Minhas" (montar meu pacote)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
            ]),
          ),
        ),
      );
    },
  );
}

class _PreviewAction extends StatelessWidget {
  const _PreviewAction(
      {required this.icon, required this.label, required this.onTap, this.listenFav});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? listenFav;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: _surface2, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            if (listenFav != null)
              ValueListenableBuilder<Set<String>>(
                valueListenable: Prefs.favs,
                builder: (_, favSet, __) => Icon(icon,
                    color: favSet.contains(listenFav) ? _accentB : _txt, size: 22),
              )
            else
              Icon(icon, color: _txt, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: _txt, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

// ---------- Aba Buscar ----------
class BuscarTab extends StatefulWidget {
  const BuscarTab({super.key, required this.packs});
  final List<Pack> packs;
  @override
  State<BuscarTab> createState() => _BuscarTabState();
}

class _BuscarTabState extends State<BuscarTab> {
  String _q = '';
  late final List<(Pack, Sticker)> _all = [
    for (final p in widget.packs)
      for (final s in p.stickers) (p, s)
  ];

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll(RegExp('[í]'), 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll(RegExp('[ú]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final q = _norm(_q.trim());
    final res =
        q.isEmpty ? _all : _all.where((e) => _norm(e.$2.text).contains(q)).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          style: const TextStyle(color: _txt),
          decoration: InputDecoration(
            hintText: 'Ex.: amor, saudade, bom dia...',
            hintStyle: const TextStyle(color: _mut),
            prefixIcon: const Icon(Icons.search_rounded, color: _mut),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${res.length} figurinhas',
                style: const TextStyle(color: _mut, fontSize: 12.5))),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: res.length,
          itemBuilder: (_, i) => StickerTile(pack: res[i].$1, sticker: res[i].$2),
        ),
      ),
    ]);
  }
}

// ---------- Editor ----------
class StickerTpl {
  const StickerTpl(this.c1, this.c2, this.sym);
  final Color c1, c2;
  final IconData? sym;
}

const _templates = <StickerTpl>[
  StickerTpl(Color(0xFFFF5F6D), Color(0xFFFF8FB1), Icons.favorite_rounded),
  StickerTpl(Color(0xFFFF9A3C), Color(0xFFFFD25A), Icons.wb_sunny_rounded),
  StickerTpl(Color(0xFF4B6CB7), Color(0xFF182848), Icons.nightlight_round),
  StickerTpl(Color(0xFF11998E), Color(0xFF38EF7D), Icons.favorite_rounded),
  StickerTpl(Color(0xFF4776E6), Color(0xFF8E54E9), Icons.star_rounded),
  StickerTpl(Color(0xFFDA22FF), Color(0xFF9733EE), Icons.auto_awesome_rounded),
  StickerTpl(Color(0xFF232526), Color(0xFF414345), null),
  StickerTpl(Color(0xFFF857A6), Color(0xFFFF5858), Icons.celebration_rounded),
];

const _textColors = <Color>[
  Colors.white,
  Color(0xFF111111),
  Color(0xFFFFE64D),
  Color(0xFF00E5FF),
];

class StickerCanvas extends StatelessWidget {
  const StickerCanvas(
      {super.key,
      required this.size,
      required this.text,
      required this.tpl,
      this.textColor = Colors.white,
      this.italic = false});
  final double size;
  final String text;
  final StickerTpl tpl;
  final Color textColor;
  final bool italic;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.transparent,
      padding: EdgeInsets.all(size * 0.035),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [tpl.c1, tpl.c2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(size * 0.17),
          border: Border.all(color: Colors.white, width: size * 0.028),
        ),
        child: Stack(alignment: Alignment.center, children: [
          if (tpl.sym != null)
            Positioned(
                top: size * 0.15,
                child: Icon(tpl.sym,
                    size: size * 0.2, color: Colors.white.withValues(alpha: 0.26))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.1),
            child: Text(text.isEmpty ? 'Sua frase aqui' : text,
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  fontSize: size * 0.108,
                  height: 1.12,
                  shadows: [
                    Shadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        offset: const Offset(0, 1),
                        blurRadius: 3)
                  ],
                )),
          ),
          Positioned(
            bottom: size * 0.055,
            child: Text('Figurinhas de Frases',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: size * 0.036,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class EditorTab extends StatelessWidget {
  const EditorTab({super.key});
  @override
  Widget build(BuildContext context) => const EditorBody();
}

class EditorBody extends StatefulWidget {
  const EditorBody({super.key});
  @override
  State<EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<EditorBody> {
  final _key = GlobalKey();
  final _ctrl = TextEditingController();
  int _tpl = 0;
  int _color = 0;
  bool _italic = false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 512 / 256);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      final png = bd!.buffer.asUint8List();
      await _ch.invokeMethod('saveCustomSticker', {'png': png});
      customVersion.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _surface2,
            content: Text('Figurinha criada! Veja em "Minhas" 🎉',
                style: TextStyle(color: _txt))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        Center(
          child: RepaintBoundary(
            key: _key,
            child: StickerCanvas(
                size: 256,
                text: _ctrl.text,
                tpl: _templates[_tpl],
                textColor: _textColors[_color],
                italic: _italic),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _ctrl,
          onChanged: (_) => setState(() {}),
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(color: _txt),
          decoration: InputDecoration(
            hintText: 'Escreva sua frase...',
            hintStyle: const TextStyle(color: _mut),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Estilo',
            style: TextStyle(color: _txt, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _tpl = i),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [_templates[i].c1, _templates[i].c2]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _tpl == i ? Colors.white : Colors.transparent, width: 3),
                ),
                child: _templates[i].sym == null
                    ? null
                    : Icon(_templates[i].sym, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          const Text('Cor',
              style: TextStyle(color: _txt, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(width: 14),
          for (var i = 0; i < _textColors.length; i++)
            GestureDetector(
              onTap: () => setState(() => _color = i),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _textColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _color == i ? _accentB : Colors.white24,
                      width: _color == i ? 3 : 1),
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _italic = !_italic),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: _italic ? _accentA : _surface,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('I',
                  style: TextStyle(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _accentA,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.add_rounded),
            label: Text(_saving ? 'Salvando...' : 'Criar figurinha',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

// ---------- Aba Minhas ----------
class MinhasTab extends StatefulWidget {
  const MinhasTab({super.key});
  @override
  State<MinhasTab> createState() => _MinhasTabState();
}

class _MinhasTabState extends State<MinhasTab> {
  List<String> _created = [];
  @override
  void initState() {
    super.initState();
    customVersion.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    customVersion.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await _ch.invokeMethod<List<dynamic>>('listCustomStickers');
    if (mounted) setState(() => _created = (list ?? []).cast<String>());
  }

  Future<void> _delete(String path) async {
    await _ch.invokeMethod('deleteCustomSticker', {'path': path});
    _refresh();
  }

  Future<void> _addMine() async {
    await addPackToWhatsApp(context,
        Pack('minhas', 'Minhas Figurinhas', '✨', _accentA, _accentB, const []));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        const Text('Minhas figurinhas',
            style: TextStyle(color: _txt, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Pra mandar 1 avulsa, toque na figurinha › "Enviar 1". '
            'O WhatsApp exige 3+ pra virar um pacote fixo.',
            style: TextStyle(color: _mut, fontSize: 12.5)),
        const SizedBox(height: 14),
        if (_created.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Column(children: const [
              Icon(Icons.brush_rounded, color: _mut, size: 48),
              SizedBox(height: 12),
              Text('Você ainda não criou figurinhas',
                  style: TextStyle(color: _mut)),
              SizedBox(height: 4),
              Text('Vá na aba "Criar" pra fazer a sua',
                  style: TextStyle(color: _mut, fontSize: 12.5)),
            ]),
          )
        else ...[
          Text(
              _created.length < 3
                  ? 'Crie mais ${3 - _created.length} pra adicionar o pacote (${_created.length}/3)'
                  : '${_created.length} figurinhas',
              style: const TextStyle(color: _mut, fontSize: 13)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10),
            itemCount: _created.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _myActions(_created[i]),
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10)),
                  padding: const EdgeInsets.all(6),
                  child: Image.file(File(_created[i])),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _delete(_created[i]),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 15),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _wa,
                  disabledBackgroundColor: _surface2,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: _created.length >= 3 ? _addMine : null,
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Adicionar pacote ao WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    );
  }

  void _myActions(String path) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration:
                BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(22)),
            child: Image.file(File(path), width: 180, height: 180),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _PreviewAction(
                icon: Icons.download_rounded,
                label: 'Salvar',
                onTap: () async {
                  Navigator.pop(ctx);
                  final m = ScaffoldMessenger.of(context);
                  try {
                    await _ch.invokeMethod(
                        'saveToGallery', {'png': await File(path).readAsBytes()});
                    m.showSnackBar(const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: _surface2,
                        content:
                            Text('Salva na galeria 📥', style: TextStyle(color: _txt))));
                  } catch (_) {}
                }),
            const SizedBox(width: 10),
            _PreviewAction(
                icon: Icons.send_rounded,
                label: 'Enviar 1',
                onTap: () {
                  Navigator.pop(ctx);
                  shareFile(path);
                }),
          ]),
        ]),
      ),
    );
  }
}
