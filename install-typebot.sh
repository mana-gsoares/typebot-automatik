#!/bin/bash

echo "
 ██████╗ ██████╗ ███╗   ███╗██╗   ██╗███╗   ██╗██╗██████╗  █████╗ ██████╗ ███████╗
██╔════╝██╔═══██╗████╗ ████║██║   ██║████╗  ██║██║██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║     ██║   ██║██╔████╔██║██║   ██║██╔██╗ ██║██║██║  ██║███████║██║  ██║█████╗  
██║     ██║   ██║██║╚██╔╝██║██║   ██║██║╚██╗██║██║██║  ██║██╔══██║██║  ██║██╔══╝  
╚██████╗╚██████╔╝██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║██████╔╝██║  ██║██████╔╝███████╗
 ╚═════╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝
                                                                                  
 █████╗ ██╗   ██╗████████╗ ██████╗ ███╗   ███╗ █████╗ ████████╗██╗██╗  ██╗        
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗████╗ ████║██╔══██╗╚══██╔══╝██║██║ ██╔╝        
███████║██║   ██║   ██║   ██║   ██║██╔████╔██║███████║   ██║   ██║█████╔╝         
██╔══██║██║   ██║   ██║   ██║   ██║██║╚██╔╝██║██╔══██║   ██║   ██║██╔═██╗         
██║  ██║╚██████╔╝   ██║   ╚██████╔╝██║ ╚═╝ ██║██║  ██║   ██║   ██║██║  ██╗        
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝╚═╝  ╚═╝        
                                                                                  
"
echo "Compartilhe Conhecimento"

# Default database settings
default_db_username="Community"
default_db_password="Automatik"
default_db_name="CommunityDB"
default_db_host="localhost"

echo "Deseja usar as configurações padrão do banco de dados (nome de usuário: $default_db_username, senha: $default_db_password, nome do banco de dados: $default_db_name, host: $default_db_host)? (s/n)"
read use_defaults

if [[ $use_defaults == 'n' || $use_defaults == 'N' ]]; then
    echo "Digite o nome de usuário do banco de dados:"
    read db_username
    echo "Digite a senha do banco de dados:"
    read db_password
    echo "Digite o nome do banco de dados:"
    read db_name
    echo "Digite o host do banco de dados:"
    read db_host
else
    db_username=$default_db_username
    db_password=$default_db_password
    db_name=$default_db_name
    db_host=$default_db_host
fi

echo "Digite o domínio do seu servidor:"
read domain

# Clone the repository
git clone https://github.com/baptisteArno/typebot.io.git

# Setup environment variables
cd typebot.io
git checkout $(git describe --tags `git rev-list --tags --max-count=1`)
cp packages/prisma/.env.example packages/prisma/.env
cp apps/builder/.env.local.example apps/builder/.env.local
cp apps/viewer/.env.local.example apps/viewer/.env.local

# Update the database details in the env files
echo "DATABASE_URL=\"postgresql://$db_username:$db_password@$db_host/$db_name\"" >> packages/prisma/.env
echo "NEXT_PUBLIC_PRISMA_URL=\"$db_host\"" >> apps/builder/.env.local
echo "NEXT_PUBLIC_PRISMA_URL=\"$db_host\"" >> apps/viewer/.env.local

# Install dependencies
pnpm install

# Build the builder and viewer
pnpm run build:apps

# Deploy the builder with PM2
pm2 start --name=typebot pnpm -- start

# Deploy the viewer with PM2
cd ../apps/viewer
pm2 start --name=typebot_viewer pnpm -- start

# Configure Nginx
echo "server {
    listen 80;
    server_name $domain www.$domain;
    return 301 https://$domain\$request_uri;
}

server {
    listen 443 ssl;
    server_name $domain www.$domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location ^~ / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}" > /etc/nginx/sites-available/typebot

# Enable the Nginx configuration
ln -s /etc/nginx/sites-available/typebot /etc/nginx/sites-enabled/

# Restart Nginx
service nginx restart
