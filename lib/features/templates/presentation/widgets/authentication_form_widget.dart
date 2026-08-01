import 'package:flutter/material.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/features/templates/data/models/app_entry.dart';
import 'package:sendzyy/features/templates/data/models/auth_form_state.dart';
import 'package:sendzyy/features/templates/presentation/widgets/message_validity_period_widget.dart';

// ---------------------------------------------------------------------------
// CodeDeliverySetupWidget
// ---------------------------------------------------------------------------

class CodeDeliverySetupWidget extends StatelessWidget {
  final String selectedType; // 'ZERO_TAP' | 'ONE_TAP' | 'COPY_CODE'
  final bool tosAccepted;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<bool> onTosChanged;

  const CodeDeliverySetupWidget({
    super.key,
    required this.selectedType,
    required this.tosAccepted,
    required this.onTypeChanged,
    required this.onTosChanged,
  });

  static const _options = [
    _DeliveryOption(
      value: 'ZERO_TAP',
      label: 'Zero-tap auto-fill (Recommended)',
    ),
    _DeliveryOption(
      value: 'ONE_TAP',
      label: 'One-tap auto-fill',
    ),
    _DeliveryOption(
      value: 'COPY_CODE',
      label: 'Copy code',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._options.map((option) => _DeliveryOptionCard(
              option: option,
              isSelected: selectedType == option.value,
              groupValue: selectedType,
              onTap: () => onTypeChanged(option.value),
            )),
        if (selectedType == 'ZERO_TAP') ...[
          const SizedBox(height: 4),
          _TosCheckbox(
            accepted: tosAccepted,
            onChanged: onTosChanged,
          ),
        ],
      ],
    );
  }
}

class _DeliveryOption {
  final String value;
  final String label;

  const _DeliveryOption({required this.value, required this.label});
}

class _DeliveryOptionCard extends StatelessWidget {
  final _DeliveryOption option;
  final bool isSelected;
  final String groupValue;
  final VoidCallback onTap;

