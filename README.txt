# simple-web-chat
it is really simple!

# Habilita módulos necessários
sudo a2enmod rewrite
sudo a2enmod headers
sudo a2enmod deflate
sudo a2enmod expires

# Reinicia Apache
sudo systemctl restart apache2

# Define permissões corretas
sudo chown -R www-data:www-data /var/www/html/chat/
sudo chmod 755 /var/www/html/chat/
sudo chmod 644 /var/www/html/chat/*.php
sudo chmod 644 /var/www/html/chat/.htaccess

# Cria pasta de dados com permissões de escrita
mkdir -p /var/www/html/chat/data
sudo chown www-data:www-data /var/www/html/chat/data
sudo chmod 755 /var/www/html/chat/data

VHOST:

# /etc/apache2/sites-available/chat.conf
<VirtualHost *:80>
    ServerName chat.seudominio.com
    DocumentRoot /var/www/html/chat
    
    <Directory /var/www/html/chat>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/chat_error.log
    CustomLog ${APACHE_LOG_DIR}/chat_access.log combined
</VirtualHost>

Acesso:

Local: http://localhost/chat/
Rede: http://seu-ip/chat/
Domínio: http://seudominio.com/chat/

# 1. Copia os arquivos para o Apache
sudo cp index.php /var/www/html/chat/
sudo cp api.php /var/www/html/chat/
sudo cp .htaccess /var/www/html/chat/

# 2. Define permissões
sudo chown -R www-data:www-data /var/www/html/chat/

# 3. Acessa o chat
# http://localhost/chat/

# 1. Roda servidor WebSocket separado
node server.js  # Na porta 3000

# 2. Configura proxy no Apache
sudo a2enmod proxy proxy_http proxy_wstunnel
sudo a2ensite chat-websocket.conf
sudo systemctl reload apache2

# 3. Acessa o chat
# http://chat.seudominio.com/
