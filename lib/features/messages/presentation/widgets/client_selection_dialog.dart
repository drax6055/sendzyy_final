import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/client_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/create_client_dialog.dart';
import 'package:iFloraBuzz/core/di/injection.dart';

class ClientSelectionDialog extends StatefulWidget {
  final List<String> existingNumbers;

  const ClientSelectionDialog({super.key, required this.existingNumbers});

  @override
  State<ClientSelectionDialog> createState() => _ClientSelectionDialogState();
}

class _ClientSelectionDialogState extends State<ClientSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, ClientModel> _selectedClients = {}; // number -> client

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ClientsBloc>()..add(FetchClients()),
      child: Builder(
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 500,
              height: 600,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Clients',
                        style: TextStyle(
                          fontSize: 20,
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

                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      context.read<ClientsBloc>().add(SearchClients(val));
                       setState(() {});
                    },
                  
                      decoration: InputDecoration(
                        hintText: 'Search by Name or Number......',
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
                  
                  const SizedBox(height: 16),
                  Expanded(
                    child: BlocBuilder<ClientsBloc, ClientsState>(
                      builder: (context, state) {
                        if (state is ClientsInitial ||
                            state is ClientsLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (state is ClientsError) {
                          return Center(
                            child: Text(
                              'Error: ${state.message}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        if (state is ClientsLoaded) {
                          final clients = state.filteredClients;
                          if (clients.isEmpty) {
                            return Center(
                              child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No clients match your search.'
                                      : 'No clients yet.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () {
                                    final bloc = context.read<ClientsBloc>();
                                    showDialog(
                                      context: context,
                                      builder: (_) => BlocProvider.value(
                                        value: bloc,
                                        child: CreateClientDialog(
                                          onSaved: () => bloc.add(FetchClients()),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                                  label: const Text('Add New Client'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    // Toggle: Select All / Clear All
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          final allSelected = clients.every((c) =>
                                              _selectedClients.containsKey(c.mobileNumber) ||
                                              widget.existingNumbers.contains(c.mobileNumber));
                                          if (allSelected) {
                                            for (final c in clients) {
                                              _selectedClients.remove(c.mobileNumber);
                                            }
                                          } else {
                                            for (final c in clients) {
                                              if (!widget.existingNumbers.contains(c.mobileNumber)) {
                                                _selectedClients[c.mobileNumber] = c;
                                              }
                                            }
                                          }
                                        });
                                      },
                                      icon: Icon(
                                        clients.every((c) =>
                                                _selectedClients.containsKey(c.mobileNumber) ||
                                                widget.existingNumbers.contains(c.mobileNumber))
                                            ? Icons.clear_all
                                            : Icons.done_all,
                                        size: 18,
                                      ),
                                      label: Text(
                                        clients.every((c) =>
                                                _selectedClients.containsKey(c.mobileNumber) ||
                                                widget.existingNumbers.contains(c.mobileNumber))
                                            ? 'Clear All'
                                            : 'Select All',
                                      ),
                                    ),
                                    const Spacer(),
                                    // Add new client button
                                    TextButton.icon(
                                      onPressed: () {
                                        final bloc = context.read<ClientsBloc>();
                                        showDialog(
                                          context: context,
                                          builder: (_) => BlocProvider.value(
                                            value: bloc,
                                            child: CreateClientDialog(
                                              onSaved: () => bloc.add(FetchClients()),
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                                      label: const Text('Add Client'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.secondaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${clients.length} results',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: clients.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final client = clients[index];
                                    final isAlreadyAdded = widget.existingNumbers
                                        .contains(client.mobileNumber);
                                    final isSelected =
                                        _selectedClients.containsKey(client.mobileNumber) ||
                                        isAlreadyAdded;

                                    return CheckboxListTile(
                                      value: isSelected,
                                      onChanged: isAlreadyAdded
                                          ? null
                                          : (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedClients[client.mobileNumber] = client;
                                                } else {
                                                  _selectedClients.remove(client.mobileNumber);
                                                }
                                              });
                                            },
                                      title: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppTheme
                                                .secondaryColor
                                                .withOpacity(0.1),
                                            child: Text(
                                              client.name.trim().isNotEmpty
                                                  ? client.name
                                                        .trim()[0]
                                                        .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: AppTheme.secondaryColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  client.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  client.mobileNumber,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isAlreadyAdded)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Added',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      activeColor: AppTheme.primaryColor,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _selectedClients.isEmpty
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  _selectedClients.values.toList(),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Add Selected (${_selectedClients.length})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
