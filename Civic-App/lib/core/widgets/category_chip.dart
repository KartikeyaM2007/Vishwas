// lib/core/widgets/category_chip.dart
import 'package:flutter/material.dart';
import '../../features/issues/models/category.dart';

class CategoryChip extends StatelessWidget {
  final IssueCategory category;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${category.name} filter${selected ? ', selected' : ''}',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: FilterChip(
          avatar: Icon(
            category.icon,
            size: 16,
            color: selected ? Colors.white : color,
          ),
          label: Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : scheme.onSurface,
            ),
          ),
          selected: selected,
          onSelected: (_) => onTap(),
          backgroundColor: scheme.surface,
          selectedColor: color,
          checkmarkColor: Colors.white,
          showCheckmark: false,
          side: BorderSide(
            color: selected ? color : scheme.outlineVariant.withOpacity(0.5),
            width: selected ? 0 : 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
      ),
    );
  }
}

class CategoryGridTile extends StatelessWidget {
  final IssueCategory category;
  final bool selected;
  final VoidCallback onTap;

  const CategoryGridTile({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${category.name}${selected ? ', selected' : ''}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant.withOpacity(0.3),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category.icon,
                  color: selected ? Colors.white : color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
