import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendzyy/core/di/injection.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/features/clients/data/models/client_model.dart';
import 'package:sendzyy/features/clients/presentation/bloc/client_bloc.dart';
import 'package:sendzyy/features/clients/presentation/bloc/group_bloc.dart';
import 'package:sendzyy/features/clients/presentation/widgets/bulk_import_dialog.dart';
import 'package:sendzyy/features/clients/presentation/widgets/create_client_dialog.dart';
import 'package:sendzyy/features/clients/presentation/widgets/create_group_dialog.dart';
import 'package:sendzyy/features/clients/presentation/widgets/groups_tab.dart';
import 'package:sendzyy/features/clients/presentation/widgets/qr_code_dialog.dart';
import 'package:sendzyy/features/clients/data/repositories/client_repository.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => getIt<ClientsBloc>()..add(FetchClients()),
        ),
        BlocProvider(
          create: (context) => getIt<GroupsBloc>(),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Material(
            color: Colors.white,
            elevation: 0,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Clients'),
                Tab(text: 'Groups'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            _ClientsView(),
            GroupsTab(),
          ],
        ),
        floatingActionButton: _tabController.index == 0
            ? null
            : Builder(
                builder: (context) {
                  final isMobileTab = MediaQuery.of(context).size.width < 800;
                  if (isMobileTab) {
                    return FloatingActionButton(
                      heroTag: 'create_group',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => MultiBlocProvider(
                            providers: [
                              BlocProvider.value(value: context.read<GroupsBloc>()),
                              BlocProvider.value(value: context.read<ClientsBloc>()),
                            ],
                            child: const CreateGroupDialog(),
                          ),
                        );
                      },
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.group_add, color: Colors.white),
                    );
                  }
                  return FloatingActionButton.extended(
                    heroTag: 'create_group',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => MultiBlocProvider(
                          providers: [
                            BlocProvider.value(value: context.read<GroupsBloc>()),
                            BlocProvider.value(
                                value: context.read<ClientsBloc>()),
                          ],
                          child: const CreateGroupDialog(),
                        ),
                      );
                    },
                    backgroundColor: Colors.green,
                    icon: const Icon(Icons.group_add),
                    label: const Text('CREATE GROUP'),
                  );
                },
              ),
      ),
    );
  }
}

class _ClientsView extends StatefulWidget {
  const _ClientsView();

  @override
  State<_ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<_ClientsView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  final Set<String> _selectedClientIds = {};
  bool _isSelectingAll = false;

  Future<void> _selectAllTotalClients(ClientsLoaded state) async {
    setState(() {
      _isSelectingAll = true;
    });
    try {
      final repo = getIt<ClientRepository>();
      final paginatedResult = await repo.getClients(
        page: 1,
        limit: state.totalClients,
        search: state.searchQuery,
      );
      setState(() {
        _selectedClientIds.addAll(paginatedResult.clients.map((c) => c.id));
        _isSelectingAll = false;
      });
    } catch (e) {
      setState(() {
        _isSelectingAll = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select all clients: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _changePage(BuildContext context, ClientsLoaded state, int targetPage, {int? newLimit}) {
    setState(() {
      _selectedClientIds.clear();
    });
    final limit = newLimit ?? state.limit;
    if (state.searchQuery.isNotEmpty) {
      context.read<ClientsBloc>().add(SearchClients(state.searchQuery, page: targetPage, limit: limit));
    } else {
      context.read<ClientsBloc>().add(FetchClients(page: targetPage, limit: limit));
    }
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 500), () {
          context.read<ClientsBloc>().add(SearchClients(val, page: 1, limit: 50));
        });
        setState(() {
          _selectedClientIds.clear();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search clients...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: Colors.grey.shade400,
          size: 20,
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  _searchDebounce?.cancel();
                  context.read<ClientsBloc>().add(
                        SearchClients(''),
                      );
                  setState(() {
                    _selectedClientIds.clear();
                  });
                },
              )
            : null,
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile, ClientsLoaded? state) {
    if (isMobile) return const SizedBox.shrink();

    final deleteButton = _selectedClientIds.isNotEmpty
        ? ElevatedButton.icon(
            onPressed: () {
              final bloc = context.read<ClientsBloc>();
              showDialog(
                context: context,
                builder: (_) => _DeleteSelectedClientsDialog(
                  selectedCount: _selectedClientIds.length,
                  onConfirm: () {
                    bloc.add(DeleteClients(_selectedClientIds.toList()));
                    setState(() {
                      _selectedClientIds.clear();
                    });
                  },
                ),
              );
            },
            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
            label: Text(
              'Delete Selected (${_selectedClientIds.length})',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(100, 40),
            ),
          )
        : null;

    final bulkImportButton = ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => BlocProvider.value(
            value: context.read<ClientsBloc>(),
            child: const BulkImportDialog(),
          ),
        );
      },
      icon: const Icon(Icons.file_upload_outlined, size: 18),
      label: const Text('Bulk Import', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(110, 40),
      ),
    );

