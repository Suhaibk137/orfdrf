import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class IndividualDataPage extends StatefulWidget {
  const IndividualDataPage({super.key});

  @override
  State<IndividualDataPage> createState() => _IndividualDataPageState();
}

class _IndividualDataPageState extends State<IndividualDataPage> {
  bool _isLoading = true;
  String _selectedDateFilter = 'Today';
  String? _selectedEmployeeId;
  
  final List<String> _dateFilters = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'Custom Range'
  ];

  // Date range for custom filter
  DateTime? _startDate;
  DateTime? _endDate;

  // Data for the page
  List<dynamic> _employees = [];
  List<dynamic> _filteredOrders = [];
  Map<String, dynamic> _employeeStats = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  // Load employees list
  Future<void> _loadEmployees() async {
    try {
      final data = await ApiService.getEmployees();
      if (data['success']) {
        setState(() {
          _employees = data['employees'];
          // Default to first employee
          if (_employees.isNotEmpty) {
            _selectedEmployeeId = _employees[0]['id'].toString();
          }
          _loadEmployeeData();
        });
      } else {
        _showErrorSnackbar('Failed to load employees: ${data['message']}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error loading employees: $e');
      setState(() {
        _isLoading = false;
      });
    }
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

  // Load employee data with filters
  Future<void> _loadEmployeeData() async {
    if (_selectedEmployeeId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final dateRange = _getDateRange();
      
      // Get orders for selected employee
      final data = await ApiService.getOrders(
        employeeId: _selectedEmployeeId,
        limit: 1000
      );
      
      if (data['success']) {
        List<dynamic> allOrders = data['orders'];
        
        // Filter orders by date range
        List<dynamic> filteredOrders = allOrders.where((order) {
          try {
            final orderDate = DateTime.parse(order['created_at']).toLocal();
            final start = DateTime.parse(dateRange['startDate']!);
            final end = DateTime.parse(dateRange['endDate']!).add(const Duration(days: 1));
            
            return orderDate.isAfter(start) && orderDate.isBefore(end);
          } catch (e) {
            return false;
          }
        }).toList();
        
        // Calculate stats
        int totalOrders = filteredOrders.length;
        int completedOrders = 0;
        int pendingOrders = 0;
        double totalRevenue = 0.0;
        double collectedAmount = 0.0;
        double pendingAmount = 0.0;
        
        for (var order in filteredOrders) {
          totalRevenue += double.parse(order['total_price'].toString());
          collectedAmount += double.parse(order['payment_collected'].toString());
          pendingAmount += double.parse(order['payment_pending'].toString());
          
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
          _filteredOrders = filteredOrders;
          _employeeStats = {
            'totalOrders': totalOrders,
            'completedOrders': completedOrders,
            'pendingOrders': pendingOrders,
            'totalRevenue': totalRevenue,
            'collectedAmount': collectedAmount,
            'pendingAmount': pendingAmount,
          };
          _isLoading = false;
        });
      } else {
        _showErrorSnackbar('Failed to load data: ${data['message']}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error loading employee data: $e');
      setState(() {
        _isLoading = false;
      });
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
      _loadEmployeeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter section
            Row(
              children: [
                // Employee filter
                Expanded(
                  flex: 2,
                  child: _buildEmployeeFilter(),
                ),
                const SizedBox(width: 16),
                // Date filter
                Expanded(
                  flex: 3,
                  child: _buildDateFilter(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Stats cards
            if (!_isLoading) _buildStatsCards(),
            const SizedBox(height: 24),
            
            // Orders list
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildOrdersList(),
            ),
          ],
        ),
      ),
    );
  }

  // Employee filter widget
  Widget _buildEmployeeFilter() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employee:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedEmployeeId,
            isExpanded: true,
            hint: const Text('Select Employee'),
            underline: Container(height: 0),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedEmployeeId = newValue;
                });
                _loadEmployeeData();
              }
            },
            items: _employees.map<DropdownMenuItem<String>>((employee) {
              return DropdownMenuItem<String>(
                value: employee['id'].toString(),
                child: Text(employee['name']),
              );
            }).toList(),
          ),
        ],
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
                      _loadEmployeeData();
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
            onPressed: _loadEmployeeData,
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
              value: _employeeStats['totalOrders'].toString(),
              details: [
                {
                  'label': 'Completed', 
                  'value': _employeeStats['completedOrders'].toString(), 
                  'color': Colors.green
                },
                {
                  'label': 'Pending', 
                  'value': _employeeStats['pendingOrders'].toString(), 
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
              value: '₹${NumberFormat('#,##,###').format(_employeeStats['totalRevenue'])}',
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
              value: '₹${NumberFormat('#,##,###').format(_employeeStats['collectedAmount'])}',
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
              value: '₹${NumberFormat('#,##,###').format(_employeeStats['pendingAmount'])}',
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

  // Orders list widget
  Widget _buildOrdersList() {
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
          // Header with employee name
          Text(
            'Orders by ${_getSelectedEmployeeName()}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Table header
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Order ID',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Customer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Divider(color: Colors.grey.shade200, height: 1),
          
          // Orders list
          Expanded(
            child: _filteredOrders.isEmpty
              ? const Center(child: Text('No orders found for the selected criteria'))
              : ListView.builder(
                  itemCount: _filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = _filteredOrders[index];
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
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          ),
          
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
            flex: 1,
            child: Text(
              DateFormat('MMM d, y').format(DateTime.parse(order['created_at'])),
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          
          // Amount
          Expanded(
            flex: 1,
            child: Text(
              '₹${NumberFormat('#,##,###').format(double.parse(order['total_price'].toString()))}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                order['status'],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isCompleted ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get selected employee name
  String _getSelectedEmployeeName() {
    if (_selectedEmployeeId == null || _employees.isEmpty) return 'Employee';
    
    for (var employee in _employees) {
      if (employee['id'].toString() == _selectedEmployeeId) {
        return employee['name'];
      }
    }
    
    return 'Employee';
  }
}