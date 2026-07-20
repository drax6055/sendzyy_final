import 'dart:ui' as ui;
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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

  Future<void> _fetchAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startUnix = MathUtils.getUnixTimestamp(_dateRange.start);
      final endUnix = MathUtils.getUnixTimestamp(_dateRange.end);
      final granularity = _selectedGranularity;

      // 1. Get WABA ID and access token from AuthBloc
      final authState = context.read<AuthBloc>().state;
      String? wabaId;
      String? accessToken;
      if (authState is AuthAuthenticated) {
        final config = authState.tenant['whatsappConfig'];
        if (config != null) {
          wabaId = config['businessAccountId']?.toString();
          accessToken = config['accessToken']?.toString();
        }
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

            setState(() {
              _rawDataPoints = combinedPoints;
              _phoneNumbers = ['All phone numbers', ...phones.map((e) => e.toString())];
              _countryCodes = ['All countries', ...countries.map((e) => e.toString())];
              _isLoading = false;
            });
            return;
          }
        } catch (e) {
          debugPrint('Live Meta API failed, falling back to mock: $e');
        }
      }

      // Fallback: Generate mock data locally
      final filterPhones = _selectedPhone != 'All phone numbers' ? [_selectedPhone] : <String>[];
      final filterCountries = _selectedCountry != 'All countries' ? [_selectedCountry] : <String>[];
      
      final mockResponse = _generateLocalMockMetaAnalytics(startUnix, endUnix, filterPhones, filterCountries, granularity);
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

  Map<String, dynamic> _generateLocalMockMetaAnalytics(int startTs, int endTs, List<String> filterPhones, List<String> filterCountries, String granularity) {
    final start = DateTime.fromMillisecondsSinceEpoch(startTs * 1000);
    final end = DateTime.fromMillisecondsSinceEpoch(endTs * 1000);
    
    final phoneNumbers = filterPhones.isNotEmpty ? filterPhones : ["16505550111", "16505550112", "16505550113"];
    final countryCodes = filterCountries.isNotEmpty ? filterCountries : ["US", "BR", "IN"];

    final List<Map<String, dynamic>> dataPoints = [];
    
    var current = DateTime(start.year, start.month, start.day);
    var safetyCounter = 0;
    
    while (current.isBefore(end) && safetyCounter < 100) {
      safetyCounter++;
      final pointStart = MathUtils.getUnixTimestamp(current);
      final nextDay = current.add(const Duration(days: 1));
      final pointEnd = nextDay.millisecondsSinceEpoch ~/ 1000 < endTs ? nextDay.millisecondsSinceEpoch ~/ 1000 : endTs;
      
      final dateSeed = current.day + current.month * 31;
      final factor = (dateSeed % 4) + 1; // 1 to 4
      
      final sent = 100 * factor + (dateSeed * 7) % 50;
      final delivered = (sent * 0.96).toInt();
      final read = (delivered * 0.82).toInt();
      final received = 20 * factor + (dateSeed * 13) % 20;

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

      current = nextDay;
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

  void _exportCSV() {
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
      'Paid Marketing',
      'Paid Utility',
      'Paid Auth',
      'Free Service',
      'Total Charges (INR)'
    ]);

    for (final dp in _rawDataPoints) {
      final start = DateTime.fromMillisecondsSinceEpoch((dp['start'] as int) * 1000).toLocal();
      final end = DateTime.fromMillisecondsSinceEpoch((dp['end'] as int) * 1000).toLocal();
      
      final cats = dp['categories'] ?? {};
      final free = dp['free_delivered'] ?? {};
      final paid = dp['paid_delivered'] ?? {};
      final costs = dp['costs'] ?? {};

      final totalCost = (costs['marketing'] ?? 0.0) +
          (costs['marketing_lite'] ?? 0.0) +
          (costs['utility'] ?? 0.0) +
          (costs['authentication'] ?? 0.0) +
          (costs['authentication_international'] ?? 0.0);

      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(start),
        DateFormat('yyyy-MM-dd HH:mm').format(end),
        dp['sent'] ?? 0,
        dp['delivered'] ?? 0,
        dp['read'] ?? 0,
        dp['received'] ?? 0,
        cats['marketing'] ?? 0,
        cats['utility'] ?? 0,
        cats['authentication'] ?? 0,
        cats['service'] ?? 0,
        paid['marketing'] ?? 0,
        paid['utility'] ?? 0,
        paid['authentication'] ?? 0,
        free['free_customer_service'] ?? 0,
        totalCost
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvString);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final formattedStart = DateFormat('yyyyMMdd').format(_dateRange.start);
    final formattedEnd = DateFormat('yyyyMMdd').format(_dateRange.end);
    final fileName = 'meta_analytics_${formattedStart}_to_$formattedEnd.csv';

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
      
    html.Url.revokeObjectUrl(url);
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
                          _buildCallingPricingTab(),
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
          const SizedBox(height: 20),
          
          // Tab segment and Filters Row
          Row(
            children: [
              // Segmented Tab switcher
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                    ],
                  ),
                  labelColor: AppTheme.secondaryColor,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Performance overview'),
                    Tab(text: 'Message pricing'),
                    Tab(text: 'Calling pricing'),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items.map((item) {
            final displayText = item == 'DAILY' ? 'Daily' : (item == 'MONTHLY' ? 'Monthly' : item);
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

    for (final dp in _rawDataPoints) {
      totalSent += (dp['sent'] as int? ?? 0);
      totalDelivered += (dp['delivered'] as int? ?? 0);
      totalReceived += (dp['received'] as int? ?? 0);

      final cats = dp['categories'] ?? {};
      catMarketing += (cats['marketing'] as int? ?? 0);
      catMarketingLite += (cats['marketing_lite'] as int? ?? 0);
      catUtility += (cats['utility'] as int? ?? 0);
      catAuth += (cats['authentication'] as int? ?? 0);
      catAuthIntl += (cats['authentication_international'] as int? ?? 0);
      catService += (cats['service'] as int? ?? 0);
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
                flex: 1,
                child: _buildDetailsGridCard(
                  title: 'All messages',
                  rows: [
                    _buildDetailRow('Messages sent', totalSent.toString(), Colors.purple.shade300),
                    _buildDetailRow('Messages delivered', totalDelivered.toString(), Colors.teal.shade400),
                    _buildDetailRow('Messages received', totalReceived.toString(), Colors.brown.shade400),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              Expanded(
                flex: 2,
                child: _buildDetailsGridCard(
                  title: 'Messages delivered',
                  subtitleValue: totalDelivered.toString(),
                  rows: [
                    _buildDetailRow('Marketing', catMarketing.toString(), Colors.green),
                    _buildDetailRow('Marketing - lite', catMarketingLite.toString(), Colors.greenAccent),
                    _buildDetailRow('Utility', catUtility.toString(), Colors.blue),
                    _buildDetailRow('Authentication', catAuth.toString(), Colors.orange),
                    _buildDetailRow('Authentication - international', catAuthIntl.toString(), Colors.deepOrange),
                    _buildDetailRow('Service', catService.toString(), Colors.pink),
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
              'Messages sent': _rawDataPoints.map((d) => (d['sent'] as int).toDouble()).toList(),
              'Messages delivered': _rawDataPoints.map((d) => (d['delivered'] as int).toDouble()).toList(),
              'Messages received': _rawDataPoints.map((d) => (d['received'] as int).toDouble()).toList(),
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
    int paidMarketing = 0;
    int paidMarketingLite = 0;
    int paidUtility = 0;
    int paidAuth = 0;
    int paidAuthIntl = 0;

    double costMarketing = 0.0;
    double costMarketingLite = 0.0;
    double costUtility = 0.0;
    double costAuth = 0.0;
    double costAuthIntl = 0.0;

    int freeCustomerService = 0;
    int freeEntryPoint = 0;

    for (final dp in _rawDataPoints) {
      final paid = dp['paid_delivered'] ?? {};
      paidMarketing += (paid['marketing'] as int? ?? 0);
      paidMarketingLite += (paid['marketing_lite'] as int? ?? 0);
      paidUtility += (paid['utility'] as int? ?? 0);
      paidAuth += (paid['authentication'] as int? ?? 0);
      paidAuthIntl += (paid['authentication_international'] as int? ?? 0);

      final costs = dp['costs'] ?? {};
      costMarketing += (costs['marketing'] as num? ?? 0.0).toDouble();
      costMarketingLite += (costs['marketing_lite'] as num? ?? 0.0).toDouble();
      costUtility += (costs['utility'] as num? ?? 0.0).toDouble();
      costAuth += (costs['authentication'] as num? ?? 0.0).toDouble();
      costAuthIntl += (costs['authentication_international'] as num? ?? 0.0).toDouble();

      final free = dp['free_delivered'] ?? {};
      freeCustomerService += (free['free_customer_service'] as int? ?? 0);
      freeEntryPoint += (free['free_entry_point'] as int? ?? 0);
    }

    final int totalPaid = paidMarketing + paidMarketingLite + paidUtility + paidAuth + paidAuthIntl;
    final double totalCharges = costMarketing + costMarketingLite + costUtility + costAuth + costAuthIntl;
    final int totalFree = freeCustomerService + freeEntryPoint;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner('Note: Approximate charges are simulated based on standard Meta conversation pricing and WABA logs.'),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDetailsGridCard(
                  title: 'Paid messages delivered',
                  subtitleValue: totalPaid.toString(),
                  rows: [
                    _buildDetailRow('Marketing', paidMarketing.toString(), Colors.green),
                    _buildDetailRow('Marketing - lite', paidMarketingLite.toString(), Colors.greenAccent),
                    _buildDetailRow('Utility', paidUtility.toString(), Colors.blue),
                    _buildDetailRow('Authentication', paidAuth.toString(), Colors.orange),
                    _buildDetailRow('Authentication - international', paidAuthIntl.toString(), Colors.deepOrange),
                  ],
                ),
              ),
              const SizedBox(width: 24),

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

  // ==================== TAB 3: Calling pricing ====================
  Widget _buildCallingPricingTab() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(40),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_rounded, size: 40, color: Colors.blue),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Calling Pricing Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'WhatsApp VoIP voice and video call metrics are currently not configured on this business account. Integrate calling webhook triggers to track live call duration costs and volume reporting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
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
    final List<String> dates = _rawDataPoints.map((dp) {
      final date = DateTime.fromMillisecondsSinceEpoch((dp['start'] as int) * 1000).toLocal();
      return DateFormat('dd MMM').format(date);
    }).toList();

    final activeKeys = filters.entries.where((e) => e.value).map((e) => e.key).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(key, style: const TextStyle(fontSize: 10, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(valStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
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
    this.hoverIndex,
    this.showCostAxis = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty || activeKeys.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(text: 'No data to display', style: TextStyle(color: Colors.grey, fontSize: 13)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
      return;
    }

    const double paddingLeft = 50.0;
    final double paddingRight = showCostAxis ? 60.0 : 20.0;
    const double paddingTop = 20.0;
    const double paddingBottom = 30.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    double maxVal = 0.0;
    double maxCost = 0.0;
    for (final key in activeKeys) {
      final data = linesData[key] ?? [];
      for (final val in data) {
        if (showCostAxis && (key.contains('charges') || key.contains('cost'))) {
          if (val > maxCost) maxCost = val;
        } else {
          if (val > maxVal) maxVal = val;
        }
      }
    }

    if (maxVal == 0) maxVal = 10.0;
    if (maxCost == 0) maxCost = 10.0;

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    const axisLabelStyle = TextStyle(color: Colors.grey, fontSize: 10);
    
    for (int i = 0; i <= 4; i++) {
      final ratio = i / 4;
      final y = paddingTop + chartHeight * (1 - ratio);
      
      canvas.drawLine(Offset(paddingLeft, y), Offset(paddingLeft + chartWidth, y), gridPaint);

      final valLabel = (maxVal * ratio).toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(text: valLabel, style: axisLabelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 8, y - tp.height / 2));

      if (showCostAxis) {
        final costLabel = '₹${(maxCost * ratio).toStringAsFixed(1)}';
        final tp2 = TextPainter(
          text: TextSpan(text: costLabel, style: axisLabelStyle.copyWith(color: Colors.deepPurple)),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp2.paint(canvas, Offset(paddingLeft + chartWidth + 8, y - tp2.height / 2));
      }
    }

    final stepX = dates.length > 1 ? chartWidth / (dates.length - 1) : chartWidth;

    for (final key in activeKeys) {
      final data = linesData[key] ?? [];
      if (data.isEmpty) continue;
      final color = colors[key] ?? Colors.blue;

      final isCostLine = showCostAxis && (key.contains('charges') || key.contains('cost'));
      final activeMax = isCostLine ? maxCost : maxVal;

      final path = Path();
      final fillPath = Path();

      for (int i = 0; i < data.length; i++) {
        final val = data[i];
        final x = paddingLeft + i * stepX;
        final y = paddingTop + chartHeight * (1 - (val / activeMax));

        if (i == 0) {
          path.moveTo(x, y);
          fillPath.moveTo(x, paddingTop + chartHeight);
          fillPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }

        if (i == data.length - 1) {
          fillPath.lineTo(x, paddingTop + chartHeight);
          fillPath.close();
        }
      }

      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, chartWidth, chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, gradientPaint);

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, linePaint);
    }

    final int labelStep = (dates.length / 5).ceil().clamp(1, dates.length);
    for (int i = 0; i < dates.length; i += labelStep) {
      final x = paddingLeft + i * stepX;
      final tp = TextPainter(
        text: TextSpan(text: dates[i], style: axisLabelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, paddingTop + chartHeight + 8));
    }

    if (hoverIndex != null && hoverIndex! >= 0 && hoverIndex! < dates.length) {
      final hX = paddingLeft + hoverIndex! * stepX;
      
      final hoverLinePaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      double startY = paddingTop;
      const dashHeight = 4.0;
      const dashSpace = 4.0;
      while (startY < paddingTop + chartHeight) {
        canvas.drawLine(
          Offset(hX, startY),
          Offset(hX, startY + dashHeight),
          hoverLinePaint,
        );
        startY += dashHeight + dashSpace;
      }

      for (final key in activeKeys) {
        final data = linesData[key] ?? [];
        if (hoverIndex! >= data.length) continue;
        final val = data[hoverIndex!];
        final color = colors[key] ?? Colors.blue;

        final isCostLine = showCostAxis && (key.contains('charges') || key.contains('cost'));
        final activeMax = isCostLine ? maxCost : maxVal;
        final hY = paddingTop + chartHeight * (1 - (val / activeMax));

        canvas.drawCircle(
          Offset(hX, hY),
          6.0,
          Paint()..color = Colors.white,
        );

        canvas.drawCircle(
          Offset(hX, hY),
          4.0,
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.dates != dates ||
        oldDelegate.linesData != linesData ||
        oldDelegate.activeKeys != activeKeys ||
        oldDelegate.hoverIndex != hoverIndex;
  }
}

class MathUtils {
  static int getUnixTimestamp(DateTime date) {
    return Math.floor(date.millisecondsSinceEpoch / 1000);
  }
}

class Math {
  static int floor(double val) => val.floor();
}
