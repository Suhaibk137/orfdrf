import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class EditOrderPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  
  const EditOrderPage({
    super.key, 
    required this.employeeId,
    required this.employeeName
  });

  @override
  State<EditOrderPage> createState() => _EditOrderPageState();
}

class _EditOrderPageState extends State<EditOrderPage> {
  // Controllers
  final _searchController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _orderCodeController = TextEditingController();
  final _planController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _previouslyCollectedController = TextEditingController();
  final _newPaymentController = TextEditingController();
  final _totalCollectedController = TextEditingController();
  final _remainingPendingController = TextEditingController();

  // Form keys
  final _searchFormKey = GlobalKey<FormState>();
  final _editFormKey = GlobalKey<FormState>();

  // State variables
  bool _isSearching = true;
  bool _isLoading = false;
  bool _orderFound = false;
  File? _newPaymentProofImage;
  String? _newPaymentProofPath;
  String _orderStatus = 'Pending';
  int _orderId = 0;

  // Status options
  final List<String> _statusOptions = ['Pending', 'Completed'];

  // Search for an order
  Future<void> _searchOrder() async {
    if (_searchFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Make API request to get order details
        final response = await http.get(
          Uri.parse('https://order-employee.suhaib.online/get_order_details.php?order_code=${_searchController.text}'),
        );
        
        setState(() {
          _isLoading = false;
        });
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['success']) {
            // Order found, populate the form
            final order = data['order'];
            
            setState(() {
              _orderFound = true;
              _isSearching = false;
              _orderId = order['id'];
              
              _customerNameController.text = order['customer_name'];
              _orderCodeController.text = order['order_code'];
              _planController.text = order['plan_type'];
              _totalPriceController.text = order['total_price'].toString();
              _previouslyCollectedController.text = order['payment_collected'].toString();
              _newPaymentController.text = '0';
              _totalCollectedController.text = order['payment_collected'].toString();
              _remainingPendingController.text = order['payment_pending'].toString();
              _orderStatus = order['status'];
            });
          } else {
            // Order not found
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message']),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Calculate payment values
  void _calculatePayments() {
    if (_totalPriceController.text.isNotEmpty && 
        _previouslyCollectedController.text.isNotEmpty &&
        _newPaymentController.text.isNotEmpty) {
      try {
        final totalPrice = double.parse(_totalPriceController.text);
        final previouslyCollected = double.parse(_previouslyCollectedController.text);
        final newPayment = double.parse(_newPaymentController.text);
        
        final totalCollected = previouslyCollected + newPayment;
        final remainingPending = totalPrice - totalCollected;
        
        _totalCollectedController.text = totalCollected.toString();
        _remainingPendingController.text = remainingPending > 0 ? remainingPending.toString() : '0';
        
        // Auto update status to completed if fully paid
        if (remainingPending <= 0) {
          setState(() {
            _orderStatus = 'Completed';
          });
        }
      } catch (e) {
        print('Error calculating payments: $e');
      }
    }
  }

  // Pick image from gallery - updated to use base64
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        // Optionally reduce image quality to save bandwidth
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          _newPaymentProofImage = File(pickedFile.path);
        });
        
        // Upload the image using base64 approach
        await _uploadImageWithBase64(_newPaymentProofImage!);
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Upload image to server with base64
  Future<void> _uploadImageWithBase64(File imageFile) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Read the image file as bytes
      List<int> imageBytes = await imageFile.readAsBytes();
      
      // Convert bytes to base64
      String base64Image = base64Encode(imageBytes);
      
      // Get file name and extension
      String fileName = imageFile.path.split('/').last;
      
      // Create the request data
      Map<String, dynamic> requestData = {
        'image_data': base64Image,
        'file_name': fileName,
        'image_type': 'payment_proof'
      };
      
      print('Sending base64 image upload request');
      
