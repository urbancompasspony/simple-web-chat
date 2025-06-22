#!/bin/bash
# deploy.sh - Script de deploy completo para Chat Docker

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

# Banner
echo -e "${BLUE}"
cat << "EOF"
 ____  _   _    _  _____   ____   ___   ____ _  __ _____ ____  
/ ___|| | | |  / \|_   _| |  _ \ / _ \ / ___| |/ /| ____|  _ \ 
| |   | |_| | / _ \ | |   | | | | | | | |   | ' / |  _| | |_) |
| |___|  _  |/ ___ \| |   | |_| | |_| | |___| . \ | |___|  _ < 
 \____|_| |_/_/   \_\_|   |____/ \___/ \____|_|\_\|_____|_| \_\
                                                              
EOF
echo -e "${NC}"

log "🚀 Iniciando deploy do Chat Docker..."

# Verifica se Docker está instalado
if ! command -v docker &> /dev/null; then
    error "Docker não está instalado!"
    echo "Instale o Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Verifica se Docker Compose está disponível
if ! docker compose version &> /dev/null; then
    error "Docker Compose não está disponível!"
    exit 1
fi

# Cria estrutura de diretórios
log "📁 Criando estrutura de diretórios..."
mkdir -p logs backups

# Função para criar arquivos necessários
create_files() {
    log "📝 Criando arquivos necessários..."
    
    # Cria .dockerignore se não existir
    if [ ! -f ".dockerignore" ]; then
        cat > .dockerignore << EOF
logs/
backups/
*.log
.git/
README.md
deploy.sh
EOF
        success "Arquivo .dockerignore criado"
    fi
    
    # Cria arquivo de ambiente
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# Configurações do Chat Docker
CHAT_PORT=8080
APACHE_LOG_LEVEL=warn
PHP_MEMORY_LIMIT=128M
CHAT_MAX_MESSAGES=1000
CHAT_USER_TIMEOUT=300
EOF
        success "Arquivo .env criado"
    fi
}

# Função para build da imagem
build_image() {
    log "🔨 Fazendo build da imagem Docker..."
    
    if docker compose build --no-cache; then
        success "Build completado com sucesso!"
    else
        error "Falha no build da imagem!"
        exit 1
    fi
}

# Função para iniciar os serviços
start_services() {
    log "🚀 Iniciando serviços..."
    
    if docker compose up -d; then
        success "Serviços iniciados com sucesso!"
    else
        error "Falha ao iniciar serviços!"
        exit 1
    fi
}

# Função para verificar saúde dos serviços
check_health() {
    log "🏥 Verificando saúde dos serviços..."
    
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if docker compose ps | grep -q "healthy"; then
            success "Serviços estão saudáveis!"
            return 0
        fi
        
        retries=$((retries + 1))
        echo -n "."
        sleep 2
    done
    
    warning "Timeout na verificação de saúde, mas serviços podem estar funcionando"
    return 1
}

# Função para mostrar status
show_status() {
    log "📊 Status dos serviços:"
    docker compose ps
    
    echo ""
    log "📈 Uso de recursos:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    
    echo ""
    log "🌐 Acessos disponíveis:"
    echo "   Local: http://localhost:8080/chat/"
    echo "   Rede:  http://$(hostname -I | cut -d' ' -f1):8080/chat/"
    
    echo ""
    log "📋 Comandos úteis:"
    echo "   Ver logs:      docker compose logs -f chat-apache"
    echo "   Parar:         docker compose down"
    echo "   Restart:       docker compose restart"
    echo "   Shell:         docker compose exec chat-apache bash"
    echo "   Backup:        ./backup.sh"
}

# Função para criar script de backup
create_backup_script() {
    cat > backup.sh << 'EOF'
#!/bin/bash
# Script de backup manual

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/manual_backup_$TIMESTAMP.tar.gz"

echo "🔄 Criando backup manual..."

# Cria backup dos dados
docker compose exec chat-apache tar -czf /tmp/backup.tar.gz -C /var/www/html/chat data/

# Copia backup para host
docker compose cp chat-apache:/tmp/backup.tar.gz "$BACKUP_FILE"

# Remove backup temporário do container
docker compose exec chat-apache rm /tmp/backup.tar.gz

echo "✅ Backup criado: $BACKUP_FILE"
EOF
    
    chmod +x backup.sh
    success "Script de backup criado: ./backup.sh"
}

# Função para limpeza
cleanup() {
    log "🧹 Limpando recursos antigos..."
    
    # Remove imagens não utilizadas
    docker system prune -f
    
    # Remove backups antigos (mais de 30 dias)
    find ./backups -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    
    success "Limpeza concluída!"
}

# Menu principal
main_menu() {
    echo ""
    log "Escolha uma opção:"
    echo "1) Deploy completo (recomendado)"
    echo "2) Apenas build"
    echo "3) Apenas start"
    echo "4) Status dos serviços"
    echo "5) Parar serviços"
    echo "6) Limpeza"
    echo "7) Sair"
    
    read -p "Opção [1-7]: " choice
    
    case $choice in
        1)
            create_files
            build_image
            start_services
            check_health
            create_backup_script
            show_status
            ;;
        2)
            build_image
            ;;
        3)
            start_services
            check_health
            show_status
            ;;
        4)
            show_status
            ;;
        5)
            log "⏹️  Parando serviços..."
            docker compose down
            success "Serviços parados!"
            ;;
        6)
            cleanup
            ;;
        7)
            log "👋 Saindo..."
            exit 0
            ;;
        *)
            warning "Opção inválida!"
            main_menu
            ;;
    esac
}

# Verifica se é execução direta ou com parâmetros
if [ $# -eq 0 ]; then
    main_menu
else
    case $1 in
        "build")
            build_image
            ;;
        "start")
            start_services
            check_health
            show_status
            ;;
        "deploy")
            create_files
            build_image
            start_services
            check_health
            create_backup_script
            show_status
            ;;
        "status")
            show_status
            ;;
        "stop")
            docker compose down
            ;;
        "clean")
            cleanup
            ;;
        *)
            echo "Uso: $0 [build|start|deploy|status|stop|clean]"
            exit 1
            ;;
    esac
fi
