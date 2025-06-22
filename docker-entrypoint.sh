#!/bin/bash
# docker-entrypoint.sh - Script de inicialização do container

set -e

echo "🚀 Iniciando container Apache + PHP Chat..."

# Função para log colorido
log() {
    echo -e "\033[36m[$(date +'%Y-%m-%d %H:%M:%S')] $1\033[0m"
}

error() {
    echo -e "\033[31m[ERROR] $1\033[0m" >&2
}

success() {
    echo -e "\033[32m[SUCCESS] $1\033[0m"
}

# Verifica se os arquivos do chat existem
log "Verificando arquivos do chat..."
if [ ! -f "/var/www/html/chat/index.php" ]; then
    error "Arquivo index.php não encontrado!"
    exit 1
fi

if [ ! -f "/var/www/html/chat/api.php" ]; then
    error "Arquivo api.php não encontrado!"
    exit 1
fi

# Cria pasta de dados se não existir
log "Configurando pasta de dados..."
mkdir -p /var/www/html/chat/data

# Inicializa arquivos JSON se não existirem
if [ ! -f "/var/www/html/chat/data/messages.json" ]; then
    log "Criando arquivo de mensagens..."
    echo '{"messages":[]}' > /var/www/html/chat/data/messages.json
fi

if [ ! -f "/var/www/html/chat/data/users.json" ]; then
    log "Criando arquivo de usuários..."
    echo '{"users":[]}' > /var/www/html/chat/data/users.json
fi

# Define permissões corretas
log "Configurando permissões..."
chown -R www-data:www-data /var/www/html/chat
chmod 755 /var/www/html/chat
chmod 644 /var/www/html/chat/*.php
chmod 644 /var/www/html/chat/.htaccess 2>/dev/null || true
chmod 755 /var/www/html/chat/data
chmod 644 /var/www/html/chat/data/*.json

# Verifica configuração do Apache
log "Verificando configuração do Apache..."
apache2ctl configtest

if [ $? -eq 0 ]; then
    success "Configuração do Apache OK!"
else
    error "Erro na configuração do Apache!"
    exit 1
fi

# Verifica módulos habilitados
log "Módulos Apache habilitados:"
apache2ctl -M | grep -E "(rewrite|headers|deflate|expires)" || log "Alguns módulos podem não estar habilitados"

# Cria arquivo de log de inicialização
log "Criando logs de inicialização..."
echo "Container iniciado em: $(date)" > /var/www/html/chat/data/container.log
echo "PHP Version: $(php -v | head -1)" >> /var/www/html/chat/data/container.log
echo "Apache Version: $(apache2 -v | head -1)" >> /var/www/html/chat/data/container.log

# Exibe informações importantes
success "==================================="
success "🎉 Chat Apache + PHP Ready!"
success "==================================="
log "📂 Diretório: /var/www/html/chat"
log "🌐 URL: http://localhost/chat/"
log "🐳 Container: $(hostname)"
log "📊 Espaço em disco:"
df -h /var/www/html/chat | tail -1

# Script de limpeza automática (executa em background)
cleanup_script() {
    while true; do
        sleep 3600  # Executa a cada hora
        
        # Remove usuários inativos (mais de 5 minutos sem atividade)
        if [ -f "/var/www/html/chat/data/users.json" ]; then
            php -r "
                \$users = json_decode(file_get_contents('/var/www/html/chat/data/users.json'), true);
                if (isset(\$users['users'])) {
                    \$active = array_filter(\$users['users'], function(\$user) {
                        return (time() - strtotime(\$user['last_seen'])) < 300; // 5 minutos
                    });
                    \$users['users'] = array_values(\$active);
                    file_put_contents('/var/www/html/chat/data/users.json', json_encode(\$users));
                }
            "
        fi
        
        # Limita mensagens a 500 mais recentes
        if [ -f "/var/www/html/chat/data/messages.json" ]; then
            php -r "
                \$messages = json_decode(file_get_contents('/var/www/html/chat/data/messages.json'), true);
                if (isset(\$messages['messages']) && count(\$messages['messages']) > 500) {
                    \$messages['messages'] = array_slice(\$messages['messages'], -500);
                    file_put_contents('/var/www/html/chat/data/messages.json', json_encode(\$messages));
                }
            "
        fi
    done
}

# Inicia limpeza em background
cleanup_script &

# Função para graceful shutdown
graceful_shutdown() {
    log "Recebido sinal de parada..."
    log "Fazendo backup dos dados..."
    
    if [ -d "/var/www/html/chat/data" ]; then
        tar -czf "/tmp/chat_backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C /var/www/html/chat data/
        log "Backup salvo em /tmp/"
    fi
    
    log "Parando Apache..."
    apache2ctl graceful-stop
    success "Container finalizado com segurança!"
    exit 0
}

# Configura tratamento de sinais
trap graceful_shutdown SIGTERM SIGINT

# Inicia Apache em foreground
log "Iniciando Apache..."
exec "$@"
