import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/media_validator.dart';
import 'package:iFloraBuzz/features/settings/data/models/client_trigger_model.dart';
import 'package:iFloraBuzz/features/settings/data/repositories/client_trigger_repository.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class LeadTriggerModel {
  final String id;
  final String tenantId;
  final String source;
  final String formName;
  final String action;
  final String templateName;
  final String templateLanguage;
  final String mediaId;
  final String mediaType;
  final Map<String, String> variableMapping; // {"1":"name","2":"mobileNumber"}
  final String chatbotId;
  final bool isActive;

  const LeadTriggerModel({
    required this.id,
    required this.tenantId,
    required this.source,
    required this.formName,
    required this.action,
    required this.templateName,
    required this.templateLanguage,
    this.mediaId = '',
    this.mediaType = '',
    this.variableMapping = const {},
    required this.chatbotId,
    required this.isActive,
  });

  factory LeadTriggerModel.fromJson(Map<String, dynamic> j) => LeadTriggerModel(
        id: j['_id']?.toString() ?? '',
        tenantId: j['tenantId']?.toString() ?? '',
        source: j['source']?.toString() ?? 'any',
        formName: j['formName']?.toString() ?? '',
        action: j['action']?.toString() ?? 'send_template',
        templateName: j['templateName']?.toString() ?? '',
        templateLanguage: j['templateLanguage']?.toString() ?? 'en_US',
        mediaId: j['mediaId']?.toString() ?? '',
        mediaType: j['mediaType']?.toString() ?? '',
        variableMapping: (j['variableMapping'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v?.toString() ?? '')),
        chatbotId: j['chatbotId']?.toString() ?? '',
        isActive: j['isActive'] == true,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'formName': formName,
        'action': action,
        'templateName': templateName,
        'templateLanguage': templateLanguage,
        'mediaId': mediaId,
        'mediaType': mediaType,
        'variableMapping': variableMapping,
        'chatbotId': chatbotId,
        'isActive': isActive,
      };
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class IntegrationSettingsPage extends StatefulWidget {
  const IntegrationSettingsPage({super.key});

  @override
  State<IntegrationSettingsPage> createState() => _IntegrationSettingsPageState();
}

class _IntegrationSettingsPageState extends State<IntegrationSettingsPage> {
  final Dio _dio = getIt<Dio>();

  // Password gate
  bool _isUnlocked = false;

  String _tenantId = '';
  String _displaySecret = '';
  bool _loadingSecret = true;
  List<LeadTriggerModel> _triggers = [];
  bool _loadingTriggers = true;

  // Chatbots for trigger form
  List<Map<String, dynamic>> _chatbots = [];

  // Client Auto-Message trigger
  ClientTriggerModel? _clientTrigger;
  bool _clientTriggerLoading = true;
  List<Map<String, String>> _clientTemplates = [];

  @override
  void initState() {
    super.initState();
    // Don't load data until unlocked
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _tenantId = prefs.getString(AppConstants.keyTenantId) ?? '');
    await Future.wait([_fetchSecret(), _fetchTriggers(), _fetchChatbots(), _fetchClientTrigger()]);
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? error;
    bool verifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> verify() async {
            final password = passwordController.text.trim();
            if (password.isEmpty) {
              setDialogState(() => error = 'Please enter your password');
              return;
            }
            setDialogState(() { verifying = true; error = null; });
            try {
              // Get the stored email from tenant_data
              final prefs = await SharedPreferences.getInstance();
              final tenantJson = prefs.getString('tenant_data');
              final email = tenantJson != null
                  ? (jsonDecode(tenantJson) as Map<String, dynamic>)['email']?.toString() ?? ''
                  : '';

              if (email.isEmpty) {
                setDialogState(() { verifying = false; error = 'Could not retrieve account info'; });
                return;
              }

              final res = await _dio.post('/login', data: {'email': email, 'password': password});
              if (res.statusCode == 200) {
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _isUnlocked = true);
                _init();
              } else {
                setDialogState(() { verifying = false; error = 'Incorrect password'; });
              }
            } on DioException catch (e) {
              final msg = e.response?.data?['error']?.toString() ?? 'Incorrect password';
              setDialogState(() { verifying = false; error = msg; });
            } catch (_) {
              setDialogState(() { verifying = false; error = 'Verification failed. Try again.'; });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.lock_rounded, color: AppTheme.secondaryColor, size: 22),
                const SizedBox(width: 8),
                const Text('Enter Password'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your login password to access Integrations.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  enabled: !verifying,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    errorText: error,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  onSubmitted: (_) => verify(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: verifying ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: verifying ? null : verify,
                child: verifying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Unlock'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _fetchSecret() async {
    setState(() => _loadingSecret = true);
    try {
      final res = await _dio.get('/api/leads/webhook-secret/reveal');
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        setState(() => _displaySecret = data['secret']?.toString() ?? '');
      }
    } catch (_) {
      setState(() => _displaySecret = '');
    } finally {
      setState(() => _loadingSecret = false);
    }
  }

