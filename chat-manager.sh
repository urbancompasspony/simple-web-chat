#!/bin/bash
# chat-manager.sh - Gerenciador completo do chat

# Configurações globais
CONTAINER_NAME="chat-apache-app"
IMAGE_NAME="chat-apache-php"
VOLUME_NAME="chat_data_vol"
NETWORK_NAME="chat_net"
HOST_PORT="8080"

# Cores
G='\033[0;32m'  # Green
R='\033[0;31m'  # Red  
Y='\033[1;33m'  # Yellow
B='\033[0;34m'  # Blue
NC='\033[0m'    # No Color

print_header() {
    clear
    echo -e "${B}╔════════════════════════════════════════╗${NC}"
    echo -e "${B}║           CHAT MANAGER v1.0            ║${NC}"
    echo -e "${B}║        Docker CLI Deployment           ║${NC}"
    echo -e "${B}╚════════════════════════════════════════╝${NC}"
    echo ""
}

log() { echo -e "${B}▶${NC} $1"; }
ok() { echo -e "${G}✓${NC} $1"; }
warn() { echo -e "${Y}!${NC} $1"; }
err() { echo -e "${R}✗${NC} $1" >&2; }

# Verifica se container está rodando
is_running() {
    docker ps -q -f name="^${CONTAINER_NAME}$" | grep -q .
}

# Verifica se container existe (parado)
exists() {
    docker ps -aq -f name="^${CONTAINER_NAME}$" | grep -q .
}

# Status do container
status() {
    print_header
    log "Status do Chat:"
    echo ""
    
    if is_running; then
        ok "Container rodando"
        echo ""
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|$CONTAINER_NAME)"
        echo ""
        
        # Informações de acesso
        echo -e "${G}🌐 Acessos disponíveis:${NC}"
        echo "   Local: http://localhost:$HOST_PORT/chat/"
        
        # Pega IP da máquina
        local machine_ip=$(hostname -I | cut -d' ' -f1 2>/dev/null || echo "IP_DA_MAQUINA")
        echo "   Rede:  http://$machine_ip:$HOST_PORT/chat/"
        
        echo ""
        # Recursos
        echo -e "${B}📊 Uso de recursos:${NC}"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" $CONTAINER_NAME
        
    elif exists; then
        warn "Container existe mas está parado"
        docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -E "(NAMES|$CONTAINER_NAME)"
    else
        warn "Container não existe"
    fi
    
    echo ""
    pause
}

# Deploy rápido
quick_deploy() {
    print_header
    log "Iniciando deploy rápido..."
    
    # Para container se estiver rodando
    if is_running; then
        log "Parando container atual..."
        docker stop $CONTAINER_NAME >/dev/null 2>&1
    fi
    
    # Remove container se existir
    if exists; then
        log "Removendo container antigo..."
        docker rm $CONTAINER_NAME >/dev/null 2>&1
    fi
    
    # Cria rede se não existir
    if ! docker network ls | grep -q $NETWORK_NAME; then
        log "Criando rede..."
        docker network create $NETWORK_NAME >/dev/null 2>&1
    fi
    
    # Cria volume se não existir
    if ! docker volume ls | grep -q $VOLUME_NAME; then
        log "Criando volume..."
        docker volume create $VOLUME_NAME >/dev/null 2>&1
    fi
    
    # Build da imagem
    log "Fazendo build da imagem..."
    create_dockerfile_if_needed
    docker build -t $IMAGE_NAME . >/dev/null 2>&1
    
    # Inicia container
    log "Iniciando container..."
    docker run -d \
        --name $CONTAINER_NAME \
        --network $NETWORK_NAME \
        --restart unless-stopped \
        -p $HOST_PORT:80 \
        -v $VOLUME_NAME:/var/www/html/chat/data \
        --health-cmd="curl -f http://localhost/chat/ || exit 1" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=3 \
        $IMAGE_NAME >/dev/null 2>&1
    
    # Verifica se subiu
    sleep 3
    if is_running; then
        ok "Deploy concluído com sucesso!"
        echo ""
        echo -e "${G}🎉 Chat disponível em: http://localhost:$HOST_PORT/chat/${NC}"
    else
        err "Erro no deploy!"
        echo "Logs:"
        docker logs $CONTAINER_NAME
        return 1
    fi
    
    pause
}

