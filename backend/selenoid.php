<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");

// Hanya POST yang diizinkan
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["error" => "Only POST is allowed"]);
    exit;
}

// Ambil JSON dari aplikasi
$input = file_get_contents("php://input");
$data = json_decode($input, true);

if (!$data || !isset($data['command'])) {
    http_response_code(400);
    echo json_encode(["error" => "Parameter 'command' tidak ditemukan"]);
    exit;
}

$cmd = strtoupper($data['command']);

// Mapping ke format ESP32
$commandMap = [
    "ON"  => "solenoid_on",
    "OFF" => "solenoid_off"
];

if (!isset($commandMap[$cmd])) {
    http_response_code(400);
    echo json_encode(["error" => "Command harus ON atau OFF"]);
    exit;
}

$finalCommand = $commandMap[$cmd];

// --- SYNC DENGAN NODE-RED ---
// Node-RED HTTP IN berada di: /api/solenoid_cmd
// Node-RED publish ke: ferment/app_solenoid_cmd
$nodeRedUrl = "http://10.23.83.199:1880/api/selenoid";

// Kirim data ke Node-RED
$ch = curl_init($nodeRedUrl);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    "command" => $finalCommand
]));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

// Respon
if ($httpCode >= 200 && $httpCode < 300) {
    echo json_encode([
        "success" => true,
        "command_sent" => $finalCommand,
        "message" => "Perintah solenoid berhasil dikirim",
        "node_red_response" => json_decode($response, true)
    ]);
} else {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => "Gagal mengirim ke Node-RED",
        "node_red_http_code" => $httpCode,
        "response" => $response
    ]);
}
