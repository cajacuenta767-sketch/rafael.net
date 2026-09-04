enum RequestSubmissionStage { create, requestId, images, dispatch }

class RequestSubmissionResult {
  const RequestSubmissionResult({
    required this.requestId,
    required this.isDemo,
  });

  final String requestId;
  final bool isDemo;
}

class RequestSubmissionException implements Exception {
  const RequestSubmissionException({required this.stage, this.requestId});

  final RequestSubmissionStage stage;
  final String? requestId;

  String get message => switch (stage) {
    RequestSubmissionStage.create =>
      'No se pudo crear la solicitud. Inténtalo nuevamente.',
    RequestSubmissionStage.requestId => 'La API aceptó la solicitud, pero no devolvió su identificador. Por seguridad no se adjuntaron fotos ni se envió a los yonkes.',
    RequestSubmissionStage.images => 'La solicitud fue creada, pero no se pudieron adjuntar todas las fotografías. No se envió a los yonkes para evitar información incompleta.',
    RequestSubmissionStage.dispatch => 'La solicitud fue creada, pero no se pudo enviar a los yonkes de cobertura.',
  };
}
