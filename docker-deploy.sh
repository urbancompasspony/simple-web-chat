#!/bin/bash
# docker-deploy.sh - Deploy via Docker CLI sem docker-compose

set -e

# Configurações
IMAGE_NAME="chat-apache-php"
CONTAINER_NAME="chat-apache"
HOST_PORT="8080"
CONTAINER_PORT="80"
DATA_VOLUME="chat_data"
LOGS_DIR="$(pwd)/logs"
BACKUPS_DIR="$(pwd)/backups"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}" >&2; }

# Banner
echo -e "${BLUE}"
cat << "EOF"
 ____   ___   ____ _  __ _____ ____     ____ _     ___ 
|  _ \ / _ \ / ___| |/ /| ____|  _ \   / ___| |   |_ _|
| | | | | | | |   | ' / |  _| | |_) | | |   | |    | | 
| |_| | |_| | |___| . \ | |___|  _ <  | |___| |___ | | 
|____/ \___/ \____|_|\_\|_____|_| \_\  \____|_____|___|
                                                       
EOF
echo -e "${NC}"

# Verifica Docker
check_docker() {
    log "🔍 Verificando Docker..."
    if ! command -v docker &> /dev/null; then
        error "Docker não está instalado!"
        echo "Instale: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker não está rodando!"
        echo "Inicie o Docker daemon"
        exit 1
    fi
    
    success "Docker OK"
}

# Cria estrutura de diretórios
setup_directories() {
    log "📁 Criando diretórios..."
    mkdir -p "$LOGS_DIR" "$BACKUPS_DIR"
    success "Diretórios criados"
}

# Cria rede Docker
create_network() {
    log "🌐 Criando rede Docker..."
    if ! docker network ls | grep -q "chat_network"; then
        docker network create \
            --driver bridge \
            --subnet=172.20.0.0/16 \
            --ip-range=172.20.240.0/20 \
            chat_network
        success "Rede chat_network criada"
    else
        log "Rede chat_network já existe"
    fi
}

# Cria volume para dados
create_volume() {
    log "💾 Criando volume de dados..."
    if ! docker volume ls | grep -q "$DATA_VOLUME"; then
        docker volume create "$DATA_VOLUME"
        success "Volume $DATA_VOLUME criado"
    else
        log "Volume $DATA_VOLUME já existe"
    fi
}

# Build da imagem
build_image() {
    log "🔨 Fazendo build da imagem..."
    
    # Verifica se Dockerfile existe
    if [ ! -f "Dockerfile" ]; then
        error "Dockerfile não encontrado!"
        create_dockerfile
    fi
    
    docker build \
        --tag "$IMAGE_NAME:latest" \
        --label "version=$(date +%Y%m%d_%H%M%S)" \
        --label "description=Chat Apache PHP" \
        .
    
    success "Build da imagem concluído"
}

