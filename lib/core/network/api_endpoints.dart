abstract final class ApiEndpoints {
  // ClienteAuth
  static const clientGoogleLogin = '/api/ClienteAuth/google';
  static const clientAppleLogin = '/api/ClienteAuth/apple';
  static const requestOtp = '/api/ClienteAuth/solicitar-otp';
  static const verifyOtp = '/api/ClienteAuth/verificar-otp';
  static const registerClientDevice = '/api/ClienteAuth/registrar-dispositivo';

  // CotizacionYonke
  static const quotes = '/api/CotizacionYonke';
  static String quote(String quoteId) => '/api/CotizacionYonke/$quoteId';

  // DashboardSuscriptores
  static const dashboardSummary = '/api/DashboardSuscriptores/resumen';
  static const dashboardRequests = '/api/DashboardSuscriptores/mis-solicitudes';
  static const dashboardQuotes = '/api/DashboardSuscriptores/mis-cotizaciones';
  static const dashboardRecentRequest =
      '/api/DashboardSuscriptores/mi-solicitud-reciente';

  // Orden
  static const orders = '/api/Orden';
  static String order(String orderId) => '/api/Orden/$orderId';
  static String orderByQuote(String quoteId) =>
      '/api/Orden/cotizacion/$quoteId';
  static String cancelOrder(String orderId) => '/api/Orden/$orderId/cancelar';

  // Pagos. El webhook y la página de éxito son responsabilidades del servidor.
  static String paymentCheckout(String orderId) =>
      '/api/Pagos/checkout/$orderId';
  static const stripeWebhook = '/api/Pagos/stripe/webhook';
  static const paymentSuccessPage = '/pago/exitoso';
  static String paymentResult(String sessionId) =>
      '/api/Pagos/resultado/$sessionId';

  // SolicitudCiudades
  static String requestCity(String requestId, int cityId) =>
      '/api/SolicitudCiudades/$requestId/ciudad/$cityId';
  static String requestCities(String requestId) =>
      '/api/SolicitudCiudades/$requestId/ciudades';
  static const requestCityExists = '/api/SolicitudCiudades/existe';

  // SolicitudCotizacionMensajes
  static const quoteMessages = '/api/SolicitudCotizacionMensajes';
  static String quoteConversation(String quoteId) =>
      '/api/SolicitudCotizacionMensajes/$quoteId';
  static String markQuoteMessagesRead(String quoteId) =>
      '/api/SolicitudCotizacionMensajes/$quoteId/leer';
  static String unreadQuoteMessages(String quoteId) =>
      '/api/SolicitudCotizacionMensajes/$quoteId/no-leidos';

  // Solicitudes
  static const requests = '/api/Solicitudes';
  static const pagedRequests = '/api/Solicitudes/AllPaged';
  static String request(String requestId) => '/api/Solicitudes/$requestId';

  // SolicitudesImagenes
  static String addRequestImage(String requestId) =>
      '/api/SolicitudesImagenes/$requestId';
  static String requestImages(String requestId) =>
      '/api/SolicitudesImagenes/solicitud/$requestId';
  static String requestImage(String imageId) =>
      '/api/SolicitudesImagenes/$imageId';

  // SolicitudYonkes
  static String sendRequestToYonkes(String requestId) =>
      '/api/SolicitudYonkes/$requestId/enviar';
  static String markYonkeRequestViewed(String requestYonkeId) =>
      '/api/SolicitudYonkes/$requestYonkeId/vista';

  // Utilerias
  static const states = '/api/Utilerias/entidades';
  static String state(int id) => '/api/Utilerias/entidad/$id';
  static String citiesByState(int stateId) =>
      '/api/Utilerias/entidad/$stateId/ciudades';
  static String city(int id) => '/api/Utilerias/ciudad/$id';
  static const brands = '/api/Utilerias/marcas';
  static const brandCreate = '/api/Utilerias/marca';
  static String brand(int id) => '/api/Utilerias/marca/$id';
  static const models = '/api/Utilerias/modelos';
  static const modelCreate = '/api/Utilerias/modelo';
  static String model(int id) => '/api/Utilerias/modelo/$id';

  // YonkeAuth y Yonkes
  static const yonkeLogin = '/api/YonkeAuth/login';
  static const yonkes = '/api/Yonkes';
  static const pagedYonkes = '/api/Yonkes/byPage';
  static String yonke(String yonkeId) => '/api/Yonkes/$yonkeId';
  static String updateYonke(String yonkeId) =>
      '/api/Yonkes/updateInfo/byGuidId/$yonkeId';
  static const updateYonkeLogo = '/api/Yonkes/ActualizarLogo';
  static String deactivateYonke(String yonkeId) =>
      '/api/Yonkes/baja/byGuidId/$yonkeId';

  // Calificaciones, coberturas y dispositivos
  static const ratings = '/api/YonkesCalificaciones';
  static String yonkeRatings(String yonkeId) =>
      '/api/YonkesCalificaciones/$yonkeId';
  static const coverage = '/api/YonkesCoberturas';
  static String yonkeCoverage(String yonkeId) =>
      '/api/YonkesCoberturas/guid/$yonkeId';
  static const yonkeDevices = '/api/YonkesDispositivos';
}
