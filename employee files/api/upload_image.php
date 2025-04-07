<?php
// Debug mode - will help identify issues
ini_set('display_errors', 1);
error_reporting(E_ALL);

// Include database connection
include_once 'config.php';

// Enable CORS for all domains
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Log upload attempts
error_log("Upload attempt received: " . date('Y-m-d H:i:s'));
error_log("Request method: " . $_SERVER['REQUEST_METHOD']);

// Check if request is POST and contains a file
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Dump the entire $_FILES array to the error log for debugging
    error_log("FILES contents: " . print_r($_FILES, true));
    
    if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
        $error_message = isset($_FILES['image']) ? "Upload error code: " . $_FILES['image']['error'] : "No image file was sent";
        error_log("Image upload error: " . $error_message);
        
        echo json_encode([
            "success" => false,
            "message" => $error_message
        ]);
        exit;
    }
    
    // Save to current directory (where this script is)
    $target_dir = "./";
    
    // Check if directory is writable
    if (!is_writable($target_dir)) {
        error_log("Upload directory is not writable: " . $target_dir);
        echo json_encode([
            "success" => false,
            "message" => "Server error: Upload directory is not writable"
        ]);
        exit;
    }
    
    // Generate a unique file name
    $file_extension = pathinfo($_FILES["image"]["name"], PATHINFO_EXTENSION);
    $unique_id = uniqid();
    $target_file = $target_dir . $unique_id . '.' . $file_extension;
    
    // Log file information
    error_log("File information - Name: " . $_FILES["image"]["name"] . ", Size: " . $_FILES["image"]["size"] . ", Type: " . $_FILES["image"]["type"]);
    
    // Check file size (limit to 5MB)
    if ($_FILES["image"]["size"] > 5000000) {
        echo json_encode([
            "success" => false,
            "message" => "File is too large. Maximum size is 5MB."
        ]);
        exit;
    }
    
    // Allow only certain file formats
    $allowed_formats = ["jpg", "jpeg", "png"];
    if (!in_array(strtolower($file_extension), $allowed_formats)) {
        echo json_encode([
            "success" => false,
            "message" => "Only JPG, JPEG, and PNG files are allowed."
        ]);
        exit;
    }
    
    // Try to upload the file
    if (move_uploaded_file($_FILES["image"]["tmp_name"], $target_file)) {
        // Make sure the file exists after upload
        if (file_exists($target_file)) {
            error_log("File successfully uploaded to: " . $target_file);
            
            // Get absolute URL for the file
            $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https://' : 'http://';
            $domain = $_SERVER['HTTP_HOST'];
            
            // Just use the filename part for the URL
            $file_url = $protocol . $domain . '/' . basename($target_file);
            
            echo json_encode([
                "success" => true,
                "message" => "File uploaded successfully",
                "file_path" => basename($target_file),
                "file_url" => $file_url
            ]);
        } else {
            error_log("File upload failed: File does not exist after move_uploaded_file");
            echo json_encode([
                "success" => false,
                "message" => "File upload appeared successful but file not found on server"
            ]);
        }
    } else {
        $upload_error = error_get_last();
        error_log("Failed to move uploaded file: " . ($upload_error ? $upload_error['message'] : 'Unknown error'));
        
        echo json_encode([
            "success" => false,
            "message" => "There was an error uploading your file. Please try again."
        ]);
    }
} else {
    // Method not allowed
    http_response_code(405);
    error_log("Invalid request method: " . $_SERVER['REQUEST_METHOD']);
    
    echo json_encode([
        "success" => false,
        "message" => "Invalid request method. Only POST is accepted."
    ]);
}
?>