# Cria Dockerfile se necessário
create_dockerfile_if_needed() {
    if [ ! -f "Dockerfile" ]; then
        cat > Dockerfile << 'EOF'
FROM php:8.2-apache

# Instala dependências
RUN apt-get update && apt-get install -y \
    curl nano zip unzip \
    && rm -rf /var/lib/apt/lists/*

# Habilita módulos Apache
RUN a2enmod rewrite headers deflate expires

# Cria estrutura
RUN mkdir -p /var/www/html/chat/data

# Copia arquivos
COPY . /var/www/html/chat/

# Configuração Apache
RUN echo '<VirtualHost *:80>' > /etc/apache2/sites-available/000-default.conf && \
    echo 'DocumentRoot /var/www/html/chat' >> /etc/apache2/sites-available/000-default.conf && \
    echo '<Directory /var/www/html/chat>' >> /etc/apache2/sites-available/000-default.conf && \
    echo 'AllowOverride All' >> /etc/apache2/sites-available/000-default.conf && \
    echo 'Require all granted' >> /etc/apache2/sites-available/000-default.conf && \
    echo '</Directory>' >> /etc/apache2/sites-available/000-default.conf && \
    echo '</VirtualHost>' >> /etc/apache2/sites-available/000-default.conf

# Permissões
RUN chown -R www-data:www-data /var/www/html/chat && \
    chmod 755 /var/www/html/chat && \
    chmod 755 /var/www/html/chat/data

# Configuração PHP
RUN echo 'memory_limit = 128M' >> /usr/local/etc/php/conf.d/custom.ini && \
    echo 'max_execution_time = 30' >> /usr/local/etc/php/conf.d/custom.ini

EXPOSE 80
CMD ["apache2-foreground"]
EOF
    fi
}

# Parar container
stop_container() {
    print_header
    if is_running; then
        log "Parando container..."
        docker stop $CONTAINER_NAME >/dev/null 2>&1
        ok "Container parado"
    else
        warn "Container não está rodando"
    fi
    pause
}

# Iniciar container
start_container() {
    print_header
    if exists && ! is_running; then
        log "Iniciando container..."
        docker start $CONTAINER_NAME >/dev/null 2>&1
        sleep 2
        if is_running; then
            ok "Container iniciado"
            echo "🌐 Acesso: http://localhost:$HOST_PORT/chat/"
        else
            err "Erro ao iniciar container"
        fi
    elif is_running; then
        warn "Container já está rodando"
    else
        warn "Container não existe. Use 'Deploy' para criar."
    fi
    pause
}

# Restart container
restart_container() {
    print_header
    if is_running; then
        log "Reiniciando container..."
        docker restart $CONTAINER_NAME >/dev/null 2>&1
        sleep 2
        if is_running; then
            ok "Container reiniciado"
        else
            err "Erro ao reiniciar"
        fi
    else
        warn "Container não está rodando"
    fi
    pause
}

# Ver logs
view_logs() {
    print_header
    if exists; then
        echo -e "${B}📋 Logs do container (Ctrl+C para sair):${NC}"
        echo ""
        docker logs -f $CONTAINER_NAME
    else
        err "Container não existe"
        pause
    fi
}

# Shell no container
shell_access() {
    print_header
    if is_running; then
        echo -e "${B}🐚 Abrindo shell no container...${NC}"
        echo "Digite 'exit' para sair"
        echo ""
        docker exec -it $CONTAINER_NAME bash
    else
        err "Container não está rodando"
        pause
    fi
}

# Backup
backup_data() {
    print_header
    if is_running; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="chat_backup_$timestamp.tar.gz"
        
        log "Criando backup..."
        docker exec $CONTAINER_NAME tar -czf /tmp/backup.tar.gz -C /var/www/html/chat data/ 2>/dev/null
        docker cp $CONTAINER_NAME:/tmp/backup.tar.gz ./$backup_file 2>/dev/null
        docker exec $CONTAINER_NAME rm /tmp/backup.tar.gz 2>/dev/null
        
        ok "Backup criado: $backup_file"
    else
        err "Container não está rodando"
    fi
    pause
}

# Limpeza completa
full_cleanup() {
    print_header
    warn "Esta ação removerá TUDO relacionado ao chat!"
    echo ""
    read -p "Tem certeza? (digite 'sim' para confirmar): " confirm
    
    if [ "$confirm" = "sim" ]; then
        log "Removendo container..."
        docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
        docker rm $CONTAINER_NAME >/dev/null 2>&1 || true
        
        log "Removendo imagem..."
        docker rmi $IMAGE_NAME >/dev/null 2>&1 || true
        
        log "Removendo volume..."
        docker volume rm $VOLUME_NAME >/dev/null 2>&1 || true
        
        log "Removendo rede..."
        docker network rm $NETWORK_NAME >/dev/null 2>&1 || true
        
        ok "Limpeza completa realizada"
    else
        warn "Operação cancelada"
    fi
    pause
}

# Função para pausar
pause() {
    echo ""
    read -p "Pressione Enter para continuar..."
}

# Menu principal
main_menu() {
    while true; do
        print_header
        
        # Status rápido
        if is_running; then
            echo -e "${G}● Chat Online${NC} - http://localhost:$HOST_PORT/chat/"
        elif exists; then
            echo -e "${Y}● Chat Parado${NC}"
        else
            echo -e "${R}● Chat Não Instalado${NC}"
        fi
        
        echo ""
        echo "Escolha uma opção:"
        echo ""
        echo "1) 🚀 Deploy Rápido"
        echo "2) 📊 Status"
        echo "3) ▶️  Iniciar"
        echo "4) ⏹️  Parar"
        echo "5) 🔄 Restart"
        echo "6) 📋 Ver Logs"
        echo "7) 🐚 Shell"
        echo "8) 💾 Backup"
        echo "9) 🗑️  Limpeza Completa"
        echo "0) ❌ Sair"
        
        echo ""
        read -p "Opção [0-9]: " choice
        
        case $choice in
            1) quick_deploy ;;
            2) status ;;
            3) start_container ;;
            4) stop_container ;;
            5) restart_container ;;
            6) view_logs ;;
            7) shell_access ;;
            8) backup_data ;;
            9) full_cleanup ;;
            0) 
                print_header
                echo "👋 Saindo..."
                exit 0
                ;;
            *)
                print_header
                err "Opção inválida!"
                pause
                ;;
        esac
    done
}

# Execução principal
if [ $# -eq 0 ]; then
    # Modo interativo
    main_menu
else
    # Modo CLI
    case $1 in
        "deploy"|"d")
            quick_deploy
            ;;
        "status"|"s")
            status
            ;;
        "start")
            start_container
            ;;
        "stop")
            stop_container
            ;;
        "restart"|"r")
            restart_container
            ;;
        "logs"|"l")
            view_logs
            ;;
        "shell"|"sh")
            shell_access
            ;;
        "backup"|"b")
            backup_data
            ;;
        "cleanup"|"clean")
            full_cleanup
            ;;
        "help"|"-h"|"--help")
            echo "Chat Manager - Comandos disponíveis:"
            echo ""
            echo "  deploy   - Deploy rápido"
            echo "  status   - Mostra status"
            echo "  start    - Inicia container"
            echo "  stop     - Para container"
            echo "  restart  - Reinicia container"
            echo "  logs     - Mostra logs"
            echo "  shell    - Abre shell"
            echo "  backup   - Cria backup"
            echo "  cleanup  - Remove tudo"
            echo "  help     - Esta ajuda"
            echo ""
            echo "Uso: $0 [comando] ou $0 (modo interativo)"
            ;;
        *)
            err "Comando desconhecido: $1"
            echo "Use: $0 help para ver comandos disponíveis"
            exit 1
            ;;
    esac
fi
