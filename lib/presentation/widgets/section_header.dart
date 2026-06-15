import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(children: [
        Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.textLo,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                fontSize: 11.5)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
