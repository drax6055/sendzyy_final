import 'package:flutter/material.dart';
import 'package:sendzyy/core/theme/app_theme.dart';

class MessageValidityPeriodWidget extends StatefulWidget {
  final bool enabled;
  final int selectedSeconds;
  final bool defaultOn;
  final ValueChanged<int> onChanged; // 0 = toggle off

  const MessageValidityPeriodWidget({
    super.key,
    required this.enabled,
    required this.selectedSeconds,
    required this.defaultOn,
    required this.onChanged,
  });

  @override
  State<MessageValidityPeriodWidget> createState() =>
      _MessageValidityPeriodWidgetState();
}

class _MessageValidityPeriodWidgetState
    extends State<MessageValidityPeriodWidget> {
  static const _defaultSeconds = 600;

  static const _options = [
    _ValidityOption(label: '30 seconds', seconds: 30),
    _ValidityOption(label: '1 minute', seconds: 60),
    _ValidityOption(label: '2 minutes', seconds: 120),
    _ValidityOption(label: '5 minutes', seconds: 300),
    _ValidityOption(label: '10 minutes', seconds: 600),
    _ValidityOption(label: '15 minutes', seconds: 900),
    _ValidityOption(label: '30 minutes', seconds: 1800),
    _ValidityOption(label: '1 hour', seconds: 3600),
    _ValidityOption(label: '3 hours', seconds: 10800),
    _ValidityOption(label: '6 hours', seconds: 21600),
    _ValidityOption(label: '12 hours', seconds: 43200),
    _ValidityOption(label: '24 hours', seconds: 86400),
  ];

  late bool _toggleOn;
  late int _selectedSeconds;

  @override
  void initState() {
    super.initState();
    _toggleOn = widget.defaultOn;
    _selectedSeconds =
        widget.selectedSeconds != 0 ? widget.selectedSeconds : _defaultSeconds;
  }

  void _onToggleChanged(bool value) {
    setState(() {
      _toggleOn = value;
    });
    if (!value) {
      widget.onChanged(0);
    } else {
      widget.onChanged(_selectedSeconds);
    }
  }

  void _onDropdownChanged(int? seconds) {
    if (seconds == null) return;
    setState(() {
      _selectedSeconds = seconds;
    });
    widget.onChanged(seconds);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _toggleOn
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _toggleOn ? AppTheme.primaryColor : Colors.grey.shade200,
          width: _toggleOn ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 22,
                color:
                    _toggleOn ? AppTheme.primaryColor : Colors.grey.shade500,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Set custom validity period for your message',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _toggleOn
                        ? AppTheme.secondaryColor
                        : Colors.black87,
                  ),
                ),
              ),
              Switch(
                value: _toggleOn,
                onChanged: _onToggleChanged,
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          if (_toggleOn) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedSeconds,
              decoration: InputDecoration(
                labelText: 'Validity period',
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
              ),
              items: _options
                  .map(
                    (opt) => DropdownMenuItem<int>(
                      value: opt.seconds,
                      child: Text(
                        opt.label,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _onDropdownChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _ValidityOption {
  final String label;
  final int seconds;

  const _ValidityOption({required this.label, required this.seconds});
}