  Future<void> _fetchTriggers() async {
    setState(() => _loadingTriggers = true);
    try {
      final res = await _dio.get('/api/leads/triggers');
      if (res.statusCode == 200) {
        final list = res.data as List<dynamic>;
        setState(() => _triggers = list
            .map((e) => LeadTriggerModel.fromJson(e as Map<String, dynamic>))
            .toList());
      }
    } catch (_) {
      setState(() => _triggers = []);
    } finally {
      setState(() => _loadingTriggers = false);
    }
  }

  Future<void> _fetchChatbots() async {
    try {
      final res = await _dio.get('/api/chatbots');
      if (res.statusCode == 200) {
        final list = res.data as List<dynamic>;
        setState(() => _chatbots = list
            .map((e) => {'id': e['_id']?.toString() ?? '', 'name': e['name']?.toString() ?? ''})
            .toList());
      }
    } catch (_) {}
  }

  Future<void> _fetchClientTrigger() async {
    setState(() => _clientTriggerLoading = true);
    try {
      final repo = ClientTriggerRepository(_dio);
      final trigger = await repo.fetchTrigger();
      // Also fetch templates for the picker
      final res = await _dio.get('/fetch-templates');
      final list = (res.data['data'] as List<dynamic>? ?? []);
      final approved = list
          .where((t) => (t['status'] as String? ?? '').toUpperCase() == 'APPROVED')
          .where((t) => (t['category'] as String? ?? '').toUpperCase() != 'AUTHENTICATION')
          .map((t) {
            final components = t['components'] as List<dynamic>? ?? [];
            final lang = t['language']?.toString() ?? 'en_US';
            final header = components.firstWhere(
              (c) => (c['type'] as String? ?? '').toUpperCase() == 'HEADER',
              orElse: () => null,
            );
            final headerFormat = (header?['format'] as String? ?? '').toUpperCase();
            final headerType = ['IMAGE', 'VIDEO', 'DOCUMENT'].contains(headerFormat) ? headerFormat : '';
            final body = components.firstWhere(
              (c) => (c['type'] as String? ?? '').toUpperCase() == 'BODY',
              orElse: () => null,
            );
            final bodyText = body?['text'] as String? ?? '';
            final varCount = RegExp(r'\{\{\d+\}\}').allMatches(bodyText).map((m) => m.group(0)).toSet().length;
            return {
              'name': t['name']?.toString() ?? '',
              'language': lang,
              'headerType': headerType,
              'varCount': varCount.toString(),
            };
          })
          .where((t) => t['name']!.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _clientTrigger = trigger;
          _clientTemplates = approved;
          _clientTriggerLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _clientTriggerLoading = false);
    }
  }

  Future<void> _toggleClientTrigger(bool newValue) async {
    try {
      final repo = ClientTriggerRepository(_dio);
      final updated = await repo.updateTrigger(isActive: newValue);
      if (mounted) setState(() => _clientTrigger = updated);
    } catch (e) {
      _showToast('Failed to update: $e', isError: true);
    }
  }

