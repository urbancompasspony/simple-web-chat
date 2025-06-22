<?php
/*
api.php - API Backend para o Chat PHP
Coloque este arquivo na mesma pasta do index.php
*/

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Configurações
define('DATA_DIR', __DIR__ . '/data');
define('MESSAGES_FILE', DATA_DIR . '/messages.json');
define('USERS_FILE', DATA_DIR . '/users.json');
define('LOCK_FILE', DATA_DIR . '/.lock');
define('USER_TIMEOUT', 30); // segundos para considerar usuário offline

// Cria diretório de dados se não existir
if (!is_dir(DATA_DIR)) {
    mkdir(DATA_DIR, 0755, true);
}

// Inicializa arquivos se não existirem
if (!file_exists(MESSAGES_FILE)) {
    file_put_contents(MESSAGES_FILE, json_encode(['messages' => []]));
}

if (!file_exists(USERS_FILE)) {
    file_put_contents(USERS_FILE, json_encode(['users' => []]));
}

// Função para lock de arquivo
function withLock($callback) {
    $lockHandle = fopen(LOCK_FILE, 'w');
    if (!$lockHandle) {
        return ['success' => false, 'error' => 'Erro interno'];
    }
    
    if (flock($lockHandle, LOCK_EX)) {
        $result = $callback();
        flock($lockHandle, LOCK_UN);
    } else {
        $result = ['success' => false, 'error' => 'Erro de concorrência'];
    }
    
    fclose($lockHandle);
    return $result;
}

// Função para ler dados JSON
function readJsonFile($file) {
    if (!file_exists($file)) {
        return [];
    }
    
    $content = file_get_contents($file);
    $data = json_decode($content, true);
    
    return $data ?: [];
}

// Função para escrever dados JSON
function writeJsonFile($file, $data) {
    return file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

// Função para limpar usuários inativos
function cleanupUsers() {
    $users = readJsonFile(USERS_FILE);
    if (!isset($users['users'])) {
        $users['users'] = [];
    }
    
    $now = time();
    $activeUsers = [];
    
    foreach ($users['users'] as $user) {
        if (isset($user['last_seen']) && ($now - strtotime($user['last_seen'])) < USER_TIMEOUT) {
            $activeUsers[] = $user;
        }
    }
    
    $users['users'] = $activeUsers;
    writeJsonFile(USERS_FILE, $users);
    
    return array_column($activeUsers, 'name');
}

// Manipula requisições
$method = $_SERVER['REQUEST_METHOD'];
$action = '';

if ($method === 'GET') {
    $action = $_GET['action'] ?? '';
} else if ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';
}

