<?php
// Include database connection
include_once 'config.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get raw data from request
    $data = json_decode(file_get_contents("php://input"));
    
    // Validate input
    if (!empty($data->order_id) && !empty($data->status) && !empty($data->employee_id)) {
        // Get current status for history
        $status_query = "SELECT status FROM orders WHERE id = ?";
        $status_stmt = $conn->prepare($status_query);
        $status_stmt->bind_param("i", $data->order_id);
        $status_stmt->execute();
        $status_result = $status_stmt->get_result();
        
        if ($status_result->num_rows > 0) {
            $row = $status_result->fetch_assoc();
            $previous_status = $row['status'];
            
            // Update order status
            $update_query = "UPDATE orders SET status = ? WHERE id = ?";
            $update_stmt = $conn->prepare($update_query);
            $update_stmt->bind_param("si", $data->status, $data->order_id);
            
            if ($update_stmt->execute()) {
                // Add entry to order history
                $history_query = "INSERT INTO order_history (
                    order_id, action_type, previous_value, new_value, employee_id
                ) VALUES (?, 'Status Change', ?, ?, ?)";
                
                $history_stmt = $conn->prepare($history_query);
                $history_stmt->bind_param("issi", 
                    $data->order_id, 
                    $previous_status, 
                    $data->status, 
                    $data->employee_id
                );
                $history_stmt->execute();
                
                echo json_encode([
                    "success" => true,
                    "message" => "Order status updated successfully",
                    "previous_status" => $previous_status,
                    "new_status" => $data->status
                ]);
                
                $history_stmt->close();
            } else {
                echo json_encode([
                    "success" => false,
                    "message" => "Failed to update order status: " . $update_stmt->error
                ]);
            }
            
            $update_stmt->close();
        } else {
            echo json_encode([
                "success" => false,
                "message" => "Order not found"
            ]);
        }
        
        $status_stmt->close();
    } else {
        echo json_encode([
            "success" => false,
            "message" => "Order ID, status, and employee ID are required"
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