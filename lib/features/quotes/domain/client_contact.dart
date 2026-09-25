import '../../yonke_messages/domain/quote_client.dart';

/// Datos de contacto del cliente que viajan en el chat.
///
/// El API no entrega al yonke el nombre, el teléfono ni la foto del cliente,
/// y el perfil del cliente solo vive en su teléfono. Para que el yonke los
/// vea en cuanto el cliente le escribe, la app del cliente agrega una última
/// línea al mensaje:
///
/// ```
/// Hola, ¿sigue disponible?
///
/// Contacto: Carlos Mendoza | +525512345678 | https://.../foto.jpg
/// ```
///
/// Ambas apps quitan esa línea del texto que muestran. Se deja legible para
/// que el aviso push y las versiones anteriores de la app sigan teniendo
/// sentido para el yonke.
const clientContactPrefix = 'Contacto: ';

class ContactSplit {
  const ContactSplit(this.text, this.contact);

  final String text;
  final QuoteClient? contact;
}

/// Separa la línea de contacto del texto del mensaje.
ContactSplit splitClientContact(String message) {
  final trimmed = message.trimRight();
  final lineStart = trimmed.lastIndexOf('\n') + 1;
  final line = trimmed.substring(lineStart);
  if (!line.startsWith(clientContactPrefix)) return ContactSplit(message, null);
  final parts = line
      .substring(clientContactPrefix.length)
      .split('|')
      .map((part) => part.trim());
  String? name;
  String? phone;
  String? photoUrl;
  for (final part in parts) {
    if (part.isEmpty) continue;
    if (part.startsWith('https://')) {
      photoUrl ??= _safeImage(part);
    } else if (RegExp(r'^\+[\d ]{10,20}$').hasMatch(part)) {
      phone ??= part;
    } else {
      name ??= part;
    }
  }
  // Sin teléfono no se trata como contacto: el cliente pudo escribir
  // "Contacto: ..." en su mensaje.
  if (phone == null) return ContactSplit(message, null);
  final contact = QuoteClient(name: name, phone: phone, photoUrl: photoUrl);
  final text = trimmed.substring(0, lineStart).trimRight();
  return ContactSplit(text.isEmpty ? message : text, contact);
}

/// Contacto del cliente a partir de su perfil, o `null` si no tiene un
/// teléfono válido que compartir.
QuoteClient? clientContactFromProfile({
  String? name,
  String? phone,
  String? photoUrl,
}) {
  final cleanName = name?.replaceAll(RegExp(r'[|\s]+'), ' ').trim();
  final contact = QuoteClient(
    name: cleanName == null || cleanName.isEmpty ? null : cleanName,
    phone: _internationalPhone(phone),
    photoUrl: _safeImage(photoUrl),
  );
  return contact.phone == null ? null : contact;
}

/// Agrega la línea de contacto al mensaje.
String signWithClientContact(String message, QuoteClient contact) {
  final parts = [
    contact.name,
    contact.phone,
    contact.photoUrl,
  ].whereType<String>().join(' | ');
  return '$message\n\n$clientContactPrefix$parts';
}

bool sameClientContact(QuoteClient? a, QuoteClient? b) =>
    a?.name == b?.name && a?.phone == b?.phone && a?.photoUrl == b?.photoUrl;

String? _internationalPhone(String? raw) {
  final value = raw?.trim() ?? '';
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (value.startsWith('+')) {
    return digits.length >= 10 && digits.length <= 15 ? '+$digits' : null;
  }
  // Los teléfonos capturados sin lada internacional son de México.
  return digits.length == 10 ? '+52$digits' : null;
}

String? _safeImage(String? url) {
  final uri = Uri.tryParse(url ?? '');
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          !url!.contains(' ')
      ? url
      : null;
}
