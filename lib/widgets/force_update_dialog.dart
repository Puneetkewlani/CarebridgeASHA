import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String message;
  final bool canDismiss;

  const ForceUpdateDialog({
    super.key,
    required this.message,
    this.canDismiss = false,
  });

  Future<void> _launchAppStore() async {
    // Replace with your actual APK download link or Play Store link
    final Uri url = Uri.parse('https://drive.google.com/uc?export=download&id=1JE2tAW4SIRajM-_n35PgODFDbKmgj5o8');
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canDismiss,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Update Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            if (!canDismiss)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You must update to continue using the app.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          if (canDismiss)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Later'),
            ),
          ElevatedButton.icon(
            onPressed: _launchAppStore,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: Icon(Icons.download),
            label: Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
