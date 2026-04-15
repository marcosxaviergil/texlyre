# syntax=docker/dockerfile:1

# ─── Stage 1: build ───────────────────────────────────────────────────────────
FROM node:24-alpine AS builder

WORKDIR /app

# Instala dependências primeiro (melhor uso de cache de layers)
COPY package.json package-lock.json ./
RUN npm ci --prefer-offline

# Copia o restante do código-fonte
COPY . .

# Build de produção (gera generate-configs, i18n, tsc, vite build)
RUN npm run build:prod

# ─── Stage 2: serve ───────────────────────────────────────────────────────────
FROM nginx:stable-alpine

# Remove configuração padrão
RUN rm /etc/nginx/conf.d/default.conf

# Configuração nginx para SPA com base path /texlyre/
COPY <<'EOF' /etc/nginx/conf.d/texlyre.conf
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Rota base: redireciona / → /texlyre/
    location = / {
        return 301 /texlyre/;
    }

    # Serve o app sob /texlyre/ — fallback para index.html (SPA routing)
    location /texlyre/ {
        try_files $uri $uri/ /texlyre/index.html;
    }

    # Assets com cache agressivo
    location ~* \.(js|css|wasm|woff2|ttf|otf|png|svg|ico|json|bcmap|wav)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Health check
    location /healthz {
        return 200 "ok\n";
        add_header Content-Type text/plain;
        access_log off;
    }
}
EOF

# Copia o artefato de build para o webroot
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]