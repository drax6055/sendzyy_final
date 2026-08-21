import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/client_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/group_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/utils/csv_export_helper.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/create_group_dialog.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/delete_group_dialog.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/group_card.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/group_qr_dialog.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _downloadingGroupId;

  @override
  void initState() {
    super.initState();
    context.read<GroupsBloc>().add(FetchGroups());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditDialog(GroupModel group) {
    final groupsBloc = context.read<GroupsBloc>();
    final clientsBloc = context.read<ClientsBloc>();
    showDialog(
      context: context,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: groupsBloc),
          BlocProvider.value(value: clientsBloc),
        ],
        child: CreateGroupDialog(group: group),
      ),
    );
  }

  void _openDeleteDialog(GroupModel group) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<GroupsBloc>(),
        child: DeleteGroupDialog(group: group),
      ),
    );
  }

  void _openQrDialog(GroupModel group) {
    showDialog(
      context: context,
      builder: (_) => GroupQrDialog(group: group),
    );
  }

  Future<void> _downloadGroupCsv(GroupModel group) async {
    if (_downloadingGroupId != null) return;
    setState(() {
      _downloadingGroupId = group.id;
    });

    try {
      final repo = getIt<ClientRepository>();
      final paginatedResult = await repo.getClients(groupId: group.id);
      final clients = paginatedResult.clients;

      if (clients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No clients found in group "${group.name}".')),
          );
        }
        return;
      }

      final sanitizedGroupName =
          group.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${sanitizedGroupName.isEmpty ? 'group' : sanitizedGroupName}_clients.csv';

      CsvExportHelper.downloadClientsCsv(clients, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${clients.length} clients for group "${group.name}".'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download group CSV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingGroupId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search groups...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : Icon(
                      Icons.search,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
            ),
          ),
        ),
        // Groups list
        Expanded(
          child: BlocBuilder<GroupsBloc, GroupsState>(
            builder: (context, state) {
              if (state is GroupsLoading || state is GroupsInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is GroupsError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.message,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.read<GroupsBloc>().add(FetchGroups()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final allGroups = state is GroupsLoaded
                  ? state.groups
                  : (state is GroupOperationSuccess
                      ? state.groups
                      : <GroupModel>[]);

              // Filter groups based on search query
              final groups = _searchQuery.isEmpty
                  ? allGroups
                  : allGroups
                      .where((group) =>
                          group.name.toLowerCase().contains(_searchQuery))
                      .toList();

              if (allGroups.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No groups yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              if (groups.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No groups match your search',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return GroupCard(
                    group: group,
                    onEdit: () => _openEditDialog(group),
                    onDelete: () => _openDeleteDialog(group),
                    onQrCode: () => _openQrDialog(group),
                    onDownloadCsv: () => _downloadGroupCsv(group),
                    isDownloading: _downloadingGroupId == group.id,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
