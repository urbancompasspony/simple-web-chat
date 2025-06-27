# Dockerfile para Chat PHP no Apache com Autenticação
FROM php:8.2-apache

# Informações do container
LABEL maintainer="chat-app"
LABEL description="Chat PHP com Apache2 e Autenticação"

# Instala dependências necessárias (incluindo apache2-utils para htpasswd)
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip \
    unzip \
    nano \
    curl \
    apache2-utils \
    && docker-php-ext-install zip \
    && rm -rf /var/lib/apt/lists/*

# Habilita módulos Apache necessários (incluindo auth_basic)
RUN a2enmod rewrite headers deflate expires auth_basic authz_user

# Cria diretório do chat
RUN mkdir -p /var/www/html/chat/data

# Define diretório de trabalho
WORKDIR /var/www/html/chat

# Copia arquivos do chat
COPY index.php /var/www/html/chat/
COPY api.php /var/www/html/chat/
COPY .htaccess /var/www/html/chat/

# Scripts de gerenciamento
COPY docker-entrypoint.sh /usr/local/bin/
COPY manage-users.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/manage-users.sh

# Cria pasta de dados com permissões corretas
RUN mkdir -p /var/www/html/chat/data && \
    chown -R www-data:www-data /var/www/html/chat && \
    chmod 755 /var/www/html/chat && \
    chmod 644 /var/www/html/chat/*.php && \
    chmod 644 /var/www/html/chat/.htaccess && \
    chmod 644 /var/www/html/chat/.htpasswd 2>/dev/null || true && \
    chmod 755 /var/www/html/chat/data

# Configuração personalizada do Apache
COPY apache-chat.conf /etc/apache2/sites-available/chat.conf

# Habilita site do chat
RUN a2ensite chat && a2dissite 000-default

# Configurações PHP customizadas
RUN echo "max_execution_time = 30" >> /usr/local/etc/php/conf.d/chat.ini && \
    echo "memory_limit = 128M" >> /usr/local/etc/php/conf.d/chat.ini && \
    echo "upload_max_filesize = 10M" >> /usr/local/etc/php/conf.d/chat.ini && \
    echo "post_max_size = 10M" >> /usr/local/etc/php/conf.d/chat.ini && \
    echo "max_input_vars = 1000" >> /usr/local/etc/php/conf.d/chat.ini && \
    echo "display_errors = Off" >> /usr/local/etc/php/conf.d/chat.ini && \
    echo "log_errors = On" >> /usr/local/etc/php/conf.d/chat.ini

# Variáveis de ambiente para autenticação
ENV CHAT_USERNAME=admin
ENV CHAT_PASSWORD=senha123
ENV CHAT_REALM="Chat Privado - Digite a senha"

# Expõe porta 80
EXPOSE 80

# Comando de inicialização
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
