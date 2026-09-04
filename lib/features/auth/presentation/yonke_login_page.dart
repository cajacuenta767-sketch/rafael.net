import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';

class YonkeLoginPage extends ConsumerStatefulWidget {
  const YonkeLoginPage({super.key});

  @override
  ConsumerState<YonkeLoginPage> createState() => _YonkeLoginPageState();
}

class _YonkeLoginPageState extends ConsumerState<YonkeLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _passwordVisible = false;
  bool _loading = false;
  String? _message;

  bool get _canSubmit =>
      !_loading &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController
      ..clear()
      ..dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo electrónico.';
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Ingresa un correo electrónico válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña.';
    if (value.length > 256) return 'La contraseña es demasiado larga.';
    return null;
  }

  Future<void> _submit() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await ref
          .read(yonkeAuthRepositoryProvider)
          .login(
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      if (!result.hasUsableSession) {
        setState(() {
          _message = result.sessionContractPending
              ? 'La API respondió, pero el contrato de sesión del yonke aún debe confirmarse.'
              : 'No fue posible crear una sesión segura para el yonke.';
        });
        return;
      }
      await ref.read(tokenStoreProvider).writeTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
      );
      if (!mounted) return;
      context.go(AppRoutes.yonkeHome);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = _messageFor(error));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message =
            'No se pudo conectar. Revisa tu conexión e inténtalo nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(ApiException error) {
    if (error.statusCode == 400 || error.statusCode == 401) {
      return 'No pudimos iniciar sesión. Revisa tus credenciales.';
    }
    if (error.statusCode != null && error.statusCode! >= 500) {
      return 'El servicio no está disponible en este momento.';
    }
    if (error.statusCode == null) {
      return 'No se pudo conectar. Revisa tu conexión e inténtalo nuevamente.';
    }
    return 'No pudimos iniciar sesión. Inténtalo nuevamente.';
  }

  void _enterDemoMode() {
    if (!AppConfig.enableMockAuth || _loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    context.go(AppRoutes.yonkeHome, extra: true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_loading,
    child: Scaffold(
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
                    context.go(AppRoutes.start);
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label: 'Logo refaNet',
                        image: true,
                        child: Center(
                          child: Image.asset(
                            'assets/images/refanet_logo_transparent.png',
                            width: MediaQuery.sizeOf(context).width < 380
                                ? 150
                                : 190,
                            height: MediaQuery.sizeOf(context).width < 380
                                ? 100
                                : 125,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingreso para yonkes',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF092B61),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accede para recibir solicitudes y enviar cotizaciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF596276)),
                      ),
                      const SizedBox(height: 28),
                      Card(
                        elevation: 1,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(
                            MediaQuery.sizeOf(context).width < 380 ? 18 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                key: const Key('yonke-email-field'),
                                controller: _emailController,
                                focusNode: _emailFocus,
                                enabled: !_loading,
                                maxLength: 254,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.none,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico',
                                  hintText: 'yonke@ejemplo.com',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: _validateEmail,
                                onChanged: (_) => setState(() {
                                  _message = null;
                                }),
                                onFieldSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                key: const Key('yonke-password-field'),
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                enabled: !_loading,
                                maxLength: 256,
                                obscureText: !_passwordVisible,
                                keyboardType: TextInputType.visiblePassword,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _passwordVisible
                                        ? 'Ocultar contraseña'
                                        : 'Mostrar contraseña',
                                    onPressed: _loading
                                        ? null
                                        : () => setState(
                                            () => _passwordVisible =
                                                !_passwordVisible,
                                          ),
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: _validatePassword,
                                onChanged: (_) => setState(() {
                                  _message = null;
                                }),
                                onFieldSubmitted: (_) {
                                  if (_canSubmit) _submit();
                                },
                              ),
                              if (_message != null) ...[
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Color(0xFF9B2C24),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(_message!)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              FilledButton(
                                key: const Key('yonke-login-button'),
                                onPressed: _canSubmit ? _submit : null,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  backgroundColor: const Color(0xFF114EB0),
                                ),
                                child: _loading
                                    ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Iniciando sesión...'),
                                        ],
                                      )
                                    : const Text('Iniciar sesión'),
                              ),
                              if (AppConfig.enableMockAuth) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  key: const Key('yonke-demo-login-button'),
                                  onPressed: _enterDemoMode,
                                  icon: const Icon(Icons.science_outlined),
                                  label: const Text(
                                    'Continuar en modo de prueba',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Modo de prueba: no representa una autenticación real.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF596276),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: Color(0xFF596276),
                          ),
                          SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Tus credenciales se envían de forma segura.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF596276)),
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
        ),
      ),
    ),
  );
}
