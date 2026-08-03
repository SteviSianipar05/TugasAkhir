<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

$input = json_decode(file_get_contents("php://input"), true);

if (!$input || !isset($input["topic"]) || !isset($input["payload"])) {
    echo json_encode([
        "success" => false,
        "message" => "topic & payload required"
    ]);
    exit;
}

$topic = $input["topic"];
$payload = $input["payload"];

// Node-RED HTTP Endpoint
$nodeRedUrl = "http://10.23.83.199:1880/mqtt_publish";

$ch = curl_init($nodeRedUrl);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    "topic" => $topic,
    "payload" => $payload
], JSON_UNESCAPED_SLASHES));
curl_setopt($ch, CURLOPT_HTTPHEADER, ["Content-Type: application/json"]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 20);

$response = curl_exec($ch);
$error = curl_error($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo json_encode([
    "success" => $error ? false : true,
    "node_red_response" => $response,
    "http_code" => $httpCode,
    "error" => $error
]);
?>
