<?php
// Include database connection
include_once 'config.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get raw data from request
    $data = json_decode(file_get_contents("php://input"));
    
    // Validate input
    if (!empty($data->order_id) && isset($data->payment_collected) && !empty($data->employee_id)) {
        // Get current payment details for history and calculations
        $query = "SELECT total_price, payment_collected FROM orders WHERE id = ?";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("i", $data->order_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            $total_price = $row['total_price'];
            $previous_payment = $row['payment_collected'];
            
            // Calculate new payment details
            $new_payment = $data->payment_collected;
            $payment_pending = $total_price - $new_payment;
            
            // Payment proof image
            $payment_proof_image = isset($data->payment_proof_image) ? $data->payment_proof_image : null;
            
            // Update payment information
            $update_query = "UPDATE orders SET 
                payment_collected = ?, 
                payment_pending = ?,
                payment_proof_image = COALESCE(?, payment_proof_image),
                status = CASE 
                    WHEN ? >= total_price THEN 'Completed' 
                    ELSE status 
                END
                WHERE id = ?";
            
            $update_stmt = $conn->prepare($update_query);
            $update_stmt->bind_param("ddsdi", 
                $new_payment, 
                $payment_pending, 
                $payment_proof_image,
                $new_payment,
                $data->order_id
            );
            
            if ($update_stmt->execute()) {
                // Add entry to order history
                $history_query = "INSERT INTO order_history (
                    order_id, action_type, previous_value, new_value, employee_id
                ) VALUES (?, 'Payment Update', ?, ?, ?)";
                
                $history_stmt = $conn->prepare($history_query);
                $previous_value = "Payment: " . $previous_payment;
                $new_value = "Payment: " . $new_payment;
                
                $history_stmt->bind_param("issi", 
                    $data->order_id, 
                    $previous_value, 
                    $new_value, 
                    $data->employee_id
                );
                $history_stmt->execute();
                
                // Check if status was auto-changed to 'Completed'
                $status_changed = false;
                if ($previous_payment < $total_price && $new_payment >= $total_price) {
                    $status_changed = true;
                    
                    // Add status change entry to history if payment completed
                    $status_history_query = "INSERT INTO order_history (
                        order_id, action_type, previous_value, new_value, employee_id
                    ) VALUES (?, 'Status Change', 'Pending', 'Completed', ?)";
                    
                    $status_history_stmt = $conn->prepare($status_history_query);
                    $status_history_stmt->bind_param("ii", $data->order_id, $data->employee_id);
                    $status_history_stmt->execute();
                    $status_history_stmt->close();
                }
                
                echo json_encode([
                    "success" => true,
                    "message" => "Payment updated successfully",
                    "previous_payment" => $previous_payment,
                    "new_payment" => $new_payment,
                    "payment_pending" => $payment_pending,
                    "status_changed" => $status_changed
                ]);
                
                $history_stmt->close();
            } else {
                echo json_encode([
                    "success" => false,
                    "message" => "Failed to update payment: " . $update_stmt->error
                ]);
            }
            
            $update_stmt->close();
        } else {
            echo json_encode([
                "success" => false,
                "message" => "Order not found"
            ]);
        }
        
        $stmt->close();
    } else {
        echo json_encode([
            "success" => false,
            "message" => "Order ID, payment amount, and employee ID are required"
        ]);
    }
} else {
    // Method not allowed
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Method not allowed"
    ]);
}

// Close connection
$conn->close();
?>