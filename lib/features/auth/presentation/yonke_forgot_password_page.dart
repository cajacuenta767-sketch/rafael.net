import '../../../app/widgets/responsive_scaffold.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';
import '../domain/yonke_auth_repository.dart';

class YonkeForgotPasswordPage extends ConsumerStatefulWidget {
  const YonkeForgotPasswordPage({super.key, this.repository});

  final YonkeAuthRepository? repository;

  @override
  ConsumerState<YonkeForgotPasswordPage> createState() =>
      _YonkeForgotPasswordPageState();
}

class _YonkeForgotPasswordPageState
    extends ConsumerState<YonkeForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _loading = false;
  String? _errorMessage;
  String? _successMessage;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  static final _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }
    if (trimmed.length > 254) {
      return 'El correo no puede tener más de 254 caracteres.';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Ingresa un correo electrónico válido.';
    }
    return null;
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _loading || _cooldownSeconds > 0) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final YonkeAuthRepository repo =
        widget.repository ?? ref.read(yonkeAuthRepositoryProvider);
    final email = _emailController.text.trim();

    try {
      final message = await repo.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _successMessage = message;
        _loading = false;
      });
      _startCooldown();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _messageFor(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'No se pudo conectar. Revisa tu conexión e inténtalo nuevamente.';
      });
    }
  }

  String _messageFor(ApiException error) {
    if (error.statusCode != null && error.statusCode! >= 500) {
      return 'El servicio no está disponible en este momento. Intenta más tarde.';
    }
    if (error.statusCode == null) {
      return 'No se pudo conectar. Revisa tu conexión e inténtalo nuevamente.';
    }
    return error.message.isNotEmpty
        ? error.message
        : 'No pudimos procesar la solicitud. Inténtalo nuevamente.';
  }

  Future<void> _openMailApp() async {
    final uri = Uri(scheme: 'mailto');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // Ignorar fallo de launcher si no hay cliente de correo configurado
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_loading,
    child: ResponsiveScaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFBFD),
        surfaceTintColor: const Color(0xFFFAFBFD),
        leading: IconButton(
          tooltip: 'Regresar',
          onPressed: _loading
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.yonkeLogin);
                  }
                },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 380 ? 20 : 28,
              8,
              MediaQuery.sizeOf(context).width < 380 ? 20 : 28,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  minHeight: constraints.maxHeight - 32,
                ),
                child: _successMessage != null
                    ? _buildSuccessView()
                    : _buildFormView(),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildFormView() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Recuperar contraseña',
          style: TextStyle(
            color: Color(0xFF0F1E36),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingresa el correo electrónico asociado a tu cuenta de yonke. Te enviaremos un enlace seguro para restablecerla desde tu navegador web.',
          style: TextStyle(
            color: Color(0xFF5E6D82),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        Card(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE3E8F0)),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 380 ? 18 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('yonke-forgot-email-field'),
                  controller: _emailController,
                  focusNode: _emailFocus,
                  enabled: !_loading,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'yonke@ejemplo.com',
                    counterText: '',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateEmail,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF9B2C24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFF9B2C24)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('yonke-forgot-submit-button'),
                  onPressed: _loading || _cooldownSeconds > 0 ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: const Color(0xFF114EB0),
                  ),
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _cooldownSeconds > 0
                              ? 'Reintentar en $_cooldownSeconds s'
                              : 'Enviar enlace de recuperación',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: _loading ? null : () => context.go(AppRoutes.yonkeLogin),
            child: const Text('Volver al inicio de sesión'),
          ),
        ),
      ],
    ),
  );

  Widget _buildSuccessView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Card(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE3E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: Color(0xFF269627),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '¡Revisa tu correo!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF0F1E36),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _successMessage ?? 'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña desde tu navegador web.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF5E6D82),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                key: const Key('yonke-open-mail-app-button'),
                onPressed: _openMailApp,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFF114EB0),
                ),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Abrir aplicación de correo'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('yonke-resend-reset-button'),
                onPressed: _cooldownSeconds > 0 ? null : _submit,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(
                  _cooldownSeconds > 0
                      ? 'Reenviar en $_cooldownSeconds s'
                      : 'Reenviar correo',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: TextButton(
          onPressed: () => context.go(AppRoutes.yonkeLogin),
          child: const Text('Volver al inicio de sesión'),
        ),
      ),
    ],
  );
}
