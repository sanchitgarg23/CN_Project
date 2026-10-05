cat > ~/cn-phase1/edge/nginx/conf/nginx.conf <<EOF
worker_processes 1;

error_log logs/error.log;
pid run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    access_log logs/access.log;

    upstream backend_pool {
        server 10.81.95.70:3001;
        server 10.81.95.68:3002;
    }

    server {
        listen 443 ssl;
        server_name app.team1.test;

        ssl_certificate     $HOME/cn-phase1/edge/nginx/certs/app.team1.test.crt;
        ssl_certificate_key $HOME/cn-phase1/edge/nginx/certs/app.team1.test.key;

        ssl_protocols TLSv1.2 TLSv1.3;

        location / {
            proxy_pass http://backend_pool;

            proxy_http_version 1.1;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }
    }
}
EOF