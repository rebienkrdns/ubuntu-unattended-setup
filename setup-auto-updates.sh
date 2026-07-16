#!/usr/bin/env bash
# =============================================================================
# setup-auto-updates.sh
# Configura actualizaciones automáticas de seguridad en Ubuntu Server
# con reinicio controlado los domingos a las 5:30 AM (solo si es necesario).
#
# Uso:
#   sudo bash setup-auto-updates.sh [opciones]
#
# Opciones:
#   -d, --day     Día de la semana para reboot (0=domingo ... 6=sábado) [default: 0]
#   -t, --time    Hora del reboot en formato HH:MM [default: 05:30]
#   -e, --email   Email para notificaciones (opcional)
#   -a, --all     Incluir todas las actualizaciones, no solo seguridad
#   -h, --help    Mostrar esta ayuda
#
# Ejemplos:
#   sudo bash setup-auto-updates.sh
#   sudo bash setup-auto-updates.sh --day 0 --time 05:30 --email admin@miserver.com
#   sudo bash setup-auto-updates.sh --all --time 03:00
# =============================================================================

set -euo pipefail

# ──────────────────────────────────────────────
# Colores
# ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✔${NC}  $*"; }
info() { echo -e "${BLUE}ℹ${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
fail() { echo -e "${RED}✘${NC}  $*"; exit 1; }

# ──────────────────────────────────────────────
# Valores por defecto
# ──────────────────────────────────────────────
REBOOT_DAY=0        # 0 = domingo
REBOOT_TIME="05:30"
NOTIFY_EMAIL=""
ALL_UPDATES=false

# ──────────────────────────────────────────────
# Parsear argumentos
# ──────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--day)    REBOOT_DAY="$2";   shift 2 ;;
    -t|--time)   REBOOT_TIME="$2";  shift 2 ;;
    -e|--email)  NOTIFY_EMAIL="$2"; shift 2 ;;
    -a|--all)    ALL_UPDATES=true;  shift   ;;
    -h|--help)   usage ;;
    *) fail "Argumento desconocido: $1. Usa --help para ver opciones." ;;
  esac
done

# ──────────────────────────────────────────────
# Validaciones
# ──────────────────────────────────────────────
[[ $EUID -ne 0 ]] && fail "Este script debe ejecutarse como root (sudo)."

if ! command -v apt &>/dev/null; then
  fail "Este script es solo para sistemas basados en Debian/Ubuntu."
fi

# Validar día (0-6)
if ! [[ "$REBOOT_DAY" =~ ^[0-6]$ ]]; then
  fail "El día debe ser un número entre 0 (domingo) y 6 (sábado)."
fi

# Validar hora HH:MM
if ! [[ "$REBOOT_TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
  fail "La hora debe estar en formato HH:MM (ej: 05:30)."
fi

CRON_HOUR="${REBOOT_TIME%:*}"
CRON_MIN="${REBOOT_TIME#*:}"

DAYS=("domingo" "lunes" "martes" "miércoles" "jueves" "viernes" "sábado")
DAY_NAME="${DAYS[$REBOOT_DAY]}"

# ──────────────────────────────────────────────
# Resumen antes de aplicar
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║      CONFIGURACIÓN AUTO-UPDATES          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Actualizaciones : $([ "$ALL_UPDATES" = true ] && echo 'Seguridad + todas' || echo 'Solo seguridad')"
echo -e "  Reboot           : ${DAY_NAME}s a las ${REBOOT_TIME}"
echo -e "  Notificaciones   : ${NOTIFY_EMAIL:-'desactivadas'}"
echo ""
read -r -p "¿Continuar con esta configuración? [s/N] " confirm
[[ "$confirm" =~ ^[sS]$ ]] || { info "Cancelado."; exit 0; }
echo ""

# ──────────────────────────────────────────────
# 1. Instalar paquetes necesarios
# ──────────────────────────────────────────────
info "Instalando unattended-upgrades..."
apt-get update -qq
apt-get install -y -qq unattended-upgrades update-notifier-common apt-listchanges
ok "Paquetes instalados."

# ──────────────────────────────────────────────
# 2. Configurar /etc/apt/apt.conf.d/50unattended-upgrades
# ──────────────────────────────────────────────
info "Escribiendo configuración principal..."

DISTRO_ID=$(lsb_release -is 2>/dev/null || echo "Ubuntu")
DISTRO_CODENAME=$(lsb_release -cs 2>/dev/null || echo "noble")

MAIL_BLOCK=""
if [[ -n "$NOTIFY_EMAIL" ]]; then
  MAIL_BLOCK="Unattended-Upgrade::Mail \"${NOTIFY_EMAIL}\";
Unattended-Upgrade::MailReport \"on-change\";"
fi

ALL_UPDATES_LINE=""
if [[ "$ALL_UPDATES" = true ]]; then
  ALL_UPDATES_LINE="    \"${DISTRO_ID}:\${distro_codename}-updates\";"
fi

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
// Configurado por setup-auto-updates.sh — $(date '+%Y-%m-%d %H:%M')
// Reboot: ${DAY_NAME}s ${REBOOT_TIME} | Email: ${NOTIFY_EMAIL:-ninguno}

Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "Ubuntu:${DISTRO_CODENAME}-security";
${ALL_UPDATES_LINE}
};

// Paquetes que NUNCA se deben actualizar automáticamente
Unattended-Upgrade::Package-Blacklist {
    // "nginx";
    // "mysql-server";
};

// Eliminar dependencias huérfanas después de actualizar
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// NO reiniciar automáticamente (el cron se encarga)
Unattended-Upgrade::Automatic-Reboot "false";

// Registrar logs detallados
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";

${MAIL_BLOCK}
EOF

ok "Archivo 50unattended-upgrades configurado."

# ──────────────────────────────────────────────
# 3. Configurar /etc/apt/apt.conf.d/20auto-upgrades
# ──────────────────────────────────────────────
info "Configurando periodicidad de APT..."

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
// Configurado por setup-auto-updates.sh — $(date '+%Y-%m-%d %H:%M')
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

ok "Periodicidad configurada (actualización diaria, limpieza semanal)."

# ──────────────────────────────────────────────
# 4. Crear script de reboot controlado
# ──────────────────────────────────────────────
info "Creando script de reboot controlado..."

cat > /usr/local/bin/auto-reboot-if-needed.sh <<'REBOOT_SCRIPT'
#!/usr/bin/env bash
# auto-reboot-if-needed.sh
# Ejecutado por cron: aplica upgrades pendientes y reinicia solo si hace falta.

LOG="/var/log/auto-reboot.log"
REBOOT_FLAG="/var/run/reboot-required"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$TIMESTAMP] $*" | tee -a "$LOG"; }

