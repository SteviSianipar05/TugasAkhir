<?php
// ===================================================
// 🌐 UNIVERSAL API HANDLER for Fermentation App (fixed)
// Supports: profile (singular) & profiles (plural), history, sensor
// ===================================================

// ---------------------------------------------------
// GLOBAL HEADERS (CORS + JSON)
// ---------------------------------------------------
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

// Handle CORS preflight request quickly
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ---------------------------------------------------
// DATABASE CONNECTION (MySQL) - use host + port explicitly
// ---------------------------------------------------
$host = "127.0.0.1";
$port = 3306;
$db   = "fermentation_app";
$user = "root";
$pass = "";
$charset = "utf8mb4";

try {
    $dsn = "mysql:host={$host};port={$port};dbname={$db};charset={$charset}";
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "error" => "Database connection failed: " . $e->getMessage()]);
    exit;
}

// ---------------------------------------------------
// ROUTING
// ---------------------------------------------------
$type = strtolower(trim($_GET['type'] ?? ''));
$method = $_SERVER['REQUEST_METHOD'];

if ($type === '') {
    $type = 'profile';
}

// ===================================================
// PROFILE(S) HANDLER (CRUD)
// ===================================================
if ($type === 'profile' || $type === 'profiles') {
    try {
        if ($method === 'GET') {
            if (isset($_GET['id'])) {
                $id = intval($_GET['id']);
                $stmt = $pdo->prepare("SELECT * FROM profiles WHERE id = :id LIMIT 1");
                $stmt->execute([':id' => $id]);
                $row = $stmt->fetch();
                echo json_encode(["success" => true, "data" => $row ? $row : null]);
                exit;
            }
            $stmt = $pdo->query("SELECT * FROM profiles ORDER BY created_at DESC");
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            exit;
        }

        if ($method === 'POST') {
            $input = json_decode(file_get_contents("php://input"), true) ?? $_POST;

            $required = ['name', 'coffee_type', 'target_ph', 'target_temp_min', 'target_temp_max', 'duration_minutes'];
            foreach ($required as $r) {
                if (!isset($input[$r])) {
                    http_response_code(400);
                    echo json_encode(["success" => false, "error" => "Missing required field: $r"]);
                    exit;
                }
            }

            // =================== VALIDASI pH & SUHU ===================
            $target_ph = floatval($input['target_ph']);
            $temp_min = floatval($input['target_temp_min']);
            $temp_max = floatval($input['target_temp_max']);

            if ($target_ph < 0 || $target_ph > 14) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Target pH harus antara 0 - 14"]);
                exit;
            }

            if ($temp_min < -40 || $temp_min > 125 || $temp_max < -40 || $temp_max > 125) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Suhu harus antara -40°C sampai 125°C"]);
                exit;
            }

            if ($temp_min > $temp_max) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Suhu minimum tidak boleh lebih besar dari suhu maksimum"]);
                exit;
            }
            // =========================================================

            $stmt = $pdo->prepare("
                INSERT INTO profiles (name, coffee_type, target_ph, target_temp_min, target_temp_max, duration_minutes, created_at)
                VALUES (:name, :coffee_type, :target_ph, :target_temp_min, :target_temp_max, :duration_minutes, NOW())
            ");
            $stmt->execute([
                ':name' => $input['name'],
                ':coffee_type' => $input['coffee_type'],
                ':target_ph' => $target_ph,
                ':target_temp_min' => $temp_min,
                ':target_temp_max' => $temp_max,
                ':duration_minutes' => intval($input['duration_minutes'])
            ]);

            echo json_encode(["success" => true, "id" => $pdo->lastInsertId()]);
            exit;
        }

        if ($method === 'PUT') {
            $input = json_decode(file_get_contents("php://input"), true);
            $id = $input['id'] ?? null;
            if (!$id) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Missing ID"]);
                exit;
            }

            // =================== VALIDASI pH & SUHU ===================
            $target_ph = floatval($input['target_ph'] ?? 0);
            $temp_min = floatval($input['target_temp_min'] ?? 0);
            $temp_max = floatval($input['target_temp_max'] ?? 0);

            if ($target_ph < 0 || $target_ph > 14) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Target pH harus antara 0 - 14"]);
                exit;
            }

            if ($temp_min < -40 || $temp_min > 125 || $temp_max < -40 || $temp_max > 125) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Suhu harus antara -40°C sampai 125°C"]);
                exit;
            }

            if ($temp_min > $temp_max) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Suhu minimum tidak boleh lebih besar dari suhu maksimum"]);
                exit;
            }
            // =========================================================

            $stmt = $pdo->prepare("
                UPDATE profiles 
                SET name=:name, coffee_type=:coffee_type, target_ph=:target_ph, 
                    target_temp_min=:target_temp_min, target_temp_max=:target_temp_max, duration_minutes=:duration_minutes
                WHERE id=:id
            ");
            $stmt->execute([
                ':id' => intval($id),
                ':name' => $input['name'] ?? '',
                ':coffee_type' => $input['coffee_type'] ?? '',
                ':target_ph' => $target_ph,
                ':target_temp_min' => $temp_min,
                ':target_temp_max' => $temp_max,
                ':duration_minutes' => intval($input['duration_minutes'] ?? 0)
            ]);

            echo json_encode(["success" => true, "message" => "Profile updated", "affected" => $stmt->rowCount()]);
            exit;
        }

        if ($method === 'DELETE') {
            $id = $_GET['id'] ?? null;
            if (!$id) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Missing ID"]);
                exit;
            }

            $stmt = $pdo->prepare("DELETE FROM profiles WHERE id=:id");
            $stmt->execute([':id' => intval($id)]);
            echo json_encode(["success" => true, "deleted" => $stmt->rowCount()]);
            exit;
        }

        http_response_code(405);
        echo json_encode(["success" => false, "error" => "Method not allowed"]);
        exit;

    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
        exit;
    }
}

