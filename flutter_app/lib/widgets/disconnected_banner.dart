import 'package:flutter/material.dart';
import '../i18n.dart';

class DisconnectedBanner extends StatelessWidget {
  final String serial;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;

  const DisconnectedBanner({
    super.key,
    required this.serial,
    required this.onRefresh,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade100,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          border: Border(
            bottom: BorderSide(
              color: Colors.orange.shade300,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.usb_off,
              size: 16,
              color: Colors.orange.shade800,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                  ),
                  children: [
                    TextSpan(text: tr('deviceDisconnected')),
                    TextSpan(
                      text: ' $serial',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontFamily: 'Menlo',
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(text: ' · '),
                    TextSpan(
                      text: tr('waitingReconnect'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(tr('retry'), style: const TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                tr('giveUp'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