# Cria Dockerfile se não existir
create_dockerfile() {
    log "📝 Criando Dockerfile..."
    cat > Dockerfile << 'EOF'
FROM php:8.2-apache

# Labels
LABEL maintainer="chat-app"
LABEL description="Chat PHP com Apache2"

# Instala dependências
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip nano curl \
    && docker-php-ext-install zip \
    && rm -rf /var/lib/apt/lists/*

# Habilita módulos Apache
RUN a2enmod rewrite headers deflate expires

# Cria estrutura
RUN mkdir -p /var/www/html/chat/data

# Copia arquivos
COPY . /var/www/html/chat/

# Permissões
RUN chown -R www-data:www-data /var/www/html/chat && \
    chmod 755 /var/www/html/chat && \
    chmod 644 /var/www/html/chat/*.php && \
    chmod 755 /var/www/html/chat/data

# Configuração Apache
RUN echo '<VirtualHost *:80>' > /etc/apache2/sites-available/chat.conf && \
    echo 'DocumentRoot /var/www/html/chat' >> /etc/apache2/sites-available/chat.conf && \
    echo '<Directory /var/www/html/chat>' >> /etc/apache2/sites-available/chat.conf && \
    echo 'AllowOverride All' >> /etc/apache2/sites-available/chat.conf && \
    echo 'Require all granted' >> /etc/apache2/sites-available/chat.conf && \
    echo '</Directory>' >> /etc/apache2/sites-available/chat.conf && \
    echo '</VirtualHost>' >> /etc/apache2/sites-available/chat.conf && \
    a2ensite chat && a2dissite 000-default

# Configuração PHP
RUN echo 'max_execution_time = 30' >> /usr/local/etc/php/conf.d/chat.ini && \
    echo 'memory_limit = 128M' >> /usr/local/etc/php/conf.d/chat.ini

EXPOSE 80
CMD ["apache2-foreground"]
EOF
    success "Dockerfile criado"
}

# Para container existente
stop_container() {
    log "⏹️  Parando container existente..."
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker stop "$CONTAINER_NAME"
        success "Container parado"
    fi
    
    if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        docker rm "$CONTAINER_NAME"
        success "Container removido"
    fi
}

# Inicia novo container
start_container() {
    log "🚀 Iniciando container..."
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        --network chat_network \
        --ip 172.20.0.10 \
        --restart unless-stopped \
        --publish "$HOST_PORT:$CONTAINER_PORT" \
        --volume "$DATA_VOLUME:/var/www/html/chat/data" \
        --volume "$LOGS_DIR:/var/log/apache2" \
        --env APACHE_RUN_USER=www-data \
        --env APACHE_RUN_GROUP=www-data \
        --env APACHE_LOG_DIR=/var/log/apache2 \
        --label "app=chat" \
        --label "version=latest" \
        --health-cmd="curl -f http://localhost/chat/ || exit 1" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=3 \
        "$IMAGE_NAME:latest"
    
    success "Container iniciado"
}

# Verifica saúde do container
check_health() {
    log "🏥 Verificando saúde do container..."
    
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            success "Container está saudável!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        retries=$((retries + 1))
    done
    
    warning "Timeout na verificação, mas container pode estar funcionando"
    return 1
}

# Mostra status
show_status() {
    log "📊 Status do container:"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -1
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$CONTAINER_NAME"
        
        echo ""
        log "📈 Uso de recursos:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" "$CONTAINER_NAME"
        
        echo ""
        log "🌐 Acessos:"
        echo "   Local: http://localhost:$HOST_PORT/chat/"
        echo "   Rede:  http://$(hostname -I | cut -d' ' -f1):$HOST_PORT/chat/"
        
        echo ""
        log "📋 Comandos úteis:"
        echo "   Logs:     docker logs -f $CONTAINER_NAME"
        echo "   Shell:    docker exec -it $CONTAINER_NAME bash"
        echo "   Restart:  docker restart $CONTAINER_NAME"
        echo "   Stop:     docker stop $CONTAINER_NAME"
    else
        warning "Container não está rodando"
    fi
}

# Backup manual
backup_data() {
    log "💾 Criando backup..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUPS_DIR/chat_backup_$timestamp.tar.gz"
    
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker exec "$CONTAINER_NAME" tar -czf /tmp/backup.tar.gz -C /var/www/html/chat data/
        docker cp "$CONTAINER_NAME:/tmp/backup.tar.gz" "$backup_file"
        docker exec "$CONTAINER_NAME" rm /tmp/backup.tar.gz
        
        success "Backup criado: $backup_file"
    else
        error "Container não está rodando"
    fi
}

# Restore backup
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        error "Arquivo de backup não encontrado: $backup_file"
        echo "Uso: $0 restore /caminho/para/backup.tar.gz"
        return 1
    fi
    
    log "🔄 Restaurando backup: $backup_file"
    
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker cp "$backup_file" "$CONTAINER_NAME:/tmp/restore.tar.gz"
        docker exec "$CONTAINER_NAME" tar -xzf /tmp/restore.tar.gz -C /var/www/html/chat/
        docker exec "$CONTAINER_NAME" rm /tmp/restore.tar.gz
        docker exec "$CONTAINER_NAME" chown -R www-data:www-data /var/www/html/chat/data
        
        success "Backup restaurado com sucesso!"
    else
        error "Container não está rodando"
    fi
}

# Limpeza
cleanup() {
    log "🧹 Limpando recursos..."
    
    # Remove imagens não utilizadas
    docker image prune -f
    
    # Remove containers parados
    docker container prune -f
    
    # Remove backups antigos
    find "$BACKUPS_DIR" -name "*.tar.gz" -mtime +7 -delete 2>/dev/null || true
    
    success "Limpeza concluída"
}

# Deploy completo
full_deploy() {
    log "🚀 Iniciando deploy completo..."
    
    check_docker
    setup_directories
    create_network
    create_volume
    stop_container
    build_image
    start_container
    check_health
    show_status
    
    success "🎉 Deploy concluído com sucesso!"
}

# Logs
show_logs() {
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        log "📋 Logs do container (Ctrl+C para sair):"
        docker logs -f "$CONTAINER_NAME"
    else
        error "Container não está rodando"
    fi
}

# Shell no container
shell() {
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        log "🐚 Abrindo shell no container..."
        docker exec -it "$CONTAINER_NAME" bash
    else
        error "Container não está rodando"
    fi
}

# Menu de ajuda
show_help() {
    echo "Uso: $0 [COMANDO]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  deploy     - Deploy completo"
    echo "  build      - Build da imagem"
    echo "  start      - Inicia container"
    echo "  stop       - Para container"
    echo "  restart    - Reinicia container"
    echo "  status     - Mostra status"
    echo "  logs       - Mostra logs"
    echo "  shell      - Abre shell no container"
    echo "  backup     - Cria backup"
    echo "  restore    - Restaura backup"
    echo "  cleanup    - Limpeza geral"
    echo "  help       - Mostra esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 deploy"
    echo "  $0 restore ./backups/backup.tar.gz"
}

# Main
case "${1:-}" in
    "deploy")
        full_deploy
        ;;
    "build")
        check_docker
        build_image
        ;;
    "start")
        check_docker
        setup_directories
        create_network
        create_volume
        start_container
        check_health
        show_status
        ;;
    "stop")
        stop_container
        ;;
    "restart")
        stop_container
        sleep 2
        start_container
        check_health
        show_status
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "shell")
        shell
        ;;
    "backup")
        backup_data
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        log "🤖 Chat Docker CLI Deploy"
        show_help
        ;;
    *)
        error "Comando desconhecido: $1"
        show_help
        exit 1
        ;;
esac
