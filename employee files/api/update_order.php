<?php
// Include database connection
include_once 'config.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get raw data from request
    $data = json_decode(file_get_contents("php://input"));
    
    // Validate input
    if (!empty($data->order_id)) {
        // Start building the update query
        $updates = [];
        $params = [];
        $types = "";
        
        // Check each potential field for updates
        if (isset($data->customer_name)) {
            $updates[] = "customer_name = ?";
            $params[] = $data->customer_name;
            $types .= "s";
        }
        
        if (isset($data->plan_type)) {
            $updates[] = "plan_type = ?";
            $params[] = $data->plan_type;
            $types .= "s";
        }
        
        if (isset($data->custom_plan_details)) {
            $updates[] = "custom_plan_details = ?";
            $params[] = $data->custom_plan_details;
            $types .= "s";
        }
        
        if (isset($data->total_price)) {
            $updates[] = "total_price = ?";
            $params[] = $data->total_price;
            $types .= "d";
        }
        
        if (isset($data->payment_collected)) {
            $updates[] = "payment_collected = ?";
            $params[] = $data->payment_collected;
            $types .= "d";
            
            // Recalculate payment_pending if total_price is available
            if (isset($data->total_price)) {
                $updates[] = "payment_pending = total_price - ?";
                $params[] = $data->payment_collected;
                $types .= "d";
            } else {
                $updates[] = "payment_pending = total_price - ?";
                $params[] = $data->payment_collected;
                $types .= "d";
            }
        }
        
        if (isset($data->status)) {
            $updates[] = "status = ?";
            $params[] = $data->status;
            $types .= "s";
        }
        
        if (isset($data->payment_proof_image)) {
            $updates[] = "payment_proof_image = ?";
            $params[] = $data->payment_proof_image;
            $types .= "s";
        }
        
        if (isset($data->pending_payment_proof_image)) {
            $updates[] = "pending_payment_proof_image = ?";
            $params[] = $data->pending_payment_proof_image;
            $types .= "s";
        }
        
        // Only proceed if there are updates
        if (count($updates) > 0) {
            // Complete the update query
            $query = "UPDATE orders SET " . implode(", ", $updates) . " WHERE id = ?";
            
            // Add order_id to parameters and types
            $params[] = $data->order_id;
            $types .= "i";
            
            // Prepare and execute statement
            $stmt = $conn->prepare($query);
            
            // Bind parameters dynamically
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                // Add entry to order history if applicable
                if (!empty($data->employee_id) && !empty($data->action_type) && 
                    !empty($data->previous_value) && !empty($data->new_value)) {
                    
                    $history_query = "INSERT INTO order_history (
                        order_id, action_type, previous_value, new_value, employee_id
                    ) VALUES (?, ?, ?, ?, ?)";
                    
                    $history_stmt = $conn->prepare($history_query);
                    $history_stmt->bind_param("isssi", 
                        $data->order_id, 
                        $data->action_type, 
                        $data->previous_value, 
                        $data->new_value, 
                        $data->employee_id
                    );
                    $history_stmt->execute();
                    $history_stmt->close();
                }
                
                echo json_encode([
                    "success" => true,
                    "message" => "Order updated successfully",
                    "affected_rows" => $stmt->affected_rows
                ]);
            } else {
                echo json_encode([
                    "success" => false,
                    "message" => "Failed to update order: " . $stmt->error
                ]);
            }
            
            $stmt->close();
        } else {
            echo json_encode([
                "success" => false,
                "message" => "No update parameters provided"
            ]);
        }
    } else {
        echo json_encode([
            "success" => false,
            "message" => "Order ID is required"
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