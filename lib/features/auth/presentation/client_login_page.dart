import 'dart:async';
import 'dart:math' as math;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';
import '../domain/international_phone.dart';
import 'client_login_controller.dart';
import 'legal_document_page.dart';

const _navy = Color(0xFF092B61);
const _blue = Color(0xFF0B4AA5);
const _green = Color(0xFF119823);
const _body = Color(0xFF596276);
const _legalVersion = '2026-08-26';
const _legalStorage = FlutterSecureStorage();

double _responsiveSize(
  BuildContext context,
  bool dense,
  double compact,
  double regular,
  double expanded,
) {
  if (dense) return compact;
  if (MediaQuery.textScalerOf(context).scale(1) > 1) return regular;
  final factor = ((MediaQuery.sizeOf(context).height - 700) / 220).clamp(
    0.0,
    1.0,
  );
  return regular + (expanded - regular) * factor;
}

class ClientLoginPage extends ConsumerStatefulWidget {
  const ClientLoginPage({this.initialLegalAccepted, super.key});

  final bool? initialLegalAccepted;

  @override
  ConsumerState<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends ConsumerState<ClientLoginPage> {
  late final ClientLoginController _controller;
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  bool _autoVerifying = false;
  bool _googleInitialized = false;
  bool _googleLoading = false;
  bool _legalPromptOpen = false;
  late bool _legalAccepted;
  late final Future<void> _legalLoaded;

  @override
  void initState() {
    super.initState();
    _legalAccepted = widget.initialLegalAccepted ?? false;
    _legalLoaded = widget.initialLegalAccepted == null
        ? _loadLegalAcceptance()
        : Future<void>.value();
    _controller = ClientLoginController(
      repository: ref.read(clientAuthRepositoryProvider),
      tokenStore: ref.read(tokenStoreProvider),
    )..addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureLegalAccepted());
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _phone.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final landscape =
                    box.maxWidth > box.maxHeight && box.maxWidth >= 650;
                final dense =
                    box.maxHeight < 680 ||
                    box.maxWidth < 340 ||
                    (scale > 1 && box.maxHeight < 900) ||
                    scale >= 1.2;
                return landscape
                    ? _landscape(box, dense)
                    : _portrait(
                        box,
                        dense,
                        MediaQuery.viewInsetsOf(context).bottom > 0 &&
                            _otpFocus.hasFocus,
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _portrait(BoxConstraints box, bool dense, bool liftForOtpKeyboard) {
    final side = box.maxWidth < 360 ? 6.0 : 10.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Transform.translate(
        offset: Offset(
          0,
          liftForOtpKeyboard ? -math.min(56.0, box.maxHeight * .07) : 0.0,
        ),
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LoginHeader(dense: dense),
                SizedBox(height: _responsiveSize(context, dense, 2, 4, 8)),
                _card(dense: dense, landscape: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _landscape(BoxConstraints box, bool dense) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: _LoginHeader(dense: true)),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: _card(dense: true, landscape: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required bool dense, required bool landscape}) => _LoginCard(
    controller: _controller,
    phoneController: _phone,
    otpController: _otp,
    otpFocus: _otpFocus,
    dense: dense,
    landscape: landscape,
    onCountryTap: _showCountrySelector,
    onRequestCode: _requestCodeWithConsent,
    onVerifyCode: _verifyCode,
    onCodeChanged: _updateCode,
    onBack: _goBack,
    onGoogle: _signInWithGoogle,
    onPending: _showPendingWithConsent,
  );

  Future<void> _requestCodeWithConsent() async {
    if (await _ensureLegalAccepted()) await _requestCode();
  }

  Future<void> _showPendingWithConsent(String feature) async {
    if (!await _ensureLegalAccepted()) return;
    if (!mounted) return;
    if (AppConfig.enableMockAuth) {
      context.go(AppRoutes.clientHome);
      return;
    }
    _showPending(feature);
  }

  Future<void> _signInWithGoogle() async {
    if (!await _ensureLegalAccepted() || _googleLoading || !mounted) return;
    if (AppConfig.enableMockAuth) {
      context.go(AppRoutes.clientHome);
      return;
    }

    setState(() => _googleLoading = true);
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: AppConfig.googleServerClientId,
        );
        _googleInitialized = true;
      }

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google no entregó un token de identidad.');
      }

      final response = await ref
          .read(authApiProvider)
          .loginClientWithGoogle(idToken);
      if (!mounted) return;

      if (response is Map && response['success'] == true) {
        _showMessage(
          response['message']?.toString() ??
              'Google validó la cuenta correctamente.',
        );
      } else {
        _showMessage(
          response is Map
              ? response['message']?.toString() ??
                    'La API rechazó el acceso con Google.'
              : 'La API respondió sin un contrato de sesión documentado.',
        );
      }
    } on GoogleSignInException catch (error) {
      if (!mounted) return;
      _showMessage(
        error.code == GoogleSignInExceptionCode.canceled
            ? 'No se completó la selección de la cuenta de Google.'
            : 'Google Sign-In no está configurado correctamente: '
                  '${error.description ?? error.code.name}.',
      );
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object catch (error) {
      if (mounted) _showMessage('No se pudo iniciar sesión con Google: $error');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<bool> _ensureLegalAccepted() async {
    await _legalLoaded;
    if (!mounted) return false;
    if (_legalAccepted) return true;
    if (_legalPromptOpen) return false;
    _legalPromptOpen = true;
    FocusScope.of(context).unfocus();
    var terms = false;
    var privacy = false;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final allAccepted = terms && privacy;

          Widget consentRow({
            required Key key,
            required bool value,
            required String label,
            required Key readKey,
            required ValueChanged<bool?> onChanged,
            required VoidCallback onRead,
          }) => Row(
            children: [
              Checkbox(key: key, value: value, onChanged: onChanged),
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(!value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(label),
                  ),
                ),
              ),
              TextButton(
                key: readKey,
                onPressed: onRead,
                child: const Text('Leer'),
              ),
            ],
          );

          return PopScope(
            canPop: false,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Material(
                key: const Key('legal_consent_dialog'),
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 12,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 520,
                    maxHeight: MediaQuery.sizeOf(context).height * .56,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Antes de continuar',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: _navy,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Acepta los documentos legales para utilizar refaNet.',
                        ),
                        CheckboxListTile(
                          key: const Key('accept_all_legal'),
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                          value: allAccepted,
                          title: const Text(
                            'Aceptar todo',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (value) => setSheetState(() {
                            terms = value ?? false;
                            privacy = value ?? false;
                          }),
                        ),
                        consentRow(
                          key: const Key('accept_terms'),
                          value: terms,
                          label: 'Términos y Condiciones',
                          readKey: const Key('read_terms'),
                          onChanged: (value) =>
                              setSheetState(() => terms = value ?? false),
                          onRead: () => _showLegalDocument(
                            'Términos y Condiciones',
                            'assets/legal/terms.txt',
                          ),
                        ),
                        consentRow(
                          key: const Key('accept_privacy'),
                          value: privacy,
                          label: 'Aviso de Privacidad',
                          readKey: const Key('read_privacy'),
                          onChanged: (value) =>
                              setSheetState(() => privacy = value ?? false),
                          onRead: () => _showLegalDocument(
                            'Aviso de Privacidad',
                            'assets/legal/privacy.txt',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                key: const Key('reject_legal_acceptance'),
                                onPressed: () async {
                                  final reject = await showDialog<bool>(
                                    context: sheetContext,
                                    barrierDismissible: false,
                                    builder: (context) => PopScope(
                                      canPop: false,
                                      child: AlertDialog(
                                        key: const Key('legal_rejection_alert'),
                                        title: const Text(
                                          'No podrás utilizar refaNet',
                                        ),
                                        content: const Text(
                                          'Si rechazas los documentos legales no podrás continuar. ¿Deseas salir?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text(
                                              'Volver y revisar',
                                            ),
                                          ),
                                          TextButton(
                                            key: const Key(
                                              'confirm_legal_rejection',
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text(
                                              'Rechazar y salir',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (reject == true && sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop(false);
                                  }
                                },
                                child: const Text('Rechazar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                key: const Key('confirm_legal_acceptance'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _green,
                                ),
                                onPressed: allAccepted
                                    ? () => Navigator.of(sheetContext).pop(true)
                                    : null,
                                child: const Text('Aceptar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    _legalPromptOpen = false;
    if (accepted == true && mounted) {
      setState(() => _legalAccepted = true);
      unawaited(_saveLegalAcceptance());
    } else if (accepted == false && mounted) {
      _goBack();
    }
    return accepted == true;
  }

  Future<void> _loadLegalAcceptance() async {
    try {
      final version = await _legalStorage.read(
        key: 'client_legal_consent_version',
      );
      if (version == _legalVersion && mounted) {
        setState(() => _legalAccepted = true);
      }
    } on PlatformException {
      // El almacenamiento seguro puede no estar disponible en pruebas.
    }
  }

  Future<void> _saveLegalAcceptance() async {
    try {
      await _legalStorage.write(
        key: 'client_legal_consent_version',
        value: _legalVersion,
      );
      await _legalStorage.write(
        key: 'client_legal_consent_accepted_at',
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } on PlatformException {
      // La API guardará la aceptación definitiva cuando publique el contrato.
    }
  }

  void _showCountrySelector() {
    FocusScope.of(context).unfocus();
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      showSearch: true,
      favorite: const ['MX', 'BO', 'US'],
      countryListTheme: CountryListThemeData(
        bottomSheetHeight: math.min(
          MediaQuery.sizeOf(context).height * .78,
          650,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        inputDecoration: InputDecoration(
          labelText: 'Buscar país',
          hintText: 'Nombre, código o prefijo',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      onSelect: (selected) {
        _phone.clear();
        _otp.clear();
        _controller.selectCountry(
          PhoneCountry(
            isoCode: selected.countryCode,
            dialCode: selected.phoneCode,
            flag: selected.flagEmoji,
            name: selected.getTranslatedName(context) ?? selected.name,
            example: selected.example,
          ),
        );
      },
    );
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    final sent = await _controller.requestCode();
    if (!mounted) return;
    if (!sent) {
      if (_controller.message != null) _showMessage(_controller.message!);
      return;
    }
    _otp.clear();
    _otpFocus.requestFocus();
  }

  Future<void> _verifyCode() async {
    if (_controller.isLoading) return;
    FocusScope.of(context).unfocus();
    final authenticated = await _controller.verifyCode();
    if (!mounted) return;
    if (authenticated) {
      context.go(AppRoutes.clientHome);
      return;
    }

    final error = _controller.codeError ?? _controller.message;
    if (error != null) _showMessage(error);
    if (_controller.codeError != null) {
      _otp.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _otp.text.length,
      );
      _otpFocus.requestFocus();
    }
  }

  void _updateCode(String value) {
    _controller.updateCode(value);
    if (_controller.step != ClientLoginStep.verification ||
        _controller.code.length != 6 ||
        _controller.isLoading ||
        _autoVerifying) {
      return;
    }

    _autoVerifying = true;
    _verifyCode().whenComplete(() {
      _autoVerifying = false;
    });
  }

  void _showPending(String feature) {
    _showMessage('$feature está pendiente de configuración oficial.');
  }

  void _showLegalDocument(String title, String assetPath) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(title: title, assetPath: assetPath),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.start);
    }
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.dense});
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final logoHeight = _responsiveSize(context, dense, 40, 100, 180);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          image: true,
          label: 'Refanet, la red nacional de autopartes usadas',
          child: ExcludeSemantics(
            child: SizedBox(
              height: logoHeight,
              child: AspectRatio(
                aspectRatio: 1203 / 809,
                child: Image.asset(
                  'assets/images/refanet_logo_transparent.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: _responsiveSize(context, dense, 1, 3, 7)),
        Text.rich(
          TextSpan(
            style: TextStyle(
              color: _navy,
              fontSize: _responsiveSize(context, dense, 18, 22, 25),
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
            children: const [
              TextSpan(text: 'Bienvenido a refa'),
              TextSpan(
                text: 'Net',
                style: TextStyle(color: _green),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: _responsiveSize(context, dense, 1, 2, 4)),
        Text(
          'Encuentra, cotiza y compra autopartes usadas.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _body,
            fontSize: _responsiveSize(context, dense, 10, 12, 14),
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.controller,
    required this.phoneController,
    required this.otpController,
    required this.otpFocus,
    required this.dense,
    required this.landscape,
    required this.onCountryTap,
    required this.onRequestCode,
    required this.onVerifyCode,
    required this.onCodeChanged,
    required this.onBack,
    required this.onGoogle,
    required this.onPending,
  });

  final ClientLoginController controller;
  final TextEditingController phoneController;
  final TextEditingController otpController;
  final FocusNode otpFocus;
  final bool dense;
  final bool landscape;
  final VoidCallback onCountryTap;
  final Future<void> Function() onRequestCode;
  final Future<void> Function() onVerifyCode;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onBack;
  final VoidCallback onGoogle;
  final ValueChanged<String> onPending;

  @override
  Widget build(BuildContext context) {
    final content = landscape
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _formColumn(context)),
              const SizedBox(width: 10),
              Expanded(child: _actionsColumn(context)),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _formColumn(context),
              SizedBox(height: _responsiveSize(context, dense, 2, 4, 8)),
              _actionsColumn(context),
            ],
          );

    return Container(
      key: const Key('client_login_card'),
      width: double.infinity,
      padding: EdgeInsets.all(_responsiveSize(context, dense, 7, 10, 18)),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(249),
        borderRadius: BorderRadius.circular(
          _responsiveSize(context, dense, 14, 18, 22),
        ),
        border: Border.all(color: const Color(0xFFE8E9ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _formColumn(BuildContext context) {
    final verification = controller.step == ClientLoginStep.verification;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardTitle(dense: dense),
        SizedBox(height: _responsiveSize(context, dense, 3, 5, 8)),
        _PhoneField(
          controller: phoneController,
          country: controller.country,
          enabled: !verification && !controller.isLoading,
          dense: dense,
          errorText: controller.phoneError,
          onChanged: controller.updatePhone,
          onCountryTap: onCountryTap,
        ),
        SizedBox(height: _responsiveSize(context, dense, 3, 4, 7)),
        Row(
          children: [
            Expanded(
              child: Text(
                'Código de 6 dígitos',
                style: TextStyle(
                  color: _navy,
                  fontSize: _responsiveSize(context, dense, 11, 13, 15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (verification)
              InkWell(
                onTap: controller.isLoading
                    ? null
                    : () {
                        otpController.clear();
                        controller.editPhone();
                      },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Text(
                    'Cambiar',
                    style: TextStyle(color: _blue, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          verification
              ? 'Te enviamos un código de verificación por SMS.'
              : 'Te enviaremos un código de verificación por SMS.',
          style: TextStyle(
            color: _body,
            fontSize: _responsiveSize(context, dense, 9, 10, 12),
            height: 1.05,
          ),
        ),
        SizedBox(height: _responsiveSize(context, dense, 3, 4, 7)),
        _OtpInput(
          controller: otpController,
          focusNode: otpFocus,
          enabled: !controller.isLoading,
          dense: dense,
          hasError: controller.codeError != null,
          onChanged: onCodeChanged,
        ),
      ],
    );
  }

  Widget _actionsColumn(BuildContext context) {
    final verification = controller.step == ClientLoginStep.verification;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _responsiveSize(context, dense, 24, 29, 36),
          child: TextButton(
            onPressed: verification && controller.canResend
                ? () => controller.resendCode()
                : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              verification && controller.resendSeconds > 0
                  ? 'Reenviar código (${_timer(controller.resendSeconds)})'
                  : 'Reenviar código',
              style: TextStyle(
                fontSize: _responsiveSize(context, dense, 10, 12, 13),
              ),
            ),
          ),
        ),
        _PrimaryButton(
          label: verification ? 'Iniciar sesión' : 'Enviar código',
          dense: dense,
          isLoading: controller.isLoading,
          enabled: verification
              ? controller.canVerifyCode
              : controller.canRequestCode,
          onPressed: verification ? onVerifyCode : onRequestCode,
        ),
        SizedBox(height: _responsiveSize(context, dense, 3, 4, 7)),
        _OrDivider(dense: dense),
        SizedBox(height: _responsiveSize(context, dense, 3, 4, 7)),
        _SocialButton(
          label: 'Continuar con Google',
          dense: dense,
          icon: Image.asset(
            'assets/images/google_signin_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          onPressed: onGoogle,
        ),
        SizedBox(height: _responsiveSize(context, dense, 3, 4, 7)),
        _SocialButton(
          label: 'Continuar con Apple',
          dense: dense,
          icon: Image.asset(
            'assets/images/apple_signin_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          onPressed: () => onPending('El acceso con Apple'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('client_login_back'),
            onPressed: onBack,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size(
                48,
                _responsiveSize(context, dense, 26, 32, 40),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.chevron_left, size: 20),
            label: Text(
              'Regresar',
              style: TextStyle(
                fontSize: _responsiveSize(context, dense, 11, 13, 15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _timer(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.dense});
  final bool dense;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: _responsiveSize(context, dense, 30, 36, 46),
        height: _responsiveSize(context, dense, 30, 36, 46),
        decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: _responsiveSize(context, dense, 19, 23, 29),
        ),
      ),
      SizedBox(width: _responsiveSize(context, dense, 7, 8, 11)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INGRESO PARA CLIENTES',
              style: TextStyle(
                color: _green,
                fontSize: _responsiveSize(context, dense, 12, 15, 18),
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Ingresa tu número de celular para iniciar sesión',
              style: TextStyle(
                color: _body,
                fontSize: _responsiveSize(context, dense, 9, 10, 12),
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.country,
    required this.enabled,
    required this.dense,
    required this.errorText,
    required this.onChanged,
    required this.onCountryTap,
  });
  final TextEditingController controller;
  final PhoneCountry country;
  final bool enabled;
  final bool dense;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onCountryTap;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('client_phone_field'),
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.phone,
    textInputAction: TextInputAction.done,
    autofillHints: const [AutofillHints.telephoneNumberNational],
    style: TextStyle(fontSize: _responsiveSize(context, dense, 13, 14, 17)),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
      LengthLimitingTextInputFormatter(16),
    ],
    onChanged: (value) {
      final prefix = '+${country.dialCode}';
      if (value.startsWith(prefix)) {
        final national = value.substring(prefix.length);
        controller.value = TextEditingValue(
          text: national,
          selection: TextSelection.collapsed(offset: national.length),
        );
        onChanged(national);
      } else {
        onChanged(value);
      }
    },
    decoration: InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: _responsiveSize(context, dense, 8, 12, 15),
        vertical: _responsiveSize(context, dense, 9, 10, 15),
      ),
      labelText: 'Número de celular',
      hintText: country.example,
      hintStyle: TextStyle(
        color: const Color(0x66929AA8),
        fontSize: _responsiveSize(context, dense, 11, 12, 14),
      ),
      errorText: errorText,
      errorStyle: TextStyle(fontSize: dense ? 9 : 10, height: 1),
      errorMaxLines: 2,
      prefixIconConstraints: BoxConstraints(
        minWidth: _responsiveSize(context, dense, 91, 103, 118),
        maxWidth: _responsiveSize(context, dense, 101, 116, 132),
      ),
      prefixIcon: Semantics(
        button: true,
        label:
            'Seleccionar país. ${country.name}, código más ${country.dialCode}',
        child: InkWell(
          key: const Key('country_selector'),
          onTap: enabled ? onCountryTap : null,
          child: Padding(
            padding: EdgeInsets.only(left: dense ? 7 : 10, right: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  country.flag,
                  style: TextStyle(
                    fontSize: _responsiveSize(context, dense, 16, 20, 23),
                  ),
                ),
                SizedBox(width: dense ? 3 : 6),
                Flexible(
                  child: Text(
                    '+${country.dialCode}',
                    style: TextStyle(
                      fontSize: _responsiveSize(context, dense, 12, 14, 16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFCACDD5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _green, width: 2),
      ),
    ),
  );
}

class _OtpInput extends StatefulWidget {
  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.dense,
    required this.hasError,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool dense;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _selectDigit(int index) {
    if (!widget.enabled) return;
    final length = widget.controller.text.length;
    widget.controller.selection = index < length
        ? TextSelection(baseOffset: index, extentOffset: index + 1)
        : TextSelection.collapsed(offset: length);
    widget.focusNode.requestFocus();
  }

  Future<void> _pasteCode() async {
    if (!widget.enabled) return;
    final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final code = digits.substring(0, math.min(6, digits.length));
    widget.controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    widget.onChanged(code);
    if (code.length < 6) widget.focusNode.requestFocus();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.focusNode.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    enabled: widget.enabled,
    label: 'Código de verificación de seis dígitos',
    value: widget.controller.text,
    hint: 'Toca una casilla para escribir o mantenla presionada para pegar',
    child: GestureDetector(
      onLongPress: widget.enabled ? _pasteCode : null,
      child: SizedBox(
        height: _responsiveSize(context, widget.dense, 32, 40, 52),
        child: Stack(
          children: [
            Row(
              children: List.generate(6, (index) {
                final value = index < widget.controller.text.length
                    ? widget.controller.text[index]
                    : '';
                final selection = widget.controller.selection;
                final activeIndex = selection.isValid
                    ? math.min(selection.start, 5)
                    : math.min(widget.controller.text.length, 5);
                final active =
                    widget.enabled &&
                    widget.focusNode.hasFocus &&
                    index == activeIndex;
                return Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Dígito ${index + 1} de 6',
                    value: value,
                    child: GestureDetector(
                      key: Key('otp_digit_$index'),
                      onTap: widget.enabled ? () => _selectDigit(index) : null,
                      onLongPress: widget.enabled ? _pasteCode : null,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: EdgeInsets.only(right: index == 5 ? 0 : 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.enabled
                              ? Colors.white
                              : const Color(0xFFF7F7F8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.hasError
                                ? const Color(0xFFB3261E)
                                : active
                                ? _green
                                : const Color(0xFFCACDD5),
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            color: _navy,
                            fontSize: _responsiveSize(
                              context,
                              widget.dense,
                              17,
                              19,
                              22,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      key: const Key('client_otp_field'),
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: widget.onChanged,
                      enableInteractiveSelection: false,
                      showCursor: false,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.dense,
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });
  final String label;
  final bool dense;
  final bool isLoading;
  final bool enabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      gradient: LinearGradient(
        colors: enabled
            ? const [Color(0xFF119823), Color(0xFF0D831C)]
            : const [Color(0xFF9ABF9F), Color(0xFF8BAE90)],
      ),
    ),
    child: FilledButton(
      onPressed: enabled && !isLoading ? onPressed : null,
      style: FilledButton.styleFrom(
        minimumSize: Size(
          double.infinity,
          _responsiveSize(context, dense, 34, 42, 52),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: _responsiveSize(context, dense, 5, 6, 9),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: isLoading
          ? SizedBox(
              width: dense ? 18 : 20,
              height: dense ? 18 : 20,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: _responsiveSize(context, dense, 13, 15, 17),
                fontWeight: FontWeight.w700,
              ),
            ),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.dense});
  final bool dense;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(height: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8),
        child: Text(
          'O continúa con',
          style: TextStyle(
            color: _body,
            fontSize: _responsiveSize(context, dense, 10, 12, 13),
          ),
        ),
      ),
      const Expanded(child: Divider(height: 1)),
    ],
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.dense,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final bool dense;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF16181D),
      minimumSize: Size(
        double.infinity,
        _responsiveSize(context, dense, 30, 38, 48),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _responsiveSize(context, dense, 9, 12, 16),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: const BorderSide(color: Color(0xFFD1D3D9)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: _responsiveSize(context, dense, 26, 28, 34),
          height: _responsiveSize(context, dense, 26, 28, 34),
          child: Center(child: icon),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _responsiveSize(context, dense, 12, 13, 15),
            ),
          ),
        ),
        SizedBox(width: _responsiveSize(context, dense, 26, 28, 34)),
      ],
    ),
  );
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          top: -100,
          left: -105,
          child: Container(
            width: 205,
            height: 205,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x1649AC53), width: 23),
            ),
          ),
        ),
        const Positioned(top: 38, right: 28, child: _DotGrid()),
        Positioned(
          right: -125,
          bottom: -140,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x140B4AA5), width: 25),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    child: Wrap(
      spacing: 9,
      runSpacing: 9,
      children: List.generate(
        16,
        (_) => Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0x140B4AA5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}
