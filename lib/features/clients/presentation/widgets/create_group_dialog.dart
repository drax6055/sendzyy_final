import 'dart:convert';
import 'dart:html' as html;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/client_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/group_bloc.dart';

class CreateGroupDialog extends StatefulWidget {
  /// Non-null means edit mode — dialog is pre-populated with existing data.
  final GroupModel? group;

  const CreateGroupDialog({super.key, this.group});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  late final TextEditingController _nameController;
  String _searchQuery = '';
  late Set<String> _selectedClientIds;
  String? _nameError;
  String? _clientsError;
  String? _bulkError;
  bool _isSubmitting = false;
  bool _isResolving = false;

  bool get _isEditMode => widget.group != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _selectedClientIds = Set<String>.from(widget.group?.clientIds ?? []);
    // Fetch clients when dialog opens
    context.read<ClientsBloc>().add(FetchClients());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    String? nameErr;
    String? clientsErr;

    if (name.isEmpty) {
      nameErr = 'Group name is required';
    }
    if (_selectedClientIds.isEmpty) {
      clientsErr = 'Please select at least one client';
    }

    if (nameErr != null || clientsErr != null) {
      setState(() {
        _nameError = nameErr;
        _clientsError = clientsErr;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _nameError = null;
      _clientsError = null;
    });

    final clientIds = _selectedClientIds.toList();
    if (_isEditMode) {
      context.read<GroupsBloc>().add(UpdateGroup(widget.group!.id, name, clientIds));
    } else {
      context.read<GroupsBloc>().add(CreateGroup(name, clientIds));
    }
  }

