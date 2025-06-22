<?php
/*
Chat PHP para Apache - Estrutura de arquivos:

/var/www/html/chat/
├── index.php (este arquivo)
├── api.php (API para mensagens)
├── data/
│   ├── messages.json
│   └── users.json
└── .htaccess

Requisitos:
- Apache com mod_rewrite
- PHP 7.0+
- Permissões de escrita na pasta data/
*/

// index.php - Interface principal do chat
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chat Apache + PHP</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }

        .chat-container {
            width: 100%;
            max-width: 900px;
            height: 85vh;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.15);
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }

        .chat-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            text-align: center;
            position: relative;
        }

        .current-user {
            position: absolute;
            top: 20px;
            right: 20px;
            background: rgba(255,255,255,0.2);
            padding: 5px 15px;
            border-radius: 15px;
            font-size: 14px;
        }

        .user-setup {
            display: flex;
            gap: 10px;
            margin-top: 15px;
            justify-content: center;
        }

        .user-setup input, .user-setup button {
            padding: 8px 16px;
            border: none;
            border-radius: 20px;
            background: rgba(255,255,255,0.2);
            color: white;
            cursor: pointer;
        }

        .user-setup input::placeholder {
            color: rgba(255,255,255,0.7);
        }

        .status-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px 20px;
            background: #f8f9fa;
            border-bottom: 1px solid #e9ecef;
            font-size: 14px;
        }

        .connection-status {
            padding: 5px 10px;
            border-radius: 15px;
            font-size: 12px;
        }

        .online { background: #d4edda; color: #155724; }
        .offline { background: #f8d7da; color: #721c24; }

        .users-online {
            display: flex;
            gap: 5px;
            flex-wrap: wrap;
        }

        .user-badge {
            background: #e9ecef;
            padding: 2px 8px;
            border-radius: 10px;
            font-size: 12px;
        }

        .messages-container {
            flex: 1;
            padding: 20px;
            overflow-y: auto;
            background: #f8f9fa;
        }

        .message {
            margin-bottom: 15px;
            padding: 12px 16px;
            border-radius: 18px;
            max-width: 70%;
            word-wrap: break-word;
            animation: fadeIn 0.3s ease-in;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .message.own {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            margin-left: auto;
            border-bottom-right-radius: 5px;
        }

        .message.other {
            background: white;
            border: 1px solid #e9ecef;
            margin-right: auto;
            border-bottom-left-radius: 5px;
        }

        .message.system {
            background: #28a745;
            color: white;
            margin: 10px auto;
            text-align: center;
            max-width: 80%;
        }

        .message-header {
            font-size: 12px;
            opacity: 0.7;
            margin-bottom: 5px;
            font-weight: 500;
        }

        .message-text {
            font-size: 14px;
            line-height: 1.4;
        }

        .input-container {
            padding: 20px;
            background: white;
            border-top: 1px solid #e9ecef;
            display: flex;
            gap: 10px;
            align-items: center;
        }

        .message-input {
            flex: 1;
            padding: 12px 16px;
            border: 1px solid #e9ecef;
            border-radius: 25px;
            outline: none;
            font-size: 14px;
        }

        .message-input:focus {
            border-color: #667eea;
        }

        .send-button {
            padding: 12px 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 25px;
            cursor: pointer;
            font-weight: 500;
        }

        .send-button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .error {
            color: #dc3545;
            text-align: center;
            margin: 10px 0;
            font-size: 14px;
        }

        .hidden {
            display: none;
        }

        .controls {
            display: flex;
            gap: 10px;
            margin-top: 10px;
            justify-content: center;
        }

        .control-button {
            padding: 6px 12px;
            background: rgba(255,255,255,0.2);
            color: white;
            border: none;
            border-radius: 15px;
            cursor: pointer;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="chat-container">
        <div class="chat-header">
            <h1>💬 Chat Apache + PHP</h1>
            <div class="current-user hidden" id="currentUser">Usuário: <span></span></div>
            
            <div class="user-setup">
                <input type="text" id="usernameInput" placeholder="Digite seu nome..." maxlength="20">
                <button onclick="joinChat()">Entrar</button>
            </div>
            
            <div class="controls">
                <button class="control-button" onclick="clearMessages()">🗑️ Limpar</button>
                <button class="control-button" onclick="exportChat()">💾 Exportar</button>
                <button class="control-button" onclick="refreshChat()">🔄 Atualizar</button>
            </div>
        </div>
        
        <div class="status-bar">
            <span id="connectionStatus" class="connection-status offline">Carregando...</span>
            <div>
                <span id="userCount">0 usuários online</span>
                <div class="users-online" id="onlineUsers"></div>
            </div>
        </div>

        <div class="messages-container" id="messagesContainer">
            <div class="message system">
                <div class="message-text">🎉 Bem-vindo ao chat! Digite seu nome acima para começar.</div>
            </div>
        </div>

        <div class="input-container">
            <input type="text" id="messageInput" class="message-input" 
                   placeholder="Digite sua mensagem..." 
                   onkeypress="handleKeyPress(event)"
                   disabled>
            <button id="sendButton" class="send-button" onclick="sendMessage()" disabled>
                Enviar
            </button>
        </div>
    </div>

    <script>
        let currentUser = null;
        let lastMessageId = 0;
        let pollInterval = null;
        let isOnline = false;

        // Configurações
        const POLL_INTERVAL = 2000; // 2 segundos
        const API_BASE = 'api.php';

        // Inicialização
        window.addEventListener('load', () => {
            loadMessages();
            startPolling();
        });

        // Polling para novas mensagens
        function startPolling() {
            if (pollInterval) clearInterval(pollInterval);
            
            pollInterval = setInterval(() => {
                if (currentUser) {
                    checkNewMessages();
                    updateUserPresence();
                }
                updateUsers();
            }, POLL_INTERVAL);
        }

        // Atualiza presença do usuário
        function updateUserPresence() {
            if (!currentUser) return;
            
            fetch(API_BASE, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    action: 'update_presence',
                    user: currentUser
                })
            }).catch(console.error);
        }

        // Verifica novas mensagens
        function checkNewMessages() {
            fetch(`${API_BASE}?action=get_messages&since=${lastMessageId}`)
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.messages.length > 0) {
                        data.messages.forEach(message => {
                            if (message.id > lastMessageId) {
                                renderMessage(message);
                                lastMessageId = message.id;
                            }
                        });
                        scrollToBottom();
                    }
                    setConnectionStatus(true);
                })
                .catch(error => {
                    console.error('Erro ao buscar mensagens:', error);
                    setConnectionStatus(false);
                });
        }

        // Carrega mensagens iniciais
        function loadMessages() {
            fetch(`${API_BASE}?action=get_messages`)
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const container = document.getElementById('messagesContainer');
                        container.innerHTML = '';
                        
                        if (data.messages.length === 0) {
                            container.innerHTML = '<div class="message system"><div class="message-text">🎉 Seja o primeiro a enviar uma mensagem!</div></div>';
                        } else {
                            data.messages.forEach(renderMessage);
                            lastMessageId = Math.max(...data.messages.map(m => m.id));
                        }
                        scrollToBottom();
                    }
                    setConnectionStatus(true);
                })
                .catch(error => {
                    console.error('Erro ao carregar mensagens:', error);
                    setConnectionStatus(false);
                });
        }

        // Atualiza lista de usuários
        function updateUsers() {
            fetch(`${API_BASE}?action=get_users`)
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        updateOnlineUsers(data.users);
                    }
                })
                .catch(console.error);
        }

        // Entra no chat
        function joinChat() {
            const input = document.getElementById('usernameInput');
            const username = input.value.trim();
            
            if (!username) {
                showError('Digite um nome válido');
                return;
            }

            fetch(API_BASE, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    action: 'join',
                    user: username
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    currentUser = username;
                    document.getElementById('currentUser').classList.remove('hidden');
                    document.getElementById('currentUser').querySelector('span').textContent = username;
                    document.getElementById('messageInput').disabled = false;
                    document.getElementById('sendButton').disabled = false;
                    document.getElementById('messageInput').placeholder = `${username}, digite sua mensagem...`;
                    document.getElementById('messageInput').focus();
                    input.value = '';
                    
                    // Adiciona mensagem de entrada
                    sendSystemMessage(`👋 ${username} entrou no chat!`);
                } else {
                    showError(data.error || 'Erro ao entrar no chat');
                }
            })
            .catch(error => {
                console.error('Erro ao entrar:', error);
                showError('Erro de conexão');
            });
        }

        // Envia mensagem
        function sendMessage() {
            const input = document.getElementById('messageInput');
            const text = input.value.trim();
            
            if (!text || !currentUser) return;

            fetch(API_BASE, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    action: 'send_message',
                    user: currentUser,
                    message: text
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    input.value = '';
                    input.focus();
                } else {
                    showError(data.error || 'Erro ao enviar mensagem');
                }
            })
            .catch(error => {
                console.error('Erro ao enviar:', error);
                showError('Erro de conexão');
            });
        }

        // Envia mensagem do sistema
        function sendSystemMessage(text) {
            fetch(API_BASE, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    action: 'system_message',
                    message: text
                })
            }).catch(console.error);
        }

        // Renderiza mensagem
        function renderMessage(message) {
            const container = document.getElementById('messagesContainer');
            const messageEl = document.createElement('div');
            
            const isOwn = message.user === currentUser;
            const isSystem = message.type === 'system';
            
            messageEl.className = `message ${isOwn && !isSystem ? 'own' : isSystem ? 'system' : 'other'}`;
            
            const time = new Date(message.timestamp).toLocaleTimeString('pt-BR', {
                hour: '2-digit',
                minute: '2-digit'
            });
            
            if (isSystem) {
                messageEl.innerHTML = `<div class="message-text">${escapeHtml(message.message)}</div>`;
            } else {
                messageEl.innerHTML = `
                    <div class="message-header">${escapeHtml(message.user)} • ${time}</div>
                    <div class="message-text">${escapeHtml(message.message)}</div>
                `;
            }
            
            container.appendChild(messageEl);
        }

        // Funções utilitárias
        function scrollToBottom() {
            const container = document.getElementById('messagesContainer');
            container.scrollTop = container.scrollHeight;
        }

        function setConnectionStatus(online) {
            const status = document.getElementById('connectionStatus');
            isOnline = online;
            status.textContent = online ? 'Online' : 'Offline';
            status.className = `connection-status ${online ? 'online' : 'offline'}`;
        }

        function updateOnlineUsers(users) {
            const container = document.getElementById('onlineUsers');
            const count = document.getElementById('userCount');
            
            count.textContent = `${users.length} usuários online`;
            container.innerHTML = '';
            
            users.forEach(user => {
                const badge = document.createElement('span');
                badge.className = 'user-badge';
                badge.textContent = user;
                container.appendChild(badge);
            });
        }

        function showError(message) {
            // Criar elemento de erro temporário
            const errorEl = document.createElement('div');
            errorEl.className = 'error';
            errorEl.textContent = message;
            
            const container = document.querySelector('.input-container');
            container.appendChild(errorEl);
            
            setTimeout(() => {
                errorEl.remove();
            }, 3000);
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function handleKeyPress(event) {
            if (event.key === 'Enter') {
                sendMessage();
            }
        }

        function clearMessages() {
            if (confirm('Tem certeza que deseja limpar todas as mensagens?')) {
                fetch(API_BASE, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({action: 'clear_messages'})
                })
                .then(() => loadMessages())
                .catch(console.error);
            }
        }

        function exportChat() {
            fetch(`${API_BASE}?action=export`)
                .then(response => response.blob())
                .then(blob => {
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = `chat_export_${new Date().toISOString().split('T')[0]}.txt`;
                    a.click();
                    URL.revokeObjectURL(url);
                })
                .catch(console.error);
        }

        function refreshChat() {
            loadMessages();
            updateUsers();
        }

        // Cleanup ao sair da página
        window.addEventListener('beforeunload', () => {
            if (currentUser) {
                navigator.sendBeacon(API_BASE, JSON.stringify({
                    action: 'leave',
                    user: currentUser
                }));
            }
        });
    </script>
</body>
</html>
