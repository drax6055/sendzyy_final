import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WhatsAppPreview extends StatelessWidget {
  final String? headerText;
  final String? mediaType;
  final String bodyText;
  final String? footerText;
  final List<Map<String, dynamic>> buttons;
  final PlatformFile? mediaFile;

  const WhatsAppPreview({
    super.key,
    this.headerText,
    this.mediaType,
    required this.bodyText,
    this.footerText,
    this.buttons = const [],
    this.mediaFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5DDD5),
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: NetworkImage(
            'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
          ),
          opacity: 0.1,
          repeat: ImageRepeat.repeat,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.videocam, color: Colors.white, size: 20),
                const SizedBox(width: 16),
                const Icon(Icons.call, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [_buildMessageBubble()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mediaType != null && mediaType != 'NONE') _buildMediaHeader(),
            if (headerText != null && headerText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                child: Text(
                  headerText!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: _buildRichBody(bodyText),
            ),
            if (footerText != null && footerText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  footerText!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(
                '11:59',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
            if (buttons.isNotEmpty) ...[
              const Divider(height: 1),
              ...buttons.map((btn) => _buildButton(btn)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaHeader() {
    if (mediaFile != null) {
      if (mediaType == 'IMAGE') {
        return Container(
          height: 180,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: kIsWeb
              ? Image.memory(mediaFile!.bytes!, fit: BoxFit.cover)
              : Image.file(File(mediaFile!.path!), fit: BoxFit.cover),
        );
      } else if (mediaType == 'VIDEO') {
        return Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mediaFile!.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else if (mediaType == 'DOCUMENT') {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: AppTheme.secondaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mediaFile!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(mediaFile!.size / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }

    IconData icon;
    String label;
    switch (mediaType) {
      case 'IMAGE':
        icon = Icons.image;
        label = 'Image';
        break;
      case 'VIDEO':
        icon = Icons.play_circle_fill;
        label = 'Video';
        break;
      case 'DOCUMENT':
        icon = Icons.description;
        label = 'Document';
        break;
      case 'LOCATION':
        icon = Icons.location_on;
        label = 'Location';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRichBody(String text) {
    if (text.isEmpty) {
      return const Text(
        'Message body',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    List<TextSpan> spans = [];
    final regExp = RegExp(r'(\*[^*]+\*|_[^_]+_|~[^~]+~|```[^`]+```)');

    int lastMatchEnd = 0;
    for (final match in regExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      final matchText = match.group(0)!;
      if (matchText.startsWith('*')) {
        spans.add(
          TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (matchText.startsWith('_')) {
        spans.add(
          TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (matchText.startsWith('~')) {
        spans.add(
          TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (matchText.startsWith('```')) {
        spans.add(
          TextSpan(
            text: matchText.substring(3, matchText.length - 3),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: Colors.grey.shade100,
            ),
          ),
        );
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        children: spans,
      ),
    );
  }

  Widget _buildButton(Map<String, dynamic> button) {
    final type = button['type'];
    final text = button['text'] ?? 'Button';

    IconData icon;
    if (type == 'PHONE_NUMBER') {
      icon = Icons.call_outlined;
    } else if (type == 'URL') {
      icon = Icons.open_in_new_outlined;
    } else if (type == 'CATALOG') {
      icon = Icons.storefront_outlined;
    } else if (type == 'MPM') {
      icon = Icons.list_alt_rounded;
    } else {
      icon = Icons.reply_outlined;
    }
    

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00a5f4)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF00a5f4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}