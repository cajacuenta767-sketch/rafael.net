import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../data/yonke_request_detail_repository.dart';
import '../domain/yonke_request_detail.dart';

class YonkeQuotePageArgs {
  const YonkeQuotePageArgs({required this.detail});

  final YonkeRequestDetail detail;
}

class YonkeQuotePage extends ConsumerStatefulWidget {
  const YonkeQuotePage({
    super.key,
    required this.requestYonkeId,
    required this.detail,
    this.repository,
  });

  final String requestYonkeId;
  final YonkeRequestDetail detail;
  final YonkeRequestDetailRepository? repository;

  @override
  ConsumerState<YonkeQuotePage> createState() => _YonkeQuotePageState();
}

class _YonkeQuotePageState extends ConsumerState<YonkeQuotePage> {
  static const _maxImages = 5;
  static const _maxImageBytes = 10 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _commentsController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _warrantyController = TextEditingController(text: '30');
  final _shippingController = TextEditingController();
  final _picker = ImagePicker();
  final List<YonkeQuoteImage> _images = [];
  late YonkeRequestDetailRepository _repository;
  bool _isNew = false;
  bool _hasWarranty = true;
  bool _shippingAvailable = false;
  bool _picking = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _partNumberController.text = widget.detail.partNumber ?? '';
    _repository =
        widget.repository ??
        (widget.detail.isDemo
            ? const DemoYonkeRequestDetailRepository()
            : ref.read(yonkeRequestDetailRepositoryProvider));
  }

  @override
  void dispose() {
    _priceController.dispose();
    _partNumberController.dispose();
    _commentsController.dispose();
    _deliveryController.dispose();
    _warrantyController.dispose();
    _shippingController.dispose();
    super.dispose();
  }

  Future<void> _chooseImageSource() async {
    if (_picking || _images.length >= _maxImages) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar fotografía'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final extension = file.name.split('.').last.toLowerCase();
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        _message('Selecciona una imagen JPG, PNG o WEBP.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        _message('Cada fotografía debe pesar menos de 10 MB.');
        return;
      }
      if (!mounted) return;
      setState(
        () => _images.add(YonkeQuoteImage(fileName: file.name, bytes: bytes)),
      );
    } catch (_) {
      if (mounted) _message('No se pudo agregar la fotografía.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState;
    if (_submitting || form == null || !form.validate()) return;
    final price = _decimal(_priceController.text);
    if (price == null || price <= 0) return;
    final submission = YonkeQuoteSubmission(
      price: price,
      isNew: _isNew,
      brandId: widget.detail.brandId,
      partNumber: _partNumberController.text,
      comments: _commentsController.text,
      deliveryDays: _integer(_deliveryController.text),
      hasWarranty: _hasWarranty,
      warrantyDays: _hasWarranty ? _integer(_warrantyController.text) ?? 0 : 0,
      shippingAvailable: _shippingAvailable,
      shippingCost: _shippingAvailable
          ? _decimal(_shippingController.text)
          : null,
      images: _images,
    );

    setState(() => _submitting = true);
    try {
      await _repository.submitQuote(widget.requestYonkeId, submission);
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            size: 52,
            color: Color(0xFF14951F),
          ),
          title: Text(
            widget.detail.isDemo
                ? 'Cotización de prueba guardada'
                : 'Cotización enviada',
          ),
          content: Text(
            widget.detail.isDemo
                ? 'Este envío solo valida la interfaz y no llegó al servidor.'
                : 'El cliente ya puede consultar tu precio y condiciones.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              key: const Key('quote-success-button'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) {
        context.go(AppRoutes.yonkeHome, extra: widget.detail.isDemo);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _message('No se pudo enviar la cotización. Inténtalo nuevamente.');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      centerTitle: true,
      title: const Text('Nueva cotización'),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
                  12,
                  MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.detail.isDemo) ...[
                      const _QuoteDemoNotice(),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      widget.detail.part,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (widget.detail.vehicle.isNotEmpty)
                      Text(
                        widget.detail.vehicle,
                        style: const TextStyle(color: Color(0xFF596276)),
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('quote-price-field'),
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio *',
                        prefixText: r'$ ',
                        border: OutlineInputBorder(),
                        helperText: 'Precio total de la pieza en MXN.',
                      ),
                      validator: (value) {
                        final number = _decimal(value ?? '');
                        if (number == null || number <= 0) {
                          return 'Ingresa un precio mayor a cero.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Usada'),
                          icon: Icon(Icons.recycling_outlined),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Nueva'),
                          icon: Icon(Icons.new_releases_outlined),
                        ),
                      ],
                      selected: {_isNew},
                      onSelectionChanged: (value) =>
                          setState(() => _isNew = value.first),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _partNumberController,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Número de parte (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _deliveryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tiempo de entrega en días (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _optionalNonNegativeInteger(
                        value,
                        'Ingresa días completos válidos.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SwitchCard(
                      title: 'Ofrece garantía',
                      value: _hasWarranty,
                      onChanged: (value) =>
                          setState(() => _hasWarranty = value),
                      child: _hasWarranty
                          ? TextFormField(
                              controller: _warrantyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Días de garantía *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (!_hasWarranty) return null;
                                final days = _integer(value ?? '');
                                return days == null || days <= 0
                                    ? 'Ingresa al menos un día de garantía.'
                                    : null;
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _SwitchCard(
                      title: 'Envío disponible',
                      value: _shippingAvailable,
                      onChanged: (value) =>
                          setState(() => _shippingAvailable = value),
                      child: _shippingAvailable
                          ? TextFormField(
                              controller: _shippingController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Costo de envío (opcional)',
                                prefixText: r'$ ',
                                border: OutlineInputBorder(),
                                helperText:
                                    'Déjalo vacío si el envío es gratuito.',
                              ),
                              validator: (value) {
                                if (!_shippingAvailable ||
                                    value == null ||
                                    value.trim().isEmpty) {
                                  return null;
                                }
                                final amount = _decimal(value);
                                return amount == null || amount < 0
                                    ? 'Ingresa un costo válido.'
                                    : null;
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _commentsController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Condiciones y comentarios (opcional)',
                        hintText: 'Ejemplo: pieza probada y en buen estado.',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _QuoteImages(
                      images: _images,
                      picking: _picking,
                      onAdd: _chooseImageSource,
                      onRemove: (index) =>
                          setState(() => _images.removeAt(index)),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('submit-quote-button'),
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: const Color(0xFF14951F),
                      ),
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.detail.isDemo
                                  ? 'Guardar cotización de prueba'
                                  : 'Enviar cotización',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.value,
    required this.onChanged,
    this.child,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFD9DEE5)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
        if (child != null) ...[const SizedBox(height: 10), child!],
      ],
    ),
  );
}

class _QuoteImages extends StatelessWidget {
  const _QuoteImages({
    required this.images,
    required this.picking,
    required this.onAdd,
    required this.onRemove,
  });

  final List<YonkeQuoteImage> images;
  final bool picking;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Fotografías de la pieza (${images.length}/5)',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'Opcionales. No incluyas documentos ni datos personales.',
        style: TextStyle(color: Color(0xFF596276)),
      ),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
        ),
        itemCount: images.length + (images.length < 5 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == images.length) {
            return InkWell(
              onTap: picking ? null : onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD9DEE5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: picking
                      ? const CircularProgressIndicator()
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined),
                            SizedBox(height: 4),
                            Text('Agregar'),
                          ],
                        ),
                ),
              ),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(images[index].bytes, fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filled(
                  tooltip: 'Quitar fotografía',
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.close, size: 17),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xDD202124),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _QuoteDemoNotice extends StatelessWidget {
  const _QuoteDemoNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.science_outlined, color: Color(0xFF8A5A00)),
        SizedBox(width: 10),
        Expanded(
          child: Text('Modo de prueba: esta cotización no llegará al cliente.'),
        ),
      ],
    ),
  );
}

double? _decimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

int? _integer(String value) => int.tryParse(value.trim());

String? _optionalNonNegativeInteger(String? value, String message) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = _integer(value);
  return parsed == null || parsed < 0 ? message : null;
}
