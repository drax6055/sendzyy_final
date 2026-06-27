import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/client_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/group_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/bulk_import_dialog.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/create_client_dialog.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/create_group_dialog.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/groups_tab.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/qr_code_dialog.dart';

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
                builder: (context) => FloatingActionButton.extended(
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
                ),
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _changePage(BuildContext context, ClientsLoaded state, int targetPage, {int? newLimit}) {
    final limit = newLimit ?? state.limit;
    if (state.searchQuery.isNotEmpty) {
      context.read<ClientsBloc>().add(SearchClients(state.searchQuery, page: targetPage, limit: limit));
    } else {
      context.read<ClientsBloc>().add(FetchClients(page: targetPage, limit: limit));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Row(
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
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Clients',
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
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                          context.read<ClientsBloc>().add(SearchClients(val, page: 1, limit: 50));
                        });
                        setState(() {});
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
                          horizontal: 24,
                          vertical: 12,
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
                                  setState(() {});
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
                ),
               ElevatedButton.icon(
                        onPressed: () {
                           showDialog(
                 context: context,
                 builder: (_) => BlocProvider.value(
                   value: context.read<ClientsBloc>(),
                   child: const BulkImportDialog(),
                 ),
               );
                        },
                            
                        icon: const Icon(Icons.add),
                        label: const Text('bulk_import'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          minimumSize: const Size(150, 45),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const QrCodeDialog(),
                          );
                        },
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Generate QR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(150, 45),
                        ),
                      ),
              ],
            ),

            const SizedBox(height: 32),

            Expanded(
              child: BlocBuilder<ClientsBloc, ClientsState>(
                builder: (context, state) {
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

                  if (state is ClientsLoaded) {
                    final clients = state.filteredClients;
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

                    final startItem = (state.currentPage - 1) * state.limit + 1;
                    final endItem = (state.currentPage * state.limit) > state.totalClients
                        ? state.totalClients
                        : (state.currentPage * state.limit);

                    return Column(
                      children: [
                        Expanded(
                          child: Container(
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
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        sortAscending: true,
                                        headingRowColor: WidgetStateProperty.all(
                                          AppTheme.primaryColor.withValues(alpha: 0.05),
                                        ),
                                        columns: const [
                                          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Company', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Venue', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Remark', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Added On', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                        rows: clients.map((client) {
                                          return DataRow(cells: [
                                            DataCell(Row(children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                                                child: Text(client.name[0].toUpperCase(),
                                                    style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 12)),
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
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                              tooltip: 'Delete client',
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
                                            )),
                                          ]);
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
                        Container(
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
                        ),
                      ],
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
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
                    fontSize: 20,
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
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                    child: Text(
                      client.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          client.mobileNumber,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        if (client.companyName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            client.companyName!,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                        if (client.emailId != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            client.emailId!,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'This action cannot be undone. Are you sure you want to delete this client?',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 32),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
