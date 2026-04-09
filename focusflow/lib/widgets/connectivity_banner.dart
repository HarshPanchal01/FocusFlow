import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

/// A slim banner that appears at the top of the screen to show
/// connectivity status. Sits below the app bar.
///
/// States:
///   - Online (normal): hidden, no banner
///   - Offline: amber bar — "You're offline — changes saved locally"
///   - Syncing: blue bar — "Back online — syncing..."
///   - Just reconnected: green bar — "Back online — all synced" (auto-dismisses)
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        // Normal online state — show nothing
        if (connectivity.isOnline && !connectivity.justReconnected) {
          return const SizedBox.shrink();
        }

        // Determine banner content
        final Color bgColor;
        final IconData icon;
        final String message;

        if (!connectivity.isOnline) {
          // Offline
          bgColor = Colors.orange.shade700;
          icon = Icons.cloud_off;
          message = "You're offline — changes saved locally";
        } else if (connectivity.isSyncing) {
          // Back online, actively syncing
          bgColor = Colors.blue.shade600;
          icon = Icons.sync;
          message = 'Back online — syncing...';
        } else {
          // Just reconnected, sync complete
          bgColor = Colors.green.shade600;
          icon = Icons.cloud_done;
          message = 'Back online — all synced';
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: bgColor,
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
