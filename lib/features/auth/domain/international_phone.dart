import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class PhoneCountry {
  const PhoneCountry({
    required this.isoCode,
    required this.dialCode,
    required this.flag,
    required this.name,
    required this.example,
  });

  const PhoneCountry.mexico()
    : isoCode = 'MX',
      dialCode = '52',
      flag = '🇲🇽',
      name = 'México',
      example = '55 1234 5678';

  final String isoCode;
  final String dialCode;
  final String flag;
  final String name;
  final String example;
}

class PhoneValidationResult {
  const PhoneValidationResult.valid(this.e164) : error = null;

  const PhoneValidationResult.invalid(this.error) : e164 = null;

  final String? e164;
  final String? error;

  bool get isValid => e164 != null;
}

class InternationalPhoneValidator {
  const InternationalPhoneValidator();

  PhoneValidationResult validate(String nationalNumber, PhoneCountry country) {
    final digits = nationalNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const PhoneValidationResult.invalid(
        'Ingresa tu número de celular.',
      );
    }

    try {
      final phone = PhoneNumber.parse(
        digits,
        destinationCountry: IsoCode.fromJson(country.isoCode),
      );
      if (!phone.isValidLength()) {
        return PhoneValidationResult.invalid(
          'La cantidad de dígitos no corresponde a ${country.name}.',
        );
      }
      if (!phone.isValid()) {
        return PhoneValidationResult.invalid(
          'Ingresa un número válido de ${country.name}.',
        );
      }
      return PhoneValidationResult.valid(phone.international);
    } on Object {
      return PhoneValidationResult.invalid(
        'Ingresa un número válido de ${country.name}.',
      );
    }
  }
}
