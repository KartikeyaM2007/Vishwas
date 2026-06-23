// lib/features/issues/models/category.dart
import 'package:flutter/material.dart';

class IssueCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const IssueCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class IssueCategories {
  static const road = IssueCategory(
    id: 'road',
    name: 'Road & Potholes',
    icon: Icons.route_rounded,
    color: Color(0xFFF44336),
  );

  static const water = IssueCategory(
    id: 'water',
    name: 'Water & Drainage',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF2196F3),
  );

  static const electricity = IssueCategory(
    id: 'electricity',
    name: 'Streetlights',
    icon: Icons.bolt_rounded,
    color: Color(0xFFFFC107),
  );

  static const garbage = IssueCategory(
    id: 'garbage',
    name: 'Garbage & Waste',
    icon: Icons.delete_rounded,
    color: Color(0xFF4CAF50),
  );

  static const park = IssueCategory(
    id: 'park',
    name: 'Parks & Trees',
    icon: Icons.park_rounded,
    color: Color(0xFF8BC34A),
  );

  static const noise = IssueCategory(
    id: 'noise',
    name: 'Noise Complaint',
    icon: Icons.volume_up_rounded,
    color: Color(0xFFFF5722),
  );

  static const other = IssueCategory(
    id: 'other',
    name: 'Other',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF9C27B0),
  );

  static List<IssueCategory> get all => [
        road,
        water,
        electricity,
        garbage,
        park,
        noise,
        other,
      ];

  static IssueCategory byId(String id) {
    return all.firstWhere(
      (c) => c.id == id,
      orElse: () => other,
    );
  }
}
