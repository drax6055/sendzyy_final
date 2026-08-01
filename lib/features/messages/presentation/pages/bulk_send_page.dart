import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sendzyy/core/di/injection.dart';
import 'package:sendzyy/features/clients/data/models/client_model.dart';
import 'package:sendzyy/features/clients/data/models/group_model.dart';
import 'package:sendzyy/features/clients/data/repositories/client_repository.dart';
import 'package:sendzyy/features/clients/presentation/bloc/group_bloc.dart';
import 'package:sendzyy/features/clients/presentation/widgets/group_selection_dialog.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendzyy/features/messages/presentation/bloc/message_bloc.dart';
import 'package:sendzyy/features/messages/presentation/widgets/csv_uploader.dart';
import 'package:sendzyy/features/messages/presentation/widgets/client_selection_dialog.dart';
import 'package:sendzyy/features/templates/presentation/bloc/template_bloc.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/features/templates/presentation/widgets/whatsapp_preview.dart';
import 'package:sendzyy/features/messages/presentation/widgets/campaign_result_dialog.dart';
import 'package:sendzyy/core/widgets/multi_contact_picker_dialog.dart';

class BulkSendPage extends StatefulWidget {
  const BulkSendPage({super.key});

  @override
  State<BulkSendPage> createState() => _BulkSendPageState();
}

class _BulkSendPageState extends State<BulkSendPage> {
  final TextEditingController _manualNumbersController = TextEditingController();
  List<RecipientData> _recipients = [];
  String? _selectedTemplate;
  Map<String, dynamic>? _selectedTemplateData;
  PlatformFile? _campaignMedia;
  bool _isUploadingMedia = false;
  bool _isScheduled = false;
  DateTime? _scheduledAt;

  // Counters shown in Campaign Summary
  int _totalDuplicates = 0;
  int _totalInvalid = 0;
  int _recipientTab = 0;

