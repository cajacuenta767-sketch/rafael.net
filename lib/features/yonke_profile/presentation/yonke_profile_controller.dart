import 'package:flutter/foundation.dart';

import '../../../core/storage/token_store.dart';
import '../data/yonke_profile_repository.dart';
import '../domain/yonke_profile.dart';

class YonkeProfileController extends ChangeNotifier {
  YonkeProfileController(this._repository, this._tokenStore);

  final YonkeProfileRepository _repository;
  final TokenStore _tokenStore;

  YonkeProfileSnapshot? snapshot;
  Object? error;
  bool loading = true;
  bool signingOut = false;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await _repository.load();
    } catch (value) {
      error = value;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (signingOut) return;
    signingOut = true;
    notifyListeners();
    try {
      // La API no documenta revocación de token; se eliminan las credenciales
      // locales que sí están bajo control de la aplicación.
      await _tokenStore.clear();
    } finally {
      signingOut = false;
      notifyListeners();
    }
  }
}
