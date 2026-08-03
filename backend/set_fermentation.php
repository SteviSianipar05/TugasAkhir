<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

include 'config.php';

$input = json_decode(file_get_contents("php://input"), true);

if (!$input) {
    echo json_encode(["success" => false, "message" => "Invalid JSON"]);
    exit;
}

$profile_id = intval($input['profile_id'] ?? 0);
$status     = isset($input['status']) ? intval($input['status']) : null;
$user_id    = intval($input['user_id'] ?? 0);

if (!$profile_id || !isset($status)) {
    echo json_encodefli(["success" => false, "message" => "profile_id and status required"]);
    exit;
}

$now = date('Y-m-d H:i:s');

// Start fermentation
if ($status == 1) {

    // Stop previous active fermentation
    $conn->query("UPDATE fermentation_control SET running=0 WHERE profile_id=$profile_id AND running=1");

    // Create new record
    $stmt = $conn->prepare("
        INSERT INTO fermentation_control 
        (profile_id, running, start_time, started_by, created_at, updated_at) 
        VALUES (?, 1, ?, ?, NOW(), NOW())
    ");
    $stmt->bind_param("isi", $profile_id, $now, $user_id);
    $stmt->execute();
    $stmt->close();

    // Get profile info
    $pstmt = $conn->prepare("
        SELECT name, coffee_type, target_ph, target_temp_min, target_temp_max, duration_minutes
        FROM profiles WHERE id=? LIMIT 1
    ");
    $pstmt->bind_param("i", $profile_id);
    $pstmt->execute();
    $p = $pstmt->get_result()->fetch_assoc();
    $pstmt->close();

    $payload_info = [
        "command" => "start",
        "profile_id" => $profile_id,
        "profile_name" => $p["name"],
        "coffee_type" => $p["coffee_type"],
        "target_ph" => floatval($p["target_ph"]),
        "temp_min" => floatval($p["target_temp_min"]),
        "temp_max" => floatval($p["target_temp_max"]),
        "duration_minutes" => intval($p["duration_minutes"])
    ];

    $message = "Fermentation started";

} else {

    // Stop fermentation
    $conn->query("
        UPDATE fermentation_control 
        SET running=0, stop_time='$now', updated_at=NOW()
        WHERE profile_id=$profile_id AND running=1
    ");

    $payload_info = [
        "command" => "stop",
        "profile_id" => $profile_id
    ];

    $message = "Fermentation stopped";
}

// SEND MQTT via mqtt_publish.php
$ch = curl_init("http://10.23.83.199/api/mqtt_publish.php");
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    "topic" => "ferment/control",
    "payload" => $payload_info
]));
curl_setopt($ch, CURLOPT_HTTPHEADER, ["Content-Type: application/json"]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$res = curl_exec($ch);
curl_close($ch);

echo json_encode([
    "success" => true,
    "message" => $message,
    "mqtt" => json_decode($res, true)
]);
?>
