import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class WhatsAppBusinessProfileDialog extends StatefulWidget {
  final dynamic config;

  const WhatsAppBusinessProfileDialog({super.key, required this.config});

  static Future<void> show(BuildContext context, dynamic config) {
    if (ResponsiveHelper.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => WhatsAppBusinessProfileDialog(config: config),
      );
    }
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => WhatsAppBusinessProfileDialog(config: config),
    );
  }

  @override
  State<WhatsAppBusinessProfileDialog> createState() => _WhatsAppBusinessProfileDialogState();
}

class _WhatsAppBusinessProfileDialogState extends State<WhatsAppBusinessProfileDialog> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _whatsappProfile;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isEditing = false;
  bool _isSaving = false;
  double _uploadProgress = 0.0;
  bool _isUploadingImage = false;

  final _aboutController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  List<TextEditingController> _websiteControllers = [];
  String? _selectedVertical;

  static Map<String, dynamic> _asSafeMap(dynamic val) {
    if (val == null) return {};
    if (val is Map<String, dynamic>) return val;
    if (val is Map) return Map<String, dynamic>.from(val);
    if (val is String && val.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  final Map<String, String> _verticals = {
    'AUTOMOTIVE': 'Automotive',
    'BEAUTY': 'Beauty, Spa & Salon',
    'CONVENIENCE_STORE': 'Convenience Store',
    'DENTIST': 'Dentist',
    'EDUCATION': 'Education',
    'ENTERTAINMENT': 'Entertainment',
    'FINANCE': 'Finance & Banking',
    'HEALTH_MEDICAL': 'Health & Medical',
    'HOTEL_LODGING': 'Hotel & Lodging',
    'INTEGRATOR': 'Integrator',
    'NOT_A_BUSINESS': 'Not a Business',
    'OTHER': 'Other',
    'PARK_GARDEN': 'Park & Garden',
    'REST_CAFE': 'Restaurant & Cafe',
    'RETAIL': 'Shopping & Retail',
    'SPECIALTY_FOOD': 'Specialty Food',
    'TRAVEL_TRANSPORT': 'Travel & Transportation',
    'UTILITY': 'Utility',
  };

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = getIt<WhatsAppRepository>();
      final rawProfile = await repository.getProfile();
      final profile = _asSafeMap(rawProfile);
      if (mounted) {
        setState(() {
          _profile = profile;
        });
      }

      final safeWidgetConfig = _asSafeMap(widget.config);
      final profileConfig = _asSafeMap(profile['whatsappConfig']);

      final phoneId = (safeWidgetConfig['phoneNumberId']?.toString().isNotEmpty == true
              ? safeWidgetConfig['phoneNumberId'].toString()
              : null) ??
          (profileConfig['phoneNumberId']?.toString().isNotEmpty == true
              ? profileConfig['phoneNumberId'].toString()
              : null);

      final token = (safeWidgetConfig['accessToken']?.toString().isNotEmpty == true
              ? safeWidgetConfig['accessToken'].toString()
              : null) ??
          (profileConfig['accessToken']?.toString().isNotEmpty == true
              ? profileConfig['accessToken'].toString()
              : null);

      if (phoneId != null && token != null && phoneId.isNotEmpty && token.isNotEmpty) {
        final rawWaProfile = await repository.fetchWhatsAppProfile(
          phoneNumberId: phoneId,
          accessToken: token,
        );
        if (mounted) {
          setState(() {
            _whatsappProfile = _asSafeMap(rawWaProfile);
            _isLoading = false;
            _initProfileFormFields();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'WhatsApp configuration incomplete. Please configure your Phone Number ID and Access Token in Settings.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _isLoading = false;
          _errorMessage = cleanMsg;
        });
      }
    }
  }

  void _initProfileFormFields() {
    if (_whatsappProfile == null) return;
    _aboutController.text = _whatsappProfile!['about']?.toString() ?? '';
    _addressController.text = _whatsappProfile!['address']?.toString() ?? '';
    _descriptionController.text = _whatsappProfile!['description']?.toString() ?? '';
    _emailController.text = _whatsappProfile!['email']?.toString() ?? '';

    dynamic rawWebsites = _whatsappProfile!['websites'];
    List<dynamic> websites = [];
    if (rawWebsites is List) {
      websites = rawWebsites;
    } else if (rawWebsites is String && rawWebsites.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawWebsites);
        if (decoded is List) {
          websites = decoded;
        } else {
          websites = [rawWebsites];
        }
      } catch (_) {
        websites = [rawWebsites];
      }
    }

    for (var c in _websiteControllers) {
      c.dispose();
    }
    _websiteControllers = websites
        .where((w) => w != null && w.toString().trim().isNotEmpty)
        .map((w) => TextEditingController(text: w.toString().trim()))
        .toList();
    if (_websiteControllers.isEmpty) {
      _websiteControllers.add(TextEditingController());
    }

    _selectedVertical = _whatsappProfile!['vertical']?.toString();
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    for (var c in _websiteControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _safeWidgetConfig => _asSafeMap(widget.config);

  String? get _resolvedPhoneId =>
      (_safeWidgetConfig['phoneNumberId']?.toString().isNotEmpty == true
          ? _safeWidgetConfig['phoneNumberId'].toString()
          : null) ??
      (_asSafeMap(_profile?['whatsappConfig'])['phoneNumberId']?.toString().isNotEmpty == true
          ? _asSafeMap(_profile?['whatsappConfig'])['phoneNumberId'].toString()
          : null);

  String? get _resolvedToken =>
      (_safeWidgetConfig['accessToken']?.toString().isNotEmpty == true
          ? _safeWidgetConfig['accessToken'].toString()
          : null) ??
      (_asSafeMap(_profile?['whatsappConfig'])['accessToken']?.toString().isNotEmpty == true
          ? _asSafeMap(_profile?['whatsappConfig'])['accessToken'].toString()
          : null);

  Future<void> _pickAndUploadProfileImage() async {
    if (!_isEditing) return;

    final phoneId = _resolvedPhoneId;
    final token = _resolvedToken;
    if (phoneId == null || token == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) return;

        setState(() {
          _isUploadingImage = true;
          _uploadProgress = 0.0;
        });

        final handleId = await getIt<WhatsAppRepository>().uploadWhatsAppProfileImage(
          phoneNumberId: phoneId,
          accessToken: token,
          imageBytes: bytes,
          fileName: file.name,
          mimeType: file.extension == 'png' ? 'image/png' : 'image/jpeg',
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );

        if (handleId != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture uploaded successfully!')),
            );
          }
          await _loadProfileData();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload profile picture')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _saveWhatsAppProfile() async {
    final phoneId = _resolvedPhoneId;
    final token = _resolvedToken;
    if (phoneId == null || token == null) return;

    setState(() {
      _isSaving = true;
    });

    final aboutText = _aboutController.text.trim();
    if (aboutText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('About Status Text is required and cannot be empty.')),
        );
      }
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final websites = _websiteControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    for (var w in websites) {
      if (!w.startsWith('http://') && !w.startsWith('https://')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid website: $w. Must start with http:// or https://')),
          );
        }
        setState(() {
          _isSaving = false;
        });
        return;
      }
    }

    final Map<String, dynamic> profileData = {
      'about': aboutText,
    };

    final addressText = _addressController.text.trim();
    if (addressText.isNotEmpty) {
      profileData['address'] = addressText;
    }
    final descriptionText = _descriptionController.text.trim();
    if (descriptionText.isNotEmpty) {
      profileData['description'] = descriptionText;
    }
    final emailText = _emailController.text.trim();
    if (emailText.isNotEmpty) {
      profileData['email'] = emailText;
    }
    if (websites.isNotEmpty) {
      profileData['websites'] = websites;
    }
    if (_selectedVertical != null && _selectedVertical!.isNotEmpty) {
      profileData['vertical'] = _selectedVertical;
    }

    try {
      final success = await getIt<WhatsAppRepository>().updateWhatsAppProfileText(
        phoneNumberId: phoneId,
        accessToken: token,
        profileData: profileData,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp Business Profile updated successfully!')),
          );
          setState(() {
            _isEditing = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update WhatsApp Business Profile')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $cleanMsg')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final verifiedName = _safeWidgetConfig['verifiedName']?.toString();
    final displayName = (verifiedName ?? _profile?['name']?.toString() ?? 'Profile Picture').toUpperCase();
    final avatarUrl = _whatsappProfile?['profile_picture_url']?.toString();

    final isMobile = ResponsiveHelper.isMobile(context);
    final dialogContent = Container(
      width: ResponsiveHelper.getModalWidth(context, desktopWidth: 650),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.9 : 0.85),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'WhatsApp Business Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                  ),
                ),
                IconButton(
                  tooltip: _isEditing ? 'Cancel Edit' : 'Edit Profile',
                  icon: Icon(
                    _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                    color: _isEditing ? Colors.redAccent : AppTheme.primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                      if (!_isEditing) {
                        _initProfileFormFields();
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Fetching WhatsApp profile from Meta...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _loadProfileData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar section
                              Row(
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 44,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                        child: avatarUrl == null
                                            ? Icon(Icons.person, size: 44, color: Colors.grey.shade400)
                                            : null,
                                      ),
                                      if (_isUploadingImage)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: CircularProgressIndicator(
                                              value: _uploadProgress > 0 ? _uploadProgress : null,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      else if (_isEditing)
                                        Positioned.fill(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _pickAndUploadProfileImage,
                                              customBorder: const CircleBorder(),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.25),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isEditing
                                              ? 'Click image to upload a new profile picture. Meta supports square JPG or PNG files.'
                                              : 'WhatsApp Verified Business Profile',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // About Status Text
                              TextFormField(
                                controller: _aboutController,
                                readOnly: !_isEditing,
                                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                                maxLength: 139,
                                decoration: InputDecoration(
                                  labelText: 'About Status Text',
                                  labelStyle: TextStyle(color: _isEditing ? AppTheme.primaryColor : Colors.grey.shade700, fontWeight: FontWeight.w600),
                                  hintText: 'Hey there! I am using WhatsApp.',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  filled: true,
                                  fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Business Description
                              TextFormField(
                                controller: _descriptionController,
                                readOnly: !_isEditing,
                                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Business Description',
                                  labelStyle: TextStyle(color: _isEditing ? AppTheme.primaryColor : Colors.grey.shade700, fontWeight: FontWeight.w600),
                                  hintText: 'Tell customers about your business vertical, services, or catalog...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  filled: true,
                                  fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Business Address
                              TextFormField(
                                controller: _addressController,
                                readOnly: !_isEditing,
                                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  labelText: 'Business Address',
                                  labelStyle: TextStyle(color: _isEditing ? AppTheme.primaryColor : Colors.grey.shade700, fontWeight: FontWeight.w600),
                                  hintText: 'Ahmedabad, Gujarat 380006',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  filled: true,
                                  fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Contact Email
                              TextFormField(
                                controller: _emailController,
                                readOnly: !_isEditing,
                                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Contact Email',
                                  labelStyle: TextStyle(color: _isEditing ? AppTheme.primaryColor : Colors.grey.shade700, fontWeight: FontWeight.w600),
                                  hintText: 'info@yourbusiness.com',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  filled: true,
                                  fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Business Vertical Category
                              Text(
                                'Business Vertical Category',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _isEditing ? AppTheme.primaryColor : Colors.grey.shade700),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedVertical,
                                isExpanded: true,
                                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                                disabledHint: Text(
                                  _verticals[_selectedVertical] ?? _selectedVertical ?? 'None',
                                  style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                                ),
                                dropdownColor: Colors.white,
                                items: _verticals.entries.map((e) {
                                  return DropdownMenuItem<String>(
                                    value: e.key,
                                    child: Text(e.value, style: const TextStyle(color: Colors.black87)),
                                  );
                                }).toList(),
                                onChanged: _isEditing
                                    ? (val) {
                                        setState(() {
                                          _selectedVertical = val;
                                        });
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 20),

                              // Websites Editor
                              _buildWebsitesEditor(),

                              if (_isEditing) ...[
                                const SizedBox(height: 24),
                                // Save Button
                                ElevatedButton(
                                  onPressed: _isSaving ? null : _saveWhatsAppProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Save WhatsApp Business Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
    );

    if (isMobile) {
      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: dialogContent,
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: dialogContent,
    );
  }

  Widget _buildWebsitesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Websites',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _isEditing ? AppTheme.primaryColor : Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        ...List.generate(_websiteControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _websiteControllers[index],
                    readOnly: !_isEditing,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'https://example.com',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        _websiteControllers[index].dispose();
                        _websiteControllers.removeAt(index);
                        if (_websiteControllers.isEmpty) {
                          _websiteControllers.add(TextEditingController());
                        }
                      });
                    },
                  ),
                ],
              ],
            ),
          );
        }),
        if (_isEditing && _websiteControllers.length < 2)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _websiteControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Another Website'),
          )
        else if (_isEditing && _websiteControllers.length >= 2)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              'Maximum 2 websites allowed by Meta.',
              style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
   