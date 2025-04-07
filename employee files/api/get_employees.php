<?php
// Include database connection
include_once 'config.php';

// Check if request is GET
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Query to get all employees
    $query = "SELECT id, name, position, email FROM employees ORDER BY name";
    
    $stmt = $conn->prepare($query);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $employees = [];
    while ($row = $result->fetch_assoc()) {
        $employees[] = $row;
    }
    
    echo json_encode([
        "success" => true,
        "count" => count($employees),
        "employees" => $employees
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