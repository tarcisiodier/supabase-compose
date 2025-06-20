#!/bin/bash
# Script de Diagnóstico Supabase Docker
echo "🔍 DIAGNÓSTICO SUPABASE DOCKER"
echo "=============================="

# Verificar se o Docker está rodando
echo "1️⃣ Verificando Docker..."
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando!"
    exit 1
else
    echo "✅ Docker está funcionando"
fi

# Verificar arquivo .env
echo
echo "2️⃣ Verificando arquivo .env..."
if [ ! -f .env ]; then
    echo "❌ Arquivo .env não encontrado!"
    echo "   Crie o arquivo .env com as variáveis necessárias"
    exit 1
else
    echo "✅ Arquivo .env encontrado"
    # Verificar variáveis essenciais
    missing_vars=()
    required_vars=("POSTGRES_PASSWORD" "JWT_SECRET" "ANON_KEY" "SERVICE_ROLE_KEY")
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo "❌ Variáveis em falta no .env:"
        printf '   %s\n' "${missing_vars[@]}"
    else
        echo "✅ Variáveis essenciais presentes"
    fi
fi

# Verificar estrutura de diretórios
echo
echo "3️⃣ Verificando estrutura de diretórios..."
required_dirs=("volumes/api" "volumes/db" "volumes/storage" "volumes/logs" "volumes/functions" "volumes/pooler")
missing_dirs=()

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ ${#missing_dirs[@]} -ne 0 ]; then
    echo "❌ Diretórios em falta:"
    printf '   %s\n' "${missing_dirs[@]}"
    echo "   Execute: mkdir -p ${missing_dirs[*]}"
else
    echo "✅ Estrutura de diretórios OK"
fi

# Verificar status dos serviços
echo
echo "4️⃣ Status dos serviços Docker..."
if docker compose ps > /dev/null 2>&1; then
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"
else
    echo "❌ Erro ao verificar serviços"
fi

# Verificar logs de serviços que falharam
echo
echo "5️⃣ Verificando logs de serviços com problemas..."
failed_services=$(docker compose ps --filter "status=exited" --format "{{.Service}}" 2>/dev/null)

if [ -n "$failed_services" ]; then
    echo "❌ Serviços que falharam:"
    echo "$failed_services"
    echo
    echo "📋 Logs dos últimos erros:"
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            echo "--- Logs do $service ---"
            docker compose logs --tail=10 "$service"
            echo
        fi
    done <<< "$failed_services"
else
    echo "✅ Nenhum serviço falhou"
fi

# Verificar conectividade de rede
echo
echo "6️⃣ Verificando conectividade..."
if docker compose exec -T db pg_isready -U postgres -h localhost > /dev/null 2>&1; then
    echo "✅ Banco de dados responsivo"
else
    echo "❌ Banco de dados não responsivo"
fi

# Verificar portas em uso
echo
echo "7️⃣ Verificando portas..."
ports=("5432" "54321" "54322" "54323" "54324")
for port in "${ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t > /dev/null 2>&1; then
        echo "✅ Porta $port em uso"
    else
        echo "⚠️  Porta $port livre"
    fi
done

echo
echo "🏁 DIAGNÓSTICO CONCLUÍDO"
echo "======================="
echo
echo "💡 PRÓXIMOS PASSOS:"
echo "1. Corrija os problemas encontrados acima"
echo "2. Execute: docker compose down -v"
echo "3. Execute: docker compose up -d"
echo "4. Aguarde todos os serviços ficarem healthy"
echo "5. Acesse: http://localhost:54323"