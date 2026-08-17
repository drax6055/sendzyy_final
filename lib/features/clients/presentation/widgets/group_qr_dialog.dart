import 'dart:convert';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupQrDialog extends StatefulWidget {
  final GroupModel group;
  const GroupQrDialog({super.key, required this.group});

  @override
  State<GroupQrDialog> createState() => _GroupQrDialogState();
}

class _GroupQrDialogState extends State<GroupQrDialog> {
  String? _tenantId;
  String _businessName = '';
  // Key used for the styled frame that gets captured and downloaded
  final GlobalKey _frameKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadTenantData();
  }

  Future<void> _loadTenantData() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantJson = prefs.getString('tenant_data');
    String name = '';
    if (tenantJson != null) {
      try {
        final tenant = jsonDecode(tenantJson);
        name = tenant['name']?.toString() ?? '';
      } catch (_) {}
    }
    setState(() {
      _tenantId = prefs.getString(AppConstants.keyTenantId);
      _businessName = name;
    });
  }

  String get _registrationUrl =>
      '${AppConstants.baseUrl}/register-client?tenantId=$_tenantId&groupId=${widget.group.id}';

  Future<void> _downloadQr() async {
    try {
      final boundary =
          _frameKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return;

      final rawBytes = byteData.buffer.asUint8List();
      final imgFrame = img.Image.fromBytes(
        width: uiImage.width,
        height: uiImage.height,
        bytes: rawBytes.buffer,
        order: img.ChannelOrder.rgba,
      );
      final jpegBytes = img.encodeJpg(imgFrame, quality: 95);
      await webDownloadBytes(jpegBytes, 'group_registration_qr_${widget.group.name}.jpg', mimeType: 'image/jpeg');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR downloaded as JPG'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// The styled frame that gets captured and downloaded.
  Widget _buildStyledFrame() {
    return RepaintBoundary(
      key: _frameKey,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.secondaryColor, AppTheme.accentColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Business name
            Text(
              _businessName.isNotEmpty ? _businessName : 'Our Business',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Group name subtitle
            Text(
              widget.group.name,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            // Divider accent
            Container(
              width: 48,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // QR code card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _registrationUrl,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            // Sweet message
            const Text(
              'Scan to Register',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Join us in seconds — no forms, no fuss.\nJust scan and you\'re in!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Footer badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.5), width: 1),
              ),
              child: const Text(
                'Powered by Sendzyy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Group Registration QR',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                        Text(
                          widget.group.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Share this QR so customers can self-register and join this group.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_tenantId == null)
                const CircularProgressIndicator()
              else ...[
                // Preview of the styled frame shown in dialog
                _buildStyledFrame(),
                const SizedBox(height: 16),
                // URL display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _registrationUrl,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy URL',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _registrationUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('URL copied'),
                                backgroundColor: Colors.green),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.secondaryColor,
                          side: BorderSide(
                              color:
                                  AppTheme.secondaryColor.withOpacity(0.4)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _downloadQr,
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
