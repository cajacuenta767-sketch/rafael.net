import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../domain/request_draft.dart';

class RequestPhotosPage extends StatefulWidget {
  const RequestPhotosPage({super.key, required this.draft});

  final RequestDraft draft;

  @override
  State<RequestPhotosPage> createState() => _RequestPhotosPageState();
}

class _RequestPhotosPageState extends State<RequestPhotosPage> {
  static const _maxPhotos = 5;
  static const _maxPhotoBytes = 10 * 1024 * 1024;
  final _picker = ImagePicker();
  bool _picking = false;

  Future<void> _chooseSource() async {
    if (_picking || widget.draft.photos.length >= _maxPhotos) {
      _showMessage('Puedes agregar hasta $_maxPhotos fotografías.');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;

      final extension = file.name.split('.').last.toLowerCase();
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        _showMessage('Selecciona una imagen JPG, PNG o WEBP.');
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        _showMessage('Cada fotografía debe pesar menos de 10 MB.');
        return;
      }
      if (!mounted) {
        return;
      }
      setState(
        () => widget.draft.photos.add(RequestPhoto(file: file, bytes: bytes)),
      );
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo agregar la fotografía. Inténtalo nuevamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.draft.photos;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('Fotografías'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Agrega fotos claras de la pieza',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount:
                          photos.length + (photos.length < _maxPhotos ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == photos.length) {
                          return _AddPhotoTile(
                            isLoading: _picking,
                            onTap: _chooseSource,
                          );
                        }
                        final photo = photos[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                photo.bytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Semantics(
                                button: true,
                                label: 'Quitar fotografía ${index + 1}',
                                child: IconButton.filled(
                                  onPressed: () =>
                                      setState(() => photos.removeAt(index)),
                                  icon: const Icon(Icons.close, size: 18),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xDD202124),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Las fotos se guardan solo durante esta solicitud y se subirán al confirmar el envío.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF596276)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _picking
                        ? null
                        : () => context.push(
                            AppRoutes.clientRequestCity,
                            extra: widget.draft,
                          ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xFF14951F),
                    ),
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Agregar fotografía',
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9DEE5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: isLoading
                ? const CircularProgressIndicator()
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 34),
                      SizedBox(height: 8),
                      Text('Agregar foto'),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
