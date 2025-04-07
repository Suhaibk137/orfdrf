<?php
// Include database connection
include_once 'config.php';

// Check if request is GET
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Get search query from request
    $search = isset($_GET['search']) ? $_GET['search'] : '';
    
    if (!empty($search)) {
        // Prepare search query - look in order_code and customer_name
        $query = "SELECT o.*, e.name as employee_name FROM orders o
                  JOIN employees e ON o.employee_id = e.id
                  WHERE o.order_code LIKE ? OR o.customer_name LIKE ?
                  ORDER BY o.created_at DESC LIMIT 50";
        
        $searchTerm = "%$search%";  // Add wildcards for partial matching
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param("ss", $searchTerm, $searchTerm);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $orders = [];
        while ($row = $result->fetch_assoc()) {
            $orders[] = $row;
        }
        
        echo json_encode([
            "success" => true,
            "count" => count($orders),
            "orders" => $orders
        ]);
        
        $stmt->close();
    } else {
        echo json_encode([
            "success" => false,
            "message" => "Search query is required"
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