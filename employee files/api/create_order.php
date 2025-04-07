<?php
// Include database connection
include_once 'config.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get raw data from request
    $data = json_decode(file_get_contents("php://input"));
    
    // Validate input
    if (!empty($data->customer_name) && 
        !empty($data->contact_number) && 
        !empty($data->order_code) && 
        !empty($data->plan_type) && 
        !empty($data->total_price) && 
        !empty($data->employee_id)) {
        
        // Use the provided order code
        $order_code = $data->order_code;
        
        // Prepare payment values
        $payment_collected = !empty($data->payment_collected) ? $data->payment_collected : 0;
        $payment_pending = $data->total_price - $payment_collected;
        
        // Custom plan details
        $custom_plan_details = !empty($data->custom_plan_details) ? $data->custom_plan_details : null;
        
        // Image paths
        $payment_proof_image = !empty($data->payment_proof_image) ? $data->payment_proof_image : null;
        $pending_payment_proof_image = !empty($data->pending_payment_proof_image) ? $data->pending_payment_proof_image : null;
        
        // Check if order code already exists
        $check_query = "SELECT id FROM orders WHERE order_code = ?";
        $check_stmt = $conn->prepare($check_query);
        $check_stmt->bind_param("s", $order_code);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();
        
        if ($check_result->num_rows > 0) {
            // Order code already exists
            echo json_encode(array(
                "success" => false,
                "message" => "Order code already exists. Please use a different code."
            ));
            $check_stmt->close();
            exit;
        }
        
        $check_stmt->close();
        
        // Insert query
        $query = "INSERT INTO orders (
            order_code, customer_name, contact_number, plan_type, custom_plan_details,
            total_price, payment_collected, payment_pending, status,
            payment_proof_image, pending_payment_proof_image, employee_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Pending', ?, ?, ?)";
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param("sssssddsssi", 
            $order_code, 
            $data->customer_name,
            $data->contact_number,
            $data->plan_type,
            $custom_plan_details,
            $data->total_price,
            $payment_collected,
            $payment_pending,
            $payment_proof_image,
            $pending_payment_proof_image,
            $data->employee_id
        );
        
        if ($stmt->execute()) {
            // Get the ID of the inserted order
            $order_id = $conn->insert_id;
            
            // Add entry to order history
            $history_query = "INSERT INTO order_history (
                order_id, action_type, previous_value, new_value, employee_id
            ) VALUES (?, 'Status Change', '', 'Pending', ?)";
            
            $history_stmt = $conn->prepare($history_query);
            $history_stmt->bind_param("ii", $order_id, $data->employee_id);
            $history_stmt->execute();
            
            // Successful response
            echo json_encode(array(
                "success" => true,
                "message" => "Order created successfully",
                "order_code" => $order_code,
                "order_id" => $order_id
            ));
        } else {
            // Failed to insert
            echo json_encode(array(
                "success" => false,
                "message" => "Failed to create order: " . $stmt->error
            ));
        }
        
        $stmt->close();
        
    } else {
        // Missing data
        echo json_encode(array(
            "success" => false,
            "message" => "Incomplete order data. Please provide all required fields including order code and contact number."
        ));
    }
} else {
    // Method not allowed
    http_response_code(405);
    echo json_encode(array(
        "success" => false,
        "message" => "Method not allowed"
    ));
}

// Close connection
$conn->close();
?>