    final qrButton = ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => const QrCodeDialog(),
        );
      },
      icon: const Icon(Icons.qr_code, size: 18),
      label: const Text('Generate QR', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(110, 40),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (deleteButton != null) ...[
          deleteButton,
          const SizedBox(width: 8),
        ],
        bulkImportButton,
        const SizedBox(width: 8),
        qrButton,
      ],
    );
  }

  Widget _buildHeader(bool isMobile, ClientsLoaded? state) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Clients',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                  ),
                  if (_isSelectingAll) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedClientIds.isNotEmpty) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      tooltip: 'Delete Selected',
                      onPressed: () {
                        final bloc = context.read<ClientsBloc>();
                        showDialog(
                          context: context,
                          builder: (_) => _DeleteSelectedClientsDialog(
                            selectedCount: _selectedClientIds.length,
                            onConfirm: () {
                              bloc.add(DeleteClients(_selectedClientIds.toList()));
                              setState(() {
                                _selectedClientIds.clear();
                              });
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.person_add_alt_1_outlined, color: AppTheme.primaryColor, size: 22),
                    tooltip: 'Create Client',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => BlocProvider.value(
                          value: context.read<ClientsBloc>(),
                          child: const CreateClientDialog(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.file_upload_outlined, color: Colors.blueGrey, size: 22),
                    tooltip: 'Bulk Import',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => BlocProvider.value(
                          value: context.read<ClientsBloc>(),
                          child: const BulkImportDialog(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.qr_code, color: AppTheme.secondaryColor, size: 22),
                    tooltip: 'Generate QR',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const QrCodeDialog(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSearchField(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Clients',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                if (_isSelectingAll) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSearchField(),
            ),
            const SizedBox(width: 16),
            _buildActionButtons(isMobile, state),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectAllMobileRow(ClientsLoaded state) {
    final allFilteredSelected = state.filteredClients.isNotEmpty &&
        state.filteredClients.every((c) => _selectedClientIds.contains(c.id));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Checkbox(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: allFilteredSelected,
            activeColor: AppTheme.primaryColor,
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  for (final client in state.filteredClients) {
                    _selectedClientIds.add(client.id);
                  }
                } else {
                  for (final client in state.filteredClients) {
                    _selectedClientIds.remove(client.id);
                  }
                }
              });
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Select All (${_selectedClientIds.length} selected)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientMobileCard(ClientModel client, bool isSelected) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.02) : Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: SizedBox(
            width: 84,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedClientIds.add(client.id);
                      } else {
                        _selectedClientIds.remove(client.id);
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                CircleAvatar(
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
              ],
            ),
          ),
          title: Text(
            client.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              client.mobileNumber,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          children: [
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCardDetailRow('Company', client.companyName),
                  const SizedBox(height: 8),
                  _buildCardDetailRow('Email', client.emailId),
                  const SizedBox(height: 8),
                  _buildCardDetailRow('Venue', client.venue),
                  const SizedBox(height: 8),
                  _buildCardDetailRow('Remark', client.remark),
                  const SizedBox(height: 8),
                  _buildCardDetailRow(
                    'Added On',
                    '${client.createdAt.day.toString().padLeft(2, '0')}/${client.createdAt.month.toString().padLeft(2, '0')}/${client.createdAt.year}',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          final bloc = context.read<ClientsBloc>();
                          showDialog(
                            context: context,
                            builder: (_) => _DeleteClientDialog(
                              client: client,
                              onConfirm: () => bloc.add(DeleteClient(client.id)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        label: const Text(
                          'Delete Client',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetailRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            (value == null || value.isEmpty) ? '-' : value,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter(bool isMobile, ClientsLoaded state) {
    final startItem = (state.currentPage - 1) * state.limit + 1;
    final endItem = (state.currentPage * state.limit) > state.totalClients
        ? state.totalClients
        : (state.currentPage * state.limit);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.totalClients == 0
                  ? '0 clients'
                  : '$startItem-$endItem of ${state.totalClients}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page, size: 18),
                  onPressed: state.currentPage > 1
                      ? () => _changePage(context, state, 1)
                      : null,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(3),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18),
                  onPressed: state.currentPage > 1
                      ? () => _changePage(context, state, state.currentPage - 1)
                      : null,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(3),
                  visualDensity: VisualDensity.compact,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${state.currentPage} / ${state.totalPages}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: state.currentPage < state.totalPages
                      ? () => _changePage(context, state, state.currentPage + 1)
                      : null,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(3),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page, size: 18),
                  onPressed: state.currentPage < state.totalPages
                      ? () => _changePage(context, state, state.totalPages)
                      : null,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(3),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              state.totalClients == 0
                  ? 'No clients'
                  : 'Showing $startItem-$endItem of ${state.totalClients} clients',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Rows per page: ',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                DropdownButton<int>(
                  value: state.limit,
                  items: [25, 50, 100].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val'),
                    );
                  }).toList(),
                  onChanged: (newLimit) {
                    if (newLimit != null) {
                      _changePage(context, state, 1, newLimit: newLimit);
                    }
                  },
                  underline: const SizedBox(),
                  style: const TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.secondaryColor),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.first_page),
                  onPressed: state.currentPage > 1
                      ? () => _changePage(context, state, 1)
                      : null,
                  tooltip: 'First Page',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: state.currentPage > 1
                      ? () => _changePage(context, state, state.currentPage - 1)
                      : null,
                  tooltip: 'Previous Page',
                ),
                const SizedBox(width: 8),
                Text(
                  'Page ${state.currentPage} of ${state.totalPages}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: state.currentPage < state.totalPages
                      ? () => _changePage(context, state, state.currentPage + 1)
                      : null,
                  tooltip: 'Next Page',
                ),
                IconButton(
                  icon: const Icon(Icons.last_page),
                  onPressed: state.currentPage < state.totalPages
                      ? () => _changePage(context, state, state.totalPages)
                      : null,
                  tooltip: 'Last Page',
                ),
              ],
            ),
          ),
          const Expanded(
            flex: 1,
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMobile
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'create_client',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: context.read<ClientsBloc>(),
                        child: const CreateClientDialog(),
                      ),
                    );
                  },
                  backgroundColor: AppTheme.primaryColor,
                  icon: const Icon(Icons.add),
                  label: const Text('CREATE CLIENT'),
                ),
              ],
            ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: BlocBuilder<ClientsBloc, ClientsState>(
          builder: (context, state) {
            ClientsLoaded? loadedState;
            if (state is ClientsLoaded) {
              loadedState = state;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile, loadedState),
                const SizedBox(height: 24),
                if (isMobile && loadedState != null && loadedState.filteredClients.isNotEmpty) ...[
                  _buildSelectAllMobileRow(loadedState),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: () {
                    if (state is ClientsInitial || state is ClientsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is ClientsError) {
                      return Center(
                        child: Text(
                          'Failed to load clients: ${state.message}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (loadedState != null) {
                      final clients = loadedState.filteredClients;
                      if (clients.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No clients found',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: isMobile
                                ? ListView.separated(
                                    itemCount: clients.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final client = clients[index];
                                      final isSelected =
                                          _selectedClientIds.contains(client.id);
                                      return _buildClientMobileCard(
                                          client, isSelected);
                                    },
                                  )
                                : Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: SingleChildScrollView(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                  minWidth: constraints.maxWidth),
                                              child: DataTable(
                                                sortAscending: true,
                                                headingRowColor: WidgetStateProperty.all(
                                                  AppTheme.primaryColor.withValues(alpha: 0.05),
                                                ),
                                                columns: [
                                                  DataColumn(
                                                    label: SizedBox(
                                                      width: 24,
                                                      child: Checkbox(
                                                        value: clients.isNotEmpty &&
                                                            _selectedClientIds.length ==
                                                                loadedState!.totalClients,
                                                        onChanged: _isSelectingAll
                                                            ? null
                                                            : (val) {
                                                                if (val == true) {
                                                                  _selectAllTotalClients(
                                                                      loadedState!);
                                                                } else {
                                                                  setState(() {
                                                                    _selectedClientIds.clear();
                                                                  });
                                                                }
                                                              },
                                                      ),
                                                    ),
                                                  ),
                                                  const DataColumn(
                                                      label: Text('Name',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold))),
                                                  const DataColumn(
                                                      label: Text('Mobile Number',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold))),
                                                  const DataColumn(
                                                      label: Text('Company',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold))),
                                                  const DataColumn(
                                                      label: Text('Email',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold))),
                                                  const DataColumn(
                                                      label: Text('Venue',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold))),
                                                  const DataColumn(
                                                      label: Text('Remark',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold))),
                                                  const DataColumn(
                                                      label: Text('Added On',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold))),
                                                  const DataColumn(
                                                      label: Text('Action',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold))),
                                                ],
                                                rows: clients.map((client) {
                                                  final isSelected =
                                                      _selectedClientIds.contains(client.id);
                                                  return DataRow(
                                                    selected: isSelected,
                                                    cells: [
                                                      DataCell(
                                                        SizedBox(
                                                          width: 24,
                                                          child: Checkbox(
                                                            value: isSelected,
                                                            onChanged: (val) {
                                                              setState(() {
                                                                if (val == true) {
                                                                  _selectedClientIds.add(client.id);
                                                                } else {
                                                                  _selectedClientIds.remove(client.id);
                                                                }
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(Row(children: [
                                                        CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: AppTheme.secondaryColor
                                                              .withValues(alpha: 0.1),
                                                          child: Text(
                                                              client.name[0].toUpperCase(),
                                                              style: const TextStyle(
                                                                  color: AppTheme.secondaryColor,
                                                                  fontSize: 12)),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Text(client.name),
                                                      ])),
                                                      DataCell(Text(client.mobileNumber)),
                                                      DataCell(Text(client.companyName ?? '-')),
                                                      DataCell(Text(client.emailId ?? '-')),
                                                      DataCell(Text(client.venue ?? '-')),
                                                      DataCell(Text(client.remark ?? '-')),
                                                      DataCell(Text(
                                                        '${client.createdAt.day.toString().padLeft(2, '0')}/${client.createdAt.month.toString().padLeft(2, '0')}/${client.createdAt.year}',
                                                      )),
                                                      DataCell(IconButton(
                                                        icon: const Icon(Icons.delete_outline,
                                                            color: Colors.redAccent, size: 20),
                                                        tooltip: 'Delete client',
                                                        onPressed: () {
                                                          final bloc = context.read<ClientsBloc>();
                                                          showDialog(
                                                            context: context,
                                                            builder: (_) => _DeleteClientDialog(
                                                              client: client,
                                                              onConfirm: () =>
                                                                  bloc.add(DeleteClient(client.id)),
                                                            ),
                                                          );
                                                        },
                                                      )),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _buildPaginationFooter(isMobile, loadedState),
                        ],
                      );
                    }

                    return const SizedBox.shrink();
                  }(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeleteClientDialog extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onConfirm;

  const _DeleteClientDialog({required this.client, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth < 500 ? screenWidth * 0.85 : 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Delete Client',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                    child: Text(
                      client.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          client.mobileNumber,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone. Are you sure you want to delete this client?',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteSelectedClientsDialog extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onConfirm;

  const _DeleteSelectedClientsDialog({
    required this.selectedCount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth < 500 ? screenWidth * 0.85 : 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Delete Selected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete $selectedCount selected clients?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone and will permanently delete all selected clients.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

