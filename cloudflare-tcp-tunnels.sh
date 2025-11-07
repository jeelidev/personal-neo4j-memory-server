#!/bin/bash
# cloudflare-tcp-tunnels-final.sh - Versión final con persistencia robusta
# Script para iniciar túneles cloudflared access para cualquier servicio TCP

# Directorios y archivos
CONFIG_DIR="/home/necrowolf/.cloudflare-tunnels"
LOG_FILE="/tmp/cloudflare-tcp-tunnels-final.log"
PID_FILE="/tmp/cloudflare-tcp-tunnels-final.pid"

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
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$PID_FILE")"
    mkdir -p "$CONFIG_DIR"
    touch "$LOG_FILE" "$PID_FILE"
    chmod 666 "$LOG_FILE" "$PID_FILE"
}

# Función para obtener lista de túneles
get_tunnel_list() {
    if [ -d "$CONFIG_DIR" ]; then
        find "$CONFIG_DIR" -name "*.conf" -exec basename {} .conf \; | sort
    fi
}

# Función para obtener información de un túnel
get_tunnel_info() {
    local name="$1"
    local config_file="$CONFIG_DIR/$name.conf"
    if [ -f "$config_file" ]; then
        cat "$config_file"
    fi
}

# Función para guardar túnel
save_tunnel() {
    local name="$1"
    local info="$2"
    local config_file="$CONFIG_DIR/$name.conf"
    echo "$info" > "$config_file"
    log "💾 Túnel $name guardado en $config_file"
}

# Función para eliminar túnel
remove_tunnel_file() {
    local name="$1"
    local config_file="$CONFIG_DIR/$name.conf"
    if [ -f "$config_file" ]; then
        rm -f "$config_file"
        log "🗑️  Archivo de túnel eliminado: $config_file"
    fi
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

    local tunnel_list=$(get_tunnel_list)
    if [ -z "$tunnel_list" ]; then
        log "⚠️  No hay túneles configurados. Usa '$0 add' para agregar túneles."
        return 1
    fi

    # Iniciar cada túnel en background
    for name in $tunnel_list; do
        local tunnel_info=$(get_tunnel_info "$name")
        IFS=':' read -r hostname port <<< "$tunnel_info"

        log "🔗 Iniciando túnel $name: $hostname -> localhost:$port"

        # Iniciar túnel en background
        cloudflared access tcp --hostname "$hostname" --url "localhost:$port" >> "$LOG_FILE" 2>&1 &

        # Guardar PID
        local tunnel_pid=$!
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

    local tunnel_list=$(get_tunnel_list)
    if [ -z "$tunnel_list" ]; then
        printf "%-20s %-30s %-10s %-10s\n" "(ninguno)" "---" "---" "❌ VACÍO"
    else
        for name in $tunnel_list; do
            local tunnel_info=$(get_tunnel_info "$name")
            IFS=':' read -r hostname port <<< "$tunnel_info"

            if timeout 3 netcat -zv localhost "$port" 2>&1 | grep -q "succeeded"; then
                status="✅ ACTIVO"
            else
                status="❌ INACTIVO"
            fi

            printf "%-20s %-30s %-10s %-10s\n" "$name" "$hostname" "$port" "$status"
        done
    fi
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

    # Verificar si ya existe
    if [ -f "$CONFIG_DIR/$name.conf" ]; then
        local existing_info=$(get_tunnel_info "$name")
        log "⚠️  El túnel '$name' ya existe: $existing_info"
        log "💡 Usa '$0 remove $name' primero para eliminarlo"
        exit 1
    fi

    # Guardar túnel
    save_tunnel "$name" "$hostname:$port"

    log "➕ Túnel $name agregado: $hostname -> localhost:$port"
    log "💡 Ejecuta '$0 restart' para activar el nuevo túnel"
}

