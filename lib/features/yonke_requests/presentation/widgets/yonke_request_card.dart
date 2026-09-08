import 'package:flutter/material.dart';

import '../../../../app/theme/yonke_theme.dart';
import '../../../../app/widgets/refanet_image.dart';
import '../../domain/yonke_request_summary.dart';

/// Tarjeta reutilizable de solicitud asignada a un yonke.
///
/// La API actual solo informa el número de fotos en la bandeja; por eso se
/// representa una autoparte sin inventar una fotografía remota.
class YonkeRequestCard extends StatelessWidget {
  const YonkeRequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.thumbnailOnLeft = true,
  });

  final YonkeRequestSummary request;
  final VoidCallback onTap;
  final bool thumbnailOnLeft;

  @override
  Widget build(BuildContext context) {
    final thumbnail = _PartThumbnail(
      photoCount: request.photoCount,
      imageUrl: request.imageUrl,
    );
    final content = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusTag(status: request.status),
          const SizedBox(height: 7),
          Text(
            request.part,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: YonkeColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          if (request.vehicle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              request.vehicle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: YonkeColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              if (request.city != null)
                _Meta(icon: Icons.location_on_outlined, text: request.city!),
              _Meta(
                icon: Icons.schedule_outlined,
                text: _when(request.receivedAt),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: '${request.status.label}: ${request.part}',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: YonkeColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: thumbnailOnLeft
                  ? [
                      thumbnail,
                      const SizedBox(width: 12),
                      content,
                      const Icon(Icons.chevron_right),
                    ]
                  : [
                      content,
                      const SizedBox(width: 12),
                      thumbnail,
                      const Icon(Icons.chevron_right),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PartThumbnail extends StatelessWidget {
  const _PartThumbnail({required this.photoCount, this.imageUrl});
  final int photoCount;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: 62,
    height: 62,
    decoration: BoxDecoration(
      color: const Color(0xFFF0F6ED),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        RefanetImage(
          source: imageUrl,
          fit: BoxFit.cover,
          fallback: const Icon(
            Icons.settings_input_component_outlined,
            color: YonkeColors.primaryNavy,
            size: 33,
          ),
        ),
        if (photoCount > 0)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: YonkeColors.accentGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$photoCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});
  final YonkeRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      YonkeRequestStatus.newRequest => YonkeColors.accentGreen,
      YonkeRequestStatus.viewed => const Color(0xFF3F6EAE),
      YonkeRequestStatus.quoted => YonkeColors.primaryNavy,
      YonkeRequestStatus.unavailable ||
      YonkeRequestStatus.closed => YonkeColors.textSecondary,
      YonkeRequestStatus.unknown => YonkeColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: YonkeColors.textSecondary),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: YonkeColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    ],
  );
}

String _when(DateTime value) {
  final now = DateTime.now();
  if (now.year == value.year &&
      now.month == value.month &&
      now.day == value.day) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return 'Hoy, $hour:$minute';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
