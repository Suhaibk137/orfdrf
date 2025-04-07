<?php
// Include database connection
include_once 'config.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get raw data from request
    $data = json_decode(file_get_contents("php://input"));
    
    // Validate input
    if (!empty($data->email) && !empty($data->password)) {
        $email = $data->email;
        $employee_code = $data->password;
        
        // Query to check if email exists
        $query = "SELECT id, name, position, employee_code, email FROM employees WHERE email = ?";
        
        $stmt = $conn->prepare($query);
        $stmt->bind_param("s", $email);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            
            // Check if employee code matches
            if ($employee_code === $row['employee_code']) {
                // Employee code matches
                echo json_encode(array(
                    "success" => true,
                    "message" => "Login successful",
                    "employee" => array(
                        "id" => $row['id'],
                        "name" => $row['name'],
                        "position" => $row['position'],
                        "employee_code" => $row['employee_code'],
                        "email" => $row['email']
                    )
                ));
            } else {
                // Employee code does not match
                echo json_encode(array(
                    "success" => false,
                    "message" => "Invalid employee code"
                ));
            }
        } else {
            // Email not found
            echo json_encode(array(
                "success" => false,
                "message" => "Email not found"
            ));
        }
        
        $stmt->close();
    } else {
        // Missing data
        echo json_encode(array(
            "success" => false,
            "message" => "Email and employee code are required"
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