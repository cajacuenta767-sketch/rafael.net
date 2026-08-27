import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_store.dart';
import '../domain/client_auth_repository.dart';
import '../domain/international_phone.dart';

enum ClientLoginStep { phone, verification }

class ClientLoginController extends ChangeNotifier {
  ClientLoginController({
    required ClientAuthRepository repository,
    required TokenStore tokenStore,
    this.phoneValidator = const InternationalPhoneValidator(),
  }) : authRepository = repository,
       sessionStore = tokenStore;

  final ClientAuthRepository authRepository;
  final TokenStore sessionStore;
  final InternationalPhoneValidator phoneValidator;

  ClientLoginStep step = ClientLoginStep.phone;
  PhoneCountry country = const PhoneCountry.mexico();
  String phoneDigits = '';
  String code = '';
  String? phoneError;
  String? codeError;
  String? message;
  bool isLoading = false;
  int resendSeconds = 0;
  Timer? _timer;

  PhoneValidationResult get phoneValidation =>
      phoneValidator.validate(phoneDigits, country);
  String? get normalizedPhone => phoneValidation.e164;
  bool get canRequestCode => phoneValidation.isValid && !isLoading;
  bool get canVerifyCode => code.length == 6 && !isLoading;
  bool get canResend => resendSeconds == 0 && !isLoading;

  void updatePhone(String value) {
    final trimmed = value.trim();
    phoneDigits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (trimmed.startsWith('+${country.dialCode}') &&
        phoneDigits.startsWith(country.dialCode)) {
      phoneDigits = phoneDigits.substring(country.dialCode.length);
    }
    if (phoneDigits.length > 15) {
      phoneDigits = phoneDigits.substring(0, 15);
    }
    phoneError = null;
    message = null;
    notifyListeners();
  }

  void selectCountry(PhoneCountry value) {
    country = value;
    phoneDigits = '';
    phoneError = null;
    message = null;
    notifyListeners();
  }

  void updateCode(String value) {
    code = value.replaceAll(RegExp(r'\D'), '');
    if (code.length > 6) code = code.substring(0, 6);
    codeError = null;
    message = null;
    notifyListeners();
  }

  Future<bool> requestCode() async {
    final validation = phoneValidation;
    if (!validation.isValid) {
      phoneError = validation.error;
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      await authRepository.requestOtp(validation.e164!);
      step = ClientLoginStep.verification;
      code = '';
      message = 'Código enviado. Revisa tus mensajes SMS.';
      _startTimer();
      return true;
    } catch (error) {
      message = _friendlyError(error, requestingCode: true);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendCode() async {
    if (!canResend) return false;

    final phone = normalizedPhone;
    if (phone == null) return false;

    _setLoading(true);
    try {
      await authRepository.requestOtp(phone);
      message = 'Enviamos un nuevo código por SMS.';
      _startTimer();
      return true;
    } catch (error) {
      message = _friendlyError(error, requestingCode: true);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyCode() async {
    if (code.length != 6) {
      codeError = 'Completa los seis dígitos del código.';
      notifyListeners();
      return false;
    }

    final phone = normalizedPhone;
    if (phone == null) {
      codeError = 'El número de celular ya no es válido.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final result = await authRepository.verifyOtp(phone: phone, code: code);
      if (!result.hasUsableSession) {
        message = result.sessionContractPending
            ? 'El servidor recibió el código, pero todavía no publica el contrato de sesión.'
            : 'No fue posible crear una sesión segura.';
        return false;
      }

      await sessionStore.writeTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
      );
      return true;
    } catch (error) {
      codeError = _friendlyError(error, requestingCode: false);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void editPhone() {
    _timer?.cancel();
    resendSeconds = 0;
    code = '';
    codeError = null;
    message = null;
    step = ClientLoginStep.phone;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds <= 1) {
        resendSeconds = 0;
        timer.cancel();
      } else {
        resendSeconds--;
      }
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  String _friendlyError(Object error, {required bool requestingCode}) {
    if (error is ApiException) {
      final status = error.statusCode;
      if (status == 400 || status == 401 || status == 422) {
        return requestingCode
            ? 'Revisa el número e inténtalo nuevamente.'
            : 'El código es incorrecto o ya venció.';
      }
      if (status == 429) {
        return 'Realizaste demasiados intentos. Espera unos minutos.';
      }
      if (status != null && status >= 500) {
        return 'El servicio no está disponible. Inténtalo más tarde.';
      }
      return 'No pudimos conectar con el servicio. Revisa tu conexión.';
    }
    return 'No pudimos conectar con el servicio. Revisa tu conexión.';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
