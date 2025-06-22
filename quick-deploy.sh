#!/bin/bash
# quick-deploy.sh - Deploy super rápido em uma linha

set -e

echo "🚀 Chat Docker - Deploy Rápido"

# Configurações
IMAGE="chat-apache"
CONTAINER="chat-app" 
PORT="8080"

# Para container existente
docker stop $CONTAINER 2>/dev/null || true
docker rm $CONTAINER 2>/dev/null || true

# Cria Dockerfile on-the-fly se não existir
if [ ! -f "Dockerfile" ]; then
    echo "📝 Criando Dockerfile..."
    cat > Dockerfile << 'EOF'
FROM php:8.2-apache
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN a2enmod rewrite headers
RUN mkdir -p /var/www/html/chat/data
COPY . /var/www/html/chat/
RUN chown -R www-data:www-data /var/www/html/chat
RUN echo '<VirtualHost *:80>\nDocumentRoot /var/www/html/chat\n<Directory /var/www/html/chat>\nAllowOverride All\nRequire all granted\n</Directory>\n</VirtualHost>' > /etc/apache2/sites-available/000-default.conf
EXPOSE 80
CMD ["apache2-foreground"]
EOF
fi

# Build e run em comandos separados
echo "🔨 Building..."
docker build -t $IMAGE .

echo "🚀 Starting..."
docker run -d \
    --name $CONTAINER \
    --restart unless-stopped \
    -p $PORT:80 \
    -v chat_data:/var/www/html/chat/data \
    $IMAGE

# Aguarda container ficar ready
echo "⏳ Aguardando container..."
sleep 5

# Verifica se está rodando
if docker ps | grep -q $CONTAINER; then
    echo "✅ Deploy concluído!"
    echo "🌐 Acesse: http://localhost:$PORT/chat/"
    echo ""
    echo "📋 Comandos úteis:"
    echo "   Logs:    docker logs -f $CONTAINER"
    echo "   Shell:   docker exec -it $CONTAINER bash" 
    echo "   Stop:    docker stop $CONTAINER"
    echo "   Restart: docker restart $CONTAINER"
else
    echo "❌ Erro no deploy!"
    docker logs $CONTAINER
    exit 1
fi
