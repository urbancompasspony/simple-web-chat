<?php
// index.php - Interface principal do chat
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chat Apache + PHP</title>
    <link rel="stylesheet" href="style.css">
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
    
    <script src="script.js"></script>
    
</body>
</html>
