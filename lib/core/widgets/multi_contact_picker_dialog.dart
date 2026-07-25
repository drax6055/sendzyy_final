import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

class ContactItem {
  final Contact contact;
  final Phone phone;
  final String normalizedNumber;

  ContactItem({
    required this.contact,
    required this.phone,
    required this.normalizedNumber,
  });
}

class MultiContactPickerDialog extends StatefulWidget {
  const MultiContactPickerDialog({super.key});

  /// Helper method to show the picker bottom sheet
  static Future<List<String>?> show(BuildContext context) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MultiContactPickerDialog(),
    );
  }

  @override
  State<MultiContactPickerDialog> createState() => _MultiContactPickerDialogState();
}

class _MultiContactPickerDialogState extends State<MultiContactPickerDialog> {
  bool _isLoading = true;
  bool _permissionDenied = false;
  bool _isMissingPlugin = false;
  String? _errorMessage;

  List<ContactItem> _allContactItems = [];
  List<ContactItem> _filteredContactItems = [];
  final Set<String> _selectedNumbers = {};
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
      _isMissingPlugin = false;
      _errorMessage = null;
    });

    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _permissionDenied = true;
          });
        }
        return;
      }

      final contacts = await FlutterContacts.getAll();

      final List<ContactItem> items = [];
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final raw = phone.number.replaceAll(RegExp(r'[^\d+]'), '');
          if (raw.isNotEmpty) {
            items.add(ContactItem(
              contact: contact,
              phone: phone,
              normalizedNumber: raw,
            ));
          }
        }
      }

      // Sort alphabetically by contact name
      items.sort((a, b) {
        final nameA = (a.contact.displayName ?? '').toLowerCase();
        final nameB = (b.contact.displayName ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _allContactItems = items;
          _filteredContactItems = items;
          _isLoading = false;
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMissingPlugin = true;
        });
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('MissingPluginException')) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isMissingPlugin = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load contacts: $e';
          });
        }
      }
    }
  }

  Future<void> _fallbackPickSingleContact() async {
    try {
      final picker = FlutterNativeContactPicker();
      final contact = await picker.selectContact();
      if (contact == null) return;
      final List<String> numbers = contact.phoneNumbers ?? [];
      if (numbers.isNotEmpty) {
        final raw = numbers.first.replaceAll(RegExp(r'[^\d+]'), '');
        if (raw.isNotEmpty && mounted) {
          Navigator.of(context).pop([raw]);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick contact: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContactItems = List.from(_allContactItems);
      } else {
        _filteredContactItems = _allContactItems.where((item) {
          final displayName = (item.contact.displayName ?? '').toLowerCase();
          final nameMatch = displayName.contains(query);
          final phoneMatch = item.normalizedNumber.contains(query) || item.phone.number.contains(query);
          return nameMatch || phoneMatch;
        }).toList();
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final allFilteredNumbers = _filteredContactItems.map((e) => e.normalizedNumber).toSet();
      final isAllSelected = allFilteredNumbers.every((phoneNumber) => _selectedNumbers.contains(phoneNumber));

      if (isAllSelected) {
        _selectedNumbers.removeAll(allFilteredNumbers);
      } else {
        _selectedNumbers.addAll(allFilteredNumbers);
      }
    });
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return AppTheme.primaryColor;
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> colors = [
      const Color(0xFF075E54),
      const Color(0xFF128C7E),
      const Color(0xFF25D366),
      const Color(0xFF34B7F1),
      const Color(0xFF074B54),
      const Color(0xFF1B5E20),
    ];
    return colors[hash % colors.length];
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return parts[0][0].toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height * 0.85;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.contacts_rounded, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Contacts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${_selectedNumbers.length} contacts selected',
                        style: TextStyle(
                          fontSize: 13,
                          color: _selectedNumbers.isNotEmpty ? AppTheme.primaryColor : Colors.grey.shade600,
                          fontWeight: _selectedNumbers.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search & Select All Bar
          if (!_isLoading && !_permissionDenied && !_isMissingPlugin && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or number...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _filteredContactItems.isEmpty ? null : _toggleSelectAll,
                    icon: Icon(
                      _filteredContactItems.isNotEmpty &&
                              _filteredContactItems
                                  .every((item) => _selectedNumbers.contains(item.normalizedNumber))
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    label: Text(
                      _filteredContactItems.isNotEmpty &&
                              _filteredContactItems
                                  .every((item) => _selectedNumbers.contains(item.normalizedNumber))
                          ? 'Deselect All'
                          : 'Select All',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 24),

          // Main Content
          Expanded(
            child: _buildBody(),
          ),

          // Bottom Action Button
          if (!_isLoading && !_permissionDenied && !_isMissingPlugin && _errorMessage == null)
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: mediaQuery.padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _selectedNumbers.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop(_selectedNumbers.toList());
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _selectedNumbers.isEmpty
                      ? 'Select Contacts'
                      : 'Add ${_selectedNumbers.length} ${_selectedNumbers.length == 1 ? 'Contact' : 'Contacts'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text(
              'Loading contacts...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_isMissingPlugin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update_rounded, size: 60, color: Colors.blue.shade600),
              const SizedBox(height: 16),
              const Text(
                'Rebuild Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'New native permissions were installed.\nPlease stop and re-run your app ("flutter run" or restart the build) to enable Multi-Contact Selection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fallbackPickSingleContact,
                icon: const Icon(Icons.person_add),
                label: const Text('Pick Single Contact (Fallback)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loadContacts,
                child: const Text('Retry Multi-Contact Check'),
              ),
            ],
          ),
        ),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts_outlined, size: 64, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              const Text(
                'Permission Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Contact access permission is needed to select multiple contacts from your device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.security_rounded),
                label: const Text('Allow Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadContacts,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredContactItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No contacts matching "${_searchController.text}"'
                  : 'No contacts found with phone numbers',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _filteredContactItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
      itemBuilder: (context, index) {
        final item = _filteredContactItems[index];
        final isSelected = _selectedNumbers.contains(item.normalizedNumber);
        final displayName = item.contact.displayName ?? '';
        final avatarColor = _getAvatarColor(displayName);
        final initials = _getInitials(displayName);

        return CheckboxListTile(
          value: isSelected,
          activeColor: AppTheme.primaryColor,
          checkboxShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          onChanged: (bool? checked) {
            setState(() {
              if (checked == true) {
                _selectedNumbers.add(item.normalizedNumber);
              } else {
                _selectedNumbers.remove(item.normalizedNumber);
              }
            });
          },
          title: Text(
            displayName.isNotEmpty ? displayName : 'Unknown',
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            item.phone.number,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          secondary: CircleAvatar(
            backgroundColor: avatarColor,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }
}
