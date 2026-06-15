import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bordered status row used on the home page for account / profile / java.
///
/// Tapping it always does something — either jumps to the right page or
/// shows a snack. We pass a `trailing` cue (chevron / check) so the user
/// can see at a glance whether this row needs attention.
class StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;
  final VoidCallback onTap;
  final Color? iconColor;

  const StatusTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgPanel,
            border: Border.all(
                color: ok ? AppTheme.stroke : AppTheme.warn.withOpacity(0.5),
                width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (iconColor ?? AppTheme.accent).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor ?? AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textHi)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppTheme.textMid)),
                  ]),
            ),
            Icon(ok ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: ok ? AppTheme.accent : AppTheme.textLo, size: 22),
          ]),
        ),
      ),
    );
  }
}
