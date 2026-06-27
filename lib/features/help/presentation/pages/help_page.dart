import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _faqs = [
    {
      'q': 'What is Sendzyy?',
      'a':
          'iFloraBuzz is a WhatsApp Business messaging platform that lets you send bulk messages, manage client conversations, and use pre-approved templates — all from one dashboard.',
    },
    {
      'q': 'How do I send a bulk message?',
      'a':
          'Go to "Bulk Send" from the sidebar, select a template, choose your clients, and hit Send. Make sure you have enough credits before sending.',
    },
    {
      'q': 'What are credits and how are they used?',
      'a':
          'Credits are consumed each time you send a WhatsApp message. The cost depends on the message type (template vs. session). You can buy more credits from the "Buy Credits" section.',
    },
    {
      'q': 'Why can\'t I send a free-text message to a client?',
      'a':
          'WhatsApp only allows free-text replies within a 24-hour conversation window. Once that window expires, you must use an approved template to re-engage the client.',
    },
    {
      'q': 'How do I create or manage templates?',
      'a':
          'Navigate to "Templates" in the sidebar. You can view existing approved templates there. New templates must be submitted through your WhatsApp Business API provider for approval.',
    },
    {
      'q': 'How do I add a new client?',
      'a':
          'Go to "Clients" and click "Add Client". Enter the client\'s name and mobile number (with country code, e.g. 919876543210).',
    },
    {
      'q': 'What does the green/grey dot next to a conversation mean?',
      'a':
          'A green dot means the 24-hour conversation window is still open and you can send free-text messages. A grey dot means the window has expired and only templates can be sent.',
    },
    {
      'q': 'How do I update my API configuration?',
      'a':
          'Click the settings (gear) icon in the top header bar to open the API Configuration dialog and update your credentials.',
    },
    {
      'q': 'My messages are not being delivered. What should I check?',
      'a':
          'Verify your API key and WhatsApp Business number in API Configuration. Also ensure you have sufficient credits and that the recipient\'s number is valid with the correct country code.',
    },
    {
      'q': 'How do I view usage reports?',
      'a':
          'Go to "Reports" in the sidebar to see a breakdown of messages sent, delivered, and failed over time.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: AppTheme.secondaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help & Q/A',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                  ),
                  Text(
                    'Frequently asked questions & support',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // FAQ Section
          Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
          ),
          const SizedBox(height: 16),
          ...(_faqs.map((faq) => _FaqTile(q: faq['q']!, a: faq['a']!))),

          const SizedBox(height: 40),

          // Contact Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Still need help? Contact Us',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _ContactRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: 'iflorainfopvtltd@gmail.com',
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: '+91 90997 05065',
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.language_outlined,
                  label: 'Website',
                  value: 'www.iflorainfo.com',
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.access_time_outlined,
                  label: 'Support Hours',
                  value: 'Mon – Sat, 9:00 AM – 6:00 PM IST',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String q;
  final String a;

  const _FaqTile({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'Q',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        title: Text(
          q,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.secondaryColor,
          ),
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
