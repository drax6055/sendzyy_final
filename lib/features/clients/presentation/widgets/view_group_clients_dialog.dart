import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';

class ViewGroupClientsDialog extends StatefulWidget {
  final GroupModel group;

  const ViewGroupClientsDialog({super.key, required this.group});

  @override
  State<ViewGroupClientsDialog> createState() => _ViewGroupClientsDialogState();
}

class _ViewGroupClientsDialogState extends State<ViewGroupClientsDialog> {
  final List<ClientModel> _clients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final repo = getIt<ClientRepository>();
      final result = await repo.getClients(
        page: 1,
        limit: 500, // Fetch up to 500 clients in the group
        groupId: widget.group.id,
      );
      if (mounted) {
        setState(() {
          _clients.clear();
          _clients.addAll(result.clients);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? screenWidth * 0.92 : 450,
        height: 500,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline, color: AppTheme.secondaryColor, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.group.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.group.clientIds.length} members in this group',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_clients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'No members in this group',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _clients.length,
      itemBuilder: (context, index) {
        final client = _clients[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
            child: Text(
              client.name[0].toUpperCase(),
              style: const TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            client.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
          ),
          subtitle: Text(
            client.mobileNumber,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        );
      },
    );
  }
}
