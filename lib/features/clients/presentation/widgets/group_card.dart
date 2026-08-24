import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
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
    final isMobile = ResponsiveHelper.isMobile(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.12),
          child: Icon(Icons.group_rounded, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        trailing: isMobile
            ? (isDownloading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'Group Options',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'download':
                          if (onDownloadCsv != null) onDownloadCsv!();
                          break;
                        case 'edit':
                          onEdit();
                          break;
                        case 'qr':
                          onQrCode();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (onDownloadCsv != null)
                        const PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Download CSV'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Edit Group'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'qr',
                        child: Row(
                          children: [
                            Icon(Icons.qr_code_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Registration QR'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Delete Group',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ))
            : Row(
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
                    icon: const Icon(Icons.qr_code_rounded),
                    tooltip: 'Group Registration QR',
                    onPressed: onQrCode,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Delete group',
                    onPressed: onDelete,
                  ),
                ],
              ),
      ),
    );
  }
}
