<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include 'config.php';

$profile_id = isset($_GET["profile_id"]) ? intval($_GET["profile_id"]) : 0;

$q = $conn->query("
    SELECT running, start_time, stop_time
    FROM fermentation_control 
    WHERE profile_id=$profile_id 
    ORDER BY id DESC LIMIT 1
");

if ($q->num_rows > 0) {
    echo json_encode($q->fetch_assoc());
} else {
    echo json_encode(["running" => 0]);
}
?>
