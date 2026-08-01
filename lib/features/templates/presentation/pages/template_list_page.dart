import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendzyy/features/templates/presentation/bloc/template_bloc.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/features/templates/presentation/widgets/whatsapp_preview.dart';
import 'package:sendzyy/features/templates/presentation/pages/create_template_page.dart';
import 'package:sendzyy/features/templates/presentation/pages/test_template_page.dart' show TestTemplateDialog;
import 'package:sendzyy/core/di/injection.dart';
import 'package:sendzyy/features/chat/data/services/socket_service.dart';
import 'package:dio/dio.dart';

class TemplateListPage extends StatefulWidget {
  const TemplateListPage({super.key});

  @override
  State<TemplateListPage> createState() => _TemplateListPageState();
}

class _TemplateListPageState extends State<TemplateListPage> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _templateSubscription;

  static const _categories = ['ALL', 'MARKETING', 'UTILITY', 'AUTHENTICATION'];

  @override
  void initState() {
    super.initState();
    _templateSubscription = getIt<SocketService>().templateUpdateStream.listen((data) {
      if (mounted) {
        final name = data['name'];
        final status = data['status'];
        final reason = data['reason'];
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'APPROVED'
                  ? '🎉 Template "$name" was APPROVED!'
                  : '❌ Template "$name" was REJECTED${reason != null ? ": $reason" : ""}',
            ),
            backgroundColor: status == 'APPROVED' ? Colors.green : Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        
        context.read<TemplateBloc>().add(FetchTemplates());
      }
    });
  }

  @override
  void dispose() {
    _templateSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateTemplatePage()),
        ),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('CREATE TEMPLATE'),
      ),
      body: BlocBuilder<TemplateBloc, TemplateState>(
        builder: (context, state) {
          if (state is TemplateLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TemplateLoaded) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Templates',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.secondaryColor,
                                      ),
                                ),
                                IconButton(
                                  onPressed: () => context.read<TemplateBloc>().add(FetchTemplates()),
                                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.secondaryColor),
                                  tooltip: 'Sync with Meta',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                context.read<TemplateBloc>().add(SearchTemplates(val));
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                hintText: 'Search templates...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          context.read<TemplateBloc>().add(SearchTemplates(''));
                                          setState(() {});
                                        },
                                      )
                                    : Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Message Templates',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                  ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) {
                                    context.read<TemplateBloc>().add(SearchTemplates(val));
                                    setState(() {});
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search templates...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              context.read<TemplateBloc>().add(SearchTemplates(''));
                                              setState(() {});
                                            },
                                          )
                                        : Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                                  ),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => context.read<TemplateBloc>().add(FetchTemplates()),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Sync with Meta'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                minimumSize: const Size(150, 45),
                              ),
                            ),
                          ],
                        ),

                  const SizedBox(height: 16),

                  // Category filter chips
                  isMobile
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories.map((cat) {
                              final isSelected = cat == 'ALL'
                                  ? state.selectedCategory == null
                                  : state.selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(
                                    cat == 'ALL' ? 'All' : _categoryLabel(cat),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    context.read<TemplateBloc>().add(
                                          FilterByCategory(cat == 'ALL' ? null : cat),
                                        );
                                  },
                                  selectedColor: AppTheme.primaryColor,
                                  checkmarkColor: Colors.white,
                                  backgroundColor: Colors.grey.shade100,
                                  side: BorderSide(
                                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                                  ),
                                  showCheckmark: false,
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          children: _categories.map((cat) {
                            final isSelected = cat == 'ALL'
                                ? state.selectedCategory == null
                                : state.selectedCategory == cat;
                            return FilterChip(
                              label: Text(
                                cat == 'ALL' ? 'All' : _categoryLabel(cat),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                context.read<TemplateBloc>().add(
                                      FilterByCategory(cat == 'ALL' ? null : cat),
                                    );
                              },
                              selectedColor: AppTheme.primaryColor,
                              checkmarkColor: Colors.white,
                              backgroundColor: Colors.grey.shade100,
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                              ),
                              showCheckmark: false,
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 24),
                  state.filteredTemplates.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: Text('No templates found.'),
                          ),
                        )
                      : isMobile
                          ? Column(
                              children: state.filteredTemplates.map((template) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildTemplateCard(context, template),
                                );
                              }).toList(),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 220,
                              ),
                              itemCount: state.filteredTemplates.length,
                              itemBuilder: (context, index) {
                                final template = state.filteredTemplates[index];
                                return _buildTemplateCard(context, template);
                              },
                            ),
                ],
              ),
            );
          } else if (state is TemplateError) {
            String errorMessage = state.message;
            bool isAuthError = errorMessage.contains('400') || 
                               errorMessage.contains('401') || 
                               errorMessage.contains('403') || 
                               errorMessage.toLowerCase().contains('bad response');
            
            if (isAuthError) {
              errorMessage = 'Please connect your Meta account first and verify your settings to view templates.';
            } else if (errorMessage.contains('DioException') || errorMessage.contains('SocketException') || errorMessage.contains('Exception:')) {
              errorMessage = 'Failed to fetch templates. Please check your connection and Meta settings.';
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAuthError ? Icons.link_off : Icons.error_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(child: Text('Start syncing to see templates'));
        },
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'MARKETING': return 'Marketing';
      case 'UTILITY': return 'Utility';
      case 'AUTHENTICATION': return 'Authentication';
      default: return cat;
    }
  }

  Widget _buildTemplateCard(
    BuildContext context,
    Map<String, dynamic> template,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final name = template['name'] ?? 'Unknown';
    final status = template['status'] ?? 'UNKNOWN';
    final category = template['category'] ?? 'MARKETING';
    final language = template['language'] ?? 'en';
    final components = template['components'] as List<dynamic>? ?? [];

    String bodyText = 'No body content';
    for (var comp in components) {
      if (comp['type'] == 'BODY') {
        bodyText = comp['text'] ?? bodyText;
        break;
      }
    }

    Color statusColor = status == 'APPROVED'
        ? Colors.green
        : (status == 'PENDING' ? Colors.orange : Colors.red);

    final isAuth = category == 'AUTHENTICATION';

    final card = Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 12,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  category,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(Icons.translate, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  language,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 16),
            isMobile
                ? Text(
                    bodyText,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  )
                : Expanded(
                    child: Text(
                      bodyText,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'REJECTED') ...[
                  TextButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => RejectionDetailsDialog(templateName: name),
                    ),
                    icon: const Icon(Icons.error_outline, size: 16),
                    label: const Text('Fix Help', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (isAuth && status == 'APPROVED') ...[
                  TextButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => TestTemplateDialog(
                        templateName: name,
                        languageCode: language,
                      ),
                    ),
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Test', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                TextButton.icon(
                  onPressed: () => _showTemplatePreview(context, template),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, name),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return card;
  }

  void _showTemplatePreview(
    BuildContext context,
    Map<String, dynamic> template,
  ) {
    final components = template['components'] as List<dynamic>? ?? [];
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

    final isMobile = MediaQuery.of(context).size.width < 800;

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Template Preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: WhatsAppPreview(
                  headerText: header,
                  bodyText: body ?? '',
                  footerText: footer,
                  mediaType: mediaType,
                  buttons: buttons,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Template Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: WhatsAppPreview(
                  headerText: header,
                  bodyText: body ?? '',
                  footerText: footer,
                  mediaType: mediaType,
                  buttons: buttons,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String name) {
    final templateBloc = context.read<TemplateBloc>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              templateBloc.add(DeleteTemplate(name));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}

class RejectionDetailsDialog extends StatefulWidget {
  final String templateName;
  const RejectionDetailsDialog({super.key, required this.templateName});

  @override
  State<RejectionDetailsDialog> createState() => _RejectionDetailsDialogState();
}

class _RejectionDetailsDialogState extends State<RejectionDetailsDialog> {
  String? _reason;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReason();
  }

  Future<void> _fetchReason() async {
    try {
      final dio = getIt<Dio>();
      final resp = await dio.get('/template-rejection-reason/${widget.templateName}');
      if (mounted) {
        setState(() {
          _reason = resp.data['reason'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text('Template Rejected: ${widget.templateName}')),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 600
            ? MediaQuery.of(context).size.width * 0.85
            : 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_reason != null && _reason!.isNotEmpty) ...[
                  const Text(
                    'Meta Rejection Reason:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Text(
                      _reason!,
                      style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const Text(
                    'No specific rejection reason returned by Meta. This usually happens for older template requests or automated reviews.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Common Rejection Causes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildTipRow('Incorrect Category: Submitting promotional/marketing text under "Utility" or "Authentication".'),
                _buildTipRow('Variable Formatting: Placeholders must look like {{1}}, {{2}} in order and cannot contain special characters/letters inside braces.'),
                _buildTipRow('Quality & Policy: Templates must follow Meta\'s Commerce and Business Policies (no drug sales, gambling, abusive content).'),
                _buildTipRow('Placeholder/Test Text: Submitting random strings like "dhhddh" or "Shendjdndjndn" is auto-rejected.'),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'What should you do?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                ),
                const SizedBox(height: 4),
                const Text(
                  '1. Delete this template using the Delete button on the card.\n'
                  '2. Create a new template with high-quality English/native language content.\n'
                  '3. Or appeal the decision directly in your Meta Business Suite.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ]
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  Widget _buildTipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

