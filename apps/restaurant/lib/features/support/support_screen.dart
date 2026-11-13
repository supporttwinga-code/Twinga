import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

const String kSupportEmail = 'support.twinga@gmail.com';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, color: TwingaColors.blue, size: 30),
                      SizedBox(width: 10),
                      Text(
                        'Need help?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: TwingaColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Email the Twinga support team and we will get back to you.',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EEFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SelectableText(
                      kSupportEmail,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: TwingaColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: kSupportEmail),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support email copied')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy email address'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tip: write your registered email and the order number (for example #AB12C) in your message so we can help faster.',
          ),
        ],
      ),
    );
  }
}
