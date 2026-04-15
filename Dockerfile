# syntax=docker/dockerfile:1

# ─── Stage 1: build ───────────────────────────────────────────────────────────
FROM node:24-alpine AS builder

WORKDIR /app

# Instala dependências primeiro
COPY package.json package-lock.json ./
RUN npm ci

# Copia o restante do código-fonte
COPY . .

# Build de produção
RUN npm run build:prod

# ─── Stage 2: serve ───────────────────────────────────────────────────────────
FROM nginx:stable-alpine

# Remove configuração padrão
RUN rm -f /etc/nginx/conf.d/default.conf

# Copia a configuração do nginx
COPY nginx/texlyre.conf /etc/nginx/conf.d/texlyre.conf

# Copia o build para o webroot
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]