// ===================================================
// HISTORY HANDLER (unchanged)
// ===================================================
if ($type === 'history') {
    try {
        if ($method === 'GET') {
            $stmt = $pdo->query("SELECT * FROM fermentasi_history ORDER BY created_at DESC");
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            exit;
        }

        if ($method === 'POST') {
            $input = json_decode(file_get_contents("php://input"), true);
            $stmt = $pdo->prepare("
                INSERT INTO fermentasi_history 
                (name, coffee_type, target_ph, target_temp_min, target_temp_max, final_ph, final_temp_min, final_temp_max, start_time, end_time, status, reason, created_at)
                VALUES (:name, :coffee_type, :target_ph, :target_temp_min, :target_temp_max, :final_ph, :final_temp_min, :final_temp_max, :start_time, :end_time, :status, :reason, NOW())
            ");
            $stmt->execute([
                ':name' => $input['name'] ?? '',
                ':coffee_type' => $input['coffee_type'] ?? '',
                ':target_ph' => floatval($input['target_ph'] ?? 0),
                ':target_temp_min' => floatval($input['target_temp_min'] ?? 0),
                ':target_temp_max' => floatval($input['target_temp_max'] ?? 0),
                ':final_ph' => floatval($input['final_ph'] ?? 0),
                ':final_temp_min' => floatval($input['final_temp_min'] ?? 0),
                ':final_temp_max' => floatval($input['final_temp_max'] ?? 0),
                ':start_time' => $input['start_time'] ?? null,
                ':end_time' => $input['end_time'] ?? null,
                ':status' => $input['status'] ?? 'Unknown',
                ':reason' => $input['reason'] ?? ''
            ]);
            echo json_encode(["success" => true, "message" => "History saved"]);
            exit;
        }

        if ($method === 'DELETE') {
            $id = $_GET['id'] ?? null;
            if (!$id) {
                http_response_code(400);
                echo json_encode(["success" => false, "error" => "Missing ID"]);
                exit;
            }
            $stmt = $pdo->prepare("DELETE FROM fermentasi_history WHERE id=:id");
            $stmt->execute([':id' => intval($id)]);
            echo json_encode(["success" => true, "deleted" => $stmt->rowCount()]);
            exit;
        }

        http_response_code(405);
        echo json_encode(["success" => false, "error" => "Method not allowed"]);
        exit;
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
        exit;
    }
}

// ===================================================
// SENSOR HANDLER (InfluxDB) - unchanged but safer
// ===================================================
if ($type === 'sensor') {
    // NOTE: ensure these are strings
    $influx_host = "10.23.83.199";
    $influx_port = "8086";
    $influx_db   = "iot_data";
    $measurement = "phsensor";
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 20;

    $queryString = "SELECT * FROM $measurement ORDER BY time DESC LIMIT $limit";
    $query = urlencode($queryString);
    $url = "http://{$influx_host}:{$influx_port}/query?db={$influx_db}&q={$query}";

    $response = @file_get_contents($url);

    if ($response === false) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => "Failed to fetch from InfluxDB", "url" => $url]);
        exit;
    }

    $data = json_decode($response, true);
    $points = [];
    $columns = [];

    if (!empty($data['results'][0]['series'][0])) {
        $series = $data['results'][0]['series'][0];
        $points = $series['values'] ?? [];
        $columns = $series['columns'] ?? [];
    }

    $result = [];
    foreach ($points as $row) {
        if (count($columns) === count($row)) {
            $result[] = array_combine($columns, $row);
        } else {
            // fallback: push raw row
            $result[] = $row;
        }
    }

    echo json_encode(["success" => true, "count" => count($result), "data" => $result]);
    exit;
}

