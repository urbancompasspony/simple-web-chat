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

# ===== COMANDOS DE GERENCIAMENTO =====

# Status do container
docker ps -f name=chat-apache

# Logs do container
docker logs -f chat-apache

# Shell no container
docker exec -it chat-apache bash

# Parar container
docker stop chat-apache

# Iniciar container
docker start chat-apache

# Reiniciar container
docker restart chat-apache

# Remover container
docker rm chat-apache

# ===== COMANDOS DE BACKUP =====

# Criar backup
docker exec chat-apache tar -czf /tmp/backup.tar.gz -C /var/www/html/chat data/
docker cp chat-apache:/tmp/backup.tar.gz ./chat_backup_$(date +%Y%m%d).tar.gz
docker exec chat-apache rm /tmp/backup.tar.gz

# Restaurar backup
docker cp ./chat_backup.tar.gz chat-apache:/tmp/
docker exec chat-apache tar -xzf /tmp/backup.tar.gz -C /var/www/html/chat/
docker exec chat-apache chown -R www-data:www-data /var/www/html/chat/data

# ===== COMANDOS DE MONITORAMENTO =====

# Ver uso de recursos
docker stats chat-apache

# Ver informações do container
docker inspect chat-apache

# Ver logs de erro
docker logs chat-apache 2>&1 | grep ERROR

# Verificar saúde
docker inspect chat-apache --format='{{.State.Health.Status}}'

# ===== COMANDOS DE LIMPEZA =====

# Remover tudo do chat
docker stop chat-apache
docker rm chat-apache
docker rmi chat-apache-php
docker volume rm chat_data
docker network rm chat_network

# Limpeza geral do Docker
docker system prune -f
docker volume prune -f
docker image prune -f

# ===== DEPLOY EM UMA LINHA =====

# Deploy completo (para por existente, build e start novo)
docker stop chat-apache 2>/dev/null || true && \
docker rm chat-apache 2>/dev/null || true && \
docker build -t chat-apache-php . && \
docker run -d --name chat-apache --restart unless-stopped -p 8080:80 -v chat_data:/var/www/html/chat/data chat-apache-php && \
echo "✅ Chat disponível em: http://localhost:8080/chat/"

# ===== COMANDOS ÚTEIS =====

# Ver arquivos de dados
docker exec chat-apache ls -la /var/www/html/chat/data/

# Ver configuração Apache
docker exec chat-apache apache2ctl -S

# Ver módulos Apache habilitados
docker exec chat-apache apache2ctl -M

# Testar configuração
docker exec chat-apache apache2ctl configtest

# Ver processos no container
docker exec chat-apache ps aux

# Ver espaço em disco
docker exec chat-apache df -h

# ===== DESENVOLVIMENTO =====

# Mount do código para desenvolvimento (sem rebuild)
docker run -d \
  --name chat-apache-dev \
  -p 8080:80 \
  -v $(pwd):/var/www/html/chat \
  -v chat_data:/var/www/html/chat/data \
  chat-apache-php

# Rebuild apenas se código mudou
docker build --no-cache -t chat-apache-php .

# Copiar arquivo para container
docker cp index.php chat-apache:/var/www/html/chat/

# Copiar arquivo do container
docker cp chat-apache:/var/www/html/chat/data/messages.json ./

# ===== TROUBLESHOOTING =====

# Se container não inicia
docker logs chat-apache
docker run --rm -it chat-apache-php bash  # Debug mode

# Se porta já estiver em uso
docker run -d --name chat-apache -p 8081:80 -v chat_data:/var/www/html/chat/data chat-apache-php

# Se volume não funcionar
docker volume inspect chat_data
docker exec chat-apache ls -la /var/www/html/chat/data/

# Se permissões estiverem erradas
docker exec chat-apache chown -R www-data:www-data /var/www/html/chat/
docker exec chat-apache chmod 755 /var/www/html/chat/data/

# ===== MÚLTIPLAS INSTÂNCIAS =====

# Chat 1 na porta 8080
docker run -d --name chat1 -p 8080:80 -v chat1_data:/var/www/html/chat/data chat-apache-php

# Chat 2 na porta 8081  
docker run -d --name chat2 -p 8081:80 -v chat2_data:/var/www/html/chat/data chat-apache-php

# Chat 3 na porta 8082
docker run -d --name chat3 -p 8082:80 -v chat3_data:/var/www/html/chat/data chat-apache-php

# Torna executável e roda
chmod +x quick-deploy.sh
./quick-deploy.sh

# Acessa o chat
http://localhost:8080/chat/

# Modo interativo
chmod +x chat-manager.sh
./chat-manager.sh

# Ou comandos diretos
./chat-manager.sh deploy
./chat-manager.sh status
./chat-manager.sh logs

# Deploy completo
chmod +x docker-deploy.sh
./docker-deploy.sh deploy

# Comandos específicos
./docker-deploy.sh build
./docker-deploy.sh start
./docker-deploy.sh backup

# Deploy em uma linha
docker stop chat-apache 2>/dev/null || true && \
docker rm chat-apache 2>/dev/null || true && \
docker build -t chat-apache-php . && \
docker run -d --name chat-apache --restart unless-stopped -p 8080:80 -v chat_data:/var/www/html/chat/data chat-apache-php

# Acesso
curl http://localhost:8080/chat/

./quick-deploy.sh                    # Mais rápido
./chat-manager.sh deploy            # Com menu
docker build -t chat . && docker run -d --name chat -p 8080:80 chat  # Manual

docker logs -f chat-apache          # Ver logs
docker exec -it chat-apache bash    # Shell
docker restart chat-apache          # Restart
docker stop chat-apache             # Parar

./chat-manager.sh backup            # Backup via script
docker exec chat-apache tar -czf /tmp/backup.tar.gz -C /var/www/html/chat data/  # Manual
