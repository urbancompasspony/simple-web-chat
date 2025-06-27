#!/bin/bash
# manage-users.sh - Gerenciador de usuários do chat (dentro do container)

set -e

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

HTPASSWD_FILE="/var/www/html/chat/.htpasswd"

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        GERENCIADOR DE USUÁRIOS         ║${NC}"
    echo -e "${BLUE}║             Chat Apache                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
}

log() { echo -e "${BLUE}▶${NC} $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
error() { echo -e "${RED}❌${NC} $1" >&2; }

# Lista usuários existentes
list_users() {
    print_header
    log "Usuários cadastrados:"
    echo ""
    
    if [ -f "$HTPASSWD_FILE" ]; then
        if [ -s "$HTPASSWD_FILE" ]; then
            echo -e "${GREEN}👥 Usuários ativos:${NC}"
            cut -d: -f1 "$HTPASSWD_FILE" | nl -w2 -s') '
        else
            warn "Nenhum usuário cadastrado ainda"
        fi
    else
        warn "Arquivo .htpasswd não existe"
        log "Será criado automaticamente ao adicionar o primeiro usuário"
    fi
    echo ""
}

# Adiciona usuário
add_user() {
    print_header
    log "Adicionar novo usuário:"
    echo ""
    
    read -p "Nome do usuário: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        error "Nome de usuário não pode estar vazio!"
        return 1
    fi
    
    # Verifica se usuário já existe
    if [ -f "$HTPASSWD_FILE" ] && grep -q "^$USERNAME:" "$HTPASSWD_FILE"; then
        error "Usuário '$USERNAME' já existe!"
        return 1
    fi
    
    read -s -p "Senha: " PASSWORD
    echo ""
    read -s -p "Confirme a senha: " PASSWORD_CONFIRM
    echo ""
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        error "Senhas não coincidem!"
        return 1
    fi
    
    if [ -z "$PASSWORD" ]; then
        error "Senha não pode estar vazia!"
        return 1
    fi
    
    # Adiciona usuário
    if [ -f "$HTPASSWD_FILE" ]; then
        htpasswd -b "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
    else
        htpasswd -cb "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
    fi
    
    # Define permissões
    chmod 644 "$HTPASSWD_FILE"
    chown www-data:www-data "$HTPASSWD_FILE"
    
    success "Usuário '$USERNAME' adicionado com sucesso!"
    
    # Recarrega Apache
    if pgrep apache2 > /dev/null; then
        log "Recarregando configuração do Apache..."
        apache2ctl graceful
        success "Apache recarregado!"
    fi
}

# Remove usuário
remove_user() {
    print_header
    
    if [ ! -f "$HTPASSWD_FILE" ] || [ ! -s "$HTPASSWD_FILE" ]; then
        warn "Nenhum usuário cadastrado para remover"
        return 1
    fi
    
    log "Usuários cadastrados:"
    cut -d: -f1 "$HTPASSWD_FILE" | nl -w2 -s') '
    echo ""
    
    read -p "Nome do usuário para remover: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        error "Nome de usuário não pode estar vazio!"
        return 1
    fi
    
    if ! grep -q "^$USERNAME:" "$HTPASSWD_FILE"; then
        error "Usuário '$USERNAME' não encontrado!"
        return 1
    fi
    
    echo ""
    read -p "Tem certeza que deseja remover '$USERNAME'? (s/N): " CONFIRM
    
    if [[ $CONFIRM =~ ^[Ss]$ ]]; then
        htpasswd -D "$HTPASSWD_FILE" "$USERNAME"
        success "Usuário '$USERNAME' removido com sucesso!"
        
        # Recarrega Apache
        if pgrep apache2 > /dev/null; then
            log "Recarregando configuração do Apache..."
            apache2ctl graceful
            success "Apache recarregado!"
        fi
    else
        warn "Operação cancelada"
    fi
}

# Altera senha de usuário
change_password() {
    print_header
    
    if [ ! -f "$HTPASSWD_FILE" ] || [ ! -s "$HTPASSWD_FILE" ]; then
        warn "Nenhum usuário cadastrado"
        return 1
    fi
    
    log "Usuários cadastrados:"
    cut -d: -f1 "$HTPASSWD_FILE" | nl -w2 -s') '
    echo ""
    
    read -p "Nome do usuário: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        error "Nome de usuário não pode estar vazio!"
        return 1
    fi
    
    if ! grep -q "^$USERNAME:" "$HTPASSWD_FILE"; then
        error "Usuário '$USERNAME' não encontrado!"
        return 1
    fi
    
    echo ""
    read -s -p "Nova senha: " PASSWORD
    echo ""
    read -s -p "Confirme a nova senha: " PASSWORD_CONFIRM
    echo ""
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        error "Senhas não coincidem!"
        return 1
    fi
    
    if [ -z "$PASSWORD" ]; then
        error "Senha não pode estar vazia!"
        return 1
    fi
    
    # Altera senha
    htpasswd -b "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
    success "Senha do usuário '$USERNAME' alterada com sucesso!"
    
    # Recarrega Apache
    if pgrep apache2 > /dev/null; then
        log "Recarregando configuração do Apache..."
        apache2ctl graceful
        success "Apache recarregado!"
    fi
}

# Gera senha aleatória
generate_user() {
    print_header
    log "Gerar usuário com senha aleatória:"
    echo ""
    
    read -p "Nome do usuário: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        error "Nome de usuário não pode estar vazio!"
        return 1
    fi
    
    # Verifica se usuário já existe
    if [ -f "$HTPASSWD_FILE" ] && grep -q "^$USERNAME:" "$HTPASSWD_FILE"; then
        error "Usuário '$USERNAME' já existe!"
        return 1
    fi
    
    # Gera senha aleatória
    PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    
    # Adiciona usuário
    if [ -f "$HTPASSWD_FILE" ]; then
        htpasswd -b "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
    else
        htpasswd -cb "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
    fi
    
    # Define permissões
    chmod 644 "$HTPASSWD_FILE"
    chown www-data:www-data "$HTPASSWD_FILE"
    
    success "Usuário '$USERNAME' criado com sucesso!"
    echo ""
    echo -e "${GREEN}🔑 Credenciais geradas:${NC}"
    echo "   Usuário: $USERNAME"
    echo "   Senha: $PASSWORD"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANTE: Anote essas credenciais!${NC}"
    
    # Salva em arquivo
    echo "Usuário: $USERNAME" >> /var/www/html/chat/data/credentials.txt
    echo "Senha: $PASSWORD" >> /var/www/html/chat/data/credentials.txt
    echo "Data: $(date)" >> /var/www/html/chat/data/credentials.txt
    echo "---" >> /var/www/html/chat/data/credentials.txt
    
    log "Credenciais salvas em: /var/www/html/chat/data/credentials.txt"
    
    # Recarrega Apache
    if pgrep apache2 > /dev/null; then
        log "Recarregando configuração do Apache..."
        apache2ctl graceful
        success "Apache recarregado!"
    fi
}

# Backup do arquivo de senhas
backup_users() {
    print_header
    
    if [ ! -f "$HTPASSWD_FILE" ]; then
        warn "Arquivo .htpasswd não existe"
        return 1
    fi
    
    BACKUP_FILE="/var/www/html/chat/data/htpasswd_backup_$(date +%Y%m%d_%H%M%S).txt"
    cp "$HTPASSWD_FILE" "$BACKUP_FILE"
    
    success "Backup criado: $BACKUP_FILE"
    log "Usuários no backup:"
    cut -d: -f1 "$BACKUP_FILE" | nl -w2 -s') '
}

# Mostra informações do sistema
show_info() {
    print_header
    log "Informações do sistema de autenticação:"
    echo ""
    
    echo -e "${BLUE}📁 Arquivos:${NC}"
    echo "   .htpasswd: $HTPASSWD_FILE"
    echo "   .htaccess: /var/www/html/chat/.htaccess"
    echo ""
    
    if [ -f "$HTPASSWD_FILE" ]; then
        echo -e "${GREEN}✅ Arquivo .htpasswd existe${NC}"
        echo "   Usuários: $(wc -l < "$HTPASSWD_FILE")"
        echo "   Tamanho: $(du -h "$HTPASSWD_FILE" | cut -f1)"
        echo "   Permissões: $(stat -c %a "$HTPASSWD_FILE")"
    else
        echo -e "${YELLOW}⚠️  Arquivo .htpasswd não existe${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🔧 Status do Apache:${NC}"
    if pgrep apache2 > /dev/null; then
        echo -e "${GREEN}✅ Apache rodando${NC}"
        
        # Verifica módulos de autenticação
        if apache2ctl -M | grep -q auth_basic; then
            echo -e "${GREEN}✅ Módulo auth_basic carregado${NC}"
        else
            echo -e "${RED}❌ Módulo auth_basic não carregado${NC}"
        fi
    else
        echo -e "${RED}❌ Apache não está rodando${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📊 Estatísticas:${NC}"
    if [ -f "/var/www/html/chat/data/credentials.txt" ]; then
        GENERATED_COUNT=$(grep -c "Usuário:" /var/www/html/chat/data/credentials.txt 2>/dev/null || echo 0)
        echo "   Usuários gerados automaticamente: $GENERATED_COUNT"
    fi
}

# Menu principal
show_menu() {
    while true; do
        print_header
        
        # Status rápido
        if [ -f "$HTPASSWD_FILE" ] && [ -s "$HTPASSWD_FILE" ]; then
            USER_COUNT=$(wc -l < "$HTPASSWD_FILE")
            echo -e "${GREEN}🔐 Autenticação Ativa${NC} - $USER_COUNT usuário(s) cadastrado(s)"
        else
            echo -e "${YELLOW}⚠️  Nenhum usuário cadastrado${NC}"
        fi
        
        echo ""
        echo "Escolha uma opção:"
        echo ""
        echo "1) 👥 Listar usuários"
        echo "2) ➕ Adicionar usuário"
        echo "3) ❌ Remover usuário"
        echo "4) 🔑 Alterar senha"
        echo "5) 🎲 Gerar usuário com senha aleatória"
        echo "6) 💾 Fazer backup dos usuários"
        echo "7) ℹ️  Informações do sistema"
        echo "8) 🚪 Sair"
        
        echo ""
        read -p "Opção [1-8]: " choice
        
        case $choice in
            1) list_users; read -p "Pressione Enter para continuar..."; ;;
            2) add_user; read -p "Pressione Enter para continuar..."; ;;
            3) remove_user; read -p "Pressione Enter para continuar..."; ;;
            4) change_password; read -p "Pressione Enter para continuar..."; ;;
            5) generate_user; read -p "Pressione Enter para continuar..."; ;;
            6) backup_users; read -p "Pressione Enter para continuar..."; ;;
            7) show_info; read -p "Pressione Enter para continuar..."; ;;
            8) 
                print_header
                log "👋 Saindo do gerenciador..."
                exit 0
                ;;
            *)
                error "Opção inválida!"
                read -p "Pressione Enter para continuar..."
                ;;
        esac
    done
}

