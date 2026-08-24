import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/features/leads/presentation/pages/lead_management_page.dart';

class IndiaMartLeadsPage extends StatefulWidget {
  const IndiaMartLeadsPage({super.key});

  @override
  State<IndiaMartLeadsPage> createState() => _IndiaMartLeadsPageState();
}

class _IndiaMartLeadsPageState extends State<IndiaMartLeadsPage> {
  final Dio _dio = getIt<Dio>();

  bool _loading = true;
  bool _syncing = false;
  bool _connected = false;
  String? _glusrMobile;
  DateTime? _lastSyncedAt;
  List<LeadModel> _leads = [];
  DateTimeRange? _dateRange;
  String? _error;
  bool _keyExpired = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    setState(() {
      _loading = true;
      _error = null;
      _keyExpired = false;
    });

    try {
      final response = await _dio.get('/api/integrations/indiamart');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['connected'] == true) {
          setState(() {
            _connected = true;
            _glusrMobile = data['glusrMobile'];
            _lastSyncedAt = data['lastSyncedAt'] != null
                ? DateTime.tryParse(data['lastSyncedAt'].toString())
                : null;
          });
          // Connection is active, fetch stored leads
          await _fetchLeads();
        } else {
          setState(() {
            _connected = false;
            _leads = [];
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load connection status: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchLeads() async {
    try {
      final params = <String, dynamic>{
        'source': 'indiamart',
        if (_dateRange != null) ...{
          'startDate': _dateRange!.start.toIso8601String(),
          'endDate': _dateRange!.end.toIso8601String(),
        }
      };

      final response = await _dio.get('/api/leads', queryParameters: params);
      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> items;
        if (data is List) {
          items = data;
        } else if (data is Map && data['leads'] != null) {
          items = data['leads'] as List;
        } else {
          items = [];
        }

        final fetched = items
            .map((e) => LeadModel.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _leads = fetched;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load leads from database: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      final body = <String, dynamic>{
        if (_dateRange != null) ...{
          'startDate': _dateRange!.start.toIso8601String(),
          'endDate': _dateRange!.end.toIso8601String(),
        }
      };

      final response = await _dio.post('/api/integrations/indiamart/sync', data: body);
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _keyExpired = false;
          _lastSyncedAt = data['lastSyncedAt'] != null
              ? DateTime.tryParse(data['lastSyncedAt'].toString())
              : DateTime.now();
        });
        
        final syncResult = data['syncResult'];
        final int fetchedCount = syncResult != null ? syncResult['totalRecords'] ?? 0 : 0;
        final int newCount = syncResult != null ? syncResult['newLeadsCount'] ?? 0 : 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync complete! Fetched $fetchedCount queries ($newCount new leads saved).',
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );

        await _fetchLeads();
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        final data = e.response?.data;
        if (data is Map && data['code'] == 'KEY_EXPIRED') {
          setState(() {
            _keyExpired = true;
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_keyExpired
              ? 'Key Expired: Please update your IndiaMART CRM key.'
              : 'Sync failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _syncing = false;
      });
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect IndiaMART?'),
        content: const Text(
          'Are you sure you want to disconnect IndiaMART? Stored leads will remain in the database, but no new leads will be synced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(100, 44),
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
    });

    try {
      final response = await _dio.delete('/api/integrations/indiamart');
      if (response.statusCode == 200) {
        setState(() {
          _connected = false;
          _glusrMobile = null;
          _lastSyncedAt = null;
          _leads = [];
          _keyExpired = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IndiaMART integration disconnected.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to disconnect: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showConnectDialog() {
    final mobileCtrl = TextEditingController(text: _glusrMobile);
    final keyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool connecting = false;
    bool obscureKey = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.store_rounded, color: AppTheme.secondaryColor),
                  const SizedBox(width: 10),
                  Text(_connected ? 'Update IndiaMART Key' : 'Connect IndiaMART'),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Enter your credentials generated from the IndiaMART Seller Panel (Lead Manager > CRM Integration).',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Registered Mobile (GLUSR_MOBILE)',
                          prefixIcon: Icon(Icons.phone_iphone_rounded),
                          hintText: 'e.g. 9876543210',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: keyCtrl,
                        obscureText: obscureKey,
                        decoration: InputDecoration(
                          labelText: 'CRM Key (glusr_crm_key)',
                          prefixIcon: const Icon(Icons.key_rounded),
                          hintText: 'Enter API key',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureKey
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setModalState(() {
                                obscureKey = !obscureKey;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'CRM Key is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: connecting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 44),
                  ),
                  onPressed: connecting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() {
                            connecting = true;
                          });

                          try {
                            final response = await _dio.post(
                              '/api/integrations/indiamart',
                              data: {
                                'glusrMobile': mobileCtrl.text.trim(),
                                'glusrCrmKey': keyCtrl.text.trim(),
                              },
                            );

                            if (response.statusCode == 200) {
                              final data = response.data;
                              setState(() {
                                _connected = true;
                                _glusrMobile = mobileCtrl.text.trim();
                                _keyExpired = false;
                                _lastSyncedAt = data['config'] != null &&
                                        data['config']['lastSyncedAt'] != null
                                    ? DateTime.tryParse(data['config']['lastSyncedAt'].toString())
                                    : DateTime.now();
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Connected successfully!'),
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              );

                              Navigator.pop(ctx);
                              await _fetchLeads();
                            }
                          } catch (e) {
                            String errMessage = e.toString();
                            if (e is DioException && e.response?.statusCode == 401) {
                              errMessage = 'Authentication failed. Please verify your CRM API key.';
                            }
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Connection failed: $errMessage'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            setModalState(() {
                              connecting = false;
                            });
                          }
                        },
                  child: connecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MMM-yyyy hh:mm a');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upper Header Actions Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'IndiaMART Leads',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                          if (_connected && _lastSyncedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Last Synced: ${dateFormat.format(_lastSyncedAt!.toLocal())}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ]
                        ],
                      ),
                      const Spacer(),
                      if (_connected) ...[
                        // Connected badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Connected: $_glusrMobile',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _syncing ? null : _syncNow,
                          icon: _syncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync, size: 16),
                          label: const Text('Sync Now'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.secondaryColor,
                            side: const BorderSide(color: AppTheme.secondaryColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _disconnect,
                          icon: const Icon(Icons.link_off_rounded, size: 16),
                          label: const Text('Disconnect'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: _showConnectDialog,
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Connect Now'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(150, 44),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Expired Key Warnings Banner
                if (_keyExpired)
                  Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CRM API Key Expired/Deactivated',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your IndiaMART CRM key has expired due to 7 days of inactivity. Please log in to your IndiaMART Seller Dashboard, generate a new key, and update it here.',
                                style: TextStyle(
                                  color: Colors.amber.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _showConnectDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(130, 44),
                          ),
                          child: const Text('Update Key'),
                        ),
                      ],
                    ),
                  ),

                // Table controls (Filters) and the Table
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Card(
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Table Filter Bar
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Text(
                                  'Synced Lead Entries',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                                const Spacer(),
                                if (_connected) ...[
                                  // Date range button
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showCompactDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                        initialDateRange: _dateRange,
                                      );

                                      if (picked != null) {
                                        final diff = picked.end.difference(picked.start).inDays;
                                        if (diff > 7) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'IndiaMART API restricts date queries to a maximum of 7 days.',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        setState(() {
                                          _dateRange = picked;
                                        });

                                        _fetchLeads();
                                        _syncNow(); // Pull historical leads for selection
                                      }
                                    },
                                    icon: const Icon(Icons.date_range_rounded, size: 16),
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _dateRange == null
                                              ? 'Historical Date Range'
                                              : '${DateFormat('dd/MM').format(_dateRange!.start)} – ${DateFormat('dd/MM').format(_dateRange!.end)}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        if (_dateRange != null) ...[
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _dateRange = null;
                                              });
                                              _fetchLeads();
                                            },
                                            child: const Icon(Icons.close, size: 14),
                                          ),
                                        ],
                                      ],
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.grey.shade300),
                                      foregroundColor: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          // Table Body
                          Expanded(
                            child: !_connected
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.store_outlined,
                                          size: 80,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'IndiaMART Integration is not connected.',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Connect your seller panel to sync incoming marketplace leads.',
                                          style: TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: _showConnectDialog,
                                          icon: const Icon(Icons.link_rounded),
                                          label: const Text('Connect Now'),
                                          style: ElevatedButton.styleFrom(
                                            minimumSize: const Size(150, 44),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _leads.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.assignment_turned_in_rounded,
                                              size: 64,
                                              color: Colors.grey.shade300,
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'No IndiaMART leads found.',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Try selecting a date range or click "Sync Now" to fetch records.',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      )
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          return SizedBox(
                                            width: constraints.maxWidth,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.vertical,
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: DataTable(
                                                  headingRowColor: WidgetStateProperty.all(
                                                    AppTheme.secondaryColor.withValues(alpha: 0.04),
                                                  ),
                                                  columns: const [
                                                    DataColumn(
                                                      label: Text(
                                                        'Date & Time',
                                                        style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Sender Name',
                                                        style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Mobile Number',
                                                        style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Product',
                                                        style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Requirement / Message',
                                                        style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                  rows: _leads.map((lead) {
                                                    // Map metadata fields
                                                    final queryProduct = lead.metadata['QUERY_PRODUCT_NAME'] ?? '-';
                                                    final queryMessage = lead.metadata['QUERY_MESSAGE'] ?? lead.message;

                                                    return DataRow(
                                                      cells: [
                                                        DataCell(
                                                          Text(dateFormat.format(lead.createdAt.toLocal())),
                                                        ),
                                                        DataCell(
                                                          Text(lead.name.isNotEmpty ? lead.name : '-'),
                                                        ),
                                                        DataCell(
                                                          Text(lead.mobileNumber),
                                                        ),
                                                        DataCell(
                                                          Text(queryProduct.toString()),
                                                        ),
                                                        DataCell(
                                                          SizedBox(
                                                            width: 250,
                                                            child: Text(
                                                              queryMessage.toString(),
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