  const _DeliveryOptionCard({
    required this.option,
    required this.isSelected,
    required this.groupValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color:
                      isSelected ? AppTheme.secondaryColor : Colors.black87,
                ),
              ),
            ),
            Radio<String>(
              value: option.value,
              groupValue: groupValue,
              onChanged: (_) => onTap(),
              activeColor: AppTheme.primaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _TosCheckbox extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const _TosCheckbox({required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: accepted,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppTheme.primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!accepted),
              child: Text(
                'I agree to the WhatsApp Business Terms of Service for zero-tap messages',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppSetupWidget
// ---------------------------------------------------------------------------

class AppSetupWidget extends StatefulWidget {
  final List<AppEntry> entries;
  final ValueChanged<List<AppEntry>> onChanged;

  const AppSetupWidget({
    super.key,
    required this.entries,
    required this.onChanged,
  });

  @override
  State<AppSetupWidget> createState() => _AppSetupWidgetState();
}

class _AppSetupWidgetState extends State<AppSetupWidget> {
  late List<TextEditingController> _packageControllers;
  late List<TextEditingController> _hashControllers;

  @override
  void initState() {
    super.initState();
    _buildControllers(widget.entries);
  }

  @override
  void didUpdateWidget(AppSetupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      _disposeControllers();
      _buildControllers(widget.entries);
    }
  }

  void _buildControllers(List<AppEntry> entries) {
    _packageControllers = entries
        .map((e) => TextEditingController(text: e.packageName))
        .toList();
    _hashControllers = entries
        .map((e) => TextEditingController(text: e.signatureHash))
        .toList();
  }

  void _disposeControllers() {
    for (final c in _packageControllers) {
      c.dispose();
    }
    for (final c in _hashControllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _notify() {
    final updated = List.generate(
      _packageControllers.length,
      (i) => AppEntry(
        packageName: _packageControllers[i].text,
        signatureHash: _hashControllers[i].text,
      ),
    );
    widget.onChanged(updated);
  }

  void _addEntry() {
    if (_packageControllers.length >= 5) return;
    setState(() {
      _packageControllers.add(TextEditingController());
      _hashControllers.add(TextEditingController());
    });
    _notify();
  }

  void _removeEntry(int index) {
    if (_packageControllers.length <= 1) return;
    setState(() {
      _packageControllers[index].dispose();
      _hashControllers[index].dispose();
      _packageControllers.removeAt(index);
      _hashControllers.removeAt(index);
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final count = _packageControllers.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < count; i++) _AppEntryRow(
          index: i,
          packageController: _packageControllers[i],
          hashController: _hashControllers[i],
          canRemove: count > 1,
          onRemove: () => _removeEntry(i),
          onChanged: _notify,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: count < 5 ? _addEntry : null,
          icon: const Icon(Icons.add),
          label: const Text('Add another app'),
        ),
      ],
    );
  }
}

class _AppEntryRow extends StatefulWidget {
  final int index;
  final TextEditingController packageController;
  final TextEditingController hashController;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _AppEntryRow({
    required this.index,
    required this.packageController,
    required this.hashController,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_AppEntryRow> createState() => _AppEntryRowState();
}

class _AppEntryRowState extends State<_AppEntryRow> {
  @override
  void initState() {
    super.initState();
    widget.packageController.addListener(_onChanged);
    widget.hashController.addListener(_onChanged);
  }

  void _onChanged() {
    setState(() {});
    widget.onChanged();
  }

  @override
  void dispose() {
    widget.packageController.removeListener(_onChanged);
    widget.hashController.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packageLen = widget.packageController.text.length;
    final hashLen = widget.hashController.text.length;
    final hashInvalid = hashLen > 0 && hashLen != 11;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'App ${widget.index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.canRemove ? widget.onRemove : null,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.packageController,
            maxLength: 224,
            decoration: InputDecoration(
              labelText: 'Package name',
              counterText: '$packageLen/224',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.hashController,
            maxLength: 11,
            decoration: InputDecoration(
              labelText: 'App signature hash',
              counterText: '$hashLen/11',
              errorText: hashInvalid
                  ? 'App signature hash must be exactly 11 characters.'
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ContentOptionsWidget
// ---------------------------------------------------------------------------

class ContentOptionsWidget extends StatelessWidget {
  final bool addSecurityRecommendation;
  final bool addExpiryTime;
  final int? codeExpirationMinutes;
  final ValueChanged<bool> onSecurityChanged;
  final ValueChanged<bool> onExpiryChanged;
  final ValueChanged<int?> onExpiryMinutesChanged;

  const ContentOptionsWidget({
    super.key,
    required this.addSecurityRecommendation,
    required this.addExpiryTime,
    required this.onSecurityChanged,
    required this.onExpiryChanged,
    required this.onExpiryMinutesChanged,
    this.codeExpirationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OptionCheckboxRow(
          label: 'Add security recommendation',
          value: addSecurityRecommendation,
          onChanged: onSecurityChanged,
        ),
        const SizedBox(height: 8),
        _OptionCheckboxRow(
          label: 'Add expiry time for the code',
          value: addExpiryTime,
          onChanged: onExpiryChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 44, top: 2),
          child: Text(
            'After the code has expired, the auto-fill button will be disabled.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        if (addExpiryTime) ...[
          const SizedBox(height: 12),
          _ExpiryMinutesField(
            value: codeExpirationMinutes,
            onChanged: onExpiryMinutesChanged,
          ),
        ],
      ],
    );
  }
}

class _OptionCheckboxRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionCheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? AppTheme.primaryColor : Colors.grey.shade200,
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppTheme.primaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: value ? AppTheme.secondaryColor : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryMinutesField extends StatefulWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _ExpiryMinutesField({required this.value, required this.onChanged});

  @override
  State<_ExpiryMinutesField> createState() => _ExpiryMinutesFieldState();
}

class _ExpiryMinutesFieldState extends State<_ExpiryMinutesField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? widget.value.toString() : '',
    );
  }

  @override
  void didUpdateWidget(_ExpiryMinutesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value != null ? widget.value.toString() : '';
    if (_controller.text != newText) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Expiry duration (minutes)',
          border: OutlineInputBorder(),
          isDense: true,
          suffixText: 'min',
        ),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          widget.onChanged(parsed);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AuthenticationFormWidget
// ---------------------------------------------------------------------------

class AuthenticationFormWidget extends StatefulWidget {
  final AuthFormState initialState;
  final ValueChanged<AuthFormState> onChanged;

  const AuthenticationFormWidget({
    super.key,
    required this.initialState,
    required this.onChanged,
  });

  @override
  State<AuthenticationFormWidget> createState() =>
      _AuthenticationFormWidgetState();
}

class _AuthenticationFormWidgetState extends State<AuthenticationFormWidget> {
  late AuthFormState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  void _update(AuthFormState updated) {
    setState(() => _state = updated);
    widget.onChanged(_state);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Code Delivery ---
        _sectionLabel('Code Delivery'),
        CodeDeliverySetupWidget(
          selectedType: _state.codeDeliveryType,
          tosAccepted: _state.zeroTapTosAccepted,
          onTypeChanged: (type) => _update(
            _state.copyWith(codeDeliveryType: type),
          ),
          onTosChanged: (accepted) => _update(
            _state.copyWith(zeroTapTosAccepted: accepted),
          ),
        ),

        // --- App Setup (hidden for COPY_CODE) ---
        if (_state.codeDeliveryType != 'COPY_CODE') ...[
          _sectionLabel('App Setup'),
          AppSetupWidget(
            entries: _state.appEntries,
            onChanged: (entries) => _update(
              _state.copyWith(appEntries: entries),
            ),
          ),
        ],

        // --- Content Options ---
        _sectionLabel('Content Options'),
        ContentOptionsWidget(
          addSecurityRecommendation: _state.addSecurityRecommendation,
          addExpiryTime: _state.addExpiryTime,
          codeExpirationMinutes: _state.codeExpirationMinutes,
          onSecurityChanged: (v) => _update(
            _state.copyWith(addSecurityRecommendation: v),
          ),
          onExpiryChanged: (v) => _update(
            v
                ? _state.copyWith(addExpiryTime: true)
                : _state.copyWith(
                    addExpiryTime: false,
                    clearCodeExpirationMinutes: true,
                  ),
          ),
          onExpiryMinutesChanged: (minutes) => _update(
            _state.copyWith(codeExpirationMinutes: minutes),
          ),
        ),

        // --- Message Validity ---
        _sectionLabel('Message Validity'),
        MessageValidityPeriodWidget(
          defaultOn: true,
          enabled: _state.validityEnabled,
          selectedSeconds: _state.validitySeconds,
          onChanged: (seconds) => _update(
            seconds == 0
                ? _state.copyWith(validityEnabled: false, validitySeconds: _state.validitySeconds)
                : _state.copyWith(validityEnabled: true, validitySeconds: seconds),
          ),
        ),
      ],
    );
  }
}

