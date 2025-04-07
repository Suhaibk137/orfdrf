<?php
// Include database connection
include_once 'config.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get raw data from request
    $data = json_decode(file_get_contents("php://input"));
    
    // Validate input
    if (!empty($data->order_id) && !empty($data->verification_status)) {
        // Update order verification status
        $query = "UPDATE orders SET payment_verification_status = ? WHERE id = ?";
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param("si", $data->verification_status, $data->order_id);
        
        if ($stmt->execute()) {
            // Add entry to order history
            $history_query = "INSERT INTO order_history (
                order_id, action_type, previous_value, new_value, employee_id
            ) VALUES (?, 'Verification Status', 'Not specified', ?, 1)";
            
            $history_stmt = $conn->prepare($history_query);
            $history_stmt->bind_param("is", 
                $data->order_id, 
                $data->verification_status
            );
            $history_stmt->execute();
            $history_stmt->close();
            
            echo json_encode([
                "success" => true,
                "message" => "Verification status updated successfully"
            ]);
        } else {
            echo json_encode([
                "success" => false,
                "message" => "Failed to update verification status: " . $stmt->error
            ]);
        }
        
        $stmt->close();
    } else {
        echo json_encode([
            "success" => false,
            "message" => "Order ID and verification status are required"
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