  @override
  void initState() {
    super.initState();
    // Retry template fetch if they failed to load (e.g. token wasn't ready at app start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<TemplateBloc>().state;
      if (state is TemplateError || state is TemplateInitial) {
        context.read<TemplateBloc>().add(FetchTemplates());
      }
    });
  }

  Future<void> _pickNumberFromContacts() async {
    try {
      final selectedNumbers = await MultiContactPickerDialog.show(context);
      if (selectedNumbers == null || selectedNumbers.isEmpty) return;

      final List<String> validNormalized = [];
      final List<String> invalidNumbers = [];

      for (final rawNumber in selectedNumbers) {
        final normalized = RecipientData.normalizeNumber(rawNumber);
        if (normalized != null) {
          validNormalized.add(normalized);
        } else {
          invalidNumbers.add(rawNumber);
        }
      }

      if (validNormalized.isNotEmpty) {
        setState(() {
          final existingText = _manualNumbersController.text.trim();
          final joinedNew = validNormalized.join(', ');
          if (existingText.isEmpty) {
            _manualNumbersController.text = joinedNew;
          } else {
            _manualNumbersController.text = '$existingText, $joinedNew';
          }
        });
      }

      if (invalidNumbers.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid contact format skipped: ${invalidNumbers.join(", ")}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick contacts: $e')),
        );
      }
    }
  }

  // Per-recipient variable controllers: recipientIndex -> {varIndex -> controller}
  // Used only for manually added recipients (CSV ones carry their own values)
  final Map<int, Map<int, TextEditingController>> _perRecipientControllers = {};

  /// Returns how many {{n}} variables the selected template body has
  int get _templateVariableCount {
    if (_selectedTemplateData == null) return 0;
    final components = _selectedTemplateData!['components'] as List<dynamic>? ?? [];
    final body = components.firstWhere(
      (c) => c['type'] == 'BODY',
      orElse: () => null,
    );
    if (body == null) return 0;
    final text = body['text'] as String? ?? '';
    final matches = RegExp(r'\{\{\d+\}\}').allMatches(text);
    if (matches.isEmpty) return 0;
    return matches.map((m) {
      final inner = m.group(0)!.replaceAll(RegExp(r'[{}]'), '');
      return int.tryParse(inner) ?? 0;
    }).fold(0, (a, b) => a > b ? a : b);
  }

  void _syncVariableControllers(int count) {
    // For each recipient, ensure controllers exist for all variable indices
    for (int ri = 0; ri < _recipients.length; ri++) {
      _perRecipientControllers.putIfAbsent(ri, () => {});
      final recipient = _recipients[ri];
      for (int vi = 1; vi <= count; vi++) {
        // Seed controller with pre-filled variable value (e.g. name from client)
        _perRecipientControllers[ri]!.putIfAbsent(vi, () {
          final prefilled = recipient.variables[vi] ?? '';
          return TextEditingController(text: prefilled);
        });
      }
      // Remove extra variable controllers
      _perRecipientControllers[ri]!.removeWhere((k, v) {
        if (k > count) { v.dispose(); return true; }
        return false;
      });
    }
    // Remove controllers for removed recipients
    _perRecipientControllers.removeWhere((ri, _) => ri >= _recipients.length);
  }

  Future<void> _addFromClients() async {
    debugPrint('[BulkSend] "Add from Clients" clicked — opening client selection dialog');
    final existingNumbers = _recipients.map((r) => r.mobileNumber).toList();
    final selected = await showDialog<List<ClientModel>>(
      context: context,
      builder: (_) => ClientSelectionDialog(existingNumbers: existingNumbers),
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _recipients.addAll(selected.map((client) => RecipientData(
          mobileNumber: client.mobileNumber,
          // Pre-fill {{1}} with client name so user doesn't have to type it
          variables: client.name.trim().isNotEmpty ? {1: client.name.trim()} : {},
        )));
        if (_templateVariableCount > 0) {
          _syncVariableControllers(_templateVariableCount);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${selected.length} client(s)')),
        );
      }
    }
  }

  Future<void> _addFromGroup() async {
    final selected = await showDialog<GroupModel>(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => getIt<GroupsBloc>()..add(FetchGroups()),
        child: const GroupSelectionDialog(),
      ),
    );
    if (selected == null || selected.clientIds.isEmpty) return;

    final repo = getIt<ClientRepository>();
    final paginatedResult = await repo.getClients(groupId: selected.id);
    final groupClients = paginatedResult.clients;

    final existing = _recipients.map((r) => r.mobileNumber).toSet();
    final toAdd = groupClients
        .where((c) => !existing.contains(c.mobileNumber))
        .toList();

    setState(() {
      _recipients.addAll(toAdd.map((c) => RecipientData(
        mobileNumber: c.mobileNumber,
        variables: c.name.trim().isNotEmpty ? {1: c.name.trim()} : {},
      )));
      if (_templateVariableCount > 0) _syncVariableControllers(_templateVariableCount);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${toAdd.length} client(s) from group "${selected.name}"')),
      );
    }
  }

  void _addManualNumbers() {
    if (_manualNumbersController.text.isNotEmpty) {
      final existing = _recipients.map((r) => r.mobileNumber).toSet();
      final invalid = <String>[];
      final newNumbers = _manualNumbersController.text
          .split(RegExp(r'[,\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) {
            final normalized = RecipientData.normalizeNumber(e);
            if (normalized == null) invalid.add(e);
            return normalized;
          })
          .whereType<String>()
          .where((n) => !existing.contains(n))
          .toSet() // dedup within input
          .toList();

      if (invalid.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid number(s) skipped: ${invalid.join(', ')}. Use 10 digits or 12 digits with country code 91.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (newNumbers.isEmpty) {
        if (invalid.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Number(s) already added or invalid.')),
          );
        }
        _manualNumbersController.clear();
        return;
      }

      setState(() {
        _recipients.addAll(newNumbers.map(RecipientData.fromNumber));
        _manualNumbersController.clear();
        _totalInvalid += invalid.length;
        if (_templateVariableCount > 0) {
          _syncVariableControllers(_templateVariableCount);
        }
      });
    }
  }

  void _onCsvParsed(List<RecipientData> parsed, {required int invalidCount, required int duplicateCount}) {
    final existing = _recipients.map((r) => r.mobileNumber).toSet();
    final unique = parsed.where((r) => !existing.contains(r.mobileNumber)).toList();
    final alreadyExisting = parsed.length - unique.length;

    setState(() {
      _recipients.addAll(unique);
      _totalDuplicates += duplicateCount + alreadyExisting;
      _totalInvalid += invalidCount;
    });

    final parts = <String>[];
    if (unique.isNotEmpty) parts.add('Added ${unique.length} recipient(s)');
    if (alreadyExisting > 0) parts.add('$alreadyExisting already in list');
    if (duplicateCount > 0) parts.add('$duplicateCount duplicate(s) in CSV');
    if (invalidCount > 0) parts.add('$invalidCount invalid number(s)');

    if (parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new recipients found in CSV.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join(' · ')),
        backgroundColor: invalidCount > 0 || duplicateCount > 0 ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Build final recipients: CSV ones keep their own variables, manual ones use per-row controllers
  List<RecipientData> _buildFinalRecipients() {
    return List.generate(_recipients.length, (ri) {
      final ctrlMap = _perRecipientControllers[ri] ?? {};
      final vars = <int, String>{};
      ctrlMap.forEach((vi, ctrl) {
        if (ctrl.text.trim().isNotEmpty) vars[vi] = ctrl.text.trim();
      });
      return RecipientData(mobileNumber: _recipients[ri].mobileNumber, variables: vars);
    });
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _sendMessages() async {
    if (_recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add recipients first')));
      return;
    }
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a template first')));
      return;
    }

    String? mediaId;
    String? mediaType;

    final components = _selectedTemplateData?['components'] as List<dynamic>? ?? [];
    final headerComp = components.firstWhere(
      (c) => c['type'] == 'HEADER',
      orElse: () => null,
    );

    if (headerComp != null && headerComp['format'] != 'TEXT') {
      if (_campaignMedia == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image/video/document for this template')),
        );
        return;
      }

      setState(() => _isUploadingMedia = true);
      try {
        final repo = getIt<WhatsAppRepository>();
        mediaId = await repo.uploadMedia(_campaignMedia!);
        mediaType = headerComp['format'];
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        setState(() => _isUploadingMedia = false);
        return;
      }
      setState(() => _isUploadingMedia = false);
    }

    final finalRecipients = _buildFinalRecipients();

    if (_isScheduled) {
      if (_scheduledAt == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a schedule date & time first')));
        return;
      }
      try {
        final repo = getIt<WhatsAppRepository>();
        await repo.scheduleCampaign(
          campaignName: 'Campaign ${DateTime.now().millisecondsSinceEpoch}',
          template: _selectedTemplate!,
          language: _selectedTemplateData?['language'] ?? 'en_US',
          recipients: finalRecipients.map((r) => {'mobileNumber': r.mobileNumber, 'variables': r.variables.map((k, v) => MapEntry(k.toString(), v))}).toList(),
          scheduledAt: _scheduledAt!,
          mediaId: mediaId,
          mediaType: mediaType,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Campaign scheduled for ${_formatScheduledAt(_scheduledAt!)}')),
          );
          setState(() {
            _isScheduled = false;
            _scheduledAt = null;
            _recipients.clear();
            _selectedTemplate = null;
            _selectedTemplateData = null;
            _campaignMedia = null;
            _currentMobileStep = 0;
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to schedule: $e')));
      }
      return;
    }

    context.read<MessageBloc>().add(
      SendBulkMessages(
        finalRecipients,
        _selectedTemplate!,
        _selectedTemplateData?['language'] ?? 'en_US',
        mediaId: mediaId,
        mediaType: mediaType,
      ),
    );
  }

  @override
  void dispose() {
    for (final m in _perRecipientControllers.values) {
      for (final c in m.values) c.dispose();
    }
    super.dispose();
  }

  int _currentMobileStep = 0;

  Widget _buildWebLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Campaign',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildRecipientCard()),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: CsvUploader(onParsed: _onCsvParsed)),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildTemplateSelector(),
                    const SizedBox(height: 16),
                    if (_selectedTemplateData != null) ...[
                      if (_templateVariableCount > 0) _buildVariableMapping(),
                      const SizedBox(height: 16),
                      _buildMediaSelector(),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: _selectedTemplateData != null
                    ? _buildTemplatePreview()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    bool isNextDisabled = false;
    if (_currentMobileStep == 0 && _recipients.isEmpty) isNextDisabled = true;
    if (_currentMobileStep == 1 && _selectedTemplateData == null) isNextDisabled = true;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMobileStepIndicator(),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0.0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: _buildMobileStepContent(),
          ),
          const SizedBox(height: 32),

          // Bottom Action Row
          Row(
            children: [
              if (_currentMobileStep > 0)
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _currentMobileStep--),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_currentMobileStep > 0 && _currentMobileStep < 2) const SizedBox(width: 16),
              if (_currentMobileStep < 2)
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isNextDisabled ? null : () => setState(() => _currentMobileStep++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        disabledForegroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('Next'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildMobileStepCircle(0, 'Recipients', Icons.people_alt_rounded),
          _buildMobileStepLine(0),
          _buildMobileStepCircle(1, 'Setup', Icons.settings_rounded),
          _buildMobileStepLine(1),
          _buildMobileStepCircle(2, 'Send', Icons.send_rounded),
        ],
      ),
    );
  }

  Widget _buildMobileStepCircle(int step, String label, IconData icon) {
    bool isActive = _currentMobileStep == step;
    bool isCompleted = _currentMobileStep > step;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green
                  : isActive
                      ? AppTheme.primaryColor
                      : Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              size: 16,
              color: isActive || isCompleted ? Colors.white : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isCompleted
                  ? Colors.green
                  : isActive
                      ? AppTheme.primaryColor
                      : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStepLine(int step) {
    bool isCompleted = _currentMobileStep > step;
    return Container(
      height: 2,
      width: 30,
      margin: const EdgeInsets.only(bottom: 18),
      color: isCompleted ? Colors.green : Colors.grey.shade200,
    );
  }

  Widget _buildMobileStepContent() {
    switch (_currentMobileStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          key: const ValueKey(0),
          children: [
            _buildRecipientCard(),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          key: const ValueKey(1),
          children: [
            _buildTemplateSelector(),
            const SizedBox(height: 16),
            if (_selectedTemplateData != null) ...[
              if (_templateVariableCount > 0) ...[
                _buildVariableMapping(),
                const SizedBox(height: 16),
              ],
              _buildMediaSelector(),
            ] else
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Please select a WhatsApp template to start your campaign setup.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          key: const ValueKey(2),
          children: [
            if (_selectedTemplateData != null) ...[
              _buildTemplatePreview(),
              const SizedBox(height: 24),
            ],
            _buildSummaryCard(),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MessageBloc, MessageState>(
          listener: (context, state) {
            if (state is MessageSent) {
              setState(() {
                _recipients.clear();
                _selectedTemplate = null;
                _selectedTemplateData = null;
                _campaignMedia = null;
                _currentMobileStep = 0;
              });
              showDialog(
                context: context,
                builder: (context) => CampaignResultDialog(
                  successCount: state.successCount,
                  failureCount: state.failureCount,
                  campaignId: state.campaignId,
                  dispatchedAt: state.dispatchedAt,
                ),
              );
            }
          },
        ),
      ],
      child: kIsWeb ? _buildWebLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildRecipientTabs() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _recipientTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _recipientTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _recipientTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: _recipientTab == 0 ? AppTheme.primaryColor : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manual & Contacts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _recipientTab == 0 ? FontWeight.bold : FontWeight.normal,
                        color: _recipientTab == 0 ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _recipientTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _recipientTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _recipientTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file_rounded,
                      size: 18,
                      color: _recipientTab == 1 ? AppTheme.primaryColor : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upload CSV',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _recipientTab == 1 ? FontWeight.bold : FontWeight.normal,
                        color: _recipientTab == 1 ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileManualSection() {
    return Container(
      key: const ValueKey('manual'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Mobile Numbers',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _manualNumbersController,
                    decoration: InputDecoration(
                      hintText: 'Enter numbers separated by comma',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: kIsWeb
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.contacts_rounded, color: AppTheme.primaryColor),
                              onPressed: _pickNumberFromContacts,
                              tooltip: 'Select from contacts',
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addManualNumbers,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Quick Imports',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFromClients,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('From Clients', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondaryColor,
                    side: BorderSide(color: AppTheme.secondaryColor.withValues(alpha: 0.15)),
                    backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFromGroup,
                  icon: const Icon(Icons.group_add_rounded, size: 16),
                  label: const Text('From Groups', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondaryColor,
                    side: BorderSide(color: AppTheme.secondaryColor.withValues(alpha: 0.15)),
                    backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          if (_recipients.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Selected Recipients',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${_recipients.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _recipients.clear()),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recipients.take(15).map((r) {
                return Container(
                  padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.mobileNumber,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _recipients.removeWhere((x) => x.mobileNumber == r.mobileNumber)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (_recipients.length > 15)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  '+ ${_recipients.length - 15} more recipients',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecipientCard() {
    final isMobile = MediaQuery.of(context).size.width < 800;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRecipientTabs(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _recipientTab == 0
                ? _buildMobileManualSection()
                : CsvUploader(onParsed: _onCsvParsed),
          ),
        ],
      );
    }

    return Card(
      elevation: 0,
      color: const Color(0xFFF9FBFB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Recipients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _manualNumbersController,
                      decoration: InputDecoration(
                        hintText: 'Enter numbers separated by comma or newline',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        suffixIcon: kIsWeb
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.contacts_rounded, color: Colors.green),
                                onPressed: _pickNumberFromContacts,
                                tooltip: 'Select from contacts',
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _addManualNumbers,
                    tooltip: 'Add Client',
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _addFromClients,
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Add from Clients'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _addFromGroup,
                  icon: const Icon(Icons.group_outlined, size: 18),
                  label: const Text('Add from Group'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
            if (_recipients.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recipients.take(15).map((r) {
                  return Chip(
                    label: Text(r.mobileNumber),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.black12),
                    onDeleted: () => setState(
                        () => _recipients.removeWhere((x) => x.mobileNumber == r.mobileNumber)),
                  );
                }).toList(),
              ),
              if (_recipients.length > 15)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${_recipients.length - 15} more',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVariableMapping() {
    final count = _templateVariableCount;
    _syncVariableControllers(count);

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.withOpacity(0.15)),
      ),
      color: const Color(0xFFF0F4FF),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text('Personalisation Variables',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            if (_recipients.isNotEmpty) ...[
              Text(
                'Fill in variable values for each recipient:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              
              if (isMobile) ...[
                ...List.generate(_recipients.length, (ri) {
                  final r = _recipients[ri];
                  final ctrlMap = _perRecipientControllers[ri] ?? {};
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r.mobileNumber,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                              onPressed: () => _removeRecipient(ri),
                            ),
                          ],
                        ),
                        const Divider(),
                        ...List.generate(count, (vi) {
                          final idx = vi + 1;
                          final ctrl = ctrlMap[idx] ?? TextEditingController();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: Text('{{$idx}}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: ctrl,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: _variableHint(idx),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ] else ...[
                Row(
                  children: [
                    const SizedBox(
                      width: 160,
                      child: Text('Mobile Number',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    ...List.generate(count, (i) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('{{${i + 1}}}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent)),
                      ),
                    )),
                    const SizedBox(width: 32),
                  ],
                ),
                const Divider(height: 16),
                ...List.generate(_recipients.length, (ri) {
                  final r = _recipients[ri];
                  final ctrlMap = _perRecipientControllers[ri] ?? {};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            r.mobileNumber,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...List.generate(count, (vi) {
                          final idx = vi + 1;
                          final ctrl = ctrlMap[idx] ?? TextEditingController();
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: TextField(
                                controller: ctrl,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: _variableHint(idx),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                          onPressed: () => _removeRecipient(ri),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _removeRecipient(int ri) {
    setState(() {
      _perRecipientControllers[ri]?.values.forEach((c) => c.dispose());
      _perRecipientControllers.remove(ri);
      _recipients.removeAt(ri);
      final reKeyed = <int, Map<int, TextEditingController>>{};
      int newIdx = 0;
      for (int old = 0; old < _recipients.length + 1; old++) {
        if (old == ri) continue;
        if (_perRecipientControllers.containsKey(old)) {
          reKeyed[newIdx] = _perRecipientControllers[old]!;
        }
        newIdx++;
      }
      _perRecipientControllers
        ..clear()
        ..addAll(reKeyed);
    });
  }

  String _formatScheduledAt(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, $h:$m';
  }

  String _variableHint(int idx) {
    switch (idx) {
      case 1: return 'John (Name)';
      case 2: return '+919876543210 (Number)';
      case 3: return 'ABC Company';
      default: return 'Value $idx';
    }
  }

  Widget _buildTemplateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Template',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            BlocBuilder<TemplateBloc, TemplateState>(
              builder: (context, state) {
                if (state is TemplateLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is TemplateLoaded) {
                  return DropdownButtonFormField<String>(
                    value: _selectedTemplate,
                    decoration: const InputDecoration(
                      hintText: 'Choose from approved templates',
                    ),
                    items: state.templates
                        .where((t) =>
                            t['status'] == 'APPROVED' &&
                            t['category'] != 'AUTHENTICATION')
                        .map<DropdownMenuItem<String>>((t) {
                      return DropdownMenuItem<String>(
                        value: t['name'],
                        child: Text(t['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedTemplate = val;
                        _selectedTemplateData =
                            state.templates.firstWhere((t) => t['name'] == val);
                        // Reset all per-recipient controllers on template change
                        for (final m in _perRecipientControllers.values) {
                          for (final c in m.values) c.dispose();
                        }
                        _perRecipientControllers.clear();
                      });
                    },
                  );
                }
                return const Text('Sync templates to select');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return BlocBuilder<MessageBloc, MessageState>(
      builder: (context, state) {
        final bool isSending = state is MessageSending;
        final currentProgress =
            isSending ? state.sentCount / state.totalCount : 0.0;

        return Card(
          elevation: 0,
          color: const Color(0xFFF9FBFB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Campaign Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                          'Duplicates Skipped', '$_totalDuplicates', Icons.content_copy,
                          valueColor: _totalDuplicates > 0 ? Colors.orange.shade700 : null),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                          'Invalid Numbers', '$_totalInvalid', Icons.error_outline,
                          valueColor: _totalInvalid > 0 ? Colors.red.shade600 : null),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                          'Total Recipients', '${_recipients.length}', Icons.people),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                          'Template', _selectedTemplate ?? 'None', Icons.description),
                    ),
                  ],
                ),
                if (isSending) ...[
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: currentProgress,
                      backgroundColor: Colors.black12,
                      color: const Color(0xFF2E7D32),
                      minHeight: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sending ${state.sentCount}/${state.totalCount}...',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 32),
                // Schedule toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isScheduled ? Colors.orange.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isScheduled ? Colors.orange.shade200 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 18,
                              color: _isScheduled ? Colors.orange.shade700 : Colors.grey.shade500),
                          const SizedBox(width: 10),
                          const Text('Schedule for later',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const Spacer(),
                          Switch(
                            value: _isScheduled,
                            onChanged: isSending ? null : (v) => setState(() {
                              _isScheduled = v;
                              if (!v) _scheduledAt = null;
                            }),
                            activeColor: Colors.orange.shade700,
                          ),
                        ],
                      ),
                      if (_isScheduled) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _pickScheduleDateTime,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 10),
                                Text(
                                  _scheduledAt != null
                                      ? _formatScheduledAt(_scheduledAt!)
                                      : 'Pick date & time',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _scheduledAt != null
                                        ? Colors.black87
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: isSending ||
                            _isUploadingMedia ||
                            _recipients.isEmpty ||
                            _selectedTemplate == null ||
                            (_isScheduled && _scheduledAt == null)
                        ? null
                        : _sendMessages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSending || _isUploadingMedia
                          ? Colors.grey
                          : _isScheduled
                              ? Colors.orange.shade700
                              : const Color(0xFF2E7D32),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      isSending
                          ? 'SENDING...'
                          : _isUploadingMedia
                              ? 'UPLOADING MEDIA...'
                              : _isScheduled
                                  ? 'SCHEDULE CAMPAIGN'
                                  : 'START CAMPAIGN',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 24),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: valueColor,
            ),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildTemplatePreview() {
    if (_selectedTemplateData == null) return const SizedBox.shrink();
    final components = _selectedTemplateData!['components'] as List<dynamic>? ?? [];
    String? header;
    String? body;
    String? footer;
    String mediaType = 'NONE';
    List<Map<String, dynamic>> buttons = [];

    for (var comp in components) {
      if (comp['type'] == 'HEADER') {
        if (comp['format'] == 'TEXT') {
          header = comp['text'];
        } else {
          mediaType = comp['format'] ?? 'NONE';
        }
      } else if (comp['type'] == 'BODY') {
        body = comp['text'];
      } else if (comp['type'] == 'FOOTER') {
        footer = comp['text'];
      } else if (comp['type'] == 'BUTTONS') {
        final btns = comp['buttons'] as List<dynamic>? ?? [];
        buttons = btns.map((b) => Map<String, dynamic>.from(b)).toList();
      }
    }

    // Substitute variables in preview using the first manual recipient's controllers
    String previewBody = body ?? '';
    final firstManualIdx = _recipients.indexWhere((r) => r.variables.isEmpty);
    if (firstManualIdx >= 0) {
      final ctrlMap = _perRecipientControllers[firstManualIdx] ?? {};
      ctrlMap.forEach((idx, ctrl) {
        if (ctrl.text.trim().isNotEmpty) {
          previewBody = previewBody.replaceAll('{{$idx}}', ctrl.text.trim());
        }
      });
    } else {
      // CSV recipient — use first recipient's variables
      if (_recipients.isNotEmpty) {
        _recipients.first.variables.forEach((idx, val) {
          previewBody = previewBody.replaceAll('{{$idx}}', val);
        });
      }
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4F4),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(
            children: [
              Icon(Icons.person, size: 20, color: Colors.grey),
              SizedBox(width: 8),
              Text('Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Spacer(),
              Icon(Icons.videocam, size: 20, color: Colors.grey),
              SizedBox(width: 12),
              Icon(Icons.phone, size: 18, color: Colors.grey),
            ],
          ),
        ),
        Container(
          height: 450,
          decoration: BoxDecoration(
            color: const Color(0xFFE5DDD5),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: Colors.black12),
          ),
          child: WhatsAppPreview(
            headerText: header,
            bodyText: previewBody,
            footerText: footer,
            mediaType: mediaType,
            buttons: buttons,
            mediaFile: _campaignMedia,
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSelector() {
    if (_selectedTemplateData == null) return const SizedBox.shrink();
    final components = _selectedTemplateData!['components'] as List<dynamic>? ?? [];
    final headerComp = components.firstWhere(
      (c) => c['type'] == 'HEADER',
      orElse: () => null,
    );

    if (headerComp == null || headerComp['format'] == 'TEXT') {
      return const SizedBox.shrink();
    }

    final String format = headerComp['format'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Campaign ${format[0]}${format.substring(1).toLowerCase()}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'This template requires a media file for the header.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _pickCampaignFile(format),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBFB),
              border: Border.all(color: Colors.green.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  format == 'IMAGE'
                      ? Icons.image
                      : format == 'VIDEO'
                          ? Icons.play_circle
                          : Icons.description,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _campaignMedia?.name ?? 'Select $format file',
                    style: TextStyle(
                      fontSize: 13,
                      color: _campaignMedia == null ? Colors.black54 : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_campaignMedia != null)
                  IconButton(
                    onPressed: () => setState(() => _campaignMedia = null),
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCampaignFile(String format) async {
    FileType type = FileType.any;
    if (format == 'IMAGE') type = FileType.image;
    if (format == 'VIDEO') type = FileType.video;

    final result = await FilePicker.platform.pickFiles(
      type: type,
      withData: true,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() => _campaignMedia = result.files.first);
    }
  }
}

