import 'package:flutter/material.dart';

abstract interface class AdaptiveNavigation {
  Widget buildSideNavigation(BuildContext context);
}

class SideNavigation extends StatelessWidget {
  const SideNavigation({
    super.key,
    required this.background,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelect,
  });
  final Color background;
  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    child: SafeArea(
      child: SizedBox(
        width: 220,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 24),
              child: Text(
                'REFANET',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (var index = 0; index < labels.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  selected: selectedIndex == index,
                  selectedTileColor: Colors.white.withValues(alpha: .14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    icons[index],
                    color: selectedIndex == index
                        ? const Color(0xFF80D33C)
                        : Colors.white,
                  ),
                  title: Text(
                    labels[index],
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () => onSelect(index),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
