import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/templates/data/models/auth_form_state.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/features/templates/presentation/widgets/auth_preview_widget.dart';
import 'package:iFloraBuzz/features/templates/presentation/widgets/authentication_form_widget.dart';
import 'package:iFloraBuzz/features/templates/presentation/widgets/category_selector_widget.dart';
import 'package:iFloraBuzz/features/templates/presentation/widgets/message_validity_period_widget.dart';
import 'package:iFloraBuzz/features/templates/presentation/widgets/whatsapp_preview.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/core/utils/media_validator.dart';
import 'package:iFloraBuzz/features/templates/presentation/widgets/assistant_dialog.dart';

class CreateTemplatePage extends StatefulWidget {
  const CreateTemplatePage({super.key});

  @override
  State<CreateTemplatePage> createState() => _CreateTemplatePageState();
}

class _CreateTemplatePageState extends State<CreateTemplatePage> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'MARKETING';
  String? _subCategory = 'DEFAULT';
  String _language = 'en_US';
  String _variableType = 'Number';
  String _mediaSample = 'NONE';
  final _nameController = TextEditingController();
  final _headerController = TextEditingController();
  final _bodyController = TextEditingController();
  final _footerController = TextEditingController();
  final List<Map<String, dynamic>> _buttons = [];
  int _currentStep = 0;
  PlatformFile? _selectedFile;
  AuthFormState _authFormState = const AuthFormState();
  int _validitySeconds = 0; // 0 means disabled

  @override
  void initState() {
    super.initState();
    _headerController.addListener(_onFieldChanged);
    _bodyController.addListener(_onFieldChanged);
    _footerController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _headerController.removeListener(_onFieldChanged);
    _bodyController.removeListener(_onFieldChanged);
    _footerController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _headerController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  final List<Map<String, String>> _languages = [
    {'code': 'en_US', 'name': 'English (US)'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'gu', 'name': 'Gujarati'},
    {'code': 'mr', 'name': 'Marathi'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Create WhatsApp Template'),
        elevation: 0,
      ),
      body: BlocConsumer<TemplateBloc, TemplateState>(
        listener: (context, state) {
          if (state is TemplateCreateSuccess) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Template submitted successfully!'),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
          } else if (state is TemplateError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          return LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 900;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: isWide ? 1200 : 700),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isWide ? 3 : 1,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildStepProgress(),
                                const SizedBox(height: 16),
                                if (_currentStep == 0) ...[
                                  _buildCard(
                                    title: 'Template Settings',
                                    icon: Icons.settings_outlined,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
                                        const SizedBox(height: 8),
                                        CategorySelectorWidget(
                                          selectedCategory: _category,
                                          onChanged: (category) {
                                            setState(() {
                                              _category = category;
                                              // Reset all Step 2 fields to defaults
                                              _headerController.clear();
                                              _bodyController.clear();
                                              _footerController.clear();
                                              _buttons.clear();
                                              _mediaSample = 'NONE';
                                              _selectedFile = null;
                                              _authFormState = const AuthFormState();
                                              _validitySeconds = 0;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        _buildLanguageSelection(),
                                        const SizedBox(height: 24),
                                        TextFormField(
                                          controller: _nameController,
                                          decoration: const InputDecoration(
                                            labelText: 'Template Name',
                                            hintText: 'welcome_message',
                                            prefixIcon: Icon(
                                              Icons.label_outline,
                                            ),
                                          ),
                                          validator: (val) {
                                            if (val == null || val.isEmpty)
                                              return 'Required';
                                            if (!RegExp(
                                              r'^[a-z0-9_]+$',
                                            ).hasMatch(val)) {
                                              return 'Only lowercase, numbers, and underscores';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  if (_category == 'AUTHENTICATION') ...[
                                    _buildCard(
                                      title: 'Content',
                                      icon: Icons.edit_note_outlined,
                                      child: AuthenticationFormWidget(
                                        initialState: _authFormState,
                                        onChanged: (state) => setState(() => _authFormState = state),
                                      ),
                                    ),
                                  ] else ...[
                                    _buildCard(
                                      title: 'Content',
                                      icon: Icons.edit_note_outlined,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Add a header, body and footer for your template. Cloud API hosted by Meta will review the template variables and content to protect the security and integrity of our services.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildVariableAndMediaSelection(),
                                          _buildMediaUploadField(),
                                          const SizedBox(height: 24),
                                          _buildHeaderSection(),
                                          const SizedBox(height: 16),
                                          _buildBodySection(),
                                          const SizedBox(height: 16),
                                          _buildFooterSection(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildButtonsSection(),
                                    if (_category == 'UTILITY') ...[
                                      const SizedBox(height: 16),
                                      MessageValidityPeriodWidget(
                                        defaultOn: false,
                                        enabled: _validitySeconds != 0,
                                        selectedSeconds: _validitySeconds != 0 ? _validitySeconds : 600,
                                        onChanged: (seconds) => setState(() => _validitySeconds = seconds),
                                      ),
                                    ],
                                  ],
                                ],
                                const SizedBox(height: 32),
                                _buildActionButtons(state),
                              ],
                            ),
                          ),
                        ),
                        if (isWide) ...[
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 2,
                            child: StickyPreview(child: _buildPreview()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _currentStep == 1 && _category != 'AUTHENTICATION'
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AssistantDialog(
                    initialHeader: _headerController.text,
                    initialBody: _bodyController.text,
                    initialFooter: _footerController.text,
                    category: _category,
                    onApply: (body, header, footer) {
                      setState(() {
                        _bodyController.text = body;
                        if (header != null) _headerController.text = header;
                        if (footer != null) _footerController.text = footer;
                      });
                    },
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI Assistant'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
      bottomNavigationBar: MediaQuery.of(context).size.width <= 900
          ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => Container(
                      height: MediaQuery.of(context).size.height * 0.8,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Template Preview',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: _buildPreview()),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('VIEW PREVIEW'),
              ),
            )
          : null,
    );
  }

  Widget _buildPreview() {
    if (_category == 'AUTHENTICATION') {
      return AuthPreviewWidget(state: _authFormState);
    }
    return WhatsAppPreview(
      headerText: _headerController.text,
      mediaType: _mediaSample,
      bodyText: _bodyController.text,
      footerText: _footerController.text,
      buttons: _buttons,
      mediaFile: _selectedFile,
    );
  }

  Widget _buildStepProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildStepCircle(1, 'Basic Details', _currentStep >= 0),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: _currentStep > 0
                  ? AppTheme.primaryColor
                  : Colors.grey.shade300,
            ),
          ),
          _buildStepCircle(2, 'Content & Preview', _currentStep >= 1),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppTheme.secondaryColor : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(TemplateState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (_currentStep == 0)
            Expanded(
              child: OutlinedButton(
                onPressed: state is TemplateLoading
                    ? null
                    : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.secondaryColor),
                ),
                child: const Text('DISCARD'),
              ),
            )
          else
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.secondaryColor),
                ),
                child: const Text('BACK'),
              ),
            ),
          const SizedBox(width: 16),
          if (_currentStep == 0)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep = 1);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                child: const Text('NEXT STEP'),
              ),
            )
          else
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: state is TemplateLoading ? null : _submitTemplate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                child: state is TemplateLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('CREATE TEMPLATE'),
              ),
            ),
        ],
      ),
    );
  }

  void _submitTemplate() {
    if (_formKey.currentState!.validate()) {
      if (_mediaSample != 'NONE' && _selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a sample file for the media header'),
          ),
        );
        return;
      }

      // Media file validation
      if (_selectedFile != null) {
        String? mediaError;
        if (_mediaSample == 'IMAGE') {
          mediaError = MediaValidator.validateImage(_selectedFile!);
        } else if (_mediaSample == 'VIDEO') {
          mediaError = MediaValidator.validateVideo(_selectedFile!);
        } else if (_mediaSample == 'DOCUMENT') {
          mediaError = MediaValidator.validateDocument(_selectedFile!);
        }
        if (mediaError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mediaError), backgroundColor: Colors.redAccent),
          );
          return;
        }
      }

      // AUTHENTICATION-specific validations
      if (_category == 'AUTHENTICATION') {
        // ToS validation for ZERO_TAP
        if (_authFormState.codeDeliveryType == 'ZERO_TAP' && !_authFormState.zeroTapTosAccepted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You must agree to the Terms of Service to use zero-tap auto-fill.'),
            backgroundColor: Colors.redAccent,
          ));
          return;
        }
        // App entry validation for ZERO_TAP and ONE_TAP
        if (_authFormState.codeDeliveryType != 'COPY_CODE') {
          for (final entry in _authFormState.appEntries) {
            if (entry.packageName.isEmpty || entry.signatureHash.length != 11) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please complete all app entries with valid package names and 11-character signature hashes.'),
                backgroundColor: Colors.redAccent,
              ));
              return;
            }
          }
        }
      }

      final isAuth = _category == 'AUTHENTICATION';
      context.read<TemplateBloc>().add(
        CreateTemplate(
          name: _nameController.text.trim(),
          category: _category,
          subCategory: isAuth ? null : _subCategory,
          language: _language,
          header: isAuth ? null : (_headerController.text.isEmpty ? null : _headerController.text.trim()),
          mediaSample: isAuth ? null : (_mediaSample == 'NONE' ? null : _mediaSample),
          variableType: isAuth ? null : _variableType,
          body: isAuth ? '' : _bodyController.text.trim(),
          footer: isAuth ? null : (_footerController.text.isEmpty ? null : _footerController.text.trim()),
          buttons: isAuth ? null : (_buttons.isEmpty ? null : _buttons),
          mediaFile: isAuth ? null : _selectedFile,
          messageSendTtlSeconds: isAuth
              ? (_authFormState.validityEnabled ? _authFormState.validitySeconds : null)
              : (_validitySeconds != 0 ? _validitySeconds : null),
          codeDeliveryType: isAuth ? _authFormState.codeDeliveryType : null,
          appEntries: isAuth ? _authFormState.appEntries : null,
          addSecurityRecommendation: isAuth ? _authFormState.addSecurityRecommendation : null,
          addExpiryTime: isAuth ? _authFormState.addExpiryTime : null,
          codeExpirationMinutes: isAuth ? _authFormState.codeExpirationMinutes : null,
          zeroTapTosAccepted: isAuth ? _authFormState.zeroTapTosAccepted : null,
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: _getFileType(),
      allowMultiple: false,
      withData: true,
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  FileType _getFileType() {
    switch (_mediaSample) {
      case 'IMAGE':
        return FileType.image;
      case 'VIDEO':
        return FileType.video;
      case 'DOCUMENT':
        return FileType.any;
      default:
        return FileType.any;
    }
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.secondaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppTheme.backgroundColor),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildVariableAndMediaSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Type of variable',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _variableType,
                    items: ['Name', 'Number']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _variableType = val);
                    },
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Media sample · Optional',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _mediaSample,
                    items: [
                      const DropdownMenuItem(
                        value: 'NONE',
                        child: Text('None'),
                      ),
                      const DropdownMenuItem(
                        value: 'IMAGE',
                        child: Row(
                          children: [
                            Icon(Icons.image_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Image'),
                          ],
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'VIDEO',
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Video'),
                          ],
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'DOCUMENT',
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Document'),
                          ],
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'LOCATION',
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Location'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _mediaSample = val;
                          if (val != 'NONE') _headerController.clear();
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaUploadField() {
    if (_mediaSample == 'NONE' || _mediaSample == 'LOCATION') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Sample File',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(_getMediaIcon(), color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFile?.name ??
                          'Click to select ${_mediaSample.toLowerCase()}',
                      style: TextStyle(
                        color: _selectedFile != null
                            ? Colors.black87
                            : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedFile != null)
                    IconButton(
                      onPressed: () => setState(() => _selectedFile = null),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    const Icon(Icons.upload_file, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A sample file is required for templates with media headers.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  IconData _getMediaIcon() {
    switch (_mediaSample) {
      case 'IMAGE':
        return Icons.image_outlined;
      case 'VIDEO':
        return Icons.play_circle_outline;
      case 'DOCUMENT':
        return Icons.description_outlined;
      default:
        return Icons.file_present_outlined;
    }
  }

  Widget _buildHeaderSection() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Header · Optional',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isMobile)
              IconButton(
                onPressed: () => _insertNextVariable(_headerController),
                icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryColor),
                tooltip: 'Add variable',
              )
            else
              TextButton.icon(
                onPressed: () => _insertNextVariable(_headerController),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add variable', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _headerController,
          maxLength: 60,
          enabled: _mediaSample == 'NONE',
          decoration: InputDecoration(
            hintText: _mediaSample == 'NONE'
                ? 'Add a short line of text to the header of your message'
                : 'Header is disabled when a media sample is selected',
          ),
        ),
      ],
    );
  }

  Widget _buildBodySection() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Body', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bodyController,
          maxLines: 5,
          maxLength: 1024,
          decoration: const InputDecoration(
            hintText: 'Hello',
            alignLabelWithHint: true,
          ),
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  onPressed: _showEmojiPicker,
                  icon: const Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
                IconButton(
                  onPressed: () => _formatText('*'),
                  icon: const Icon(
                    Icons.format_bold,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
                IconButton(
                  onPressed: () => _formatText('_'),
                  icon: const Icon(
                    Icons.format_italic,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
                IconButton(
                  onPressed: () => _formatText('~'),
                  icon: const Icon(
                    Icons.format_strikethrough,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
                IconButton(
                  onPressed: () => _formatText('```'),
                  icon: const Icon(Icons.code, size: 20, color: Colors.black54),
                ),
                if (!isMobile) const Spacer(),
                if (isMobile) const SizedBox(width: 8),
                if (isMobile)
                  IconButton(
                    onPressed: () => _insertNextVariable(_bodyController),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    tooltip: 'Add variable',
                  )
                else
                  TextButton.icon(
                    onPressed: () => _insertNextVariable(_bodyController),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add variable',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _formatText(String tag) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.start == -1) return;

    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$tag$selectedText$tag',
    );

    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + tag.length + selectedText.length + tag.length,
      ),
    );
  }

  void _insertNextVariable(TextEditingController controller) {
    final text = controller.text;
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(text);
    int maxIndex = 0;
    for (final m in matches) {
      final idx = int.tryParse(m.group(1) ?? '') ?? 0;
      if (idx > maxIndex) maxIndex = idx;
    }
    _insertTag('{{${maxIndex + 1}}}', controller);
  }

  void _insertTag(String tag, TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    int insertionIndex = selection.start != -1 ? selection.start : text.length;
    final newText = text.replaceRange(
      insertionIndex,
      selection.end != -1 ? selection.end : text.length,
      tag,
    );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertionIndex + tag.length),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: 350,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) {
            _insertTag(emoji.emoji, _bodyController);
            Navigator.pop(context);
          },
          config: Config(
            height: 350,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Footer · Optional',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _footerController,
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: 'Add a short line of text to the bottom of your message',
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Language',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _language,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.language)),
          items: _languages.map((lang) {
            return DropdownMenuItem(
              value: lang['code'],
              child: Text(lang['name']!),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _language = val);
          },
        ),
      ],
    );
  }

  Widget _buildButtonsSection() {
    return _buildCard(
      title: 'Buttons · Optional',
      icon: Icons.ads_click_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create buttons that let customers respond to your message or take action. You can add up to ten buttons.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _buildAddButtonDropdown(),
          const SizedBox(height: 16),
          ...List.generate(
            _buttons.length,
            (index) => _buildButtonEditor(index),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButtonDropdown() {
    return PopupMenuButton<String>(
      onSelected: (type) {
        setState(() {
          if (type == 'QUICK_REPLY') {
            _buttons.add({'type': 'QUICK_REPLY', 'text': 'Reply'});
          } else if (type == 'PHONE_NUMBER') {
            _buttons.add({
              'type': 'PHONE_NUMBER',
              'text': 'Call phone',
              'phone_number': '',
            });
          } else if (type == 'URL') {
            _buttons.add({'type': 'URL', 'text': 'Visit website', 'url': ''});
          }
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'QUICK_REPLY', child: Text('Quick Reply')),
        const PopupMenuItem(
          value: 'PHONE_NUMBER',
          child: Text('Call Phone Number'),
        ),
        const PopupMenuItem(value: 'URL', child: Text('Visit Website')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 20, color: AppTheme.secondaryColor),
            SizedBox(width: 8),
            Text(
              'Add button',
              style: TextStyle(
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppTheme.secondaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonEditor(int index) {
    final btn = _buttons[index];
    final type = btn['type'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
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
                'Button ${index + 1} · ${type.toString().replaceAll('_', ' ')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _buttons.removeAt(index)),
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: btn['text'],
                  onChanged: (val) => setState(() => btn['text'] = val),
                  decoration: const InputDecoration(
                    labelText: 'Button text',
                    counterText: '',
                  ),
                  maxLength: 25,
                ),
              ),
              const SizedBox(width: 12),
              if (type == 'PHONE_NUMBER')
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: btn['phone_number'],
                    onChanged: (val) =>
                        setState(() => btn['phone_number'] = val),
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+1234567890',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              if (type == 'URL')
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: btn['url'],
                    onChanged: (val) => setState(() => btn['url'] = val),
                    decoration: const InputDecoration(
                      labelText: 'Website URL',
                      hintText: 'https://example.com',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
              if (type == 'QUICK_REPLY') const Spacer(flex: 3),
            ],
          ),
        ],
      ),
    );
  }
}

class StickyPreview extends StatelessWidget {
  final Widget child;
  const StickyPreview({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 650,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
