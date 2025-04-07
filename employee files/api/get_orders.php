<?php
// Include database connection
include_once 'config.php';

// Check if request is GET
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Default values
    $status = isset($_GET['status']) ? $_GET['status'] : 'all';
    $employee_id = isset($_GET['employee_id']) ? intval($_GET['employee_id']) : 0;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 10;
    
    // Build the query based on filters
    $query = "SELECT o.*, e.name as employee_name FROM orders o
              JOIN employees e ON o.employee_id = e.id
              WHERE 1=1";
    
    // Always filter by employee_id if provided
    if ($employee_id > 0) {
        $query .= " AND o.employee_id = ?";
    }
    
    // Add status filter if not 'all'
    if ($status !== 'all') {
        $query .= " AND o.status = ?";
    }
    
    // Order by most recent first
    $query .= " ORDER BY o.created_at DESC LIMIT ?";
    
    // Prepare statement
    $stmt = $conn->prepare($query);
    
    // Bind parameters based on filters
    if ($status !== 'all' && $employee_id > 0) {
        $stmt->bind_param("isi", $employee_id, $status, $limit);
    } else if ($status !== 'all') {
        $stmt->bind_param("si", $status, $limit);
    } else if ($employee_id > 0) {
        $stmt->bind_param("ii", $employee_id, $limit);
    } else {
        $stmt->bind_param("i", $limit);
    }
    
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