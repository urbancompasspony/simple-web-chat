# simple-web-chat
it is really simple!

# Criar pasta do projeto
mkdir chat-docker && cd chat-docker

# Copiar todos os arquivos criados:
# - Dockerfile
# - docker-compose.yml
# - apache-chat.conf
# - docker-entrypoint.sh
# - index.php
# - api.php
# - .htaccess
# - deploy.sh

# Dar permissões
chmod +x deploy.sh docker-entrypoint.sh

# Opção 1: Deploy automático
./deploy.sh deploy

# Opção 2: Deploy manual
docker compose build --no-cache
docker compose up -d

# Ver status
docker compose ps

# Ver logs em tempo real
docker compose logs -f chat-apache

# Entrar no container
docker compose exec chat-apache bash

# Restart do serviço
docker compose restart chat-apache

# Parar tudo
docker compose down

# Parar e remover volumes
docker compose down -v

# Local
http://localhost:8080/chat/

# Rede (substitua pelo IP da máquina)
http://192.168.1.100:8080/chat/

# Backup manual
./backup.sh

# Backup automático via container
docker compose exec chat-backup sh

# Restore (se necessário)
docker compose cp backup.tar.gz chat-apache:/tmp/
docker compose exec chat-apache tar -xzf /tmp/backup.tar.gz -C /var/www/html/chat/

# Ver uso de recursos
docker stats

# Ver logs específicos
docker compose logs chat-apache | grep ERROR

# Verificar saúde
docker compose exec chat-apache curl -f http://localhost/chat/
