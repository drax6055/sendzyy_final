import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/presentation/widgets/create_client_dialog.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/client_bloc.dart';
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

  final List<ClientModel> _clients = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalClients = 0;
  bool _isLoading = false;
  String? _errorMessage;
  late final ScrollController _scrollController;
  Timer? _searchDebounce;

  // Selection states
  bool _allTotalSelected = false;
  bool _isSelectingAll = false;

  Future<void> _selectAllTotalClients() async {
    setState(() {
      _isSelectingAll = true;
    });
    try {
      final repo = getIt<ClientRepository>();
      final paginatedResult = await repo.getClients(
        page: 1,
        limit: _totalClients,
        search: _searchController.text.trim(),
      );
      setState(() {
        for (final c in paginatedResult.clients) {
          if (!widget.existingNumbers.contains(c.mobileNumber)) {
            _selectedClients[c.mobileNumber] = c;
          }
        }
        _allTotalSelected = true;
        _isSelectingAll = false;
      });
    } catch (e) {
      setState(() {
        _isSelectingAll = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting all clients: $e')),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadClients(page: 1);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_searchDebounce?.isActive == true) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _currentPage < _totalPages) {
        _loadClients(page: _currentPage + 1);
      }
    }
  }

  Future<void> _loadClients({required int page}) async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = getIt<ClientRepository>();
      final paginatedResult = await repo.getClients(
        page: page,
        limit: 50,
        search: _searchController.text.trim(),
      );

      setState(() {
        if (page == 1) {
          _clients.clear();
          _allTotalSelected = false;
        }
        _clients.addAll(paginatedResult.clients);
        _currentPage = paginatedResult.currentPage;
        _totalPages = paginatedResult.totalPages;
        _totalClients = paginatedResult.totalClients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                  _loadClients(page: 1);
                });
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
                          _searchDebounce?.cancel();
                          _loadClients(page: 1);
                        },
                      )
                    : Icon(Icons.search, color: Colors.grey.shade400, size: 20),
              ),
            ),

            const SizedBox(height: 16),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading && _clients.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_errorMessage != null && _clients.isEmpty) {
                    return Center(
                      child: Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (_clients.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
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
                              showDialog(
                                context: context,
                                builder: (_) => BlocProvider.value(
                                  value: getIt<ClientsBloc>(),
                                  child: CreateClientDialog(
                                    onSaved: () {
                                      _loadClients(page: 1);
                                    },
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
                            // Toggle: Select All / Clear All (applies to currently loaded items)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  final allSelected = _clients.every(
                                    (c) =>
                                        _selectedClients.containsKey(
                                          c.mobileNumber,
                                        ) ||
                                        widget.existingNumbers.contains(
                                          c.mobileNumber,
                                        ),
                                  );
                                  if (allSelected) {
                                    _selectedClients.clear();
                                    _allTotalSelected = false;
                                  } else {
                                    if (_totalClients > _clients.length) {
                                      _selectAllTotalClients();
                                    } else {
                                      for (final c in _clients) {
                                        if (!widget.existingNumbers.contains(
                                          c.mobileNumber,
                                        )) {
                                          _selectedClients[c.mobileNumber] = c;
                                        }
                                      }
                                    }
                                  }
                                });
                              },
                              icon: Icon(
                                _clients.every(
                                      (c) =>
                                          _selectedClients.containsKey(
                                            c.mobileNumber,
                                          ) ||
                                          widget.existingNumbers.contains(
                                            c.mobileNumber,
                                          ),
                                    )
                                    ? Icons.clear_all
                                    : Icons.done_all,
                                size: 18,
                              ),
                              label: Text(
                                _clients.every(
                                      (c) =>
                                          _selectedClients.containsKey(
                                            c.mobileNumber,
                                          ) ||
                                          widget.existingNumbers.contains(
                                            c.mobileNumber,
                                          ),
                                    )
                                    ? 'Clear All'
                                    : 'Select All',
                              ),
                            ),
                            const Spacer(),
                            // Add new client button
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => BlocProvider.value(
                                    value: getIt<ClientsBloc>(),
                                    child: CreateClientDialog(
                                      onSaved: () {
                                        _loadClients(page: 1);
                                      },
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                size: 18,
                              ),
                              label: const Text('Add Client'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.secondaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isSelectingAll) ...[
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                '$_totalClients results',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: _clients.length + (_isLoading ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == _clients.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final client = _clients[index];
                            final isAlreadyAdded = widget.existingNumbers
                                .contains(client.mobileNumber);
                            final isSelected =
                                _selectedClients.containsKey(
                                  client.mobileNumber,
                                ) ||
                                isAlreadyAdded;

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: isAlreadyAdded
                                  ? null
                                  : (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedClients[client
                                                  .mobileNumber] =
                                              client;
                                        } else {
                                          _selectedClients.remove(
                                            client.mobileNumber,
                                          );
                                          _allTotalSelected = false;
                                        }
                                      });
                                    },
                              title: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.secondaryColor
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      client.name.trim().isNotEmpty
                                          ? client.name.trim()[0].toUpperCase()
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
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
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                      ),
                    ],
                  );
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
  }
}
