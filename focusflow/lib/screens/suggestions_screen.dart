import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Example static data for suggestions, TODO: Replace with dynamic data from provider once implemented
    final suggestions = [
      {
        'type': 'Heavy Task',
        'title': 'Task name',
        'time': '2 hrs · Today 10:00 AM - 12:00 PM',
        'description': 'Description',
      },
      {
        'type': 'Light Task',
        'title': 'Task name',
        'time': '1 hrs · Today 2:00 PM - 3:00 PM',
        'description': 'Description',
      },
      {
        'type': 'Collaboration',
        'title': 'Task name',
        'time': '2 hrs · Today 4:00 PM - 5:00 PM',
        'description': 'Description',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        toolbarHeight: 0, // Hide the AppBar content
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: ListView.separated(
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.divider.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      suggestion['type']!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    suggestion['title']!,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion['time']!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    suggestion['description']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {},
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: AppColors.secondary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {},
                          child: const Text('Override'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