log "=== Inicio de ciclo de mantenimiento ==="

# Aplicar actualizaciones pendientes
log "Ejecutando unattended-upgrade..."
if /usr/bin/unattended-upgrade 2>&1 | tee -a "$LOG"; then
  log "unattended-upgrade completado correctamente."
else
  log "ADVERTENCIA: unattended-upgrade retornó un error."
fi

# Verificar si se necesita reboot
if [[ -f "$REBOOT_FLAG" ]]; then
  REASON=$(cat /var/run/reboot-required.pkgs 2>/dev/null || echo "desconocido")
  log "Reboot requerido por: $REASON"
  log "Reiniciando en 60 segundos..."
  # Notificar a usuarios conectados
  wall "⚠ Mantenimiento: el servidor reiniciará en 60 segundos."
  sleep 60
  log "Reiniciando ahora."
  /sbin/reboot
else
  log "No se requiere reboot. Todo listo."
fi

log "=== Fin de ciclo de mantenimiento ==="
REBOOT_SCRIPT

chmod +x /usr/local/bin/auto-reboot-if-needed.sh
ok "Script /usr/local/bin/auto-reboot-if-needed.sh creado."

# ──────────────────────────────────────────────
# 5. Instalar el cron job
# ──────────────────────────────────────────────
info "Configurando cron job para ${DAY_NAME}s a las ${REBOOT_TIME}..."

CRON_FILE="/etc/cron.d/auto-updates-reboot"

cat > "$CRON_FILE" <<EOF
# Auto-reboot controlado — configurado por setup-auto-updates.sh
# Ejecuta: ${DAY_NAME}s a las ${REBOOT_TIME}
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

${CRON_MIN} ${CRON_HOUR} * * ${REBOOT_DAY} root /usr/local/bin/auto-reboot-if-needed.sh
EOF

chmod 644 "$CRON_FILE"
ok "Cron job instalado en ${CRON_FILE}."

# ──────────────────────────────────────────────
# 6. Habilitar y arrancar el servicio
# ──────────────────────────────────────────────
info "Habilitando servicio unattended-upgrades..."
systemctl enable --now unattended-upgrades &>/dev/null
ok "Servicio activo."

# ──────────────────────────────────────────────
# 7. Prueba en seco
# ──────────────────────────────────────────────
info "Ejecutando prueba en seco (--dry-run)..."
echo ""
unattended-upgrade --dry-run 2>&1 | head -20
echo ""

# ──────────────────────────────────────────────
# Resumen final
# ──────────────────────────────────────────────
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║            ¡TODO LISTO! ✔                ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
ok "Actualizaciones de seguridad : automáticas (diario)"
ok "Reboot automático            : ${DAY_NAME}s a las ${REBOOT_TIME} (solo si es necesario)"
ok "Logs de upgrades             : /var/log/unattended-upgrades/"
ok "Logs de reboot               : /var/log/auto-reboot.log"
ok "Script de reboot             : /usr/local/bin/auto-reboot-if-needed.sh"
ok "Cron job                     : /etc/cron.d/auto-updates-reboot"
echo ""
info "Para revisar logs  : sudo tail -f /var/log/auto-reboot.log"
info "Para forzar ahora  : sudo /usr/local/bin/auto-reboot-if-needed.sh"
echo ""