// ===================================================
// AUTH HANDLER: LOGIN & REGISTER
// ===================================================
if ($type === 'register') {
    try {
        $input = json_decode(file_get_contents("php://input"), true);

        $username = trim($input['username'] ?? '');
        $password = trim($input['password'] ?? '');
        $email = trim($input['email'] ?? '');

        if ($username === '' || $password === '') {
            echo json_encode(["success" => false, "error" => "Username dan password wajib diisi"]);
            exit;
        }

        // cek username sudah ada?
        $check = $pdo->prepare("SELECT id FROM users WHERE username = :username LIMIT 1");
        $check->execute([':username' => $username]);
        if ($check->fetch()) {
            echo json_encode(["success" => false, "error" => "Username sudah terdaftar"]);
            exit;
        }

        // hash password
        $hash = password_hash($password, PASSWORD_BCRYPT);

        // ubah query tanpa fullname
        $stmt = $pdo->prepare("INSERT INTO users (username, password, email, created_at) VALUES (:username, :password, :email, NOW())");
        $stmt->execute([
            ':username' => $username,
            ':password' => $hash,
            ':email' => $email
        ]);

        echo json_encode(["success" => true, "message" => "Registrasi berhasil"]);
        exit;

    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
        exit;
    }
}

if ($type === 'login') {
    try {
        $input = json_decode(file_get_contents("php://input"), true);
        $username = trim($input['username'] ?? '');
        $password = trim($input['password'] ?? '');

        if ($username === '' || $password === '') {
            echo json_encode(["success" => false, "error" => "Username dan password wajib diisi"]);
            exit;
        }

        $stmt = $pdo->prepare("SELECT id, username, password, email FROM users WHERE username = :username LIMIT 1");
        $stmt->execute([':username' => $username]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password'])) {
            echo json_encode(["success" => false, "error" => "Username atau password salah"]);
            exit;
        }

        // berhasil login
        echo json_encode([
            "success" => true,
            "message" => "Login berhasil",
            "user" => [
                "id" => $user['id'],
                "username" => $user['username'],
                "email" => $user['email']
            ]
        ]);
        exit;

    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $e->getMessage()]);
        exit;
    }
}

// INVALID TYPE
http_response_code(404);
echo json_encode(["success" => false, "error" => "Invalid endpoint or type parameter"]);
exit;
?>
