<?php
// Database configuration for hosted environment
$host = "sdb-82.hosting.stackcp.net"; // Your server from screenshot
$port = 3306;        // Default MySQL port
$db_name = "elite_orders-35303839b270"; // Your database name
$username = "suhaib1"; // Replace with your username
$password = "12345678@"; // Replace with your password

// Create connection
$conn = new mysqli($host, $username, $password, $db_name);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Set proper CORS headers
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    // Just exit with 200 OK status
    http_response_code(200);
    exit;
}
?>