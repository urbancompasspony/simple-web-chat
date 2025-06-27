#!/bin/bash
# chat-users.sh - Gerencia usuários do chat via Docker (executar no HOST)

set -e

# Configurações
CONTAINER_NAME="chat-apache"  # Nome do seu container

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verifica se container está rodando
check_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${RED}❌ Container '$CONTAINER_NAME' não está rodando!${NC}"
        echo "Inicie o container primeiro:"
        echo "   docker start $CONTAINER_NAME"
        exit 1
    fi
}

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       CHAT USERS MANAGER (HOST)        ║${NC}"
    echo -e "${BLUE}║         Container: $CONTAINER_NAME$(printf "%*s" $((13-${#CONTAINER_NAME})) "")         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# Lista usuários
list_users() {
    print_header
    echo -e "${BLUE}👥 Usuários cadastrados:${NC}"
    echo ""
    
    docker exec $CONTAINER_NAME bash -c '
        if [ -f /var/www/html/chat/.htpasswd ] && [ -s /var/www/html/chat/.htpasswd ]; then
            cut -d: -f1 /var/www/html/chat/.htpasswd | nl -w2 -s") "
        else
            echo "Nenhum usuário cadastrado ainda"
        fi
    '
    echo ""
}

# Adiciona usuário
add_user() {
    print_header
    echo -e "${BLUE}➕ Adicionar usuário:${NC}"
    echo ""
    
    read -p "Nome do usuário: " USERNAME
    read -s -p "Senha: " PASSWORD
    echo ""
    
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        echo -e "${RED}❌ Usuário e senha são obrigatórios!${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Adicionando usuário no container...${NC}"
    
    docker exec $CONTAINER_NAME bash -c "
        if [ -f /var/www/html/chat/.htpasswd ]; then
            htpasswd -b /var/www/html/chat/.htpasswd '$USERNAME' '$PASSWORD'
        else
            htpasswd -cb /var/www/html/chat/.htpasswd '$USERNAME' '$PASSWORD'
        fi
        chmod 644 /var/www/html/chat/.htpasswd
        chown www-data:www-data /var/www/html/chat/.htpasswd
        apache2ctl graceful
    "
    
    echo -e "${GREEN}✅ Usuário '$USERNAME' adicionado com sucesso!${NC}"
}

# Remove usuário
remove_user() {
    print_header
    echo -e "${BLUE}❌ Remover usuário:${NC}"
    echo ""
    
    # Lista usuários atuais
    echo "Usuários cadastrados:"
    docker exec $CONTAINER_NAME bash -c 'cut -d: -f1 /var/www/html/chat/.htpasswd 2>/dev/null | nl -w2 -s") " || echo "Nenhum usuário cadastrado"'
    echo ""
    
    read -p "Nome do usuário para remover: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}❌ Nome do usuário é obrigatório!${NC}"
        return 1
    fi
    
    echo ""
    read -p "Tem certeza que deseja remover '$USERNAME'? (s/N): " CONFIRM
    
    if [[ $CONFIRM =~ ^[Ss]$ ]]; then
        echo -e "${BLUE}🔄 Removendo usuário do container...${NC}"
        
        if docker exec $CONTAINER_NAME bash -c "htpasswd -D /var/www/html/chat/.htpasswd '$USERNAME' && apache2ctl graceful"; then
            echo -e "${GREEN}✅ Usuário '$USERNAME' removido com sucesso!${NC}"
        else
            echo -e "${RED}❌ Erro ao remover usuário (pode não existir)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Operação cancelada${NC}"
    fi
}

# Gera usuário com senha aleatória
generate_user() {
    print_header
    echo -e "${BLUE}🎲 Gerar usuário com senha aleatória:${NC}"
    echo ""
    
    read -p "Nome do usuário: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}❌ Nome do usuário é obrigatório!${NC}"
        return 1
    fi
    
    # Gera senha aleatória
    PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    
    echo -e "${BLUE}🔄 Criando usuário no container...${NC}"
    
    docker exec $CONTAINER_NAME bash -c "
        if [ -f /var/www/html/chat/.htpasswd ]; then
            htpasswd -b /var/www/html/chat/.htpasswd '$USERNAME' '$PASSWORD'
        else
            htpasswd -cb /var/www/html/chat/.htpasswd '$USERNAME' '$PASSWORD'
        fi
        chmod 644 /var/www/html/chat/.htpasswd
        chown www-data:www-data /var/www/html/chat/.htpasswd
        apache2ctl graceful
        
        # Salva credenciais
        echo 'Usuário: $USERNAME' >> /var/www/html/chat/data/credentials.txt
        echo 'Senha: $PASSWORD' >> /var/www/html/chat/data/credentials.txt
        echo 'Data: \$(date)' >> /var/www/html/chat/data/credentials.txt
        echo '---' >> /var/www/html/chat/data/credentials.txt
    "
    
    echo -e "${GREEN}✅ Usuário '$USERNAME' criado com sucesso!${NC}"
    echo ""
    echo -e "${GREEN}🔑 Credenciais geradas:${NC}"
    echo "   Usuário: $USERNAME"
    echo "   Senha: $PASSWORD"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANTE: Anote essas credenciais!${NC}"
    
    # Salva localmente também
    echo "Usuário: $USERNAME" >> chat-credentials.txt
    echo "Senha: $PASSWORD" >> chat-credentials.txt
    echo "Data: $(date)" >> chat-credentials.txt
    echo "---" >> chat-credentials.txt
    
    echo -e "${BLUE}💾 Credenciais salvas em: chat-credentials.txt${NC}"
}

