<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

include 'config.php';

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'POST':
        $input = json_decode(file_get_contents("php://input"), true);

        if (isset($_GET['action']) && $_GET['action'] === 'register') {
            // REGISTER
            $username = $input['username'] ?? '';
            $email = $input['email'] ?? '';
            $password = $input['password'] ?? '';

            if (empty($username) || empty($email) || empty($password)) {
                echo json_encode(['success' => false, 'message' => 'Lengkapi semua field']);
                exit;
            }

            $hashed = password_hash($password, PASSWORD_BCRYPT);

            $stmt = $conn->prepare("INSERT INTO users (username, email, password) VALUES (?, ?, ?)");
            $stmt->bind_param("sss", $username, $email, $hashed);

            if ($stmt->execute()) {
                echo json_encode(['success' => true, 'message' => 'Registrasi berhasil']);
            } else {
                echo json_encode(['success' => false, 'message' => 'Username/email sudah digunakan']);
            }
            $stmt->close();

        } elseif (isset($_GET['action']) && $_GET['action'] === 'login') {
            // LOGIN
            $username = $input['username'] ?? '';
            $password = $input['password'] ?? '';

            $stmt = $conn->prepare("SELECT * FROM users WHERE username = ?");
            $stmt->bind_param("s", $username);
            $stmt->execute();
            $result = $stmt->get_result();
            $user = $result->fetch_assoc();

            if ($user && password_verify($password, $user['password'])) {
                echo json_encode([
                    'success' => true,
                    'message' => 'Login berhasil',
                    'user' => [
                        'id' => $user['id'],
                        'username' => $user['username'],
                        'email' => $user['email']
                    ]
                ]);
            } else {
                echo json_encode(['success' => false, 'message' => 'Username atau password salah']);
            }

            $stmt->close();

        } else {
            echo json_encode(['success' => false, 'message' => 'Aksi tidak dikenali']);
        }
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Metode tidak diizinkan']);
        break;
}

$conn->close();
?>
