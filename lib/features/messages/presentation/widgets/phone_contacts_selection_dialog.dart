import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';

class PhoneContactsSelectionDialog extends StatefulWidget {
  final List<String> existingNumbers;

  const PhoneContactsSelectionDialog({
    super.key,
    required this.existingNumbers,
  });

  static Future<List<ClientModel>?> show(
    BuildContext context, {
    required List<String> existingNumbers,
  }) async {
    // Always open the Flutter dialog directly with full contact list and Select All.
    // We do NOT use the native browser Contact Picker API (navigator.contacts.select)
    // because it does not support "Select All" — users can only pick one by one.
    // Instead we load all contacts into our own modal which has full Select All support.

    if (!context.mounted) return null;

    if (ResponsiveHelper.isMobile(context)) {
      return showModalBottomSheet<List<ClientModel>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: PhoneContactsSelectionDialog(
            existingNumbers: existingNumbers,
          ),
        ),
      );
    }
    return showDialog<List<ClientModel>>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: ResponsiveHelper.getModalWidth(context, desktopWidth: 550),
          height: 650,
          child: PhoneContactsSelectionDialog(
            existingNumbers: existingNumbers,
          ),
        ),
      ),
    );
  }

  @override
  State<PhoneContactsSelectionDialog> createState() =>
      _PhoneContactsSelectionDialogState();
}

class _PhoneContactsSelectionDialogState
    extends State<PhoneContactsSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, ClientModel> _selectedContacts = {};

  List<ClientModel> _allContacts = [];
  List<ClientModel> _filteredContacts = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        // On web (mobile browser or desktop), load from server client list
        final repo = getIt<ClientRepository>();
        final result = await repo.getClients(page: 1, limit: 5000);
        setState(() {
          _allContacts = result.clients;
          _filteredContacts = List.from(_allContacts);
          _isLoading = false;
        });
        return;
      }

      // Native mobile app — request permission and load device contacts
      final bool permissionGranted =
          await FlutterContacts.requestPermission(readonly: true);
      if (!permissionGranted) {
        setState(() {
          _errorMessage =
              'Permission to access phone contacts was denied. Please allow contact permission in device settings.';
          _isLoading = false;
        });
        return;
      }

      final deviceContacts = await FlutterContacts.getContacts(
          withProperties: true, withPhoto: false);

      final List<ClientModel> parsedList = [];
      for (final c in deviceContacts) {
        final name = c.displayName.isNotEmpty
            ? c.displayName
            : '${c.name.first} ${c.name.last}'.trim();
        for (final phone in c.phones) {
          final rawNumber = phone.number.replaceAll(RegExp(r'[^\d+]'), '');
          if (rawNumber.isNotEmpty) {
            parsedList.add(ClientModel(
              id: '${c.id}_${parsedList.length}',
              tenantId: 'device_contact',
              name: name.isNotEmpty ? name : 'Phone Contact',
              mobileNumber: rawNumber,
              companyName: 'Device Contact',
              createdAt: DateTime.now(),
            ));
          }
        }
      }

      setState(() {
        _allContacts = parsedList;
        _filteredContacts = List.from(_allContacts);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load contacts: $e';
        _isLoading = false;
      });
    }
  }


  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      final q = query.trim().toLowerCase();
      setState(() {
        if (q.isEmpty) {
          _filteredContacts = List.from(_allContacts);
        } else {
          _filteredContacts = _allContacts.where((c) {
            final name = c.name.toLowerCase();
            final phone = c.mobileNumber.toLowerCase();
            final company = (c.companyName ?? '').toLowerCase();
            return name.contains(q) || phone.contains(q) || company.contains(q);
          }).toList();
        }
      });
    });
  }

  bool get _isAllFilteredSelected {
    if (_filteredContacts.isEmpty) return false;
    final available = _filteredContacts
        .where((c) => !widget.existingNumbers.contains(c.mobileNumber));
    if (available.isEmpty) return false;
    return available.every((c) => _selectedContacts.containsKey(c.mobileNumber));
  }

  void _toggleSelectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        for (final c in _filteredContacts) {
          if (!widget.existingNumbers.contains(c.mobileNumber)) {
            _selectedContacts[c.mobileNumber] = c;
          }
        }
      } else {
        for (final c in _filteredContacts) {
          _selectedContacts.remove(c.mobileNumber);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = _filteredContacts
        .where((c) => !widget.existingNumbers.contains(c.mobileNumber))
        .length;

    return Column(
      children: [
        // Top Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              const Icon(Icons.contacts_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Select Contacts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Search + Select All Controls Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search contacts by name or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _isAllFilteredSelected,
                        activeColor: AppTheme.primaryColor,
                        onChanged: availableCount > 0 ? _toggleSelectAll : null,
                      ),
                      GestureDetector(
                        onTap: () {
                          if (availableCount > 0) {
                            _toggleSelectAll(!_isAllFilteredSelected);
                          }
                        },
                        child: Text(
                          _isAllFilteredSelected
                              ? 'Deselect All'
                              : 'Select All ($availableCount)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: availableCount > 0
                                ? AppTheme.primaryColor
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: availableCount > 0
                        ? () => _toggleSelectAll(!_isAllFilteredSelected)
                        : null,
                    icon: Icon(
                      _isAllFilteredSelected
                          ? Icons.clear_all_rounded
                          : Icons.done_all_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isAllFilteredSelected ? 'Clear All' : 'Select All',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: availableCount > 0
                          ? AppTheme.primaryColor
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Contact List Body
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : _filteredContacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.contacts_outlined,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No contacts match your search.'
                                    : 'No contacts found.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredContacts.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            final number = contact.mobileNumber;
                            final isAlreadyAdded =
                                widget.existingNumbers.contains(number);
                            final isSelected =
                                _selectedContacts.containsKey(number);

                            return CheckboxListTile(
                              value: isAlreadyAdded ? true : isSelected,
                              enabled: !isAlreadyAdded,
                              activeColor: isAlreadyAdded
                                  ? Colors.grey
                                  : AppTheme.primaryColor,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedContacts[number] = contact;
                                  } else {
                                    _selectedContacts.remove(number);
                                  }
                                });
                              },
                              secondary: CircleAvatar(
                                backgroundColor: AppTheme.secondaryColor
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  contact.name.isNotEmpty
                                      ? contact.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppTheme.secondaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                contact.name.isNotEmpty
                                    ? contact.name
                                    : 'Unnamed Contact',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isAlreadyAdded
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                isAlreadyAdded
                                    ? '$number · (Already added)'
                                    : contact.companyName != null &&
                                            contact.companyName!.isNotEmpty
                                        ? '$number · ${contact.companyName}'
                                        : number,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isAlreadyAdded
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            );
                          },
                        ),
        ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedContacts.isEmpty
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                            _selectedContacts.values.toList(),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Import (${_selectedContacts.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