      // Send the request
      final response = await http.post(
        Uri.parse('https://order-employee.suhaib.online/save_base64_image.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );
      
      setState(() {
        _isLoading = false;
      });
      
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      // Handle response
      if (response.statusCode == 200) {
        try {
          var jsonData = jsonDecode(response.body);
          
          if (jsonData['success']) {
            setState(() {
              _newPaymentProofPath = jsonData['file_path'];
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment proof uploaded successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image: ${jsonData['message']}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          print('Error parsing JSON response: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing server response: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update order
  Future<void> _updateOrder() async {
    if (_editFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Prepare update data
        final previousValue = _previouslyCollectedController.text;
        final newValue = _totalCollectedController.text;
        
        final updateData = {
          'order_id': _orderId,
          'payment_collected': double.parse(_totalCollectedController.text),
          'employee_id': widget.employeeId,
          'action_type': 'Payment Update',
          'previous_value': 'Payment: $previousValue',
          'new_value': 'Payment: $newValue',
          'status': _orderStatus,
          'payment_proof_image': _newPaymentProofPath,
        };
        
        // Make API request to update payment
        final response = await http.post(
          Uri.parse('https://order-employee.suhaib.online/update_payment.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updateData),
        );
        
        setState(() {
          _isLoading = false;
        });
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Reset to search state
            setState(() {
              _isSearching = true;
              _orderFound = false;
              _searchController.clear();
              _newPaymentProofImage = null;
              _newPaymentProofPath = null;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update order: ${data['message']}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Reset search
  void _resetSearch() {
    setState(() {
      _isSearching = true;
      _orderFound = false;
      _searchController.clear();
      _newPaymentProofImage = null;
      _newPaymentProofPath = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _orderCodeController.dispose();
    _planController.dispose();
    _totalPriceController.dispose();
    _previouslyCollectedController.dispose();
    _newPaymentController.dispose();
    _totalCollectedController.dispose();
    _remainingPendingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Order'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF39C12),
        foregroundColor: Colors.white,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _resetSearch,
              tooltip: 'Search again',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isSearching ? _buildSearchSection() : _buildEditForm(),
        ),
      ),
    );
  }

  // Search section widget
  Widget _buildSearchSection() {
    return Form(
      key: _searchFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.search_rounded,
            size: 70,
            color: Color(0xFFF39C12),
          ),
          const SizedBox(height: 24),
          const Text(
            'Find Order to Edit',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the order code to find and edit payment details',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7F8C8D),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Order Code',
              hintText: 'Enter order code to search',
              prefixIcon: const Icon(Icons.qr_code, color: Color(0xFFF39C12)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFF39C12), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter order code';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _searchOrder,
              style: ElevatedButton.styleFrom(
               foregroundColor: Colors.white,
               backgroundColor: const Color(0xFFF39C12),
               disabledBackgroundColor: Colors.grey.shade300,
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(12),
               ),
             ),
             child: _isLoading
                 ? const CircularProgressIndicator(color: Colors.white)
                 : const Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.search),
                       SizedBox(width: 12),
                       Text(
                         'SEARCH ORDER',
                         style: TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           letterSpacing: 1.2,
                         ),
                       ),
                     ],
                   ),
           ),
         ),
       ],
     ),
   );
 }

 // Edit form widget
 Widget _buildEditForm() {
   return Form(
     key: _editFormKey,
     child: SingleChildScrollView(
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
           // Order Info Section
           _buildSectionHeader('Order Information'),
           const SizedBox(height: 16),
           
           // Order details row
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Colors.grey.shade200),
             ),
             child: Column(
               children: [
                 _buildInfoField('Customer Name', _customerNameController.text),
                 const Divider(height: 24),
                 _buildInfoField('Order Code', _orderCodeController.text),
                 const Divider(height: 24),
                 _buildInfoField('Plan', _planController.text),
                 const Divider(height: 24),
                 _buildInfoField('Total Price', '₹${_totalPriceController.text}'),
               ],
             ),
           ),
           const SizedBox(height: 24),
           
           // Payment Update Section
           _buildSectionHeader('Payment Update'),
           const SizedBox(height: 16),
           
           // Previously collected
           TextFormField(
             controller: _previouslyCollectedController,
             readOnly: true,
             decoration: _inputDecoration(
               'Previously Collected',
               'Amount already collected',
               Icons.history,
             ),
           ),
           const SizedBox(height: 16),
           
           // New payment
           TextFormField(
             controller: _newPaymentController,
             decoration: _inputDecoration(
               'New Payment Amount',
               'Enter amount received now',
               Icons.payments,
             ),
             keyboardType: TextInputType.number,
             inputFormatters: [
               FilteringTextInputFormatter.digitsOnly,
             ],
             validator: (value) {
               if (value == null || value.isEmpty) {
                 return 'Please enter payment amount';
               }
               return null;
             },
             onChanged: (value) {
               _calculatePayments();
             },
           ),
           const SizedBox(height: 16),
           
           // New payment proof
           _buildImageUploader(
             'Upload New Payment Proof',
             _newPaymentProofImage,
             _pickImage,
           ),
           const SizedBox(height: 16),
           
           // Total collected
           TextFormField(
             controller: _totalCollectedController,
             readOnly: true,
             decoration: _inputDecoration(
               'Total Collected',
               'Total amount collected (calculated)',
               Icons.account_balance_wallet,
             ),
           ),
           const SizedBox(height: 16),
           
           // Remaining pending
           TextFormField(
             controller: _remainingPendingController,
             readOnly: true,
             decoration: _inputDecoration(
               'Remaining Pending',
               'Amount still pending (calculated)',
               Icons.money_off,
             ),
           ),
           const SizedBox(height: 24),
           
           // Order Status Section
           _buildSectionHeader('Order Status'),
           const SizedBox(height: 16),
           
           // Status dropdown
           DropdownButtonFormField<String>(
             decoration: _inputDecoration(
               'Order Status',
               'Select order status',
               Icons.flag,
             ),
             value: _orderStatus,
             items: _statusOptions.map((String status) {
               return DropdownMenuItem<String>(
                 value: status,
                 child: Text(status),
               );
             }).toList(),
             onChanged: (String? newValue) {
               setState(() {
                 _orderStatus = newValue!;
               });
             },
           ),
           const SizedBox(height: 32),
           
           // Update Button
           SizedBox(
             height: 55,
             child: ElevatedButton(
               onPressed: _isLoading ? null : _updateOrder,
               style: ElevatedButton.styleFrom(
                 foregroundColor: Colors.white,
                 backgroundColor: const Color(0xFFF39C12),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(12),
                 ),
               ),
               child: _isLoading
                 ? const CircularProgressIndicator(color: Colors.white)
                 : const Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(Icons.save),
                     SizedBox(width: 12),
                     Text(
                       'UPDATE ORDER',
                       style: TextStyle(
                         fontSize: 16,
                         fontWeight: FontWeight.bold,
                         letterSpacing: 1.2,
                       ),
                     ),
                   ],
                 ),
             ),
           ),
           const SizedBox(height: 24),
         ],
       ),
     ),
   );
 }

 // Helper method to build info field
 Widget _buildInfoField(String label, String value) {
   return Row(
     mainAxisAlignment: MainAxisAlignment.spaceBetween,
     children: [
       Text(
         label,
         style: TextStyle(
           color: Colors.grey.shade600,
           fontSize: 14,
         ),
       ),
       Text(
         value,
         style: const TextStyle(
           color: Color(0xFF2C3E50),
           fontSize: 16,
           fontWeight: FontWeight.bold,
         ),
       ),
     ],
   );
 }

 // Helper method to create section headers
 Widget _buildSectionHeader(String title) {
   return Column(
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
       const SizedBox(height: 8),
       Container(
         height: 2,
         width: 100,
         color: const Color(0xFFF39C12),
       ),
     ],
   );
 }

 // Helper method to create consistent input decoration
 InputDecoration _inputDecoration(String label, String hint, IconData icon) {
   return InputDecoration(
     labelText: label,
     hintText: hint,
     prefixIcon: Icon(icon, color: const Color(0xFFF39C12)),
     border: OutlineInputBorder(
       borderRadius: BorderRadius.circular(12),
     ),
     enabledBorder: OutlineInputBorder(
       borderRadius: BorderRadius.circular(12),
       borderSide: BorderSide(color: Colors.grey.shade300),
     ),
     focusedBorder: OutlineInputBorder(
       borderRadius: BorderRadius.circular(12),
       borderSide: const BorderSide(color: Color(0xFFF39C12), width: 2),
     ),
     filled: true,
     fillColor: Colors.white,
     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
   );
 }

 // Helper method to create image upload sections
 Widget _buildImageUploader(String title, File? image, VoidCallback onTap) {
   return Container(
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       border: Border.all(color: Colors.grey.shade300),
       borderRadius: BorderRadius.circular(12),
       color: Colors.white,
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Text(
               title,
               style: const TextStyle(
                 fontSize: 16,
                 fontWeight: FontWeight.bold,
               ),
             ),
             if (_newPaymentProofPath != null)
               const Icon(Icons.check_circle, color: Colors.green),
           ],
         ),
         const SizedBox(height: 12),
         InkWell(
           onTap: onTap,
           child: Container(
             height: 120,
             width: double.infinity,
             decoration: BoxDecoration(
               color: Colors.grey.shade100,
               borderRadius: BorderRadius.circular(8),
               border: Border.all(
                 color: Colors.grey.shade300,
                 width: 1,
               ),
             ),
             child: image != null
                 ? ClipRRect(
                     borderRadius: BorderRadius.circular(8),
                     child: Image.file(
                       image,
                       fit: BoxFit.cover,
                     ),
                   )
                 : Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(
                         Icons.image,
                         size: 40,
                         color: Colors.grey.shade400,
                       ),
                       const SizedBox(height: 8),
                       Text(
                         'Tap to select image',
                         style: TextStyle(
                           color: Colors.grey.shade600,
                         ),
                       ),
                     ],
                   ),
           ),
         ),
       ],
     ),
   );
 }
}