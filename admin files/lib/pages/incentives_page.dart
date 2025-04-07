import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class IncentivesPage extends StatefulWidget {
  const IncentivesPage({super.key});

  @override
  State<IncentivesPage> createState() => _IncentivesPageState();
}

class _IncentivesPageState extends State<IncentivesPage> {
  bool _isLoading = true;
  String _selectedDateFilter = 'Today';
  String? _selectedEmployeeId;
  
  final List<String> _dateFilters = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'Custom Range',
    'This Month',
    'Last Month'
  ];

  // Date range for custom filter
  DateTime? _startDate;
  DateTime? _endDate;

  // Data for the page
  List<dynamic> _employees = [];
  List<Map<String, dynamic>> _incentiveData = [];
  Map<String, dynamic> _summaryData = {
    'totalIncentiveEligible': 0.0,
    'totalIncentiveEarned': 0.0,
    'totalPendingIncentive': 0.0,
    'totalOrders': 0,
    'totalAmount': 0.0,
    'totalCollected': 0.0,
    'totalPending': 0.0,
  };

  // Incentive percentage tiers
  final Map<String, double> _incentiveTiers = {
    '5000-7999': 7.0,
    '8000-9999': 8.0,
    '10000-25000': 10.0,
    '25000+': 12.0,
  };

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
          _loadIncentiveData();
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
      case 'This Month':
        startDate = DateFormat('yyyy-MM-01').format(now);
        endDate = DateFormat('yyyy-MM-dd').format(now);
        break;
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = DateFormat('yyyy-MM-01').format(lastMonth);
        endDate = DateFormat('yyyy-MM-dd').format(
          DateTime(now.year, now.month, 0)
        );
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

  // Load incentive data with filters
  Future<void> _loadIncentiveData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dateRange = _getDateRange();
      final Map<String, dynamic> queryParams = {
        'limit': '1000',
      };
      
      // Add employee filter if selected
      if (_selectedEmployeeId != null) {
        queryParams['employee_id'] = _selectedEmployeeId;
      }
      
      // Get orders for selected employee and date range
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
        
        // Group orders by date
        Map<String, List<dynamic>> ordersByDate = {};
        
        for (var order in filteredOrders) {
          final date = DateFormat('yyyy-MM-dd').format(
            DateTime.parse(order['created_at']).toLocal()
          );
          
          if (!ordersByDate.containsKey(date)) {
            ordersByDate[date] = [];
          }
          
          ordersByDate[date]!.add(order);
        }
        
        // Calculate incentives for each date
        double totalIncentiveEligible = 0.0;
        double totalIncentiveEarned = 0.0;
        int totalOrders = 0;
        double totalAmount = 0.0;
        double totalCollected = 0.0;
        double totalPending = 0.0;
        
        List<Map<String, dynamic>> incentiveData = [];
        
        ordersByDate.forEach((date, orders) {
          double dailyTotal = 0.0;
          double dailyCollected = 0.0;
          double dailyPending = 0.0;
          int orderCount = orders.length;
          
          // Calculate daily totals
          for (var order in orders) {
            double orderAmount = double.parse(order['total_price'].toString());
            double orderCollected = double.parse(order['payment_collected'].toString());
            double orderPending = double.parse(order['payment_pending'].toString());
            
            dailyTotal += orderAmount;
            dailyCollected += orderCollected;
            dailyPending += orderPending;
          }
          
          // Calculate incentive percentage based on daily total
          double incentivePercentage = _calculateIncentivePercentage(dailyTotal);
          
          // Calculate incentives only if daily total meets minimum threshold
          double incentiveEligible = 0.0;
          double incentiveEarned = 0.0;
          
          if (dailyTotal >= 5000) {
            incentiveEligible = dailyTotal * (incentivePercentage / 100);
            incentiveEarned = dailyCollected * (incentivePercentage / 100);
          }
          
          // Add to totals
          totalIncentiveEligible += incentiveEligible;
          totalIncentiveEarned += incentiveEarned;
          totalOrders += orderCount;
          totalAmount += dailyTotal;
          totalCollected += dailyCollected;
          totalPending += dailyPending;
          
          // Add to incentive data
          incentiveData.add({
            'date': date,
            'orderCount': orderCount,
            'dailyTotal': dailyTotal,
            'dailyCollected': dailyCollected,
            'dailyPending': dailyPending,
            'incentivePercentage': incentivePercentage,
            'incentiveEligible': incentiveEligible,
            'incentiveEarned': incentiveEarned,
            'incentivePending': incentiveEligible - incentiveEarned,
          });
        });
        
        // Sort by date descending
        incentiveData.sort((a, b) => b['date'].compareTo(a['date']));
        
        setState(() {
          _incentiveData = incentiveData;
          _summaryData = {
            'totalIncentiveEligible': totalIncentiveEligible,
            'totalIncentiveEarned': totalIncentiveEarned,
            'totalPendingIncentive': totalIncentiveEligible - totalIncentiveEarned,
            'totalOrders': totalOrders,
            'totalAmount': totalAmount,
            'totalCollected': totalCollected,
            'totalPending': totalPending,
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
      _showErrorSnackbar('Error loading incentive data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Calculate incentive percentage based on amount
  double _calculateIncentivePercentage(double amount) {
    if (amount < 5000) {
      return 0.0;
    } else if (amount < 8000) {
      return 7.0;
    } else if (amount < 10000) {
      return 8.0;
    } else if (amount < 25000) {
      return 10.0;
    } else {
      return 12.0;
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
      _loadIncentiveData();
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
            // Filters section
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
            
            // Incentive summary cards
            if (!_isLoading) _buildIncentiveSummary(),
            const SizedBox(height: 24),
            
            // Incentive details table
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildIncentiveTable(),
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
                _loadIncentiveData();
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
                      _loadIncentiveData();
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
            onPressed: _loadIncentiveData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
    );
  }

  // Incentive summary widget
  Widget _buildIncentiveSummary() {
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
          // Header
          Text(
            'Incentive Summary for ${_getSelectedEmployeeName()}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Summary cards
          Row(
            children: [
              // Order count & amount
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Orders & Revenue',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3498DB),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Orders:'),
                          Text(
                            '${_summaryData['totalOrders']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount:'),
                          Text(
                            '₹${NumberFormat('#,##,###').format(_summaryData['totalAmount'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Collected:'),
                          Text(
                            '₹${NumberFormat('#,##,###').format(_summaryData['totalCollected'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pending:'),
                          Text(
                            '₹${NumberFormat('#,##,###').format(_summaryData['totalPending'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Incentive details
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Incentive Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2ECC71),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Eligible Incentive:'),
                          Text(
                            '₹${NumberFormat('#,##,###.##').format(_summaryData['totalIncentiveEligible'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Earned Incentive:'),
                          Text(
                            '₹${NumberFormat('#,##,###.##').format(_summaryData['totalIncentiveEarned'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pending Incentive:'),
                          Text(
                            '₹${NumberFormat('#,##,###.##').format(_summaryData['totalPendingIncentive'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Incentive rate info
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Incentive Rates',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9B59B6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('₹5,000 - ₹7,999:'),
                          Text(
                            '7%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('₹8,000 - ₹9,999:'),
                          Text(
                            '8%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('₹10,000 - ₹25,000:'),
                          Text(
                            '10%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Above ₹25,000:'),
                          Text(
                            '12%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Incentive table widget
  Widget _buildIncentiveTable() {
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
          // Header
          const Text(
            'Daily Incentive Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 2,
                ),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Orders',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total Sales',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Rate',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Eligible Incentive',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Earned Incentive',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Pending Incentive',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2980B9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          // Table content
          Expanded(
            child: _incentiveData.isEmpty
              ? const Center(child: Text('No incentive data available for the selected criteria'))
              : ListView.builder(
                  itemCount: _incentiveData.length,
                  itemBuilder: (context, index) {
                    final data = _incentiveData[index];
                    return _buildIncentiveRow(data);
                  },
                ),
          ),
        ],
      ),
    );
  }

  // Incentive row widget
  Widget _buildIncentiveRow(Map<String, dynamic> data) {
    // Format date
    final date = DateTime.parse(data['date']);
    final formattedDate = DateFormat('MMM d, y (EEEE)').format(date);
    
    // Calculate whether incentive applies
    final bool hasIncentive = data['dailyTotal'] >= 5000;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: hasIncentive ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Date
          Expanded(
            flex: 2,
            child: Text(
              formattedDate,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: hasIncentive ? Colors.black : Colors.grey.shade600,
              ),
            ),
          ),
          
          // Order count
          Expanded(
            flex: 1,
            child: Text(
              '${data['orderCount']}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: hasIncentive ? Colors.black : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Total sales
          Expanded(
            flex: 2,
            child: Text(
              '₹${NumberFormat('#,##,###').format(data['dailyTotal'])}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasIncentive ? Colors.black : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Incentive rate
          Expanded(
            flex: 1,
            child: Text(
              hasIncentive ? '${data['incentivePercentage']}%' : '-',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasIncentive 
                  ? const Color(0xFF2980B9) 
                  : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Eligible incentive
          Expanded(
            flex: 2,
            child: Text(
              hasIncentive 
                ? '₹${NumberFormat('#,##,###.##').format(data['incentiveEligible'])}' 
                : '-',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasIncentive ? Colors.black : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Earned incentive
          Expanded(
            flex: 2,
            child: Text(
              hasIncentive 
                ? '₹${NumberFormat('#,##,###.##').format(data['incentiveEarned'])}' 
                : '-',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasIncentive ? Colors.green : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Pending incentive
          Expanded(
            flex: 2,
            child: Text(
              hasIncentive 
                ? '₹${NumberFormat('#,##,###.##').format(data['incentivePending'])}' 
                : '-',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasIncentive 
                  ? (data['incentivePending'] > 0 ? Colors.orange : Colors.grey.shade600) 
                  : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
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