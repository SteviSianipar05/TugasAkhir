<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

include 'config.php'; // koneksi ke database

$data = json_decode(file_get_contents("php://input"), true);
$name = $data['name'];
$email = $data['email'];
$password = password_hash($data['password'], PASSWORD_DEFAULT);

if (!$name || !$email || !$password) {
    echo json_encode(["success" => false, "message" => "Semua field wajib diisi"]);
    exit;
}

$check = $conn->prepare("SELECT id FROM users WHERE email = ?");
$check->bind_param("s", $email);
$check->execute();
$checkResult = $check->get_result();

if ($checkResult->num_rows > 0) {
    echo json_encode(["success" => false, "message" => "Email sudah terdaftar"]);
    exit;
}

$query = $conn->prepare("INSERT INTO users (name, email, password) VALUES (?, ?, ?)");
$query->bind_param("sss", $name, $email, $password);
if ($query->execute()) {
    echo json_encode(["success" => true, "message" => "Registrasi berhasil"]);
} else {
    echo json_encode(["success" => false, "message" => "Gagal menyimpan data"]);
}
?>
