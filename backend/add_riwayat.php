<?php
header('Content-Type: application/json');

include 'config.php'; // sesuaikan nama koneksi kamu

$data = json_decode(file_get_contents('php://input'), true);

if (!$data) {
    echo json_encode(["success" => false, "message" => "No data received"]);
    exit;
}

$name = $data['name'] ?? '';
$coffee_type = $data['coffee_type'] ?? '';
$target_ph = $data['target_ph'] ?? 0;
$target_temp_min = $data['target_temp_min'] ?? 0;
$target_temp_max = $data['target_temp_max'] ?? 0;
$final_ph = $data['final_ph'] ?? 0;
$final_temp_min = $data['final_temp_min'] ?? 0;
$final_temp_max = $data['final_temp_max'] ?? 0;
$start_time = $data['start_time'] ?? '';
$end_time = $data['end_time'] ?? '';
$status = $data['status'] ?? '';
$reason = $data['reason'] ?? '';

$sql = "INSERT INTO history (name, coffee_type, target_ph, target_temp_min, target_temp_max, final_ph, final_temp_min, final_temp_max, start_time, end_time, status, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ssddddddssss", $name, $coffee_type, $target_ph, $target_temp_min, $target_temp_max, $final_ph, $final_temp_min, $final_temp_max, $start_time, $end_time, $status, $reason);

if ($stmt->execute()) {
    echo json_encode(["success" => true]);
} else {
    echo json_encode(["success" => false, "message" => $stmt->error]);
}
?>
