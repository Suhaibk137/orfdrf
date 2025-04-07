import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for the API - use the same backend as employee app
  static const String baseUrl = 'https://order-employee.suhaib.online';
  
  // Get all orders
  static Future<Map<String, dynamic>> getOrders({int limit = 1000, String? status, String? employeeId}) async {
    String url = '$baseUrl/get_orders.php?limit=$limit';
    
    // Add optional filters
    if (status != null && status != 'all') {
      url += '&status=$status';
    }
    
    if (employeeId != null) {
      url += '&employee_id=$employeeId';
    }
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load orders: ${response.statusCode}');
    }
  }
  
  // Get order details
  static Future<Map<String, dynamic>> getOrderDetails({String? id, String? orderCode}) async {
    String url;
    
    if (id != null) {
      url = '$baseUrl/get_order_details.php?id=$id';
    } else if (orderCode != null) {
      url = '$baseUrl/get_order_details.php?order_code=$orderCode';
    } else {
      throw Exception('Either order ID or order code is required');
    }
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load order details: ${response.statusCode}');
    }
  }
  
  // Update order status
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId, 
    required String status,
    required String employeeId
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update_order_status.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'order_id': orderId,
        'status': status,
        'employee_id': employeeId
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update order status: ${response.statusCode}');
    }
  }
  
  // Update payment
  static Future<Map<String, dynamic>> updatePayment({
    required String orderId,
    required double paymentCollected,
    required String employeeId,
    String? paymentProofImage,
  }) async {
    final Map<String, dynamic> requestData = {
      'order_id': orderId,
      'payment_collected': paymentCollected,
      'employee_id': employeeId,
    };
    
    if (paymentProofImage != null) {
      requestData['payment_proof_image'] = paymentProofImage;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/update_payment.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestData),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update payment: ${response.statusCode}');
    }
  }
  
  // Upload image using base64
  static Future<Map<String, dynamic>> uploadImageBase64({
    required String base64Image,
    required String fileName,
    required String imageType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/save_base64_image.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'image_data': base64Image,
        'file_name': fileName,
        'image_type': imageType
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload image: ${response.statusCode}');
    }
  }
  
  // Get all employees (for admin panel)
  static Future<Map<String, dynamic>> getEmployees() async {
    final response = await http.get(Uri.parse('$baseUrl/get_employees.php'));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load employees: ${response.statusCode}');
    }
  }
  
  // Get dashboard analytics data
  static Future<Map<String, dynamic>> getDashboardData({
    required String startDate,
    required String endDate,
  }) async {
    // For now, we'll get all orders and process them client-side
    final response = await http.get(Uri.parse('$baseUrl/get_orders.php?limit=1000'));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard data: ${response.statusCode}');
    }
  }
  
  // Search orders
  static Future<Map<String, dynamic>> searchOrders(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/search_orders.php?search=$query'));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search orders: ${response.statusCode}');
    }
  }
}