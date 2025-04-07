import 'package:flutter/material.dart';
import 'addneworder.dart';
import 'editorder.dart';
import 'trackorder.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MainPage extends StatefulWidget {
 final String employeeName;
 final String employeePosition;
 final String employeeId;
 
 const MainPage({
   super.key, 
   required this.employeeName,
   required this.employeePosition,
   required this.employeeId, // Changed from default value to required
 });

 @override
 State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
 int _totalOrders = 0;
 int _completedOrders = 0;
 int _pendingOrders = 0;
 bool _isLoading = true;

 @override
 void initState() {
   super.initState();
   print('MainPage initialized with employee ID: ${widget.employeeId}');
   _fetchOrderStats();
 }

 // Fetch order statistics
 Future<void> _fetchOrderStats() async {
   setState(() {
     _isLoading = true;
   });
   
   try {
     // Get all orders for this employee
     final url = 'https://order-employee.suhaib.online/get_orders.php?limit=1000&employee_id=${widget.employeeId}';
     print('Fetching orders from: $url');
     
     final response = await http.get(
       Uri.parse(url),
     );
     
     if (response.statusCode == 200) {
       final data = jsonDecode(response.body);
       print('API response data count: ${data['count']}');
       
       if (data['success']) {
         final orders = data['orders'];
         
         // Count orders by status
         int totalOrders = orders.length;
         int completed = 0;
         int pending = 0;
         
         for (var order in orders) {
           if (order['status'] == 'Completed') {
             completed++;
           }
           
           // Check if payment is pending
           if (double.parse(order['payment_pending'].toString()) > 0) {
             pending++;
           }
         }
         
         setState(() {
           _totalOrders = totalOrders; // Total orders count
           _completedOrders = completed;
           _pendingOrders = pending;
           _isLoading = false;
         });
       } else {
         setState(() {
           _isLoading = false;
         });
       }
     } else {
       print('Error status code: ${response.statusCode}');
       setState(() {
         _isLoading = false;
       });
     }
   } catch (e) {
     print('Error fetching order stats: $e');
     setState(() {
       _isLoading = false;
     });
   }
 }
 
 @override
 Widget build(BuildContext context) {
   return Scaffold(
     backgroundColor: Colors.grey[50],
     appBar: AppBar(
       title: const Text(
         'Elite Orders',
         style: TextStyle(fontWeight: FontWeight.bold),
       ),
       centerTitle: true,
       backgroundColor: const Color(0xFF2980B9),
       foregroundColor: Colors.white,
       elevation: 2,
       actions: [
         IconButton(
           icon: const Icon(Icons.logout),
           onPressed: () {
             // Navigate back to login page
             Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
           },
         ),
       ],
     ),
     body: SafeArea(
       child: RefreshIndicator(
         onRefresh: _fetchOrderStats,
         child: SingleChildScrollView(
           physics: const AlwaysScrollableScrollPhysics(),
           child: Padding(
             padding: const EdgeInsets.all(20.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                 // Welcome Header
                 Container(
                   decoration: BoxDecoration(
                     gradient: LinearGradient(
                       colors: [
                         const Color(0xFF2980B9).withOpacity(0.8),
                         const Color(0xFF2980B9).withOpacity(0.6),
                       ],
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight,
                     ),
                     borderRadius: BorderRadius.circular(16),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.grey.withOpacity(0.3),
                         spreadRadius: 2,
                         blurRadius: 8,
                         offset: const Offset(0, 3),
                       ),
                     ],
                   ),
                   padding: const EdgeInsets.all(24),
                   margin: const EdgeInsets.only(bottom: 24),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Welcome, ${widget.employeeName}',
                         style: const TextStyle(
                           fontSize: 24,
                           fontWeight: FontWeight.bold,
                           color: Colors.white,
                         ),
                       ),
                       const SizedBox(height: 4),
                       Text(
                         widget.employeePosition,
                         style: TextStyle(
                           fontSize: 16,
                           color: Colors.white.withOpacity(0.9),
                         ),
                       ),
                       const SizedBox(height: 10),
                       const Text(
                         'Every new order is a testament to your dedication and commitment to excellence.',
                         style: TextStyle(
                           fontSize: 16,
                           color: Colors.white,
                           height: 1.4,
                         ),
                       ),
                     ],
                   ),
                 ),
                 
                 // Stats Summary Card
                 Container(
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(16),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.grey.withOpacity(0.2),
                         spreadRadius: 1,
                         blurRadius: 6,
                         offset: const Offset(0, 2),
                       ),
                     ],
                   ),
                   padding: const EdgeInsets.all(16),
                   margin: const EdgeInsets.only(bottom: 24),
                   child: _isLoading
                     ? const Center(
                         child: Padding(
                           padding: EdgeInsets.all(8.0),
                           child: CircularProgressIndicator(),
                         ),
                       )
                     : Row(
                         mainAxisAlignment: MainAxisAlignment.spaceAround,
                         children: [
                           _buildStatItem(Icons.receipt_long, _totalOrders.toString(), 'Total Orders'),
                           _buildStatItem(Icons.check_circle_outline, _completedOrders.toString(), 'Completed'),
                           _buildStatItem(Icons.schedule, _pendingOrders.toString(), 'Pending'),
                         ],
                       ),
                 ),
                 
                 // Main Action Buttons
                 const Text(
                   'Quick Actions',
                   style: TextStyle(
                     fontSize: 20,
                     fontWeight: FontWeight.bold,
                     color: Color(0xFF2C3E50),
                   ),
                 ),
                 const SizedBox(height: 16),
                 
                 // Add New Order Button
                 _buildActionButton(
                   icon: Icons.add_circle_outline,
                   title: 'Add New Order',
                   subtitle: 'Create a new order entry',
                   color: const Color(0xFF27AE60),
                   onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => AddNewOrderPage(
                           employeeId: widget.employeeId,
                           employeeName: widget.employeeName,
                         ),
                       ),
                     ).then((value) {
                       // Refresh stats when returning from add order page
                       if (value == true) {
                         _fetchOrderStats();
                       }
                     });
                   },
                 ),
                 
                 const SizedBox(height: 16),
                 
                 // Edit Order Button
                 _buildActionButton(
                   icon: Icons.edit_note,
                   title: 'Edit Order',
                   subtitle: 'Modify existing orders',
                   color: const Color(0xFFF39C12),
                   onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => EditOrderPage(
                           employeeId: widget.employeeId,
                           employeeName: widget.employeeName,
                         ),
                       ),
                     ).then((_) {
                       // Refresh stats when returning from edit order page
                       _fetchOrderStats();
                     });
                   },
                 ),
                 
                 const SizedBox(height: 16),
                 
                 // Track Order Button
                 _buildActionButton(
                   icon: Icons.location_on_outlined,
                   title: 'Track Order',
                   subtitle: 'Check order status and location',
                   color: const Color(0xFF3498DB),
                   onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => TrackOrderPage(
                           employeeId: widget.employeeId,
                           employeeName: widget.employeeName,
                         ),
                       ),
                     );
                   },
                 ),
               ],
             ),
           ),
         ),
       ),
     ),
   );
 }
 
 Widget _buildStatItem(IconData icon, String value, String label) {
   return Column(
     children: [
       Icon(
         icon,
         size: 28,
         color: const Color(0xFF2980B9),
       ),
       const SizedBox(height: 8),
       Text(
         value,
         style: const TextStyle(
           fontSize: 24,
           fontWeight: FontWeight.bold,
           color: Color(0xFF2C3E50),
         ),
       ),
       Text(
         label,
         style: TextStyle(
           fontSize: 12,
           color: Colors.grey[600],
         ),
       ),
     ],
   );
 }
 
 Widget _buildActionButton({
   required IconData icon,
   required String title,
   required String subtitle,
   required Color color,
   required VoidCallback onTap,
 }) {
   return InkWell(
     onTap: onTap,
     borderRadius: BorderRadius.circular(12),
     child: Container(
       padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12),
         boxShadow: [
           BoxShadow(
             color: color.withOpacity(0.3),
             spreadRadius: 1,
             blurRadius: 6,
             offset: const Offset(0, 2),
           ),
         ],
         border: Border.all(
           color: color.withOpacity(0.1),
           width: 1,
         ),
       ),
       child: Row(
         children: [
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: color.withOpacity(0.1),
               borderRadius: BorderRadius.circular(10),
             ),
             child: Icon(
               icon,
               size: 30,
               color: color,
             ),
           ),
           const SizedBox(width: 20),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   title,
                   style: const TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                     color: Color(0xFF2C3E50),
                   ),
                 ),
                 const SizedBox(height: 4),
                 Text(
                   subtitle,
                   style: TextStyle(
                     fontSize: 14,
                     color: Colors.grey[600],
                   ),
                 ),
               ],
             ),
           ),
           Icon(
             Icons.arrow_forward_ios,
             size: 16,
             color: Colors.grey[400],
           ),
         ],
       ),
     ),
   );
 }
}