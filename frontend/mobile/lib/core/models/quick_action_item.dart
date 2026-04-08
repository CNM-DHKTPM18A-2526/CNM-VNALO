import 'package:flutter/material.dart';

class QuickActionItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const QuickActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