# Execução
if [ $# -eq 0 ]; then
    # Modo interativo
    show_menu
else
    # Modo CLI
    case $1 in
        "list"|"l")
            list_users
            ;;
        "add"|"a")
            if [ ! -z "$2" ] && [ ! -z "$3" ]; then
                USERNAME="$2"
                PASSWORD="$3"
                if [ -f "$HTPASSWD_FILE" ]; then
                    htpasswd -b "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
                else
                    htpasswd -cb "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
                fi
                chmod 644 "$HTPASSWD_FILE"
                chown www-data:www-data "$HTPASSWD_FILE"
                success "Usuário '$USERNAME' adicionado!"
            else
                add_user
            fi
            ;;
        "remove"|"rm")
            if [ ! -z "$2" ]; then
                htpasswd -D "$HTPASSWD_FILE" "$2" 2>/dev/null && success "Usuário '$2' removido!" || error "Usuário não encontrado"
            else
                remove_user
            fi
            ;;
        "generate"|"gen")
            generate_user
            ;;
        "info"|"i")
            show_info
            ;;
        "help"|"-h"|"--help")
            echo "Gerenciador de Usuários do Chat - Comandos:"
            echo ""
            echo "  list        - Lista usuários"
            echo "  add         - Adiciona usuário"
            echo "  add USER PASS - Adiciona usuário via CLI"
            echo "  remove      - Remove usuário"
            echo "  remove USER - Remove usuário via CLI"
            echo "  generate    - Gera usuário com senha aleatória"
            echo "  info        - Mostra informações do sistema"
            echo "  help        - Esta ajuda"
            echo ""
            echo "Uso: $0 [comando] ou $0 (modo interativo)"
            ;;
        *)
            error "Comando desconhecido: $1"
            echo "Use: $0 help para ver comandos disponíveis"
            exit 1
            ;;
    esac
fi