switch ($action) {
    case 'get_messages':
        $since = intval($_GET['since'] ?? 0);
        $messages = readJsonFile(MESSAGES_FILE);
        
        if (!isset($messages['messages'])) {
            $messages['messages'] = [];
        }
        
        // Filtra mensagens por ID se especificado
        if ($since > 0) {
            $messages['messages'] = array_filter($messages['messages'], function($msg) use ($since) {
                return intval($msg['id']) > $since;
            });
        }
        
        // Limita a 50 mensagens mais recentes
        $messages['messages'] = array_slice($messages['messages'], -50);
        
        echo json_encode([
            'success' => true,
            'messages' => array_values($messages['messages'])
        ]);
        break;
        
    case 'send_message':
        $result = withLock(function() use ($input) {
            $user = trim($input['user'] ?? '');
            $message = trim($input['message'] ?? '');
            
            if (empty($user) || empty($message)) {
                return ['success' => false, 'error' => 'Usuário ou mensagem inválidos'];
            }
            
            if (strlen($message) > 1000) {
                return ['success' => false, 'error' => 'Mensagem muito longa'];
            }
            
            $messages = readJsonFile(MESSAGES_FILE);
            if (!isset($messages['messages'])) {
                $messages['messages'] = [];
            }
            
            $newMessage = [
                'id' => time() . mt_rand(1000, 9999),
                'user' => $user,
                'message' => $message,
                'timestamp' => date('c'),
                'type' => 'user'
            ];
            
            $messages['messages'][] = $newMessage;
            
            // Limita a 1000 mensagens
            if (count($messages['messages']) > 1000) {
                $messages['messages'] = array_slice($messages['messages'], -1000);
            }
            
            if (writeJsonFile(MESSAGES_FILE, $messages)) {
                return ['success' => true, 'message' => $newMessage];
            } else {
                return ['success' => false, 'error' => 'Erro ao salvar mensagem'];
            }
        });
        
        echo json_encode($result);
        break;
        
    case 'system_message':
        $result = withLock(function() use ($input) {
            $message = trim($input['message'] ?? '');
            
            if (empty($message)) {
                return ['success' => false, 'error' => 'Mensagem inválida'];
            }
            
            $messages = readJsonFile(MESSAGES_FILE);
            if (!isset($messages['messages'])) {
                $messages['messages'] = [];
            }
            
            $newMessage = [
                'id' => time() . mt_rand(1000, 9999),
                'user' => 'Sistema',
                'message' => $message,
                'timestamp' => date('c'),
                'type' => 'system'
            ];
            
            $messages['messages'][] = $newMessage;
            
            if (writeJsonFile(MESSAGES_FILE, $messages)) {
                return ['success' => true];
            } else {
                return ['success' => false, 'error' => 'Erro ao salvar mensagem'];
            }
        });
        
        echo json_encode($result);
        break;
        
    case 'join':
        $result = withLock(function() use ($input) {
            $user = trim($input['user'] ?? '');
            
            if (empty($user) || strlen($user) > 20) {
                return ['success' => false, 'error' => 'Nome de usuário inválido'];
            }
            
            $users = readJsonFile(USERS_FILE);
            if (!isset($users['users'])) {
                $users['users'] = [];
            }
            
            // Verifica se usuário já existe
            foreach ($users['users'] as $existingUser) {
                if ($existingUser['name'] === $user) {
                    return ['success' => false, 'error' => 'Nome já está em uso'];
                }
            }
            
            // Adiciona usuário
            $users['users'][] = [
                'name' => $user,
                'joined_at' => date('c'),
                'last_seen' => date('c')
            ];
            
            if (writeJsonFile(USERS_FILE, $users)) {
                return ['success' => true];
            } else {
                return ['success' => false, 'error' => 'Erro ao registrar usuário'];
            }
        });
        
        echo json_encode($result);
        break;
        
    case 'update_presence':
        $result = withLock(function() use ($input) {
            $user = trim($input['user'] ?? '');
            
            if (empty($user)) {
                return ['success' => false];
            }
            
            $users = readJsonFile(USERS_FILE);
            if (!isset($users['users'])) {
                $users['users'] = [];
            }
            
            // Atualiza último acesso do usuário
            $found = false;
            foreach ($users['users'] as &$existingUser) {
                if ($existingUser['name'] === $user) {
                    $existingUser['last_seen'] = date('c');
                    $found = true;
                    break;
                }
            }
            
            // Se não encontrou, adiciona
            if (!$found) {
                $users['users'][] = [
                    'name' => $user,
                    'joined_at' => date('c'),
                    'last_seen' => date('c')
                ];
            }
            
            writeJsonFile(USERS_FILE, $users);
            return ['success' => true];
        });
        
        echo json_encode($result);
        break;
        
    case 'get_users':
        $activeUsers = cleanupUsers();
        echo json_encode([
            'success' => true,
            'users' => $activeUsers
        ]);
        break;
        
    case 'leave':
        $result = withLock(function() use ($input) {
            $user = trim($input['user'] ?? '');
            
            if (empty($user)) {
                return ['success' => false];
            }
            
            $users = readJsonFile(USERS_FILE);
            if (!isset($users['users'])) {
                $users['users'] = [];
            }
            
            // Remove usuário
            $users['users'] = array_filter($users['users'], function($u) use ($user) {
                return $u['name'] !== $user;
            });
            
            writeJsonFile(USERS_FILE, $users);
            return ['success' => true];
        });
        
        echo json_encode($result);
        break;
        
    case 'clear_messages':
        $result = withLock(function() {
            $cleared = writeJsonFile(MESSAGES_FILE, ['messages' => []]);
            return ['success' => $cleared];
        });
        
        echo json_encode($result);
        break;
        
    case 'export':
        $messages = readJsonFile(MESSAGES_FILE);
        
        if (!isset($messages['messages'])) {
            $messages['messages'] = [];
        }
        
        header('Content-Type: text/plain; charset=utf-8');
        header('Content-Disposition: attachment; filename="chat_export_' . date('Y-m-d') . '.txt"');
        
        echo "=== Exportação do Chat - " . date('d/m/Y H:i:s') . " ===\n\n";
        
        foreach ($messages['messages'] as $msg) {
            $time = date('d/m/Y H:i:s', strtotime($msg['timestamp']));
            echo "[{$time}] {$msg['user']}: {$msg['message']}\n";
        }
        break;
        
    default:
        echo json_encode(['success' => false, 'error' => 'Ação não reconhecida']);
        break;
}
?>
