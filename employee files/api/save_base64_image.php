<?php
// Enable error reporting for debugging
ini_set('display_errors', 1);
error_reporting(E_ALL);

// Set headers
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Include database connection
include_once 'config.php';

// Log request
error_log("Base64 image upload attempt received: " . date('Y-m-d H:i:s'));

// Handle OPTIONS preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Check if it's a POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get JSON data
    $json_data = file_get_contents("php://input");
    $data = json_decode($json_data, true);
    
    error_log("Received data: " . substr(print_r($data, true), 0, 100) . "...");
    
    // Validate input
    if (!empty($data['image_data']) && !empty($data['file_name'])) {
        // Directory to save images
        $target_dir = "./";
        
        // Create directory if it doesn't exist (though not needed for current dir)
        if (!is_writable($target_dir)) {
            error_log("Target directory is not writable: " . $target_dir);
            echo json_encode([
                'success' => false,
                'message' => 'Server error: Target directory is not writable'
            ]);
            exit();
        }
        
        // Extract base64 data (remove data:image/jpeg;base64, if present)
        $base64_image = $data['image_data'];
        if (strpos($base64_image, ',') !== false) {
            $base64_image = explode(',', $base64_image)[1];
        }
        
        // Generate a unique filename
        $file_name = uniqid() . '_' . basename($data['file_name']);
        $file_path = $target_dir . $file_name;
        
        error_log("Attempting to save file to: " . $file_path);
        
        // Decode and save the image
        $image_data = base64_decode($base64_image);
        if (file_put_contents($file_path, $image_data)) {
            error_log("File saved successfully: " . $file_path);
            
            // Get absolute URL for the file
            $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https://' : 'http://';
            $domain = $_SERVER['HTTP_HOST'];
            $file_url = $protocol . $domain . '/' . $file_name;
            
            // Success response
            echo json_encode([
                'success' => true,
                'message' => 'Image saved successfully',
                'file_path' => $file_name,
                'file_url' => $file_url
            ]);
        } else {
            error_log("Failed to save image file: " . $file_path);
            // Error saving file
            echo json_encode([
                'success' => false,
                'message' => 'Failed to save image file'
            ]);
        }
    } else {
        error_log("Missing required data in request");
        // Missing data
        echo json_encode([
            'success' => false,
            'message' => 'Image data and file name are required'
        ]);
    }
} else {
    error_log("Invalid request method: " . $_SERVER['REQUEST_METHOD']);
    // Method not allowed
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Method not allowed. Only POST is accepted.'
    ]);
}
?>