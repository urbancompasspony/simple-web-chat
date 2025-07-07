# 💬 Chat Apache + PHP Docker

> **Sistema de chat em tempo real com autenticação HTTP Basic, containerizado com Docker para deploy fácil e escalável.**

## 🎯 Sobre o Projeto

Este é um sistema de chat web completo desenvolvido em PHP que roda em Apache dentro de containers Docker. Oferece interface moderna, autenticação segura, persistência de dados e ferramentas de administração completas.

## ✨ Características

- **🔐 Autenticação HTTP Basic** - Proteção por usuário/senha
- **💬 Chat em Tempo Real** - Atualização automática de mensagens
- **👥 Usuários Online** - Lista de usuários conectados
- **💾 Persistência** - Dados salvos em JSON com backup automático
- **🎨 Interface Moderna** - Design responsivo e intuitivo
- **🐳 Containerizado** - Deploy fácil com Docker
- **🔧 Ferramentas Admin** - Scripts de gerenciamento completos
- **📊 Monitoramento** - Health checks e logs detalhados

## 🚀 Deploy Rápido (1 Minuto)

### Opção 1: Deploy Ultra-Rápido ⚡
```bash
# Clone e execute
git clone https://github.com/usuario/chat-docker.git
cd chat-docker
chmod +x quick-deploy.sh
./quick-deploy.sh
```

### Opção 2: Deploy com Gerenciador 🎛️
```bash
# Com menu interativo
chmod +x chat-manager.sh
./chat-manager.sh

# Ou via CLI
./chat-manager.sh deploy
```

### Opção 3: Docker Compose 🐳
```bash
docker compose up -d
```

## 📁 Estrutura do Projeto

```
chat-docker/
├── 📄 index.php              # Interface principal do chat
├── 🔌 api.php               # Backend API REST
├── ⚙️ .htaccess             # Configuração Apache + Autenticação
├── 🐳 Dockerfile            # Imagem Docker principal
├── 📋 docker-compose.yml    # Orquestração completa
├── 🚀 Scripts de Deploy/
│   ├── quick-deploy.sh      # Deploy em 1 comando
│   ├── chat-manager.sh      # Gerenciador completo
│   ├── docker-deploy.sh     # Deploy via CLI
│   └── deploy.sh            # Deploy avançado
├── 👥 Scripts de Usuários/
│   ├── chat-users.sh        # Gerenciar usuários (HOST)
│   └── manage-users.sh      # Gerenciar usuários (CONTAINER)
├── 🔧 Configurações/
│   ├── apache-chat.conf     # Config Apache personalizada
│   ├── docker-entrypoint.sh # Script de inicialização
│   └── .env                 # Variáveis de ambiente
├── 📚 Documentação/
│   ├── README.txt           # Comandos básicos
│   ├── SIMPLIFIED/          # Versão simplificada
│   └── LICENSE              # Licença MIT
└── 📦 Dados/
    ├── data/                # Dados do chat (volume)
    ├── logs/                # Logs Apache
    └── backups/             # Backups automáticos
```

## 🛠️ Configuração e Gerenciamento

### Gerenciamento de Usuários

#### Via Host (Recomendado)
```bash
# Menu interativo
./chat-users.sh

# Via CLI
./chat-users.sh add joao senha123
./chat-users.sh generate admin
./chat-users.sh list
./chat-users.sh remove joao
```

#### Dentro do Container
```bash
# Acesso ao container
docker exec -it chat-apache bash

# Gerenciar usuários
./manage-users.sh
```

### Comandos Úteis

#### Gerenciamento Básico
```bash
# Status do chat
./chat-manager.sh status

# Ver logs em tempo real
docker logs -f chat-apache

# Shell no container
docker exec -it chat-apache bash

# Backup manual
./chat-manager.sh backup

# Restart completo
./chat-manager.sh restart
```

#### Administração
```bash
# Limpar mensagens antigas
curl -X POST http://localhost:8080/chat/api.php \
  -H "Content-Type: application/json" \
  -d '{"action":"clear_messages"}'

# Exportar chat
curl http://localhost:8080/chat/api.php?action=export \
  -o chat_export.txt

# Verificar usuários online
curl http://localhost:8080/chat/api.php?action=get_users
```

## 🔧 Configurações Avançadas

### Variáveis de Ambiente (.env)
```env
# Porta do chat
CHAT_PORT=8080

# Configurações PHP
PHP_MEMORY_LIMIT=128M
PHP_MAX_EXECUTION_TIME=30

# Configurações do chat
CHAT_MAX_MESSAGES=1000
CHAT_USER_TIMEOUT=300

# Apache
APACHE_LOG_LEVEL=warn
```

### Personalização da Interface

#### Modificar Cores
Edite `index.php` e altere o CSS:
```css
/* Gradiente principal */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);

/* Cor das mensagens próprias */
.message.own {
    background: linear-gradient(135deg, #your-color-1, #your-color-2);
}
```

#### Modificar Configurações de Polling
```javascript
// Em index.php, altere:
const POLL_INTERVAL = 2000; // Intervalo em ms (padrão: 2 segundos)
```

### Configuração de Backup Automático

O sistema já inclui backup automático via container:
```yaml
# Em docker-compose.yml
chat-backup:
  image: alpine:latest
  volumes:
    - chat_data:/data:ro
    - ./backups:/backups
  command: >
    sh -c "
      while true; do
        sleep 86400;  # Backup diário
        tar -czf /backups/chat_backup_$$(date +%Y%m%d_%H%M%S).tar.gz -C /data .;
        find /backups -name 'chat_backup_*.tar.gz' -mtime +7 -delete;
      done
    "
```

