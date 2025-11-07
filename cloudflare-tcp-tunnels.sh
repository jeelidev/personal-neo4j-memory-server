#!/bin/bash
# cloudflare-tcp-tunnels.sh
# Script para iniciar túneles cloudflared access para cualquier servicio TCP

# Lista de túneles a iniciar (formato: nombre="hostname:puerto_local")
declare -A TUNNELS=(
    ["neo4j-bolt"]="neo4j-bolt.jeelidev.uk:7687"
    ["neo4j-routing"]="neo4j-routing.jeelidev.uk:7688"
    ["mysql-db"]="mysql-server.jeelidev.uk:3306"
    ["postgresql"]="postgres-server.jeelidev.uk:5432"
    ["ssh-server"]="ssh-server.jeelidev.uk:22"
    ["redis-cache"]="redis-server.jeelidev.uk:6379"
    ["mongodb"]="mongodb-server.jeelidev.uk:27017"
    ["game-server"]="minecraft-server.jeelidev.uk:25565"
    # Agregar más túneles aquí siguiendo el formato:
    # ["nombre-servicio"]="hostname.jeelidev.uk:puerto_local"
)

LOG_FILE="/var/log/cloudflare-tcp-tunnels.log"
PID_FILE="/var/run/cloudflare-tcp-tunnels.pid"

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para verificar si cloudflared está instalado
check_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        log "❌ ERROR: cloudflared no está instalado o no está en el PATH"
        log "Por favor, instala cloudflared: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
        exit 1
    fi
}

# Función para crear directorios necesarios
create_directories() {
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo mkdir -p "$(dirname "$PID_FILE")"
    sudo touch "$LOG_FILE" "$PID_FILE"
    sudo chmod 666 "$LOG_FILE" "$PID_FILE"
}

# Función para iniciar túneles
start_tunnels() {
    log "🚀 Iniciando túneles Cloudflare Access para servicios TCP..."

    # Verificar instalación
    check_cloudflared

    # Crear directorios
    create_directories

    # Limpiar procesos anteriores
    log "🧹 Limpiando procesos anteriores..."
    pkill -f "cloudflared access tcp" 2>/dev/null || true
    > "$PID_FILE"

    # Iniciar cada túnel en background
    for name in "${!TUNNELS[@]}"; do
        IFS=':' read -r hostname port <<< "${TUNNELS[$name]}"
        log "🔗 Iniciando túnel $name: $hostname -> localhost:$port"

        # Iniciar túnel en background
        cloudflared access tcp --hostname "$hostname" --url "localhost:$port" >> "$LOG_FILE" 2>&1 &

        # Guardar PID
        tunnel_pid=$!
        echo "$tunnel_pid:$name:$hostname:$port" >> "$PID_FILE"

        # Esperar a que se establezca la conexión
        log "⏳ Esperando que se establezca la conexión para $name..."
        sleep 3

        # Verificar que el túnel esté funcionando
        if timeout 5 netcat -zv localhost "$port" 2>&1 | grep -q "succeeded"; then
            log "✅ Túnel $name establecido exitosamente en puerto $port (PID: $tunnel_pid)"
        else
            log "⚠️  Puerto $port no está respondiendo localmente, pero el túnel $name está iniciado"
            log "   (Esto es normal si el servicio local no está corriendo)"
        fi
    done

    log "🎉 Todos los túneles han sido iniciados"
    log "📊 Estado final:"
    show_status
}

# Función para detener túneles
stop_tunnels() {
    log "🛑 Deteniendo túneles Cloudflare Access..."

    if [ -f "$PID_FILE" ]; then
        while IFS=':' read -r pid name hostname port; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                log "🔌 Detenido túnel $name (PID: $pid)"
            fi
        done < "$PID_FILE"

        rm -f "$PID_FILE"
    fi

    # Matar cualquier proceso residual
    pkill -f "cloudflared access tcp" 2>/dev/null || true

    log "✅ Todos los túneles han sido detenidos"
}

# Función para mostrar estado
show_status() {
    log "📊 Estado de los túneles TCP:"
    echo ""
    printf "%-20s %-30s %-10s %-10s\n" "SERVICIO" "HOSTNAME" "PUERTO" "ESTADO"
    printf "%-20s %-30s %-10s %-10s\n" "--------" "--------" "-----" "------"

    for name in "${!TUNNELS[@]}"; do
        IFS=':' read -r hostname port <<< "${TUNNELS[$name]}"

        if timeout 3 netcat -zv localhost "$port" 2>&1 | grep -q "succeeded"; then
            status="✅ ACTIVO"
        else
            status="❌ INACTIVO"
        fi

        printf "%-20s %-30s %-10s %-10s\n" "$name" "$hostname" "$port" "$status"
    done
    echo ""
}

# Función para agregar nuevo túnel
add_tunnel() {
    if [ $# -ne 3 ]; then
        echo "Uso: $0 add <nombre> <hostname> <puerto>"
        echo "Ejemplo: $0 add mi-servicio mi-servicio.jeelidev.uk 8080"
        exit 1
    fi

    local name="$1"
    local hostname="$2"
    local port="$3"

    # Validar puerto
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log "❌ ERROR: Puerto inválido: $port"
        exit 1
    fi

    # Agregar al array de túneles
    TUNNELS["$name"]="$hostname:$port"

    log "➕ Túnel $name agregado: $hostname -> localhost:$port"
    log "💡 Ejecuta '$0 restart' para activar el nuevo túnel"
}

# Función para listar túneles configurados
list_tunnels() {
    log "📋 Túneles configurados:"
    echo ""
    printf "%-20s %-30s %-10s\n" "NOMBRE" "HOSTNAME" "PUERTO"
    printf "%-20s %-30s %-10s\n" "------" "--------" "-----"

    for name in "${!TUNNELS[@]}"; do
        IFS=':' read -r hostname port <<< "${TUNNELS[$name]}"
        printf "%-20s %-30s %-10s\n" "$name" "$hostname" "$port"
    done
    echo ""
}

# Función de help
show_help() {
    echo "Cloudflare TCP Tunnels Manager"
    echo ""
    echo "Uso: $0 {start|stop|restart|status|list|add} [argumentos]"
    echo ""
    echo "Comandos:"
    echo "  start           - Inicia todos los túneles configurados"
    echo "  stop            - Detiene todos los túneles"
    echo "  restart         - Reinicia todos los túneles"
    echo "  status          - Muestra el estado de los túneles"
    echo "  list            - Lista los túneles configurados"
    echo "  add <name> <host> <port> - Agrega un nuevo túnel"
    echo ""
    echo "Ejemplos:"
    echo "  $0 start                           # Iniciar todos los túneles"
    echo "  $0 add mi-api api.jeelidev.uk 3000  # Agregar nuevo túnel"
    echo "  $0 status                          # Ver estado"
    echo ""
    echo "Logs: $LOG_FILE"
    echo "PIDs: $PID_FILE"
}

# Main
case "$1" in
    start)
        start_tunnels
        ;;
    stop)
        stop_tunnels
        ;;
    restart)
        stop_tunnels
        sleep 2
        start_tunnels
        ;;
    status)
        show_status
        ;;
    list)
        list_tunnels
        ;;
    add)
        add_tunnel "$2" "$3" "$4"
        ;;
    *)
        show_help
        exit 1
        ;;
esac