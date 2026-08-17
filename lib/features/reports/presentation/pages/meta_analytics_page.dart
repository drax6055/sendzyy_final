import 'dart:ui' as ui;
import 'dart:convert';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';

class MetaAnalyticsPage extends StatefulWidget {
  const MetaAnalyticsPage({super.key});

  @override
  State<MetaAnalyticsPage> createState() => _MetaAnalyticsPageState();
}

class _MetaAnalyticsPageState extends State<MetaAnalyticsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  // Filter States
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  String _selectedGranularity = 'DAILY';
  String _selectedPhone = 'All phone numbers';
  String _selectedCountry = 'All countries';

  // Available Filter Options from API
  List<String> _phoneNumbers = ['All phone numbers'];
  List<String> _countryCodes = ['All countries'];

  // Phone details map for human-readable display (ID/Number -> Display Phone / Verified Name)
  final Map<String, Map<String, String>> _phoneDetailsMap = {};

  // API Raw Data Points
  List<Map<String, dynamic>> _rawDataPoints = [];

  // Interactive Chart Hover Index
  int? _hoverIndexChart1;
  int? _hoverIndexChart2;
  int? _hoverIndexChart3;

  // Chart Checked Series Filters
  final Map<String, bool> _chart1Filters = {
    'Messages sent': true,
    'Messages delivered': true,
    'Messages received': true,
  };

  final Map<String, bool> _chart2Filters = {
    'Total': true,
    'Free customer service': true,
    'Free entry point': true,
  };

  final Map<String, bool> _chart3Filters = {
    'Total Paid': true,
    'Approximate charges': true,
    'Marketing': false,
    'Utility': false,
    'Authentication': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _fetchAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getPhoneLabel(String raw) {
    if (raw == 'All phone numbers') return 'All phone numbers';
    final cleanRaw = raw.replaceAll(RegExp(r'\D'), '');
    
    if (_phoneDetailsMap.containsKey(raw)) {
      final detail = _phoneDetailsMap[raw]!;
      final disp = detail['display'] ?? raw;
      final name = detail['name'] ?? '';
      return name.isNotEmpty ? '$disp ($name)' : disp;
    }
    if (_phoneDetailsMap.containsKey(cleanRaw)) {
      final detail = _phoneDetailsMap[cleanRaw]!;
      final disp = detail['display'] ?? raw;
      final name = detail['name'] ?? '';
      return name.isNotEmpty ? '$disp ($name)' : disp;
    }
    // If raw is standard digits like 16505550111 -> format with leading +
    if (RegExp(r'^\d{10,13}$').hasMatch(raw)) {
      return '+$raw';
    }
    return raw;
  }

  int _getUnixTimestamp(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

  Future<void> _fetchAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startUnix = _getUnixTimestamp(_dateRange.start);
      final endUnix = _getUnixTimestamp(_dateRange.end);
      final granularity = _selectedGranularity;

      // 1. Get WABA ID and access token from AuthBloc
      final authState = context.read<AuthBloc>().state;
      String? wabaId;
      String? accessToken;
      List<String> connectedPhones = [];

      if (authState is AuthAuthenticated) {
        final config = authState.tenant['whatsappConfig'];
        if (config != null) {
          wabaId = config['businessAccountId']?.toString();
          accessToken = config['accessToken']?.toString();
          final activePhone = config['displayPhoneNumber']?.toString() ?? config['phoneNumber']?.toString() ?? config['phoneNumberId']?.toString();
          final activeName = config['verifiedName']?.toString() ?? authState.tenant['name']?.toString() ?? '';
          if (activePhone != null && activePhone.isNotEmpty) {
            connectedPhones.add(activePhone);
            _phoneDetailsMap[activePhone] = {'display': activePhone, 'name': activeName};
            _phoneDetailsMap[activePhone.replaceAll(RegExp(r'\D'), '')] = {'display': activePhone, 'name': activeName};
          }
        }
      }

      // Fetch Phone Details for Dropdown Display Name mapping
      if (wabaId != null && accessToken != null && wabaId.isNotEmpty && accessToken.isNotEmpty) {
        try {
          final phoneList = await getIt<WhatsAppRepository>().fetchPhoneNumbers(wabaId: wabaId, accessToken: accessToken);
          if (phoneList != null && phoneList.isNotEmpty) {
            for (final p in phoneList) {
              final id = p['id']?.toString() ?? '';
              final display = p['display_phone_number']?.toString() ?? '';
              final name = p['verified_name']?.toString() ?? '';
              if (id.isNotEmpty) {
                _phoneDetailsMap[id] = {'display': display.isNotEmpty ? display : id, 'name': name};
              }
              if (display.isNotEmpty) {
                _phoneDetailsMap[display.replaceAll(RegExp(r'\D'), '')] = {'display': display, 'name': name};
                if (!connectedPhones.contains(display)) {
                  connectedPhones.add(display);
                }
              }
            }
          }
        } catch (_) {}
      }

      // If credentials exist, try direct Meta API call
      if (wabaId != null && accessToken != null && wabaId.isNotEmpty && accessToken.isNotEmpty && !accessToken.contains('dummy')) {
        try {
          final phonesParam = _selectedPhone != 'All phone numbers' ? '["$_selectedPhone"]' : '[]';
          final countriesParam = _selectedCountry != 'All countries' ? '["$_selectedCountry"]' : '[]';

          final volGranularity = granularity; // 'DAILY' or 'MONTHLY'
          final convGranularity = granularity == 'DAILY' ? 'DAY' : 'MONTH';

          final fields = 'analytics.start($startUnix).end($endUnix).granularity($volGranularity).phone_numbers($phonesParam).country_codes($countriesParam),'
              'conversation_analytics.start($startUnix).end($endUnix).granularity($convGranularity).dimensions(["conversation_type","conversation_direction"])';

          final cleanDio = Dio();
          final response = await cleanDio.get(
            '${AppConstants.metaGraphUrl}/$wabaId',
            queryParameters: {
              'fields': fields,
              'access_token': accessToken,
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            
            // Parse volume analytics
            final analyticsObj = data['analytics'] ?? {};
            final rawVolPoints = List<dynamic>.from(analyticsObj['data_points'] ?? []);
            
            // Parse conversation/pricing analytics
            final convObj = data['conversation_analytics'] ?? {};
            final List<dynamic> convDataList = List<dynamic>.from(convObj['data'] ?? []);
            
            // Group conversation data points by start timestamp
            final Map<int, Map<String, dynamic>> convByTime = {};
            for (final entry in convDataList) {
              final points = List<dynamic>.from(entry['data_points'] ?? []);
              for (final p in points) {
                final int start = p['start'] ?? 0;
                final int end = p['end'] ?? 0;
                final String type = p['conversation_type'] ?? 'service';
                final int count = p['count'] ?? 0;
                final double cost = (p['cost'] ?? 0.0).toDouble();
                
                if (!convByTime.containsKey(start)) {
                  convByTime[start] = {
                    'start': start,
                    'end': end,
                    'marketing': 0,
                    'utility': 0,
                    'authentication': 0,
                    'service': 0,
                    'cost_marketing': 0.0,
                    'cost_utility': 0.0,
                    'cost_authentication': 0.0,
                  };
                }
                
                final bucket = convByTime[start]!;
                if (type == 'marketing') {
                  bucket['marketing'] = (bucket['marketing'] as int) + count;
                  bucket['cost_marketing'] = (bucket['cost_marketing'] as double) + cost;
                } else if (type == 'utility') {
                  bucket['utility'] = (bucket['utility'] as int) + count;
                  bucket['cost_utility'] = (bucket['cost_utility'] as double) + cost;
                } else if (type == 'authentication') {
                  bucket['authentication'] = (bucket['authentication'] as int) + count;
                  bucket['cost_authentication'] = (bucket['cost_authentication'] as double) + cost;
                } else {
                  bucket['service'] = (bucket['service'] as int) + count;
                }
              }
            }

            final List<Map<String, dynamic>> combinedPoints = [];
            for (final vp in rawVolPoints) {
              final int start = vp['start'] ?? 0;
              final int end = vp['end'] ?? 0;
              final int sent = vp['sent'] ?? 0;
              final int delivered = vp['delivered'] ?? 0;
              final int read = vp['read'] ?? 0;
              final int received = vp['received'] ?? 0;
              
              final cb = convByTime[start] ?? {
                'marketing': 0,
                'utility': 0,
                'authentication': 0,
                'service': 0,
                'cost_marketing': 0.0,
                'cost_utility': 0.0,
                'cost_authentication': 0.0,
              };
              
              combinedPoints.add({
                'start': start,
                'end': end,
                'sent': sent,
                'delivered': delivered,
                'read': read > 0 ? read : (delivered * 0.8).toInt(),
                'received': received > 0 ? received : cb['service'] as int,
                'categories': {
                  'marketing': cb['marketing'] as int,
                  'marketing_lite': 0,
                  'utility': cb['utility'] as int,
                  'authentication': cb['authentication'] as int,
                  'authentication_international': 0,
                  'service': cb['service'] as int,
                  'ai_provider': 0,
                },
                'free_delivered': {
                  'free_customer_service': (cb['service'] as int) > 0 ? (cb['service'] as int) : 0,
                  'free_entry_point': 0,
                },
                'paid_delivered': {
                  'marketing': cb['marketing'] as int,
                  'marketing_lite': 0,
                  'utility': cb['utility'] as int,
                  'authentication': cb['authentication'] as int,
                  'authentication_international': 0,
                  'ai_provider': 0,
                },
                'costs': {
                  'marketing': cb['cost_marketing'] as double,
                  'marketing_lite': 0.0,
                  'utility': cb['cost_utility'] as double,
                  'authentication': cb['cost_authentication'] as double,
                  'authentication_international': 0.0,
                  'ai_provider': 0.0,
                }
              });
            }

            final List<dynamic> phones = analyticsObj['phone_numbers'] ?? [];
            final List<dynamic> countries = analyticsObj['country_codes'] ?? [];

            final finalPhonesList = phones.isNotEmpty ? phones.map((e) => e.toString()).toList() : connectedPhones;

            setState(() {
              _rawDataPoints = combinedPoints;
              _phoneNumbers = ['All phone numbers', ...finalPhonesList];
              _countryCodes = ['All countries', ...countries.map((e) => e.toString())];
              _isLoading = false;
            });
            return;
          }
        } catch (e) {
          debugPrint('Live Meta API failed, falling back to mock: $e');
        }
      }

      // Fallback: Generate mock data locally using tenant connected phone numbers
      String tenantIdentifier = 'default_tenant';
      if (authState is AuthAuthenticated) {
        tenantIdentifier = authState.tenant['whatsappConfig']?['phoneNumberId']?.toString() ??
            authState.tenant['email']?.toString() ??
            authState.user;
      }

      final filterPhones = _selectedPhone != 'All phone numbers' ? [_selectedPhone] : <String>[];
      final filterCountries = _selectedCountry != 'All countries' ? [_selectedCountry] : <String>[];
      
      final mockResponse = _generateLocalMockMetaAnalytics(startUnix, endUnix, filterPhones, filterCountries, granularity, tenantIdentifier, connectedPhones);
      final analytics = mockResponse['analytics'];
      final rawPoints = List<Map<String, dynamic>>.from(analytics['data_points'] ?? []);
      
      final List<dynamic> phones = analytics['phone_numbers'] ?? [];
      final List<dynamic> countries = analytics['country_codes'] ?? [];

      setState(() {
        _rawDataPoints = rawPoints;
        _phoneNumbers = ['All phone numbers', ...phones.map((e) => e.toString())];
        _countryCodes = ['All countries', ...countries.map((e) => e.toString())];
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not fetch real-time stats from Meta account. Displaying simulated analytics instead.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load analytics: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _generateLocalMockMetaAnalytics(int startTs, int endTs, List<String> filterPhones, List<String> filterCountries, String granularity, String tenantIdentifier, List<String> connectedPhones) {
    final start = DateTime.fromMillisecondsSinceEpoch(startTs * 1000);
    final end = DateTime.fromMillisecondsSinceEpoch(endTs * 1000);
    
    final tenantSeed = tenantIdentifier.hashCode.abs();
    final defaultPhone = connectedPhones.isNotEmpty
        ? connectedPhones.first
        : ((tenantIdentifier.replaceAll(RegExp(r'\D'), '').isNotEmpty)
            ? '+$tenantIdentifier'
            : "+1 555-01${(10 + (tenantSeed % 89)).toString()}");

    final phoneNumbers = filterPhones.isNotEmpty ? filterPhones : (connectedPhones.isNotEmpty ? connectedPhones : [defaultPhone]);
    final countryCodes = filterCountries.isNotEmpty ? filterCountries : ["IN", "US"];

    final List<Map<String, dynamic>> dataPoints = [];
    
    final isMonthly = granularity == 'MONTHLY';
    var current = isMonthly ? DateTime(start.year, start.month, 1) : DateTime(start.year, start.month, start.day);
    var safetyCounter = 0;
    
    while (current.isBefore(end) && safetyCounter < 100) {
      safetyCounter++;
      final pointStart = _getUnixTimestamp(current);
      final nextStep = isMonthly
          ? DateTime(current.year, current.month + 1, 1)
          : current.add(const Duration(days: 1));
      final nextTs = _getUnixTimestamp(nextStep);
      final pointEnd = nextTs < endTs ? nextTs : endTs;
      
      final dateSeed = current.day + current.month * 31 + (tenantSeed % 100);
      final factor = ((dateSeed + tenantSeed) % 5) + 1;
      final multiplier = isMonthly ? 15 : 1;
      
      final sent = (80 * factor + (dateSeed * 7) % 60) * multiplier;
      final delivered = (sent * 0.96).toInt();
      final read = (delivered * 0.82).toInt();
      final received = (15 * factor + (dateSeed * 13) % 25) * multiplier;

      final marketing = (delivered * 0.75).toInt();
      final marketingLite = (delivered * 0.05).toInt();
      final utility = (delivered * 0.12).toInt();
      final authentication = (delivered * 0.06).toInt();
      final authInternational = (delivered * 0.02).toInt();
      final service = received;
      
      final freeCustomerService = (service * 0.8).toInt();
      final freeEntryPoint = (service * 0.2).toInt();

      final costMarketing = double.parse((marketing * 0.72).toStringAsFixed(2));
      final costMarketingLite = double.parse((marketingLite * 0.40).toStringAsFixed(2));
      final costUtility = double.parse((utility * 0.35).toStringAsFixed(2));
      final costAuth = double.parse((authentication * 0.15).toStringAsFixed(2));
      final costAuthIntl = double.parse((authInternational * 1.50).toStringAsFixed(2));

      dataPoints.add({
        'start': pointStart,
        'end': pointEnd,
        'sent': sent,
        'delivered': delivered,
        'read': read,
        'received': received,
        'categories': {
          'marketing': marketing,
          'marketing_lite': marketingLite,
          'utility': utility,
          'authentication': authentication,
          'authentication_international': authInternational,
          'service': service,
          'ai_provider': 0
        },
        'free_delivered': {
          'free_customer_service': freeCustomerService,
          'free_entry_point': freeEntryPoint
        },
        'paid_delivered': {
          'marketing': marketing,
          'marketing_lite': marketingLite,
          'utility': utility,
          'authentication': authentication,
          'authentication_international': authInternational,
          'ai_provider': 0
        },
        'costs': {
          'marketing': costMarketing,
          'marketing_lite': costMarketingLite,
          'utility': costUtility,
          'authentication': costAuth,
          'authentication_international': costAuthIntl,
          'ai_provider': 0.0
        }
      });

      current = nextStep;
    }

    return {
      'analytics': {
        'phone_numbers': phoneNumbers,
        'country_codes': countryCodes,
        'granularity': granularity,
        'data_points': dataPoints
      },
      'id': "952305634918047"
    };
  }

  Future<void> _exportCSV() async {
    if (_rawDataPoints.isEmpty) return;

    final List<List<dynamic>> rows = [];
    
    // CSV Header row
    rows.add([
      'Start Date',
      'End Date',
      'Sent Count',
      'Delivered Count',
      'Read Count',
      'Received Count',
      'Marketing Count',
      'Utility Count',
      'Authentication Count',
      'Service Count',
      'Marketing Cost (₹)',
      'Utility Cost (₹)',
      'Authentication Cost (₹)',
    ]);

    for (final pt in _rawDataPoints) {
      final int startTs = pt['start'] ?? 0;
      final int endTs = pt['end'] ?? 0;
      final startDt = DateTime.fromMillisecondsSinceEpoch(startTs * 1000);
      final endDt = DateTime.fromMillisecondsSinceEpoch(endTs * 1000);

      final cats = pt['categories'] ?? {};
      final costs = pt['costs'] ?? {};

      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(startDt),
        DateFormat('yyyy-MM-dd HH:mm').format(endDt),
        pt['sent'] ?? 0,
        pt['delivered'] ?? 0,
        pt['read'] ?? 0,
        pt['received'] ?? 0,
        cats['marketing'] ?? 0,
        cats['utility'] ?? 0,
        cats['authentication'] ?? 0,
        cats['service'] ?? 0,
        costs['marketing'] ?? 0.0,
        costs['utility'] ?? 0.0,
        costs['authentication'] ?? 0.0,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final formattedStart = DateFormat('yyyyMMdd').format(_dateRange.start);
    final formattedEnd = DateFormat('yyyyMMdd').format(_dateRange.end);
    final fileName = 'meta_analytics_${formattedStart}_to_$formattedEnd.csv';
    await webDownloadBytes(bytes, fileName, mimeType: 'text/csv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-Header with title and filters
          _buildTopHeaderPanel(),
          
          // Tab bar content wrapper
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _errorMessage != null
                    ? _buildErrorScreen()
                    : TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildPerformanceOverviewTab(),
                          _buildMessagePricingTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeaderPanel() {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and export
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meta Analytics Insights',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Direct delivery, pricing, and volume stats from Meta Developer Account',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchAnalyticsData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Sync with Meta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _rawDataPoints.isEmpty ? null : _exportCSV,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tab segment and Filters Row
          Row(
            children: [
              // Segmented Tab switcher
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                    ],
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  labelColor: AppTheme.secondaryColor,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Performance overview'),
                    Tab(text: 'Message pricing'),
                  ],
                ),
              ),
              const Spacer(),

              // Filters
              _buildFilterDropdown(
                value: _selectedPhone,
                items: _phoneNumbers,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPhone = val);
                    _fetchAnalyticsData();
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                value: _selectedCountry,
                items: _countryCodes,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCountry = val);
                    _fetchAnalyticsData();
                  }
                },
              ),
              const SizedBox(width: 8),
              
              // Date Range Button
              OutlinedButton.icon(
                onPressed: () async {
                  final range = await showCompactDateRangePicker(
                    context: context,
                    initialDateRange: _dateRange,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                  );
                  if (range != null) {
                    setState(() => _dateRange = range);
                    _fetchAnalyticsData();
                  }
                },
                icon: const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.secondaryColor),
                label: Text(
                  '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 8),

              // Granularity Dropdown
              _buildFilterDropdown(
                value: _selectedGranularity,
                items: const ['DAILY', 'MONTHLY'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedGranularity = val);
                    _fetchAnalyticsData();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isPhoneDropdown = items == _phoneNumbers;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: Colors.white,
          items: items.map((item) {
            final displayText = item == 'DAILY'
                ? 'Daily'
                : (item == 'MONTHLY'
                    ? 'Monthly'
                    : (isPhoneDropdown ? _getPhoneLabel(item) : item));
            return DropdownMenuItem<String>(
              value: item,
              child: Text(displayText, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchAnalyticsData,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: Performance overview ====================
  Widget _buildPerformanceOverviewTab() {
    int totalSent = 0;
    int totalDelivered = 0;
    int totalReceived = 0;

    int catMarketing = 0;
    int catMarketingLite = 0;
    int catUtility = 0;
    int catAuth = 0;
    int catAuthIntl = 0;
    int catService = 0;

    for (final pt in _rawDataPoints) {
      totalSent += pt['sent'] as int? ?? 0;
      totalDelivered += pt['delivered'] as int? ?? 0;
      totalReceived += pt['received'] as int? ?? 0;

      final cats = pt['categories'] ?? {};
      catMarketing += cats['marketing'] as int? ?? 0;
      catMarketingLite += cats['marketing_lite'] as int? ?? 0;
      catUtility += cats['utility'] as int? ?? 0;
      catAuth += cats['authentication'] as int? ?? 0;
      catAuthIntl += cats['authentication_international'] as int? ?? 0;
      catService += cats['service'] as int? ?? 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner('Note: All insights data is approximate and may differ from what\'s shown on your invoices due to small variations in data processing.'),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDetailsGridCard(
                  title: 'All messages',
                  rows: [
                    _buildDetailRow('Messages sent', totalSent.toString(), Colors.purple.shade300),
                    _buildDetailRow('Messages delivered', totalDelivered.toString(), Colors.teal),
                    _buildDetailRow('Messages received', totalReceived.toString(), Colors.brown.shade300),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              Expanded(
                child: _buildDetailsGridCard(
                  title: 'Messages delivered',
                  subtitleValue: totalDelivered.toString(),
                  rows: [
                    _buildDetailRow('Marketing', catMarketing.toString(), Colors.green),
                    _buildDetailRow('Marketing - lite', catMarketingLite.toString(), Colors.greenAccent),
                    _buildDetailRow('Utility', catUtility.toString(), Colors.blue),
                    _buildDetailRow('Authentication', catAuth.toString(), Colors.orange),
                    _buildDetailRow('Authentication - international', catAuthIntl.toString(), Colors.deepOrange),
                    _buildDetailRow('Service', catService.toString(), Colors.pinkAccent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          _buildInteractiveChartSection(
            title: 'Messages delivered',
            filters: _chart1Filters,
            linesData: {
              'Messages sent': _rawDataPoints.map((d) => (d['sent'] as int? ?? 0).toDouble()).toList(),
              'Messages delivered': _rawDataPoints.map((d) => (d['delivered'] as int? ?? 0).toDouble()).toList(),
              'Messages received': _rawDataPoints.map((d) => (d['received'] as int? ?? 0).toDouble()).toList(),
            },
            colors: {
              'Messages sent': Colors.purple.shade400,
              'Messages delivered': Colors.teal.shade500,
              'Messages received': Colors.brown.shade400,
            },
            hoverIndex: _hoverIndexChart1,
            onHoverChanged: (idx) => setState(() => _hoverIndexChart1 = idx),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 2: Message pricing ====================
  Widget _buildMessagePricingTab() {
    double totalCharges = 0.0;
    double costMarketing = 0.0;
    double costMarketingLite = 0.0;
    double costUtility = 0.0;
    double costAuth = 0.0;
    double costAuthIntl = 0.0;

    int totalFree = 0;
    int freeCustomerService = 0;
    int freeEntryPoint = 0;

    for (final pt in _rawDataPoints) {
      final costs = pt['costs'] ?? {};
      costMarketing += costs['marketing'] as num? ?? 0.0;
      costMarketingLite += costs['marketing_lite'] as num? ?? 0.0;
      costUtility += costs['utility'] as num? ?? 0.0;
      costAuth += costs['authentication'] as num? ?? 0.0;
      costAuthIntl += costs['authentication_international'] as num? ?? 0.0;

      final free = pt['free_delivered'] ?? {};
      freeCustomerService += free['free_customer_service'] as int? ?? 0;
      freeEntryPoint += free['free_entry_point'] as int? ?? 0;
    }
    totalCharges = costMarketing + costMarketingLite + costUtility + costAuth + costAuthIntl;
    totalFree = freeCustomerService + freeEntryPoint;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner('Note: All insights data is approximate and may differ from what\'s shown on your invoices due to small variations in data processing.'),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDetailsGridCard(
                  title: 'Approximate total charges',
                  subtitleValue: '₹${totalCharges.toStringAsFixed(2)}',
                  rows: [
                    _buildDetailRow('Marketing', '₹${costMarketing.toStringAsFixed(2)}', Colors.green),
                    _buildDetailRow('Marketing - lite', '₹${costMarketingLite.toStringAsFixed(2)}', Colors.greenAccent),
                    _buildDetailRow('Utility', '₹${costUtility.toStringAsFixed(2)}', Colors.blue),
                    _buildDetailRow('Authentication', '₹${costAuth.toStringAsFixed(2)}', Colors.orange),
                    _buildDetailRow('Authentication - international', '₹${costAuthIntl.toStringAsFixed(2)}', Colors.deepOrange),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              Expanded(
                child: _buildDetailsGridCard(
                  title: 'Free messages delivered',
                  subtitleValue: totalFree.toString(),
                  rows: [
                    _buildDetailRow('Free customer service', freeCustomerService.toString(), Colors.teal),
                    _buildDetailRow('Free entry point', freeEntryPoint.toString(), Colors.purple),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          _buildInteractiveChartSection(
            title: 'Free messages delivered',
            filters: _chart2Filters,
            linesData: {
              'Total': _rawDataPoints.map((d) {
                final free = d['free_delivered'] ?? {};
                return ((free['free_customer_service'] as int? ?? 0) + (free['free_entry_point'] as int? ?? 0)).toDouble();
              }).toList(),
              'Free customer service': _rawDataPoints.map((d) => ((d['free_delivered'] ?? {})['free_customer_service'] as int? ?? 0).toDouble()).toList(),
              'Free entry point': _rawDataPoints.map((d) => ((d['free_delivered'] ?? {})['free_entry_point'] as int? ?? 0).toDouble()).toList(),
            },
            colors: {
              'Total': Colors.blue.shade600,
              'Free customer service': Colors.teal.shade500,
              'Free entry point': Colors.purple.shade400,
            },
            hoverIndex: _hoverIndexChart2,
            onHoverChanged: (idx) => setState(() => _hoverIndexChart2 = idx),
          ),
          const SizedBox(height: 32),

          _buildInteractiveChartSection(
            title: 'Paid messages delivered and approximate total charges',
            filters: _chart3Filters,
            linesData: {
              'Total Paid': _rawDataPoints.map((d) {
                final paid = d['paid_delivered'] ?? {};
                return ((paid['marketing'] as int? ?? 0) + (paid['marketing_lite'] as int? ?? 0) + (paid['utility'] as int? ?? 0) + (paid['authentication'] as int? ?? 0) + (paid['authentication_international'] as int? ?? 0)).toDouble();
              }).toList(),
              'Approximate charges': _rawDataPoints.map((d) {
                final costs = d['costs'] ?? {};
                return ((costs['marketing'] as num? ?? 0.0) + (costs['marketing_lite'] as num? ?? 0.0) + (costs['utility'] as num? ?? 0.0) + (costs['authentication'] as num? ?? 0.0) + (costs['authentication_international'] as num? ?? 0.0)).toDouble();
              }).toList(),
              'Marketing': _rawDataPoints.map((d) => ((d['paid_delivered'] ?? {})['marketing'] as int? ?? 0).toDouble()).toList(),
              'Utility': _rawDataPoints.map((d) => ((d['paid_delivered'] ?? {})['utility'] as int? ?? 0).toDouble()).toList(),
              'Authentication': _rawDataPoints.map((d) => ((d['paid_delivered'] ?? {})['authentication'] as int? ?? 0).toDouble()).toList(),
            },
            colors: {
              'Total Paid': Colors.teal.shade500,
              'Approximate charges': Colors.deepPurple,
              'Marketing': Colors.green,
              'Utility': Colors.blue,
              'Authentication': Colors.orange,
            },
            hoverIndex: _hoverIndexChart3,
            onHoverChanged: (idx) => setState(() => _hoverIndexChart3 = idx),
            showCostAxis: true,
          ),
        ],
      ),
    );
  }

  // ==================== UI Helper Widgets ====================

  Widget _buildInfoBanner(String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGridCard({
    required String title,
    String? subtitleValue,
    required List<Widget> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          if (subtitleValue != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitleValue,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveChartSection({
    required String title,
    required Map<String, bool> filters,
    required Map<String, List<double>> linesData,
    required Map<String, Color> colors,
    required int? hoverIndex,
    required ValueChanged<int?> onHoverChanged,
    bool showCostAxis = false,
  }) {
    final dates = _rawDataPoints.map((d) {
      final start = d['start'] ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch((start as int) * 1000);
      return _selectedGranularity == 'MONTHLY'
          ? DateFormat('MMM yyyy').format(dt)
          : DateFormat('dd MMM').format(dt);
    }).toList();

    final activeKeys = filters.keys.where((k) => filters[k] == true).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
              ),
              _buildChartFilterButton(filters),
            ],
          ),
          const SizedBox(height: 28),

          Stack(
            clipBehavior: Clip.none,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartWidth = constraints.maxWidth - 50.0 - (showCostAxis ? 60.0 : 20.0);
                  
                  return MouseRegion(
                    onHover: (event) {
                      final localX = event.localPosition.dx;
                      final relativeX = localX - 50.0;
                      if (dates.isNotEmpty && relativeX >= 0 && relativeX <= chartWidth) {
                        final stepX = dates.length > 1 ? chartWidth / (dates.length - 1) : chartWidth;
                        final idx = (relativeX / stepX).round().clamp(0, dates.length - 1);
                        onHoverChanged(idx);
                      } else {
                        onHoverChanged(null);
                      }
                    },
                    onExit: (event) {
                      onHoverChanged(null);
                    },
                    child: SizedBox(
                      height: 260,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _LineChartPainter(
                          dates: dates,
                          linesData: linesData,
                          colors: colors,
                          activeKeys: activeKeys,
                          hoverIndex: hoverIndex,
                          showCostAxis: showCostAxis,
                        ),
                      ),
                    ),
                  );
                },
              ),

              if (hoverIndex != null && hoverIndex < dates.length && activeKeys.isNotEmpty)
                _buildHoverTooltipOverlay(
                  index: hoverIndex,
                  dates: dates,
                  activeKeys: activeKeys,
                  linesData: linesData,
                  colors: colors,
                  showCostAxis: showCostAxis,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartFilterButton(Map<String, bool> filters) {
    return PopupMenuButton<String>(
      tooltip: 'Filter Chart Lines',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Customise', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.black54),
          ],
        ),
      ),
      itemBuilder: (context) {
        return filters.keys.map((key) {
          final isChecked = filters[key] ?? false;
          return PopupMenuItem<String>(
            value: key,
            child: StatefulBuilder(
              builder: (ctx, setMenuState) {
                return CheckboxListTile(
                  title: Text(key, style: const TextStyle(fontSize: 12)),
                  value: isChecked,
                  dense: true,
                  activeColor: AppTheme.primaryColor,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() {
                      filters[key] = val ?? false;
                    });
                    setMenuState(() {});
                  },
                );
              },
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildHoverTooltipOverlay({
    required int index,
    required List<String> dates,
    required List<String> activeKeys,
    required Map<String, List<double>> linesData,
    required Map<String, Color> colors,
    bool showCostAxis = false,
  }) {
    final double leftOffset = index * 40.0 + 80.0;
    
    return Positioned(
      left: leftOffset,
      top: 10,
      child: Material(
        elevation: 6,
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dates[index],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0xFFF0F2F5)),
              const SizedBox(height: 6),
              ...activeKeys.map((key) {
                final values = linesData[key] ?? [];
                final double val = index < values.length ? values[index] : 0.0;
                final color = colors[key] ?? Colors.blue;
                final isCost = showCostAxis && (key.contains('charges') || key.contains('cost'));
                final valStr = isCost ? '₹${val.toStringAsFixed(2)}' : val.toStringAsFixed(0);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(key, style: const TextStyle(fontSize: 10, color: Colors.black54), overflow: TextOverflow.ellipsis),
                      ),
                      Text(valStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for Interactive Smooth Line Chart
class _LineChartPainter extends CustomPainter {
  final List<String> dates;
  final Map<String, List<double>> linesData;
  final Map<String, Color> colors;
  final List<String> activeKeys;
  final int? hoverIndex;
  final bool showCostAxis;

  _LineChartPainter({
    required this.dates,
    required this.linesData,
    required this.colors,
    required this.activeKeys,
    required this.hoverIndex,
    this.showCostAxis = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty || activeKeys.isEmpty) return;

    final double paddingLeft = 50.0;
    final double paddingRight = showCostAxis ? 60.0 : 20.0;
    final double paddingTop = 20.0;
    final double paddingBottom = 30.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Determine max Y values for count and cost
    double maxCount = 0.0;
    double maxCost = 0.0;

    for (final key in activeKeys) {
      final values = linesData[key] ?? [];
      final isCost = showCostAxis && (key.contains('charges') || key.contains('cost'));
      for (final v in values) {
        if (isCost) {
          if (v > maxCost) maxCost = v;
        } else {
          if (v > maxCount) maxCount = v;
        }
      }
    }

    if (maxCount == 0) maxCount = 10;
    if (maxCost == 0) maxCost = 100.0;

    // Draw Grid Lines (4 horizontal lines)
    final gridPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..strokeWidth = 1;

    final textStyle = TextStyle(color: Colors.grey.shade500, fontSize: 10);

    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + (chartHeight / 4) * i;
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      // Y-axis count labels
      final valCount = (maxCount - (maxCount / 4) * i).toInt();
      final tp = TextPainter(
        text: TextSpan(text: valCount.toString(), style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 10, y - tp.height / 2));

      // Right Y-axis cost labels if enabled
      if (showCostAxis) {
        final valCost = (maxCost - (maxCost / 4) * i);
        final tpCost = TextPainter(
          text: TextSpan(text: '₹${valCost.toStringAsFixed(0)}', style: textStyle),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tpCost.paint(canvas, Offset(size.width - paddingRight + 10, y - tpCost.height / 2));
      }
    }

    // Draw X-axis date labels
    final double stepX = dates.length > 1 ? chartWidth / (dates.length - 1) : chartWidth;
    final int labelFrequency = (dates.length / 8).ceil().clamp(1, dates.length);

    for (int i = 0; i < dates.length; i++) {
      if (i % labelFrequency == 0 || i == dates.length - 1) {
        final x = paddingLeft + i * stepX;
        final tp = TextPainter(
          text: TextSpan(text: dates[i], style: textStyle),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - paddingBottom + 8));
      }
    }

    // Draw Lines for active series
    for (final key in activeKeys) {
      final values = linesData[key] ?? [];
      if (values.isEmpty) continue;

      final color = colors[key] ?? Colors.blue;
      final isCost = showCostAxis && (key.contains('charges') || key.contains('cost'));
      final double maxY = isCost ? maxCost : maxCount;

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final Path path = Path();

      for (int i = 0; i < values.length; i++) {
        final x = paddingLeft + i * stepX;
        final y = paddingTop + chartHeight - (values[i] / maxY) * chartHeight;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          final prevX = paddingLeft + (i - 1) * stepX;
          final prevY = paddingTop + chartHeight - (values[i - 1] / maxY) * chartHeight;
          final controlX1 = prevX + (x - prevX) / 2;
          final controlY1 = prevY;
          final controlX2 = prevX + (x - prevX) / 2;
          final controlY2 = y;
          path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        }
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw vertical hover indicator line
    if (hoverIndex != null && hoverIndex! < dates.length) {
      final hoverX = paddingLeft + hoverIndex! * stepX;

      final hoverLinePaint = Paint()
        ..color = Colors.black26
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(hoverX, paddingTop), Offset(hoverX, paddingTop + chartHeight), hoverLinePaint);

      // Draw hover dots on active lines
      for (final key in activeKeys) {
        final values = linesData[key] ?? [];
        if (hoverIndex! < values.length) {
          final color = colors[key] ?? Colors.blue;
          final isCost = showCostAxis && (key.contains('charges') || key.contains('cost'));
          final double maxY = isCost ? maxCost : maxCount;
          final y = paddingTop + chartHeight - (values[hoverIndex!] / maxY) * chartHeight;

          canvas.drawCircle(Offset(hoverX, y), 5, Paint()..color = Colors.white);
          canvas.drawCircle(Offset(hoverX, y), 5, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.dates != dates ||
        oldDelegate.hoverIndex != hoverIndex ||
        oldDelegate.activeKeys != activeKeys ||
        oldDelegate.linesData != linesData;
  }
}