# Función para eliminar túnel existente
remove_tunnel() {
    if [ $# -ne 1 ]; then
        echo "Uso: $0 remove <nombre>"
        echo "Ejemplo: $0 remove mi-servicio"
        echo "Use '$0 list' para ver todos los túneles configurados"
        exit 1
    fi

    local name="$1"

    # Verificar si el túnel existe
    if [ ! -f "$CONFIG_DIR/$name.conf" ]; then
        log "❌ ERROR: El túnel '$name' no existe"
        log "💡 Usa '$0 list' para ver los túneles disponibles"
        exit 1
    fi

    # Obtener información del túnel antes de eliminar
    local tunnel_info=$(get_tunnel_info "$name")
    IFS=':' read -r hostname port <<< "$tunnel_info"

    # Detener el túnel si está corriendo
    log "🔄 Deteniendo túnel '$name' si está corriendo..."
    if [ -f "$PID_FILE" ]; then
        while IFS=':' read -r pid pid_name pid_hostname pid_port; do
            if [ "$pid_name" = "$name" ] && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                log "🔌 Detenido túnel $name (PID: $pid)"
                # Remover del archivo PID
                grep -v ":$name:" "$PID_FILE" > "${PID_FILE}.tmp" 2>/dev/null || true
                mv "${PID_FILE}.tmp" "$PID_FILE" 2>/dev/null || true
                break
            fi
        done < "$PID_FILE"
    fi

    # Eliminar archivo de configuración
    remove_tunnel_file "$name"

    log "🗑️  Túnel '$name' eliminado: $hostname -> localhost:$port"
    log "💡 El túnel ha sido removido permanentemente de la configuración"
    log "🔄 Si necesitas detener y reiniciar todos los túneles, ejecuta '$0 restart'"
}

# Función para listar túneles configurados
list_tunnels() {
    log "📋 Túneles configurados:"
    echo ""
    printf "%-20s %-30s %-10s\n" "NOMBRE" "HOSTNAME" "PUERTO"
    printf "%-20s %-30s %-10s\n" "------" "--------" "-----"

    local tunnel_list=$(get_tunnel_list)
    if [ -z "$tunnel_list" ]; then
        printf "%-20s %-30s %-10s\n" "(ninguno)" "---" "---"
    else
        for name in $tunnel_list; do
            local tunnel_info=$(get_tunnel_info "$name")
            IFS=':' read -r hostname port <<< "$tunnel_info"
            printf "%-20s %-30s %-10s\n" "$name" "$hostname" "$port"
        done
    fi
    echo ""
    log "📁 Configuración guardada en: $CONFIG_DIR"
}

# Función de help
show_help() {
    echo "Cloudflare TCP Tunnels Manager - Final Version con Persistencia Robusta"
    echo ""
    echo "Uso: $0 {start|stop|restart|status|list|add|remove|clean} [argumentos]"
    echo ""
    echo "Comandos:"
    echo "  start           - Inicia todos los túneles configurados"
    echo "  stop            - Detiene todos los túneles"
    echo "  restart         - Reinicia todos los túneles"
    echo "  status          - Muestra el estado de los túneles"
    echo "  list            - Lista los túneles configurados (persistentes)"
    echo "  add <name> <host> <port> - Agrega un nuevo túnel"
    echo "  remove <name>   - Elimina un túnel existente (persistente)"
    echo "  clean           - Limpia toda la configuración"
    echo ""
    echo "Ejemplos:"
    echo "  $0 start                           # Iniciar todos los túneles"
    echo "  $0 add mi-api api.jeelidev.uk 3000  # Agregar nuevo túnel"
    echo "  $0 remove mi-api                    # Eliminar túnel existente"
    echo "  $0 status                          # Ver estado"
    echo ""
    echo "Logs: $LOG_FILE"
    echo "PIDs: $PID_FILE"
    echo "Config: $CONFIG_DIR"
}

# Función para limpiar toda la configuración
clean_config() {
    log "🧹 Limpiando toda la configuración..."

    # Detener túneles primero
    stop_tunnels

    # Eliminar directorio de configuración
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        log "🗑️  Directorio de configuración eliminado: $CONFIG_DIR"
    fi

    log "✅ Configuración limpiada. Usa '$0 add' para agregar nuevos túneles."
}

# Inicialización
create_directories

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
    remove)
        remove_tunnel "$2"
        ;;
    clean)
        clean_config
        ;;
    *)
        show_help
        exit 1
        ;;
esac