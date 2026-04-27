import 'package:flutter/widgets.dart';

class MenuItem {
  final String key;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MenuItem({
    required this.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
  });
}

class MenuSection {
  final String? title;
  final List<MenuItem> items;

  const MenuSection({
    this.title,
    required this.items,
  });
}
