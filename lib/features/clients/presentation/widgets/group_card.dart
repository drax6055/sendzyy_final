import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';

class GroupCard extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQrCode;
  final VoidCallback? onDownloadCsv;
  final bool isDownloading;

  const GroupCard({
    super.key,
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.onQrCode,
    this.onDownloadCsv,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    final clientCount = group.clientIds.length;
    final subtitle = '$clientCount ${clientCount == 1 ? 'client' : 'clients'}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.group),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDownloadCsv != null)
              IconButton(
                icon: isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                tooltip: 'Download Group CSV',
                onPressed: isDownloading ? null : onDownloadCsv,
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit group',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Group Registration QR',
              onPressed: onQrCode,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete group',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
