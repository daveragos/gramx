import 'package:flutter/material.dart';

class DrawerNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const DrawerNavItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: onTap,
    );
  }
}
