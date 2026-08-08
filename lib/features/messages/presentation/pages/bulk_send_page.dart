import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/group_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/group_selection_dialog.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/messages/presentation/bloc/message_bloc.dart';
import 'package:iFloraBuzz/features/messages/presentation/widgets/csv_uploader.dart';
import 'package:iFloraBuzz/features/messages/presentation/widgets/client_selection_dialog.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/templates/presentation/widgets/whatsapp_preview.dart';
import 'package:iFloraBuzz/features/messages/presentation/widgets/campaign_result_dialog.dart';

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

  // Per-recipient BODY variable controllers: recipientIndex -> {varIndex -> controller}
  final Map<int, Map<int, TextEditingController>> _perRecipientControllers = {};

  // Per-recipient HEADER variable controllers: recipientIndex -> {varIndex -> controller}
  final Map<int, Map<int, TextEditingController>> _perRecipientHeaderControllers = {};

  /// Returns how many {{n}} variables the selected template BODY has
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

  /// Returns how many {{n}} variables the selected template TEXT HEADER has
  int get _templateHeaderVariableCount {
    if (_selectedTemplateData == null) return 0;
    final components = _selectedTemplateData!['components'] as List<dynamic>? ?? [];
    final header = components.firstWhere(
      (c) => c['type'] == 'HEADER' && c['format'] == 'TEXT',
      orElse: () => null,
    );
    if (header == null) return 0;
    final text = header['text'] as String? ?? '';
    final matches = RegExp(r'\{\{\d+\}\}').allMatches(text);
    if (matches.isEmpty) return 0;
    return matches.map((m) {
      final inner = m.group(0)!.replaceAll(RegExp(r'[{}]'), '');
      return int.tryParse(inner) ?? 0;
    }).fold(0, (a, b) => a > b ? a : b);
  }

  void _syncVariableControllers(int count) {
    // For each recipient, ensure controllers exist for all body variable indices
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

  void _syncHeaderVariableControllers(int count) {
    // For each recipient, ensure controllers exist for all header variable indices
    for (int ri = 0; ri < _recipients.length; ri++) {
      _perRecipientHeaderControllers.putIfAbsent(ri, () => {});
      final recipient = _recipients[ri];
      for (int vi = 1; vi <= count; vi++) {
        _perRecipientHeaderControllers[ri]!.putIfAbsent(vi, () {
          final prefilled = recipient.headerVariables[vi] ?? '';
          return TextEditingController(text: prefilled);
        });
      }
      // Remove extra controllers beyond current count
      _perRecipientHeaderControllers[ri]!.removeWhere((k, v) {
        if (k > count) { v.dispose(); return true; }
        return false;
      });
    }
    _perRecipientHeaderControllers.removeWhere((ri, _) => ri >= _recipients.length);
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
        if (_templateHeaderVariableCount > 0) {
          _syncHeaderVariableControllers(_templateHeaderVariableCount);
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
      if (_templateHeaderVariableCount > 0) _syncHeaderVariableControllers(_templateHeaderVariableCount);
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
        if (_templateHeaderVariableCount > 0) {
          _syncHeaderVariableControllers(_templateHeaderVariableCount);
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
      // Body variables
      final ctrlMap = _perRecipientControllers[ri] ?? {};
      final vars = <int, String>{};
      ctrlMap.forEach((vi, ctrl) {
        if (ctrl.text.trim().isNotEmpty) vars[vi] = ctrl.text.trim();
      });
      // Header variables
      final headerCtrlMap = _perRecipientHeaderControllers[ri] ?? {};
      final headerVars = <int, String>{};
      headerCtrlMap.forEach((vi, ctrl) {
        if (ctrl.text.trim().isNotEmpty) headerVars[vi] = ctrl.text.trim();
      });
      return RecipientData(
        mobileNumber: _recipients[ri].mobileNumber,
        variables: vars,
        headerVariables: headerVars,
      );
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
          recipients: finalRecipients.map((r) => {
            'mobileNumber': r.mobileNumber,
            'variables': r.variables.map((k, v) => MapEntry(k.toString(), v)),
            if (r.headerVariables.isNotEmpty)
              'headerVariables': r.headerVariables.map((k, v) => MapEntry(k.toString(), v)),
          }).toList(),
          scheduledAt: _scheduledAt!,
          mediaId: mediaId,
          mediaType: mediaType,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Campaign scheduled for ${_formatScheduledAt(_scheduledAt!)}')),
          );
          setState(() { _isScheduled = false; _scheduledAt = null; });
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
        // headerVariables are carried inside each RecipientData.headerVariables
      ),
    );
  }

  @override
  void dispose() {
    for (final m in _perRecipientControllers.values) {
      for (final c in m.values) c.dispose();
    }
    for (final m in _perRecipientHeaderControllers.values) {
      for (final c in m.values) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MessageBloc, MessageState>(
          listener: (context, state) {
            if (state is MessageSent) {
              showDialog(
                context: context,
                builder: (context) => CampaignResultDialog(
                  successCount: state.successCount,
                  failureCount: state.failureCount,
                  campaignId: state.campaignId,
                  dispatchedAt: state.dispatchedAt,
                ),
              );
              if (state.failureCount > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${state.failureCount} recipient(s) failed to receive message.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            } else if (state is MessageError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
        ),
      ],
      child: SingleChildScrollView(
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
                        if (_templateVariableCount > 0 || _templateHeaderVariableCount > 0)
                          _buildVariableMapping(),
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
      ),
    );
  }

  Widget _buildRecipientCard() {
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
                      decoration: const InputDecoration(
                        hintText: 'Enter numbers separated by comma or newline',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
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
            Row(
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
                const SizedBox(width: 12),
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

  /// Per-recipient variable table — each row = one contact + their variable inputs
  Widget _buildVariableMapping() {
    final bodyCount = _templateVariableCount;
    final headerCount = _templateHeaderVariableCount;
    _syncVariableControllers(bodyCount);
    _syncHeaderVariableControllers(headerCount);

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

              // Column header row
              Row(
                children: [
                  const SizedBox(
                    width: 160,
                    child: Text('Mobile Number',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  // Header variable columns (orange label)
                  ...List.generate(headerCount, (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Header {{${i + 1}}}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                  // Body variable columns (blue label)
                  ...List.generate(bodyCount, (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Body {{${i + 1}}}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(width: 32), // delete btn space
                ],
              ),
              const Divider(height: 16),

              // Data rows
              ...List.generate(_recipients.length, (ri) {
                final r = _recipients[ri];
                final bodyCtrlMap = _perRecipientControllers[ri] ?? {};
                final headerCtrlMap = _perRecipientHeaderControllers[ri] ?? {};
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
                      // Header variable inputs
                      ...List.generate(headerCount, (vi) {
                        final idx = vi + 1;
                        final ctrl = headerCtrlMap[idx] ?? TextEditingController();
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: TextField(
                              controller: ctrl,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Header value',
                                isDense: true,
                                filled: true,
                                fillColor: Colors.orange.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.orange.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.orange.shade200),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Body variable inputs
                      ...List.generate(bodyCount, (vi) {
                        final idx = vi + 1;
                        final ctrl = bodyCtrlMap[idx] ?? TextEditingController();
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
                        onPressed: () => setState(() {
                          // Dispose body controllers for this recipient
                          _perRecipientControllers[ri]?.values.forEach((c) => c.dispose());
                          _perRecipientControllers.remove(ri);
                          // Dispose header controllers for this recipient
                          _perRecipientHeaderControllers[ri]?.values.forEach((c) => c.dispose());
                          _perRecipientHeaderControllers.remove(ri);
                          _recipients.removeAt(ri);
                          // Re-key both controller maps
                          final reKeyed = <int, Map<int, TextEditingController>>{};
                          final reKeyedHeader = <int, Map<int, TextEditingController>>{};
                          int newIdx = 0;
                          for (int old = 0; old < _recipients.length + 1; old++) {
                            if (old == ri) continue;
                            if (_perRecipientControllers.containsKey(old)) {
                              reKeyed[newIdx] = _perRecipientControllers[old]!;
                            }
                            if (_perRecipientHeaderControllers.containsKey(old)) {
                              reKeyedHeader[newIdx] = _perRecipientHeaderControllers[old]!;
                            }
                            newIdx++;
                          }
                          _perRecipientControllers
                            ..clear()
                            ..addAll(reKeyed);
                          _perRecipientHeaderControllers
                            ..clear()
                            ..addAll(reKeyedHeader);
                        }),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
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
                        // Also reset header variable controllers
                        for (final m in _perRecipientHeaderControllers.values) {
                          for (final c in m.values) c.dispose();
                        }
                        _perRecipientHeaderControllers.clear();
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

    // Substitute variables in preview using the first recipient's controllers
    String previewBody = body ?? '';
    String previewHeader = header ?? '';
    final firstManualIdx = _recipients.indexWhere((r) => r.variables.isEmpty);
    if (firstManualIdx >= 0) {
      // Manual recipient — use controllers
      final ctrlMap = _perRecipientControllers[firstManualIdx] ?? {};
      ctrlMap.forEach((idx, ctrl) {
        if (ctrl.text.trim().isNotEmpty) {
          previewBody = previewBody.replaceAll('{{$idx}}', ctrl.text.trim());
        }
      });
      final headerCtrlMap = _perRecipientHeaderControllers[firstManualIdx] ?? {};
      headerCtrlMap.forEach((idx, ctrl) {
        if (ctrl.text.trim().isNotEmpty) {
          previewHeader = previewHeader.replaceAll('{{$idx}}', ctrl.text.trim());
        }
      });
    } else {
      // CSV recipient — use first recipient's variables
      if (_recipients.isNotEmpty) {
        _recipients.first.variables.forEach((idx, val) {
          previewBody = previewBody.replaceAll('{{$idx}}', val);
        });
        _recipients.first.headerVariables.forEach((idx, val) {
          previewHeader = previewHeader.replaceAll('{{$idx}}', val);
        });
      }
    }
    // Use substituted header in the preview (may still have {{n}} if not yet filled)
    final resolvedHeader = previewHeader.isEmpty ? null : previewHeader;

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
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: const Color(0xFFE5DDD5),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: Colors.black12),
          ),
          child: WhatsAppPreview(
            headerText: resolvedHeader,
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
