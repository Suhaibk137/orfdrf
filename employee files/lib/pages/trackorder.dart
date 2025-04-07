import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackOrderPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  
  const TrackOrderPage({
    super.key, 
    required this.employeeId,
    required this.employeeName
  });

  @override
  State<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends State<TrackOrderPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoading = false;
  String _selectedFilter = 'All';
  
  // List of status filter options
  final List<String> _filterOptions = ['All', 'Pending', 'Completed'];
  
  // Orders list
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  // Fetch orders from API
  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      String url = 'https://order-employee.suhaib.online/get_orders.php?limit=10';
      
      // Add filter if not "All"
      if (_selectedFilter != 'All') {
        url += '&status=$_selectedFilter';
      }
      
      // Add employee ID filter
      if (widget.employeeId.isNotEmpty) {
        url += '&employee_id=${widget.employeeId}';
      }
      
      final response = await http.get(Uri.parse(url));
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          setState(() {
            _orders = List<Map<String, dynamic>>.from(data['orders']);
          });
        } else {
          _showErrorSnackbar('Failed to load orders: ${data['message']}');
        }
      } else {
        _showErrorSnackbar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error fetching orders: $e');
    }
  }
  
  // Search orders
  Future<void> _searchOrders(String query) async {
    if (query.isEmpty) {
      _fetchOrders();
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse('https://order-employee.suhaib.online/search_orders.php?search=$query'),
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          setState(() {
            _orders = List<Map<String, dynamic>>.from(data['orders']);
          });
        } else {
          _showErrorSnackbar('Search failed: ${data['message']}');
        }
      } else {
        _showErrorSnackbar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error during search: $e');
    }
  }
  
  // Get order details
  Future<void> _fetchOrderDetails(String orderCode) async {
    try {
      final response = await http.get(
        Uri.parse('https://order-employee.suhaib.online/get_order_details.php?order_code=$orderCode'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final order = data['order'];
          final history = data['history'];
          
          _showOrderDetailsDialog(order, history);
        } else {
          _showErrorSnackbar(data['message']);
        }
      } else {
        _showErrorSnackbar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackbar('Error fetching order details: $e');
    }
  }
  
  // Show error snackbar
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Order detail dialog
  void _showOrderDetailsDialog(Map<String, dynamic> order, List<dynamic> history) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Order Details: ${order['order_code']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Customer', order['customer_name']),
                _buildDetailRow('Date', order['created_at'].substring(0, 10)),
                _buildDetailRow('Plan', order['plan_type']),
                _buildDetailRow('Total Price', '₹${order['total_price']}'),
                _buildDetailRow('Payment Collected', '₹${order['payment_collected']}'),
                _buildDetailRow('Payment Pending', '₹${order['payment_pending']}'),
                _buildDetailRow('Status', order['status']),
                _buildDetailRow('Created By', order['employee_name']),
                
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: order['status'] == 'Pending'
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order['status'],
                      style: TextStyle(
                        color: order['status'] == 'Pending'
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Order History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...history.map((entry) => _buildHistoryItem(entry)).toList(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
  
  // Build history item
  Widget _buildHistoryItem(Map<String, dynamic> entry) {
    IconData icon;
    Color color;
    
    if (entry['action_type'] == 'Status Change') {
      icon = Icons.flag;
      color = Colors.blue;
    } else if (entry['action_type'] == 'Payment Update') {
      icon = Icons.payments;
      color = Colors.green;
    } else {
      icon = Icons.edit;
      color = Colors.orange;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry['action_type']} by ${entry['employee_name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${entry['previous_value']} → ${entry['new_value']}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  entry['created_at'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for order detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !_isSearching
            ? const Text('Track Orders')
            : TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search by order code or customer',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  _searchOrders(value);
                },
              ),
        centerTitle: !_isSearching,
        backgroundColor: const Color(0xFF3498DB),
        foregroundColor: Colors.white,
        actions: [
          // Search icon
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _fetchOrders();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter tabs
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                    });
                    _fetchOrders();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF3498DB) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Order count and info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchController.text.isEmpty && _selectedFilter == 'All'
                      ? 'Latest Orders'
                      : 'Showing ${_orders.length} Orders',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _searchController.text.isNotEmpty
                    ? TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                          _fetchOrders();
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Search'),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No orders found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchOrders,
                        child: ListView.builder(
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            return _buildOrderCard(order);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final isPending = order['status'] == 'Pending';
    final orderDate = DateTime.parse(order['created_at']).toLocal();
    final formattedDate = '${orderDate.day}/${orderDate.month}/${orderDate.year}';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _fetchOrderDetails(order['order_code']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Top row with order code and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Color(0xFF3498DB),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order['order_code'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Middle row with customer name and plan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          order['customer_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          order['plan_type'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Bottom row with price and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '₹${order['total_price']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: double.parse(order['payment_pending'].toString()) > 0
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          double.parse(order['payment_pending'].toString()) > 0
                              ? 'Pending: ₹${order['payment_pending']}'
                              : 'Fully Paid',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: double.parse(order['payment_pending'].toString()) > 0
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.orange.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      order['status'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}