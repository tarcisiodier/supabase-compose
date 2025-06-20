#!/bin/bash
# Script de Configuração Inicial Supabase
set -e

echo "🚀 CONFIGURAÇÃO INICIAL SUPABASE"
echo "================================"

# Criar diretórios necessários
echo "1️⃣ Criando estrutura de diretórios..."
mkdir -p volumes/{api,db/data,storage,logs,functions,pooler}
echo "✅ Diretórios criados"

# Configurar kong.yml básico
echo
echo "2️⃣ Configurando Kong..."
cat > volumes/api/kong.yml << 'EOF'
_format_version: "2.1"
_transform: true

consumers:
  - username: anon
    keyauth_credentials:
      - key: ${SUPABASE_ANON_KEY}
  - username: service_role
    keyauth_credentials:
      - key: ${SUPABASE_SERVICE_KEY}

acls:
  - consumer: anon
    group: anon
  - consumer: service_role
    group: admin

services:
  - name: auth-v1-open
    url: http://auth:9999/
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - "/auth/v1/settings"
          - "/auth/v1/signup"
          - "/auth/v1/signin"
          - "/auth/v1/recover"
          - "/auth/v1/resend"
          - "/auth/v1/logout"
          - "/auth/v1/authorize"
          - "/auth/v1/callback"
          - "/auth/v1/user"
          - "/auth/v1/verify"
          - "/auth/v1/token"
          - "/auth/v1/admin"

  - name: auth-v1-open-authorize
    url: http://auth:9999/authorize
    routes:
      - name: auth-v1-open-authorize
        strip_path: true
        paths:
          - "/auth/v1/authorize"

  - name: auth-v1-open-callback
    url: http://auth:9999/callback
    routes:
      - name: auth-v1-open-callback
        strip_path: true
        paths:
          - "/auth/v1/callback"

  - name: auth-v1-open-verify
    url: http://auth:9999/verify
    routes:
      - name: auth-v1-open-verify
        strip_path: true
        paths:
          - "/auth/v1/verify"

  - name: rest-v1
    url: http://rest:3000/
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - "/rest/v1/"
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: realtime-v1
    url: http://realtime:4000/socket/
    routes:
      - name: realtime-v1-all
        strip_path: true
        paths:
          - "/realtime/v1/"
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: storage-v1
    url: http://storage:5000/
    routes:
      - name: storage-v1-all
        strip_path: true
        paths:
          - "/storage/v1/"
    plugins:
      - name: cors

  - name: functions-v1
    url: http://functions:9000/
    routes:
      - name: functions-v1-all
        strip_path: true
        paths:
          - "/functions/v1/"
    plugins:
      - name: cors

  - name: meta
    url: http://meta:8080/
    routes:
      - name: meta-all
        strip_path: true
        paths:
          - "/pg/"

  - name: dashboard
    url: http://studio:3000/
    routes:
      - name: dashboard-all
        strip_path: false
        paths:
          - "/"
    plugins:
      - name: cors
      - name: basic-auth
        config:
          hide_credentials: true
EOF
echo "✅ Kong configurado"

# Configurar vector.yml
echo
echo "3️⃣ Configurando Vector..."
cat > volumes/logs/vector.yml << 'EOF'
api:
  enabled: true
  address: 127.0.0.1:8686
  playground: false

sources:
  docker_host:
    type: docker_logs
    include_labels:
      - com.docker.compose.project=supabase

transforms:
  project_logs:
    type: remap
    inputs:
      - docker_host
    source: |
      # Only capture logs for services we care about
      .container_name = get!(.label."com.docker.compose.service")
      
      # Drop logs from services that are too verbose
      if includes(["imgproxy", "vector"], .container_name) {
        abort
      }

sinks:
  logflare_logs:
    type: http
    inputs:
      - project_logs
    uri: http://analytics:4000/api/logs
    method: post
    compression: none
    healthcheck:
      enabled: true
    headers:
      Content-Type: application/json
      X-API-KEY: "${LOGFLARE_API_KEY}"
    encoding:
      codec: json
    batch:
      max_bytes: 1048576
    buffer:
      type: disk
      max_size: 104857600
      when_full: drop_newest
    request:
      retry_attempts: 10
EOF
echo "✅ Vector configurado"

# Configurar pooler.exs básico
echo
echo "4️⃣ Configurando Pooler..."
cat > volumes/pooler/pooler.exs << 'EOF'
# Basic pooler configuration
:ok
EOF
echo "✅ Pooler configurado"

# Verificar se .env existe
echo
echo "5️⃣ Verificando .env..."
if [ ! -f .env ]; then
    echo "⚠️  Arquivo .env não encontrado!"
    echo "   Criando .env básico..."
    
    # Gerar JWT_SECRET aleatório
    jwt_secret=$(openssl rand -base64 64 | tr -d '\n')
    postgres_password=$(openssl rand -base64 32 | tr -d '\n')
    secret_key_base=$(openssl rand -base64 64 | tr -d '\n')
    vault_enc_key=$(openssl rand -base64 32 | tr -d '\n')
    logflare_api_key=$(openssl rand -hex 20)
    
    cat > .env << EOF
# Supabase Local Development Environment
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_PASSWORD=$postgres_password

API_EXTERNAL_URL=http://localhost:54321
SUPABASE_PUBLIC_URL=http://localhost:54321

SITE_URL=http://localhost:3000
ADDITIONAL_REDIRECT_URLS=
JWT_EXPIRY=3600
DISABLE_SIGNUP=false
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=true
ENABLE_ANONYMOUS_USERS=false

PGRST_DB_SCHEMAS=public,storage,graphql_public

DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=supabase

JWT_SECRET=$jwt_secret
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU

SECRET_KEY_BASE=$secret_key_base
VAULT_ENC_KEY=$vault_enc_key
LOGFLARE_API_KEY=$logflare_api_key
DOCKER_SOCKET_LOCATION=/var/run/docker.sock

STUDIO_DEFAULT_ORGANIZATION=Default Organization
STUDIO_DEFAULT_PROJECT=Default Project
OPENAI_API_KEY=

POOLER_TENANT_ID=localhost
POOLER_DEFAULT_POOL_SIZE=20
POOLER_MAX_CLIENT_CONN=100

FUNCTIONS_VERIFY_JWT=false
IMGPROXY_ENABLE_WEBP_DETECTION=false
EOF
    echo "✅ Arquivo .env criado com valores aleatórios seguros"
else
    echo "✅ Arquivo .env já existe"
fi

# Criar função main básica
echo
echo "6️⃣ Criando função main básica..."
mkdir -p volumes/functions
cat > volumes/functions/main/index.ts << 'EOF'
// Main function for Supabase Edge Functions
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

console.log("Hello from Functions!")

serve(async (req) => {
  const { name } = await req.json()
  const data = {
    message: `Hello ${name}!`,
  }

  return new Response(
    JSON.stringify(data),
    { headers: { "Content-Type": "application/json" } },
  )
})
EOF
echo "✅ Função main criada"

echo
echo "✅ CONFIGURAÇÃO CONCLUÍDA!"
echo "=========================="
echo
echo "📋 PRÓXIMOS PASSOS:"
echo "1. Execute: chmod +x diagnose.sh"
echo "2. Execute: ./diagnose.sh"
echo "3. Execute: docker compose down -v"
echo "4. Execute: docker compose up -d"
echo "5. Aguarde todos os serviços ficarem healthy"
echo "6. Acesse: http://localhost:54323"
echo
echo "🔐 CREDENCIAIS:"
echo "Dashboard: supabase / supabase"
echo "Database: postgres / [senha no .env]"