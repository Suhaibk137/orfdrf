<?php
// Include database connection
include_once 'config.php';

// Check if request is GET
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Get order ID or order code from request
    $order_id = isset($_GET['id']) ? intval($_GET['id']) : 0;
    $order_code = isset($_GET['order_code']) ? $_GET['order_code'] : '';
    
    if ($order_id > 0 || !empty($order_code)) {
        // Prepare query based on what was provided
        if ($order_id > 0) {
            $query = "SELECT o.*, e.name as employee_name FROM orders o 
                      JOIN employees e ON o.employee_id = e.id 
                      WHERE o.id = ?";
            $param = $order_id;
            $type = "i";
        } else {
            $query = "SELECT o.*, e.name as employee_name FROM orders o 
                      JOIN employees e ON o.employee_id = e.id 
                      WHERE o.order_code = ?";
            $param = $order_code;
            $type = "s";
        }
        
        // Prepare and execute statement
        $stmt = $conn->prepare($query);
        $stmt->bind_param($type, $param);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            // Get order details
            $order = $result->fetch_assoc();
            
            // Get order history
            $history_query = "SELECT oh.*, e.name as employee_name FROM order_history oh 
                             JOIN employees e ON oh.employee_id = e.id 
                             WHERE oh.order_id = ? ORDER BY oh.created_at DESC";
            $history_stmt = $conn->prepare($history_query);
            $history_stmt->bind_param("i", $order['id']);
            $history_stmt->execute();
            $history_result = $history_stmt->get_result();
            
            $history = [];
            while ($row = $history_result->fetch_assoc()) {
                $history[] = $row;
            }
            
            // Return order with history
            echo json_encode([
                "success" => true,
                "order" => $order,
                "history" => $history
            ]);
            
            $history_stmt->close();
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
            "message" => "Order ID or order code is required"
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