enum RequestSubmissionStage { create, requestId, images, dispatch }

class RequestSubmissionResult {
  const RequestSubmissionResult({
    required this.requestId,
    this.notifiedYonkes,
    this.dispatchMessage,
  });

  final String requestId;

  /// Número de yonkes con cobertura a los que el servidor envió la solicitud,
  /// cuando `POST /api/SolicitudYonkes/{id}/enviar` lo informa. `null` si la
  /// respuesta no trae un conteo reconocible.
  final int? notifiedYonkes;

  /// Mensaje del servidor al enviar la solicitud a los yonkes, si lo hubo.
  final String? dispatchMessage;

  bool get reachedNoYonke => notifiedYonkes == 0;
}

class RequestSubmissionException implements Exception {
  const RequestSubmissionException({
    required this.stage,
    this.requestId,
    this.customMessage,
    this.technicalDetail,
  });

  final RequestSubmissionStage stage;

  /// Identificador ya creado en el servidor cuando la falla ocurrió después
  /// de registrar la solicitud. Permite evitar duplicados al reintentar.
  final String? requestId;
  final String? customMessage;

  /// Código HTTP y cuerpo devueltos por el servidor, para diagnóstico.
  final String? technicalDetail;

  /// Descripción del paso que falló, independiente del mensaje del servidor.
  String get stageLabel => switch (stage) {
    RequestSubmissionStage.create => 'Crear la solicitud',
    RequestSubmissionStage.requestId => 'Leer el identificador de la solicitud',
    RequestSubmissionStage.images => 'Adjuntar las fotografías',
    RequestSubmissionStage.dispatch => 'Enviar a los yonkes con cobertura',
  };

  String get message =>
      customMessage ??
      switch (stage) {
        RequestSubmissionStage.create =>
          'No se pudo crear la solicitud. Inténtalo nuevamente.',
        RequestSubmissionStage.requestId => 'La API aceptó la solicitud, pero no devolvió su identificador. Por seguridad no se adjuntaron fotos ni se envió a los yonkes.',
        RequestSubmissionStage.images => 'La solicitud fue creada, pero no se pudieron adjuntar todas las fotografías. No se envió a los yonkes para evitar información incompleta.',
        RequestSubmissionStage.dispatch => 'La solicitud fue creada, pero no se pudo enviar a los yonkes de cobertura.',
      };

  @override
  String toString() => 'RequestSubmissionException(${stage.name}): $message';
}