## 🔒 Segurança

### Autenticação HTTP Basic
- Usuários protegidos por `.htpasswd`
- Senhas criptografadas com bcrypt
- Suporte a múltiplos usuários

### Proteção de Arquivos
```apache
# .htaccess protege arquivos sensíveis
<FilesMatch "\.(json|htpasswd)$">
    <RequireAll>
        Require all denied
    </RequireAll>
</FilesMatch>
```

### Headers de Segurança
```apache
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
```

### Configurações PHP Seguras
```ini
display_errors = Off
log_errors = On
max_execution_time = 30
memory_limit = 128M
```

## 📊 Monitoramento e Logs

### Health Checks
```bash
# Verificar saúde do container
docker inspect chat-apache --format='{{.State.Health.Status}}'

# Logs de saúde
docker inspect chat-apache | grep -A 10 "Health"
```

### Logs Disponíveis
```bash
# Logs do Apache
docker logs chat-apache

# Logs específicos (se montados)
tail -f logs/access.log
tail -f logs/error.log

# Logs do chat
cat data/container.log
```

### Estatísticas de Uso
```bash
# Recursos do container
docker stats chat-apache --no-stream

# Espaço em disco
docker exec chat-apache df -h /var/www/html/chat
```

## 🚀 Opções de Deploy

### 1. Deploy Local (Desenvolvimento)
```bash
./quick-deploy.sh
# Acesso: http://localhost:8080/chat/
```

### 2. Deploy em Servidor (Produção)
```bash
# Com bind de IP específico
docker run -d \
  --name chat-apache \
  -p 192.168.1.100:80:80 \
  -v chat_data:/var/www/html/chat/data \
  chat-apache-php
```

### 3. Deploy com Proxy Reverso
```nginx
# nginx.conf
server {
    listen 80;
    server_name chat.exemplo.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 4. Deploy com SSL
```bash
# Com Let's Encrypt
docker run -d \
  --name chat-apache \
  -p 443:80 \
  -v /path/to/ssl:/etc/ssl/certs \
  -e HTTPS=on \
  chat-apache-php
```

## 🔧 Troubleshooting

### Problemas Comuns

#### Container não inicia
```bash
# Verificar logs
docker logs chat-apache

# Verificar portas
sudo netstat -tulpn | grep :8080

# Recriar container
docker stop chat-apache && docker rm chat-apache
./quick-deploy.sh
```

#### Mensagens não aparecem
```bash
# Verificar permissões
docker exec chat-apache ls -la /var/www/html/chat/data/

# Verificar arquivo de mensagens
docker exec chat-apache cat /var/www/html/chat/data/messages.json

# Recriar arquivos
docker exec chat-apache rm /var/www/html/chat/data/*.json
docker restart chat-apache
```

#### Autenticação não funciona
```bash
# Verificar arquivo .htpasswd
docker exec chat-apache cat /var/www/html/chat/.htpasswd

# Recriar usuário
./chat-users.sh remove usuario
./chat-users.sh add usuario novasenha

# Verificar módulos Apache
docker exec chat-apache apache2ctl -M | grep auth
```

#### Performance lenta
```bash
# Aumentar recursos
docker update --memory=512m --cpus=1.0 chat-apache

# Limpar mensagens antigas
curl -X POST http://localhost:8080/chat/api.php \
  -H "Content-Type: application/json" \
  -d '{"action":"clear_messages"}'
```

## 📈 Escalabilidade

### Load Balancer
```yaml
# docker-compose.yml com múltiplas instâncias
version: '3.8'
services:
  chat-app-1:
    build: .
    ports:
      - "8081:80"
  chat-app-2:
    build: .
    ports:
      - "8082:80"
  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
```

### Banco de Dados Externo
Para grandes volumes, considere migrar para MySQL/PostgreSQL:
```php
// Substituir file_get_contents/file_put_contents por PDO
$pdo = new PDO('mysql:host=db;dbname=chat', $user, $pass);
```

## 🤝 Contribuição

1. **Fork** o repositório
2. Crie uma **branch** para sua feature (`git checkout -b feature/nova-feature`)
3. **Commit** suas mudanças (`git commit -am 'Adiciona nova feature'`)
4. **Push** para a branch (`git push origin feature/nova-feature`)
5. Abra um **Pull Request**

### Diretrizes de Contribuição

- Siga PSR-12 para código PHP
- Teste todos os scripts antes de enviar
- Documente novas features
- Mantenha compatibilidade com versões anteriores

## 📝 Licença

Este projeto está sob a licença **MIT**. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 👨‍💻 Autor

**Zóio The Green Eye**
- GitHub: [@zoio-the-green-eye](#)
- Website: [linuxuniverse.com.br](#)

## 🙏 Agradecimentos

- **Apache Foundation** - Servidor web
- **PHP Community** - Linguagem de programação
- **Docker** - Containerização
- **Contribuidores** - Melhorias e sugestões

## 📞 Suporte

- **Issues**: [GitHub Issues](#)
- **Discussões**: [GitHub Discussions](#)
- **Email**: contato@exemplo.com

---

<div align="center">

**💬 Desenvolvido com ❤️ para facilitar a comunicação em equipes**

[⭐ Star](https://github.com/usuario/chat-docker) | [🐛 Reportar Bug](https://github.com/usuario/chat-docker/issues) | [💡 Sugerir Feature](https://github.com/usuario/chat-docker/issues)

</div>