# Altera senha
change_password() {
    print_header
    echo -e "${BLUE}🔑 Alterar senha:${NC}"
    echo ""
    
    # Lista usuários
    echo "Usuários cadastrados:"
    docker exec $CONTAINER_NAME bash -c 'cut -d: -f1 /var/www/html/chat/.htpasswd 2>/dev/null | nl -w2 -s") " || echo "Nenhum usuário cadastrado"'
    echo ""
    
    read -p "Nome do usuário: " USERNAME
    read -s -p "Nova senha: " PASSWORD
    echo ""
    
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        echo -e "${RED}❌ Usuário e senha são obrigatórios!${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Alterando senha no container...${NC}"
    
    if docker exec $CONTAINER_NAME bash -c "htpasswd -b /var/www/html/chat/.htpasswd '$USERNAME' '$PASSWORD' && apache2ctl graceful"; then
        echo -e "${GREEN}✅ Senha do usuário '$USERNAME' alterada com sucesso!${NC}"
    else
        echo -e "${RED}❌ Erro ao alterar senha (usuário pode não existir)${NC}"
    fi
}

# Status do sistema
show_status() {
    print_header
    echo -e "${BLUE}📊 Status do sistema de autenticação:${NC}"
    echo ""
    
    docker exec $CONTAINER_NAME bash -c '
        echo -e "\033[0;34m📁 Arquivos:\033[0m"
        if [ -f /var/www/html/chat/.htpasswd ]; then
            echo -e "\033[0;32m✅ .htpasswd existe\033[0m"
            echo "   Usuários: $(wc -l < /var/www/html/chat/.htpasswd)"
            echo "   Permissões: $(stat -c %a /var/www/html/chat/.htpasswd)"
        else
            echo -e "\033[1;33m⚠️  .htpasswd não existe\033[0m"
        fi
        
        echo ""
        echo -e "\033[0;34m🔧 Apache:\033[0m"
        if pgrep apache2 > /dev/null; then
            echo -e "\033[0;32m✅ Apache rodando\033[0m"
            if apache2ctl -M | grep -q auth_basic; then
                echo -e "\033[0;32m✅ Módulo auth_basic carregado\033[0m"
            else
                echo -e "\033[0;31m❌ Módulo auth_basic não carregado\033[0m"
            fi
        else
            echo -e "\033[0;31m❌ Apache parado\033[0m"
        fi
    '
    echo ""
}

# Backup dos usuários
backup_users() {
    print_header
    echo -e "${BLUE}💾 Fazendo backup dos usuários:${NC}"
    echo ""
    
    BACKUP_FILE="htpasswd_backup_$(date +%Y%m%d_%H%M%S).txt"
    
    if docker exec $CONTAINER_NAME test -f /var/www/html/chat/.htpasswd; then
        docker cp "$CONTAINER_NAME:/var/www/html/chat/.htpasswd" "./$BACKUP_FILE"
        echo -e "${GREEN}✅ Backup criado: $BACKUP_FILE${NC}"
        
        echo ""
        echo -e "${BLUE}👥 Usuários no backup:${NC}"
        cut -d: -f1 "$BACKUP_FILE" | nl -w2 -s') '
    else
        echo -e "${YELLOW}⚠️  Arquivo .htpasswd não existe no container${NC}"
    fi
}

# Menu principal
show_menu() {
    while true; do
        check_container
        print_header
        
        # Status rápido
        USER_COUNT=$(docker exec $CONTAINER_NAME bash -c 'if [ -f /var/www/html/chat/.htpasswd ]; then wc -l < /var/www/html/chat/.htpasswd; else echo 0; fi')
        
        if [ "$USER_COUNT" -gt 0 ]; then
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
        echo "6) 📊 Status do sistema"
        echo "7) 💾 Backup dos usuários"
        echo "8) 🐚 Shell no container"
        echo "9) 🚪 Sair"
        
        echo ""
        read -p "Opção [1-9]: " choice
        
        case $choice in
            1) list_users; read -p "Pressione Enter para continuar..."; ;;
            2) add_user; read -p "Pressione Enter para continuar..."; ;;
            3) remove_user; read -p "Pressione Enter para continuar..."; ;;
            4) change_password; read -p "Pressione Enter para continuar..."; ;;
            5) generate_user; read -p "Pressione Enter para continuar..."; ;;
            6) show_status; read -p "Pressione Enter para continuar..."; ;;
            7) backup_users; read -p "Pressione Enter para continuar..."; ;;
            8) 
                echo -e "${BLUE}🐚 Abrindo shell no container...${NC}"
                docker exec -it $CONTAINER_NAME bash
                ;;
            9) 
                print_header
                echo -e "${BLUE}👋 Saindo...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opção inválida!${NC}"
                read -p "Pressione Enter para continuar..."
                ;;
        esac
    done
}

# Execução
if [ $# -eq 0 ]; then
