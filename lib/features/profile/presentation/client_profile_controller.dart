import 'package:flutter/foundation.dart';

import '../../../core/storage/token_store.dart';
import '../data/client_profile_repository.dart';
import '../domain/client_profile.dart';

class ClientProfileController extends ChangeNotifier {
  ClientProfileController(this._repository, this._tokenStore);

  final ClientProfileRepository _repository;
  final TokenStore _tokenStore;

  ClientProfileSnapshot? snapshot;
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
      // No existe endpoint confirmado de revocación. El cierre local siempre
      // elimina las credenciales seguras del dispositivo.
      await _tokenStore.clear();
    } finally {
      signingOut = false;
      notifyListeners();
    }
  }
}