  Future<void> _deleteClientTrigger() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client Auto-Message?'),
        content: const Text('New clients will no longer receive an automatic WhatsApp message.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repo = ClientTriggerRepository(_dio);
      await repo.deleteTrigger();
      if (mounted) setState(() => _clientTrigger = null);
      _showToast('Client auto-message removed');
    } catch (e) {
      _showToast('Failed to delete: $e', isError: true);
    }
  }

  void _openClientTriggerPicker() {
    String? selectedName;
    String selectedLang = 'en_US';
    String? selectedHeaderType;
    int varCount = 0;
    Map<String, String> varMapping = {};
    PlatformFile? pickedMedia;
    bool uploadingMedia = false;

    const clientFields = [
      {'value': 'name',        'label': 'Name'},
      {'value': 'mobileNumber','label': 'Mobile Number'},
      {'value': 'companyName', 'label': 'Company Name'},
      {'value': 'emailId',     'label': 'Email'},
      {'value': 'venue',       'label': 'Venue'},
      {'value': 'remark',      'label': 'Remark'},
    ];

    if (_clientTrigger != null) {
      selectedName = _clientTrigger!.templateName.isNotEmpty ? _clientTrigger!.templateName : null;
      selectedLang = _clientTrigger!.templateLanguage;
      varMapping = Map<String, String>.from(_clientTrigger!.variableMapping);
      if (selectedName != null) {
        final match = _clientTemplates.firstWhere(
          (t) => t['name'] == selectedName,
          orElse: () => {'headerType': '', 'varCount': '0'},
        );
        final ht = match['headerType'] ?? '';
        selectedHeaderType = ht.isNotEmpty ? ht : null;
        varCount = int.tryParse(match['varCount'] ?? '0') ?? 0;
      }
    }

    Future<void> pickFile(String headerType, StateSetter setDialogState) async {
      FileType type = FileType.custom;
      List<String> extensions;
      if (headerType == 'IMAGE') {
        extensions = ['jpg', 'jpeg', 'png'];
      } else if (headerType == 'VIDEO') {
        extensions = ['mp4'];
      } else {
        extensions = ['pdf'];
      }

      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: extensions,
        withData: true,
        allowMultiple: false,
      );
      if (result == null) return;

      final file = result.files.first;
      String? error;
      if (headerType == 'IMAGE') {
        error = MediaValidator.validateImage(file);
      } else if (headerType == 'VIDEO') {
        error = MediaValidator.validateVideo(file);
      } else {
        error = MediaValidator.validateDocument(file);
      }

      if (error != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      setDialogState(() => pickedMedia = file);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Set Up Client Auto-Message', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a WhatsApp template to send automatically when a new client is added.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Text('Template', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  _clientTemplates.isEmpty
                      ? const Text('No approved templates found.', style: TextStyle(color: Colors.grey, fontSize: 13))
                      : DropdownButtonFormField<String>(
                          initialValue: selectedName,
                          hint: const Text('Select a template'),
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: _clientTemplates
                              .map((t) => DropdownMenuItem(value: t['name'], child: Text(t['name']!)))
                              .toList(),
                          onChanged: (v) {
                            setDialogState(() {
                              selectedName = v;
                              final match = _clientTemplates.firstWhere(
                                (t) => t['name'] == v,
                                orElse: () => {'language': 'en_US', 'headerType': '', 'varCount': '0'},
                              );
                              selectedLang = match['language'] ?? 'en_US';
                              final ht = match['headerType'] ?? '';
                              selectedHeaderType = ht.isNotEmpty ? ht : null;
                              if (selectedHeaderType == null) pickedMedia = null;
                              varCount = int.tryParse(match['varCount'] ?? '0') ?? 0;
                              varMapping = {};
                            });
                          },
                        ),
                  if (selectedHeaderType != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${selectedHeaderType![0]}${selectedHeaderType!.substring(1).toLowerCase()} File',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => pickFile(selectedHeaderType!, setDialogState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedHeaderType == 'IMAGE' ? Icons.image : selectedHeaderType == 'VIDEO' ? Icons.play_circle : Icons.description,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pickedMedia?.name ?? 'Select ${selectedHeaderType![0]}${selectedHeaderType!.substring(1).toLowerCase()} file',
                                style: TextStyle(fontSize: 13, color: pickedMedia == null ? Colors.black54 : Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (pickedMedia != null)
                              GestureDetector(
                                onTap: () => setDialogState(() => pickedMedia = null),
                                child: const Icon(Icons.close, size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (varCount > 0) ...[
                    const SizedBox(height: 12),
                    const Text('Variable Mapping', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text(
                      'Map each template variable to a client field.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    for (int i = 1; i <= varCount; i++) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text('{{$i}}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: varMapping[i.toString()],
                              hint: const Text('Select field'),
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: clientFields
                                  .map((f) => DropdownMenuItem(value: f['value'], child: Text(f['label']!)))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => varMapping[i.toString()] = v ?? ''),
                            ),
                          ),
                        ],
                      ),
                      if (i < varCount) const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (selectedName == null || uploadingMedia)
                  ? null
                  : () async {
                      if (selectedHeaderType != null && pickedMedia == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a media file for this template')),
                        );
                        return;
                      }
                      setDialogState(() => uploadingMedia = true);
                      String uploadedMediaId = '';
                      String uploadedMediaType = '';
                      if (selectedHeaderType != null && pickedMedia != null) {
                        try {
                          final repo = getIt<WhatsAppRepository>();
                          uploadedMediaId = await repo.uploadMedia(pickedMedia!);
                          uploadedMediaType = selectedHeaderType!;
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Media upload failed: $e')),
                            );
                          }
                          setDialogState(() => uploadingMedia = false);
                          return;
                        }
                      }
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      try {
                        final repo = ClientTriggerRepository(_dio);
                        final created = await repo.createTrigger(
                          templateName: selectedName!,
                          language: selectedLang,
                          mediaId: uploadedMediaId,
                          mediaType: uploadedMediaType,
                          variableMapping: varMapping,
                        );
                        if (mounted) {
                          setState(() => _clientTrigger = created);
                          _showToast('Client auto-message configured');
                        }
                      } catch (e) {
                        _showToast('Failed to save: $e', isError: true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: uploadingMedia
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String get _webhookUrl =>
      '${AppConstants.baseUrl}/api/leads/webhook/$_tenantId';

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _regenerateSecret() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Secret?'),
        content: const Text(
          'This will invalidate your current webhook secret. Any existing integrations using the old secret will stop working until updated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await _dio.post('/api/leads/webhook-secret/generate');
      if (res.statusCode == 200) {
        _showToast('New secret generated.');
        await _fetchSecret();
      }
    } catch (e) {
      _showToast('Failed to regenerate: $e', isError: true);
    }
  }

  Future<void> _toggleTrigger(LeadTriggerModel trigger) async {
    try {
      await _dio.put('/api/leads/triggers/${trigger.id}', data: {
        ...trigger.toJson(),
        'isActive': !trigger.isActive,
      });
      await _fetchTriggers();
    } catch (e) {
      _showToast('Failed to update trigger: $e', isError: true);
    }
  }

  Future<void> _deleteTrigger(LeadTriggerModel trigger) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trigger?'),
        content: const Text('This trigger will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dio.delete('/api/leads/triggers/${trigger.id}');
      await _fetchTriggers();
      _showToast('Trigger deleted');
    } catch (e) {
      _showToast('Failed to delete: $e', isError: true);
    }
  }

  void _openAddTriggerForm({LeadTriggerModel? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _TriggerFormDialog(
        existing: existing,
        chatbots: _chatbots,
        onSave: (data) async {
          try {
            if (existing != null) {
              await _dio.put('/api/leads/triggers/${existing.id}', data: data);
            } else {
              await _dio.post('/api/leads/triggers', data: data);
            }
            await _fetchTriggers();
            _showToast(existing != null ? 'Trigger updated' : 'Trigger created');
          } catch (e) {
            _showToast('Failed to save trigger: $e', isError: true);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 450,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_rounded, size: 40, color: AppTheme.secondaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Integrations',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This section is password protected.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Enter Password', style: TextStyle(fontSize: 15)),
                      onPressed: _showPasswordDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Integrations',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _isUnlocked = false),
                  icon: const Icon(Icons.lock_rounded, size: 16),
                  label: const Text('Lock'),
                  style: TextButton.styleFrom(foregroundColor: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _WebhookSection(
              webhookUrl: _webhookUrl,
              secret: _displaySecret,
              loadingSecret: _loadingSecret,
              onRegenerate: _regenerateSecret,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, cardConstraints) {
                final isMobileCard = cardConstraints.maxWidth < 550;
                if (isMobileCard) {
                  return Column(
                    children: [
                      _ShopifyCard(
                        webhookUrl: _webhookUrl,
                        secret: _displaySecret,
                      ),
                      const SizedBox(height: 16),
                      _WordPressCard(
                        webhookUrl: _webhookUrl,
                        secret: _displaySecret,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ShopifyCard(
                        webhookUrl: _webhookUrl,
                        secret: _displaySecret,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _WordPressCard(
                        webhookUrl: _webhookUrl,
                        secret: _displaySecret,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _TriggersSection(
              triggers: _triggers,
              loading: _loadingTriggers,
              onAdd: () => _openAddTriggerForm(),
              onEdit: (t) => _openAddTriggerForm(existing: t),
              onToggle: _toggleTrigger,
              onDelete: _deleteTrigger,
            ),
            const SizedBox(height: 24),
            _ClientAutoMessageSection(
              trigger: _clientTrigger,
              loading: _clientTriggerLoading,
              onSetUp: _openClientTriggerPicker,
              onToggle: _toggleClientTrigger,
              onDelete: _deleteClientTrigger,
            ),
            const SizedBox(height: 24),
            _OpenAIKeySection(
              tenantId: _tenantId,
              dio: _dio,
              onToast: _showToast,
            ),
          ],
        ),
      );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Webhook section
// ---------------------------------------------------------------------------

class _WebhookSection extends StatelessWidget {
  final String webhookUrl;
  final String secret;
  final bool loadingSecret;
  final VoidCallback onRegenerate;

  const _WebhookSection({
    required this.webhookUrl,
    required this.secret,
    required this.loadingSecret,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Webhook Configuration',
      icon: Icons.webhook_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Webhook URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: webhookUrl),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Webhook Secret', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: loadingSecret ? '' : (secret.isEmpty ? 'No secret configured — click Regenerate' : secret),
                  ),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    suffixIcon: loadingSecret
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                ),
              ),
              if (!loadingSecret && secret.isEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Generate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondaryColor,
                    side: const BorderSide(color: AppTheme.secondaryColor),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shopify card
// ---------------------------------------------------------------------------

class _ShopifyCard extends StatelessWidget {
  final String webhookUrl;
  final String secret;

  const _ShopifyCard({required this.webhookUrl, required this.secret});

  String _buildScript(String url, String s) => '''<script>
document.addEventListener("DOMContentLoaded", function () {
  const form = document.querySelector('.contact-form__form');
  if (!form) return;

  form.addEventListener("submit", async function (e) {
    e.preventDefault();

    const formData = new FormData(form);
    const data = {};
    formData.forEach((value, key) => { data[key] = value; });

    const cleanedData = {
      name:      data["contact[name]"]    || "",
      email:     data["contact[email]"]   || "",
      phone:     data["contact[phone]"]   || "",
      company:   data["contact[company]"] || "",
      message:   data["contact[body]"]    || "",
      form_name: "Shopify Contact Form",
      source:    "shopify"
    };

    try {
      const response = await fetch("$url", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Webhook-Secret": "$s"
        },
        body: JSON.stringify(cleanedData),
      });
      console.log("Webhook sent:", response.status);
    } catch (error) {
      console.error("Webhook error:", error);
    }

    form.submit();
  });
});
</script>''';

  @override
  Widget build(BuildContext context) {
    final snippet = _buildScript(webhookUrl, secret);

    return _Card(
      title: 'Shopify Integration',
      icon: Icons.shopping_bag_rounded,
      iconColor: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Capture leads from your Shopify contact form by adding a script to contact_form.liquid.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          const Text('Setup Instructions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const _InstructionStep(step: '1', text: 'In Shopify Admin, go to Online Store → Themes → Edit Code.'),
          const _InstructionStep(step: '2', text: 'Open Sections → contact-form.liquid (or templates/contact.liquid).'),
          const _InstructionStep(step: '3', text: 'Paste the script below'),
          const _InstructionStep(step: '4', text: 'Save the file. The webhook URL and secret are already filled in.'),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Liquid Script', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                snippet,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: Color(0xFFCDD6F4),
                  height: 1.6,
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
// WordPress card
// ---------------------------------------------------------------------------

class _WordPressCard extends StatelessWidget {
  final String webhookUrl;
  final String secret;

  const _WordPressCard({
    required this.webhookUrl,
    required this.secret,
  });

  String _buildSnippet(String url, String s) => """add_action('wpcf7_before_send_mail', function(\$contact_form) {
    \$submission = WPCF7_Submission::get_instance();
    if (!\$submission) return;
    \$data = \$submission->get_posted_data();
    \$data['form_name'] = \$contact_form->title();
    \$response = wp_remote_post('$url', [
        'timeout'  => 15,
        'blocking' => true,
        'headers'  => [
            'Content-Type'     => 'application/json',
            'X-Webhook-Secret' => '$s',
        ],
        'body' => json_encode(\$data),
    ]);
    if (is_wp_error(\$response)) {
        error_log('Webhook WP_Error: ' . \$response->get_error_message());
    } else {
        error_log('Webhook status: ' . wp_remote_retrieve_response_code(\$response));
        error_log('Webhook body: '   . wp_remote_retrieve_body(\$response));
        error_log('Webhook data sent: ' . json_encode(\$data));
    }
});

add_filter('wpcf7_skip_mail', '__return_true');

add_action('wpcf7_before_send_mail', function(\$contact_form) {
    error_log('CF7 hook fired for: ' . \$contact_form->title());
}, 1);""";

  @override
  Widget build(BuildContext context) {
    final hasUrl = webhookUrl.isNotEmpty;
    final hasSecret = secret.isNotEmpty;
    final displaySnippet = _buildSnippet(
      hasUrl ? webhookUrl : 'WEBHOOK_URL',
      hasSecret ? secret : 'YOUR_SECRET',
    );

    return _Card(
      title: 'WordPress Integration',
      icon: Icons.language_rounded,
      iconColor: Colors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect Contact Form 7, Gravity Forms, WooCommerce, or any WordPress form to capture leads.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          const Text('Setup Instructions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const _InstructionStep(step: '1', text: 'Copy the PHP snippet below (values are pre-filled) into your theme\'s functions.php.'),
          const _InstructionStep(step: '2', text: 'For WooCommerce, use the woocommerce_new_order hook instead.'),
          const _InstructionStep(step: '3', text: 'Leads are captured before CF7 sends mail — works even if mail is not configured.'),
          if (!hasSecret)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Generate a webhook secret first to pre-fill the snippet.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text('PHP Snippet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              displaySnippet,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFD4D4D4),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Triggers section
// ---------------------------------------------------------------------------

class _TriggersSection extends StatelessWidget {
  final List<LeadTriggerModel> triggers;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<LeadTriggerModel> onEdit;
  final ValueChanged<LeadTriggerModel> onToggle;
  final ValueChanged<LeadTriggerModel> onDelete;

  const _TriggersSection({
    required this.triggers,
    required this.loading,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Lead Triggers',
      icon: Icons.bolt_rounded,
      trailing: ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Trigger'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : triggers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No triggers configured. Add one to auto-send WhatsApp messages when leads arrive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black45, fontSize: 13),
                    ),
                  ),
                )
              : Column(
                  children: triggers
                      .map((t) => _TriggerRow(
                            trigger: t,
                            onEdit: () => onEdit(t),
                            onToggle: () => onToggle(t),
                            onDelete: () => onDelete(t),
                          ))
                      .toList(),
                ),
    );
  }
}

class _TriggerRow extends StatelessWidget {
  final LeadTriggerModel trigger;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TriggerRow({
    required this.trigger,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final actionLabel = trigger.action == 'send_template'
        ? 'Send Template: ${trigger.templateName}'
        : 'Start Chatbot';
    final sourceLabel = trigger.source == 'any' ? 'Any Source' : trigger.source;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SmallBadge(label: sourceLabel, color: AppTheme.secondaryColor),
                    if (trigger.formName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _SmallBadge(label: trigger.formName, color: Colors.purple),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(actionLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Switch(
            value: trigger.isActive,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppTheme.primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: onEdit,
            tooltip: 'Edit',
            color: Colors.grey.shade600,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 18),
            onPressed: onDelete,
            tooltip: 'Delete',
            color: Colors.red.shade400,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add/Edit Trigger form dialog
// ---------------------------------------------------------------------------

class _TriggerFormDialog extends StatefulWidget {
  final LeadTriggerModel? existing;
  final List<Map<String, dynamic>> chatbots;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _TriggerFormDialog({
    required this.existing,
    required this.chatbots,
    required this.onSave,
  });

  @override
  State<_TriggerFormDialog> createState() => _TriggerFormDialogState();
}

class _TriggerFormDialogState extends State<_TriggerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _source;
  final TextEditingController _formNameCtrl = TextEditingController();
  bool _saving = false;

  // Template dropdown state
  List<Map<String, String>> _templates = []; // [{name, language, headerType}]
  bool _loadingTemplates = false;
  String? _selectedTemplateName;
  String? _selectedTemplateLanguage;
  String? _selectedHeaderType;

  // Variable mapping state
  int _varCount = 0;
  Map<String, String> _varMapping = {}; // {"1": "name", "2": "mobileNumber"}

  // Media picker state
  PlatformFile? _pickedMedia;
  bool _uploadingMedia = false;

  // Available lead fields for variable mapping
  static const List<Map<String, String>> _leadFields = [
    {'value': 'name',        'label': 'Name'},
    {'value': 'mobileNumber','label': 'Mobile Number'},
    {'value': 'email',       'label': 'Email'},
    {'value': 'companyName', 'label': 'Company Name'},
    {'value': 'formName',    'label': 'Form Name'},
    {'value': 'source',      'label': 'Source'},
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _source = e?.source ?? 'any';
    _formNameCtrl.text = e?.formName ?? '';
    _selectedTemplateName = e?.templateName.isNotEmpty == true ? e!.templateName : null;
    _selectedTemplateLanguage = e?.templateLanguage.isNotEmpty == true ? e!.templateLanguage : null;
    _varMapping = Map<String, String>.from(e?.variableMapping ?? {});
    _fetchTemplates();
  }

  @override
  void dispose() {
    _formNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final dio = getIt<Dio>();
      final res = await dio.get('/fetch-templates');
      if (res.statusCode == 200) {
        final list = (res.data['data'] as List<dynamic>? ?? []);
        final approved = list
            .where((t) => (t['status'] as String? ?? '').toUpperCase() == 'APPROVED')
            .where((t) => (t['category'] as String? ?? '').toUpperCase() != 'AUTHENTICATION')
            .map((t) {
              final components = t['components'] as List<dynamic>? ?? [];
              final lang = t['language']?.toString() ?? 'en_US';
              final header = components.firstWhere(
                (c) => (c['type'] as String? ?? '').toUpperCase() == 'HEADER',
                orElse: () => null,
              );
              final headerFormat = (header?['format'] as String? ?? '').toUpperCase();
              final headerType = ['IMAGE', 'VIDEO', 'DOCUMENT'].contains(headerFormat) ? headerFormat : '';
              // Count {{N}} variables in body text
              final body = components.firstWhere(
                (c) => (c['type'] as String? ?? '').toUpperCase() == 'BODY',
                orElse: () => null,
              );
              final bodyText = body?['text'] as String? ?? '';
              final varMatches = RegExp(r'\{\{\d+\}\}').allMatches(bodyText);
              final varCount = varMatches.map((m) => m.group(0)).toSet().length;
              return {
                'name': t['name']?.toString() ?? '',
                'language': lang,
                'headerType': headerType,
                'varCount': varCount.toString(),
              };
            })
            .where((t) => t['name']!.isNotEmpty)
            .toList();
        setState(() {
          _templates = approved;
          if (_selectedTemplateName != null) {
            final match = _templates.firstWhere(
              (t) => t['name'] == _selectedTemplateName,
              orElse: () => {'headerType': '', 'varCount': '0'},
            );
            _selectedHeaderType = (match['headerType'] ?? '').isNotEmpty ? match['headerType'] : null;
            _varCount = int.tryParse(match['varCount'] ?? '0') ?? 0;
          }
        });
      }
    } catch (_) {
      // non-critical
    } finally {
      setState(() => _loadingTemplates = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHeaderType != null && _pickedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a media file for this template')),
      );
      return;
    }
    setState(() => _saving = true);
    String uploadedMediaId = widget.existing?.mediaId ?? '';
    String uploadedMediaType = widget.existing?.mediaType ?? '';
    if (_selectedHeaderType != null && _pickedMedia != null) {
      try {
        setState(() => _uploadingMedia = true);
        final repo = getIt<WhatsAppRepository>();
        uploadedMediaId = await repo.uploadMedia(_pickedMedia!);
        uploadedMediaType = _selectedHeaderType!;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Media upload failed: $e')),
          );
        }
        setState(() { _saving = false; _uploadingMedia = false; });
        return;
      } finally {
        if (mounted) setState(() => _uploadingMedia = false);
      }
    }
    final data = {
      'source': _source,
      'formName': _formNameCtrl.text.trim(),
      'action': 'send_template',
      'templateName': _selectedTemplateName ?? '',
      'templateLanguage': _selectedTemplateLanguage ?? 'en_US',
      'mediaId': _selectedHeaderType != null ? uploadedMediaId : '',
      'mediaType': _selectedHeaderType != null ? uploadedMediaType : '',
      'variableMapping': _varMapping,
      'isActive': true,
    };
    await widget.onSave(data);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing != null ? 'Edit Trigger' : 'Add Trigger',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Source
              const Text('Source', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _source,
                decoration: _inputDecoration('Source'),
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('Any')),
                  DropdownMenuItem(value: 'shopify', child: Text('Shopify')),
                  DropdownMenuItem(value: 'wordpress', child: Text('WordPress')),
                ],
                onChanged: (v) => setState(() => _source = v ?? 'any'),
              ),
              const SizedBox(height: 12),
              // Form name filter
              const Text('Form Name Filter (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _formNameCtrl,
                decoration: _inputDecoration('Leave empty to match all forms'),
              ),
              const SizedBox(height: 12),
              // Template
              const Text('Template', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              _loadingTemplates
                  ? const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedTemplateName,
                      decoration: _inputDecoration('Select a template'),
                      isExpanded: true,
                      items: _templates
                          .map((t) => DropdownMenuItem<String>(
                                value: t['name'],
                                child: Text(t['name']!, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedTemplateName = v;
                          final match = _templates.firstWhere(
                            (t) => t['name'] == v,
                            orElse: () => {'language': 'en_US', 'headerType': '', 'varCount': '0'},
                          );
                          _selectedTemplateLanguage = match['language'];
                          final ht = match['headerType'] ?? '';
                          _selectedHeaderType = ht.isNotEmpty ? ht : null;
                          if (_selectedHeaderType == null) _pickedMedia = null;
                          _varCount = int.tryParse(match['varCount'] ?? '0') ?? 0;
                          _varMapping = {};
                        });
                      },
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
              if (_selectedHeaderType != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${_selectedHeaderType![0]}${_selectedHeaderType!.substring(1).toLowerCase()} File',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                _buildMediaPicker(_selectedHeaderType!),
              ],
              if (_varCount > 0) ...[
                const SizedBox(height: 12),
                const Text('Variable Mapping', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                const Text(
                  'Map each template variable to a lead field.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                for (int i = 1; i <= _varCount; i++) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text('{{$i}}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _varMapping[i.toString()],
                          decoration: _inputDecoration('Select field'),
                          isExpanded: true,
                          items: _leadFields
                              .map((f) => DropdownMenuItem(value: f['value'], child: Text(f['label']!)))
                              .toList(),
                          onChanged: (v) => setState(() => _varMapping[i.toString()] = v ?? ''),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  if (i < _varCount) const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (_saving || _uploadingMedia) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: (_saving || _uploadingMedia)
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      );

  Widget _buildMediaPicker(String headerType) {
    return GestureDetector(
      onTap: () => _pickMediaFile(headerType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              headerType == 'IMAGE' ? Icons.image : headerType == 'VIDEO' ? Icons.play_circle : Icons.description,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _pickedMedia?.name ?? 'Select ${headerType[0]}${headerType.substring(1).toLowerCase()} file',
                style: TextStyle(fontSize: 13, color: _pickedMedia == null ? Colors.black54 : Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_pickedMedia != null)
              GestureDetector(
                onTap: () => setState(() => _pickedMedia = null),
                child: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMediaFile(String headerType) async {
    FileType type = FileType.any;
    List<String>? extensions;
    if (headerType == 'IMAGE') {
      type = FileType.custom;
      extensions = ['jpg', 'jpeg', 'png'];
    } else if (headerType == 'VIDEO') {
      type = FileType.custom;
      extensions = ['mp4'];
    } else if (headerType == 'DOCUMENT') {
      type = FileType.custom;
      extensions = ['pdf'];
    }

    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: extensions,
      withData: true,
      allowMultiple: false,
    );
    if (result == null) return;

    final file = result.files.first;
    String? error;
    if (headerType == 'IMAGE') {
      error = MediaValidator.validateImage(file);
    } else if (headerType == 'VIDEO') {
      error = MediaValidator.validateVideo(file);
    } else if (headerType == 'DOCUMENT') {
      error = MediaValidator.validateDocument(file);
    }

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    setState(() => _pickedMedia = file);
  }
}

// ---------------------------------------------------------------------------
// Client Auto-Message section
// ---------------------------------------------------------------------------

class _ClientAutoMessageSection extends StatelessWidget {
  final ClientTriggerModel? trigger;
  final bool loading;
  final VoidCallback onSetUp;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ClientAutoMessageSection({
    required this.trigger,
    required this.loading,
    required this.onSetUp,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Client Auto-Message',
      icon: Icons.person_add_alt_1_rounded,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : trigger == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Automatically send a WhatsApp template when a new client is added — via the app, bulk import, or QR registration.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: onSetUp,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Set Up Auto-Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                )
              : _ClientTriggerRow(
                  trigger: trigger!,
                  onToggle: onToggle,
                  onDelete: onDelete,
                ),
    );
  }
}

class _ClientTriggerRow extends StatelessWidget {
  final ClientTriggerModel trigger;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ClientTriggerRow({
    required this.trigger,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SmallBadge(label: 'All Paths', color: AppTheme.secondaryColor),
                    const SizedBox(width: 6),
                    _SmallBadge(label: trigger.templateLanguage, color: Colors.purple),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Send Template: ${trigger.templateName}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Switch(
            value: trigger.isActive,
            onChanged: onToggle,
            activeThumbColor: AppTheme.primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 18),
            onPressed: onDelete,
            tooltip: 'Delete',
            color: Colors.red.shade400,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OpenAI Key section
// ---------------------------------------------------------------------------

class _OpenAIKeySection extends StatefulWidget {
  final String tenantId;
  final Dio dio;
  final void Function(String message, {bool isError}) onToast;

  const _OpenAIKeySection({
    required this.tenantId,
    required this.dio,
    required this.onToast,
  });

  @override
  State<_OpenAIKeySection> createState() => _OpenAIKeySectionState();
}

class _OpenAIKeySectionState extends State<_OpenAIKeySection> {
  final TextEditingController _keyController = TextEditingController();
  bool _obscure = true;
  bool _loading = true;
  bool _saving = false;
  bool _revealing = false;
  bool _isMasked = false;
  String _revealedKey = '';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _fetchKeyStatus();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _fetchKeyStatus() async {
    setState(() => _loading = true);
    try {
      final res = await widget.dio.get('/api/tenant/openai-key-status');
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final configured = data['configured'] == true;
        final maskedKey = data['maskedKey']?.toString() ?? '';
        if (configured && maskedKey.isNotEmpty) {
          _isMasked = true;
          _revealedKey = '';
          _keyController.text = maskedKey;
        }
      }
    } catch (_) {
      // Non-critical — field stays empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleVisibility() async {
    if (!_obscure) {
      setState(() => _obscure = true);
      return;
    }

    // User wants to reveal key
    if (_isMasked && _revealedKey.isEmpty) {
      setState(() => _revealing = true);
      try {
        final res = await widget.dio.get('/api/tenant/openai-key/reveal');
        if (res.statusCode == 200) {
          final data = res.data as Map<String, dynamic>;
          final fullKey = data['key']?.toString() ?? '';
          _revealedKey = fullKey;
          _keyController.text = fullKey;
          _isMasked = false;
        }
      } catch (_) {
        // Fallback
      } finally {
        if (mounted) {
          setState(() {
            _revealing = false;
            _obscure = false;
          });
        }
      }
    } else {
      setState(() => _obscure = false);
    }
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _validationError = 'API key cannot be empty');
      return;
    }
    if (_isMasked && _revealedKey.isEmpty) {
      widget.onToast('API key is unchanged');
      return;
    }
    setState(() {
      _validationError = null;
      _saving = true;
    });
    try {
      final res = await widget.dio.put('/api/tenant/openai-key', data: {'apiKey': key});
      if (res.statusCode == 200) {
        _isMasked = false;
        _revealedKey = key;
        widget.onToast('OpenAI API key saved successfully');
      } else {
        widget.onToast('Failed to save API key', isError: true);
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?.toString() ?? 'Failed to save API key';
      widget.onToast(msg, isError: true);
    } catch (_) {
      widget.onToast('Failed to save API key', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'OpenAI API Key',
      icon: Icons.key_rounded,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your OpenAI API key to enable the AI template assistant.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                const Text('API Key', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _keyController,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  onChanged: (val) {
                    _isMasked = false;
                    _revealedKey = val;
                    if (_validationError != null) {
                      setState(() => _validationError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'sk-...',
                    errorText: _validationError,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    suffixIcon: _revealing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: _toggleVisibility,
                            tooltip: _obscure ? 'Show key' : 'Hide key',
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper widgets
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final Widget? trailing;

  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? AppTheme.secondaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String step;
  final String text;

  const _InstructionStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(step, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
