<?php
// Include database connection
include_once 'config.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get raw data from request
    $data = json_decode(file_get_contents("php://input"));
    
    // Validate input
    if (!empty($data->order_id)) {
        // Start transaction to ensure data consistency
        $conn->begin_transaction();
        
        try {
            // First, delete order history entries
            $history_query = "DELETE FROM order_history WHERE order_id = ?";
            $history_stmt = $conn->prepare($history_query);
            $history_stmt->bind_param("i", $data->order_id);
            $history_stmt->execute();
            $history_stmt->close();
            
            // Then, delete the order
            $order_query = "DELETE FROM orders WHERE id = ?";
            $order_stmt = $conn->prepare($order_query);
            $order_stmt->bind_param("i", $data->order_id);
            $order_stmt->execute();
            
            // Check if order was actually deleted
            if ($order_stmt->affected_rows > 0) {
                // Commit the transaction
                $conn->commit();
                
                echo json_encode([
                    "success" => true,
                    "message" => "Order deleted successfully"
                ]);
            } else {
                // Rollback if no rows affected (order not found)
                $conn->rollback();
                
                echo json_encode([
                    "success" => false,
                    "message" => "Order not found"
                ]);
            }
            
            $order_stmt->close();
        } catch (Exception $e) {
            // Rollback transaction on error
            $conn->rollback();
            
            echo json_encode([
                "success" => false,
                "message" => "Error deleting order: " . $e->getMessage()
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