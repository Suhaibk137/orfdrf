import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  String _selectedDateFilter = 'Today';
  final List<String> _dateFilters = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'Custom Range'
  ];

  DateTime? _startDate;
  DateTime? _endDate;

  // Dashboard data
  Map<String, dynamic> _dashboardData = {
    'totalOrders': 0,
    'completedOrders': 0,
    'pendingOrders': 0,
    'totalRevenue': 0.0,
    'collectedAmount': 0.0,
    'pendingAmount': 0.0,
    'orders': [],
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // Function to calculate date range based on filter
  Map<String, String> _getDateRange() {
    final now = DateTime.now();
    String startDate, endDate;
    
    switch (_selectedDateFilter) {
      case 'Today':
        startDate = DateFormat('yyyy-MM-dd').format(now);
        endDate = startDate;
        break;
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateFormat('yyyy-MM-dd').format(yesterday);
        endDate = startDate;
        break;
      case 'Last 7 Days':
        startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
        endDate = DateFormat('yyyy-MM-dd').format(now);
        break;
      case 'Last 30 Days':
        startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 29)));
        endDate = DateFormat('yyyy-MM-dd').format(now);
        break;
      case 'Custom Range':
        if (_startDate != null && _endDate != null) {
          startDate = DateFormat('yyyy-MM-dd').format(_startDate!);
          endDate = DateFormat('yyyy-MM-dd').format(_endDate!);
        } else {
          // Default to last 7 days if no custom range
          startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
          endDate = DateFormat('yyyy-MM-dd').format(now);
        }
        break;
      default:
        startDate = DateFormat('yyyy-MM-dd').format(now);
        endDate = startDate;
    }
    
    return {'startDate': startDate, 'endDate': endDate};
  }

  // Load dashboard data from API
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dateRange = _getDateRange();
      
      // Get all orders using ApiService
      final data = await ApiService.getOrders(limit: 1000);
      
      if (data['success']) {
        final List<dynamic> allOrders = data['orders'];
        
        // Filter orders by date range
        final List<dynamic> filteredOrders = allOrders.where((order) {
          try {
            final orderDate = DateTime.parse(order['created_at']).toLocal();
            final start = DateTime.parse(dateRange['startDate']!);
            final end = DateTime.parse(dateRange['endDate']!).add(const Duration(days: 1)); // Include all of end date
            
            return orderDate.isAfter(start) && orderDate.isBefore(end);
          } catch (e) {
            // Skip orders with invalid dates
            return false;
          }
        }).toList();
        
        // Calculate stats
        double totalRevenue = 0.0;
        double collectedAmount = 0.0;
        int completedOrders = 0;
        int pendingOrders = 0;
        
        for (var order in filteredOrders) {
          totalRevenue += double.parse(order['total_price'].toString());
          collectedAmount += double.parse(order['payment_collected'].toString());
          
          if (order['status'] == 'Completed') {
            completedOrders++;
          } else {
            pendingOrders++;
          }
        }
        
        // Sort orders by date (most recent first)
        filteredOrders.sort((a, b) {
          return DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']));
        });
        
        setState(() {
          _dashboardData = {
            'totalOrders': filteredOrders.length,
            'completedOrders': completedOrders,
            'pendingOrders': pendingOrders,
            'totalRevenue': totalRevenue,
            'collectedAmount': collectedAmount,
            'pendingAmount': totalRevenue - collectedAmount,
            'orders': filteredOrders,
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackbar('Failed to load data: ${data['message']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error loading dashboard data: $e');
    }
  }
  
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Select date range
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date filter
                  _buildDateFilter(),
                  const SizedBox(height: 24),
                  
                  // Stats cards
                  _buildStatsCards(),
                  const SizedBox(height: 24),
                  
                  // Recent orders
                  Expanded(
                    child: _buildRecentOrders(),
                  ),
                ],
              ),
            ),
    );
  }

  // Date filter widget
  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Date Range:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedDateFilter,
              isExpanded: true,
              underline: Container(height: 0),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedDateFilter = newValue;
                    if (newValue == 'Custom Range') {
                      _selectDateRange(context);
                    } else {
                      _loadDashboardData();
                    }
                  });
                }
              },
              items: _dateFilters.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          
          if (_selectedDateFilter == 'Custom Range' && _startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '${DateFormat('MMM d, y').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2980B9),
                ),
              ),
            ),
            
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2980B9)),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
    );
  }

  // Stats cards widget
  Widget _buildStatsCards() {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          // Orders card
          Expanded(
            child: _buildStatCard(
              title: 'Orders',
              value: _dashboardData['totalOrders'].toString(),
              details: [
                {
                  'label': 'Completed', 
                  'value': _dashboardData['completedOrders'].toString(), 
                  'color': Colors.green
                },
                {
                  'label': 'Pending', 
                  'value': _dashboardData['pendingOrders'].toString(), 
                  'color': Colors.orange
                },
              ],
              icon: Icons.shopping_cart,
              color: const Color(0xFF3498DB),
            ),
          ),
          const SizedBox(width: 16),
          
          // Revenue card
          Expanded(
            child: _buildStatCard(
              title: 'Total Revenue',
              value: '₹${NumberFormat('#,##,###').format(_dashboardData['totalRevenue'])}',
              details: [],
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF9B59B6),
            ),
          ),
          const SizedBox(width: 16),
          
          // Collected amount card
          Expanded(
            child: _buildStatCard(
              title: 'Collected Amount',
              value: '₹${NumberFormat('#,##,###').format(_dashboardData['collectedAmount'])}',
              details: [],
              icon: Icons.payments,
              color: const Color(0xFF2ECC71),
            ),
          ),
          const SizedBox(width: 16),
          
          // Pending amount card
          Expanded(
            child: _buildStatCard(
              title: 'Pending Amount',
              value: '₹${NumberFormat('#,##,###').format(_dashboardData['pendingAmount'])}',
              details: [],
              icon: Icons.schedule,
              color: const Color(0xFFE74C3C),
            ),
          ),
        ],
      ),
    );
  }

  // Stat card widget
  Widget _buildStatCard({
    required String title,
    required String value,
    required List<Map<String, dynamic>> details,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: details.map((detail) {
                return Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: detail['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${detail['label']}: ${detail['value']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // Recent orders widget
  Widget _buildRecentOrders() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to orders page
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _dashboardData['orders'].isEmpty
              ? const Center(child: Text('No orders available for the selected date range'))
              : ListView.builder(
                  itemCount: _dashboardData['orders'].length > 5 ? 5 : _dashboardData['orders'].length,
                  itemBuilder: (context, index) {
                    final order = _dashboardData['orders'][index];
                    return _buildOrderItem(order);
                  },
                ),
          ),
        ],
      ),
    );
  }

  // Order item widget
  Widget _buildOrderItem(Map<String, dynamic> order) {
    final bool isCompleted = order['status'] == 'Completed';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Order ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              order['order_code'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCompleted ? Colors.green : Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Customer name
          Expanded(
            flex: 2,
            child: Text(
              order['customer_name'],
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Date
          Expanded(
            child: Text(
              DateFormat('MMM d, y').format(DateTime.parse(order['created_at'])),
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          
          // Amount
          Expanded(
            child: Text(
              '₹${NumberFormat('#,##,###').format(double.parse(order['total_price'].toString()))}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              order['status'],
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isCompleted ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}