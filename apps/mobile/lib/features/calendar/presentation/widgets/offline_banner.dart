import 'package:flutter/material.dart';
import 'package:mobile/shared/theme/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Offline — showing last loaded schedule',
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFFF8E1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You're offline — showing your last loaded schedule",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
