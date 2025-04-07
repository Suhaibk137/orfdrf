import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AddNewOrderPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const AddNewOrderPage({
    super.key, 
    required this.employeeId, 
    required this.employeeName
  });

  @override
  State<AddNewOrderPage> createState() => _AddNewOrderPageState();
}

class _AddNewOrderPageState extends State<AddNewOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _orderCodeController = TextEditingController();
  final TextEditingController _customPlanController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  final TextEditingController _paymentCollectedController = TextEditingController();
  final TextEditingController _paymentPendingController = TextEditingController();

  String? _selectedPlan = 'Basic Resume';
  bool _isCustomPlan = false;
  bool _isLoading = false;
  File? _paymentProofImage;
  String? _paymentProofPath;

  final List<String> _planOptions = [
    'Basic Resume',
    'Tailored Resume',
    'Pure ATS Resume',
    'Elite Plan',
    'Custom Plan'
  ];

  @override
  void dispose() {
    _customerNameController.dispose();
    _contactNumberController.dispose();
    _orderCodeController.dispose();
    _customPlanController.dispose();
    _totalPriceController.dispose();
    _paymentCollectedController.dispose();
    _paymentPendingController.dispose();
    super.dispose();
  }

  // Calculate the pending payment amount
  void _calculatePendingPayment() {
    if (_totalPriceController.text.isNotEmpty && _paymentCollectedController.text.isNotEmpty) {
      try {
        final total = double.parse(_totalPriceController.text);
        final collected = double.parse(_paymentCollectedController.text);
        final pending = total - collected;
        
        // Only update if the value is non-negative
        if (pending >= 0) {
          _paymentPendingController.text = pending.toString();
        }
      } catch (e) {
        // Handle parsing errors
        print('Error calculating pending payment: $e');
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
          _paymentProofImage = File(pickedFile.path);
        });
        
        // Upload the image using base64 approach
        await _uploadImageWithBase64(_paymentProofImage!);
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
              _paymentProofPath = jsonData['file_path'];
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image uploaded successfully'),
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

  // Submit form to API
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Get the plan name
        final planName = _isCustomPlan ? _customPlanController.text : _selectedPlan;
        
        // Prepare data for API
        var orderData = {
          'customer_name': _customerNameController.text,
          'contact_number': _contactNumberController.text, // Add contact number
          'order_code': _orderCodeController.text,
          'plan_type': planName,
          'custom_plan_details': _isCustomPlan ? _customPlanController.text : null,
          'total_price': double.parse(_totalPriceController.text),
          'payment_collected': double.parse(_paymentCollectedController.text),
          'payment_proof_image': _paymentProofPath,
          'employee_id': widget.employeeId,
        };
        
        // Make API request
        final response = await http.post(
          Uri.parse('https://order-employee.suhaib.online/create_order.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(orderData),
        );
        
        setState(() {
          _isLoading = false;
        });
        
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          
          if (data['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order created successfully: ${data['order_code']}'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate back to the main page
            Navigator.pop(context, true); // Pass true to indicate a successful creation
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create order: ${data['message']}'),
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
            content: Text('Error creating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Order'),
        centerTitle: true,
        backgroundColor: const Color(0xFF27AE60),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section Header: Customer Information
                  _buildSectionHeader('Customer Information'),
                  const SizedBox(height: 16),
                  
                  // Customer Name
                  TextFormField(
                    controller: _customerNameController,
                    decoration: _inputDecoration(
                      'Customer Name',
                      'Enter customer full name',
                      Icons.person
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter customer name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Contact Number - New field
                  TextFormField(
                    controller: _contactNumberController,
                    decoration: _inputDecoration(
                      'Contact Number',
                      'Enter customer contact number',
                      Icons.phone
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter contact number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Order Code
                  TextFormField(
                    controller: _orderCodeController,
                    decoration: _inputDecoration(
                      'Order Code',
                      'Enter order code',
                      Icons.qr_code
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter order code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Section Header: Plan Details
                  _buildSectionHeader('Plan Details'),
                  const SizedBox(height: 16),
                  
                  // Plan Dropdown
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration(
                      'Plan Chosen',
                      'Select a plan',
                      Icons.description
                    ),
                    value: _selectedPlan,
                    items: _planOptions.map((String plan) {
                      return DropdownMenuItem<String>(
                        value: plan,
                        child: Text(plan),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedPlan = newValue;
                        _isCustomPlan = newValue == 'Custom Plan';
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a plan';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Custom Plan Field (only visible if "Custom Plan" is selected)
                  if (_isCustomPlan)
                    TextFormField(
                      controller: _customPlanController,
                      decoration: _inputDecoration(
                        'Custom Plan Name',
                        'Enter custom plan name',
                        Icons.edit
                      ),
                      validator: (value) {
                        if (_isCustomPlan && (value == null || value.isEmpty)) {
                          return 'Please enter custom plan name';
                        }
                        return null;
                      },
                    ),
                  if (_isCustomPlan) 
                    const SizedBox(height: 16),
                  
                  // Total Price
                  TextFormField(
                    controller: _totalPriceController,
                    decoration: _inputDecoration(
                      'Total Price (₹)',
                      'Enter total price in rupees',
                      Icons.currency_rupee
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter total price';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _calculatePendingPayment();
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Section Header: Payment Information
                  _buildSectionHeader('Payment Information'),
                  const SizedBox(height: 16),
                  
                  // Payment Collected
                  TextFormField(
                    controller: _paymentCollectedController,
                    decoration: _inputDecoration(
                      'Payment Collected (₹)',
                      'Enter payment collected in rupees',
                      Icons.payments
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter payment collected';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _calculatePendingPayment();
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Payment Proof Upload
                  _buildImageUploader(
                    'Upload Payment Proof',
                    _paymentProofImage,
                    _pickImage,
                  ),
                  const SizedBox(height: 24),
                  
                  // Payment Pending
                  TextFormField(
                    controller: _paymentPendingController,
                    decoration: _inputDecoration(
                      'Payment Pending (₹)',
                      'Amount pending (calculated automatically)',
                      Icons.money_off
                    ),
                    readOnly: true,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF27AE60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle),
                            SizedBox(width: 12),
                            Text(
                              'ADD ORDER',
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
          ),
        ),
      ),
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
          color: const Color(0xFF27AE60),
        ),
      ],
    );
  }

  // Helper method to create consistent input decoration
  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF27AE60)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF27AE60), width: 2),
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
              if (_paymentProofPath != null)
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