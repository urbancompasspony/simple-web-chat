# ===== COMANDOS DOCKER CLI PARA CHAT =====

chat-project/
├── index.php           # Interface do chat
├── api.php            # API backend
├── .htaccess          # Configuração Apache
├── Dockerfile         # Criado automaticamente
├── quick-deploy.sh    # Deploy rápido ⭐
├── chat-manager.sh    # Gerenciador completo ⭐  
├── docker-deploy.sh   # Deploy avançado
└── backups/           # Pasta de backups

# 1. BUILD DA IMAGEM
docker build -t chat-apache-php .

# 2. CRIAR VOLUME PARA DADOS
docker volume create chat_data

# 3. CRIAR REDE (OPCIONAL)
docker network create chat_network

# 4. EXECUTAR CONTAINER
docker run -d \
  --name chat-apache \
  --restart unless-stopped \
  -p 8080:80 \
  -v chat_data:/var/www/html/chat/data \
  --health-cmd="curl -f http://localhost/chat/ || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  chat-apache-php


./chat-manager.sh backup            # Backup via script
docker exec chat-apache tar -czf /tmp/backup.tar.gz -C /var/www/html/chat data/  # Manual