  List<ClientModel> _filterClients(List<ClientModel> clients) {
    if (_searchQuery.isEmpty) return clients;
    final q = _searchQuery.toLowerCase();
    return clients.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.mobileNumber.toLowerCase().contains(q);
    }).toList();
  }

  void _downloadSample() {
    const csv = 'name,mobile,company,email,venue,remark\n'
        'John Doe,919876543210,Acme Corp,john@acme.com,Main Street Store,VIP customer\n'
        'Jane Smith,919123456789,,jane@example.com,Wedding Expo 2025,\n'
        'Bob Kumar,917890123456,Bob Enterprises,,City Mall,Referred by John\n';
    final blob = html.Blob([csv], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'sample_clients.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _pickBulkFile() async {
    setState(() {
      _bulkError = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _isResolving = true;
    });

    try {
      final content = String.fromCharCodes(result.files.single.bytes!);
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      if (rows.isEmpty) throw Exception('CSV is empty');

      // Detect header row
      final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final nameIdx = _findCol(header, ['name']);
      final mobileIdx = _findCol(header, ['mobile', 'phone', 'mobilenumber', 'mobile_number', 'mobile number']);
      final companyIdx = _findCol(header, ['company', 'companyname', 'company_name', 'company name']);
      final emailIdx = _findCol(header, ['email', 'emailid', 'email_id', 'email id']);
      final venueIdx = _findCol(header, ['venue']);
      final remarkIdx = _findCol(header, ['remark', 'remarks', 'note', 'notes']);

      if (nameIdx == -1 || mobileIdx == -1) {
        throw Exception('CSV must have "name" and "mobile" columns');
      }
      if (venueIdx == -1) {
        throw Exception('CSV must have a "venue" column (required field)');
      }

      final clients = <ClientModel>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final name = _cell(row, nameIdx);
        final mobile = _cell(row, mobileIdx);
        final venue = _cell(row, venueIdx);
        if (name.isEmpty || mobile.isEmpty) continue;
        if (venue.isEmpty) continue; // skip rows without venue
        clients.add(ClientModel(
          id: '',
          tenantId: '',
          name: name,
          mobileNumber: mobile,
          companyName: companyIdx != -1 ? _cell(row, companyIdx).nullIfEmpty : null,
          emailId: emailIdx != -1 ? _cell(row, emailIdx).nullIfEmpty : null,
          venue: venue,
          remark: remarkIdx != -1 ? _cell(row, remarkIdx).nullIfEmpty : null,
          createdAt: DateTime.now(),
        ));
      }

      if (clients.isEmpty) throw Exception('No valid rows found in CSV');

      // Call resolve on repository
      final resolved = await getIt<ClientRepository>().bulkResolveClients(clients);

      setState(() {
        for (final client in resolved) {
          _selectedClientIds.add(client.id);
        }
        _isResolving = false;
        if (_clientsError != null && _selectedClientIds.isNotEmpty) {
          _clientsError = null;
        }
      });

      // Fetch/reload clients list to make newly created clients show up in the UI
      if (mounted) {
        context.read<ClientsBloc>().add(FetchClients());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${resolved.length} clients uploaded and selected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isResolving = false;
        _bulkError = e.toString().replaceAll('Exception: ', '');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $_bulkError'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  int _findCol(List<String> header, List<String> keys) {
    for (final key in keys) {
      final idx = header.indexWhere((h) => h.replaceAll(' ', '').replaceAll('_', '') == key.replaceAll(' ', '').replaceAll('_', ''));
      if (idx != -1) return idx;
    }
    return -1;
  }

  String _cell(List row, int idx) =>
      idx < row.length ? row[idx].toString().trim() : '';

  @override
  Widget build(BuildContext context) {
    return BlocListener<GroupsBloc, GroupsState>(
      listener: (context, state) {
        if (!_isSubmitting) return;
        if (state is GroupOperationSuccess) {
          Navigator.of(context).pop();
        } else if (state is GroupsError) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 520,
          height: 620,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildNameField(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _buildClientsSection(),
                const SizedBox(height: 12),
                _buildSelectedChip(),
                const SizedBox(height: 16),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _isEditMode ? 'Edit Group' : 'Create Group',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondaryColor,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          decoration: InputDecoration(
            labelText: 'Group Name *',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.group_outlined),
            errorText: _nameError,
          ),
        ),
      ],
    );
  }

  Widget _buildClientsSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Select Clients',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  if (_isResolving) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _isResolving ? null : _downloadSample,
                    child: const Text(
                      'Download Sample',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isResolving ? null : _pickBulkFile,
                    child: const Text(
                      'Bulk Upload',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search by name or mobile...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
          if (_bulkError != null) ...[
            const SizedBox(height: 6),
            Text(
              _bulkError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (_clientsError != null) ...[
            const SizedBox(height: 6),
            Text(
              _clientsError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(child: _buildClientList()),
        ],
      ),
    );
  }

  Widget _buildClientList() {
    return BlocBuilder<ClientsBloc, ClientsState>(
      builder: (context, state) {
        if (state is ClientsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ClientsError) {
          return Center(
            child: Text(
              state.message,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (state is ClientsLoaded) {
          final filtered = _filterClients(state.filteredClients);
          if (filtered.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty ? 'No clients found' : 'No clients match "$_searchQuery"',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            );
          }
          final allFilteredSelected = filtered.isNotEmpty && filtered.every((c) => _selectedClientIds.contains(c.id));
          return Column(
            children: [
              CheckboxListTile(
                dense: true,
                value: allFilteredSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      for (final client in filtered) {
                        _selectedClientIds.add(client.id);
                      }
                    } else {
                      for (final client in filtered) {
                        _selectedClientIds.remove(client.id);
                      }
                    }
                    if (_clientsError != null && _selectedClientIds.isNotEmpty) {
                      _clientsError = null;
                    }
                  });
                },
                title: const Text(
                  'Select All',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                activeColor: AppTheme.primaryColor,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final client = filtered[index];
                    final isSelected = _selectedClientIds.contains(client.id);
                    return CheckboxListTile(
                      dense: true,
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedClientIds.add(client.id);
                          } else {
                            _selectedClientIds.remove(client.id);
                          }
                          if (_clientsError != null && _selectedClientIds.isNotEmpty) {
                            _clientsError = null;
                          }
                        });
                      },
                      title: Text(
                        client.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        client.mobileNumber,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      activeColor: AppTheme.primaryColor,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSelectedChip() {
    final count = _selectedClientIds.length;
    return Chip(
      avatar: Icon(
        Icons.people_outline,
        size: 16,
        color: count > 0 ? AppTheme.secondaryColor : Colors.grey.shade500,
      ),
      label: Text(
        '$count ${count == 1 ? 'client' : 'clients'} selected',
        style: TextStyle(
          fontSize: 13,
          color: count > 0 ? AppTheme.secondaryColor : Colors.grey.shade500,
        ),
      ),
      backgroundColor: count > 0
          ? AppTheme.primaryColor.withValues(alpha: 0.12)
          : Colors.grey.shade100,
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(_isEditMode ? 'Save' : 'Create'),
          ),
        ),
      ],
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
