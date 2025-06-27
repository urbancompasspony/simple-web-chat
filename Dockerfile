# Dockerfile para Chat PHP no Apache
FROM php:8.2-apache

# Informações do container
LABEL maintainer="chat-app"
LABEL description="Chat PHP com Apache2"

# Instala dependências necessárias
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip \
    unzip \
    nano \
    curl \
    && docker-php-ext-install zip \
    && rm -rf /var/lib/apt/lists/*

# Habilita módulos Apache necessários
RUN a2enmod rewrite headers deflate expires

# Cria diretório do chat
RUN mkdir -p /var/www/html/chat

# Define diretório de trabalho
WORKDIR /var/www/html/chat

# Copia arquivos do chat
COPY index.php /var/www/html/chat/
COPY api.php /var/www/html/chat/
COPY .htaccess /var/www/html/chat/

# Cria pasta de dados com permissões corretas
RUN mkdir -p /var/www/html/chat/data && \
    chown -R www-data:www-data /var/www/html/chat && \
    chmod 755 /var/www/html/chat && \
    chmod 644 /var/www/html/chat/*.php && \
    chmod 644 /var/www/html/chat/.htaccess && \
    chmod 755 /var/www/html/chat/data

# Configuração personalizada do Apache
COPY apache-chat.conf /etc/apache2/sites-available/chat.conf
COPY manage-users.sh /usr/bin/manage-users.sh

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

# Script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/bin/manage-users.sh

# Expõe porta 80
EXPOSE 80

# Comando de inicialização
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
