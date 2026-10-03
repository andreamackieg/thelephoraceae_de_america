#!/bin/bash
#SBATCH -J treepl
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=4G
#SBATCH --time=5-00:00:00
#SBATCH --array=1-50%6
#SBATCH --signal=B:USR1@600
#SBATCH --requeue
#SBATCH --open-mode=append
#SBATCH -o logs/%x_%A_%a.out
#SBATCH -e logs/%x_%A_%a.err
##SBATCH -p nombre_de_particion      # descomenta y ajusta si tu clúster lo requiere

# =========================================================
# treePL - Maurin (2020), Step 6: fechado de réplicas bootstrap en paralelo
#
# Divide las réplicas en bloques de TAMANO árboles y fecha cada bloque
# como una tarea de un job array de SLURM. Al terminar el último bloque,
# une todos los resultados en un solo archivo.
#
# Por defecto: 1,000 réplicas = 50 bloques x 20 árboles, máximo 6 bloques
# simultáneos (--array=1-50%6). Si cambias TAMANO o el número de réplicas,
# ajusta --array a 1-<número de bloques>%<simultáneos>.
#
# Uso (desde la carpeta raíz del proyecto):
#   mkdir -p logs
#   sbatch scripts/treePL/treepl_fechado.sh
#
# Relanzar tras una interrupción: vuelve a ejecutar el mismo comando.
# Los bloques terminados se saltan; solo se repiten los incompletos
# (treePL no guarda checkpoint dentro de un bloque).
#
# Notificaciones por Telegram (opcional): crea secrets.env en la raíz del
# proyecto a partir de secrets.env.example. Sin ese archivo, el script
# corre igual, sin avisos.
# =========================================================

# ---- Parámetros ----
PROY="${SLURM_SUBMIT_DIR:-$(pwd)}"                         # raíz del proyecto
SIF="${SIF:-$PROY/contenedores/treepl.sif}"                 # contenedor de treePL
ARBOLES=datos/treepl/its_paso2_boot_treePL_x10000.tre       # réplicas bootstrap (una por línea)
CONFIG_BASE=scripts/treePL/config_base.txt                  # config de treePL para el fechado
TAMANO=20                                                   # árboles por bloque
DIR=resultados/treepl
FINAL=$DIR/its_boot_fechados_s1e-9.tre
REPORTE=3600                                                # segundos entre resúmenes
NOMBRE="treePL (Step 6)"

TAREA=$SLURM_ARRAY_TASK_ID
JOBA=$SLURM_ARRAY_JOB_ID
ID=$(printf "%02d" $TAREA)
ENTRADA=$DIR/entradas/boot_$ID.tre
SALIDA=$DIR/fechados/fechados_$ID.tre
CONFIG=$DIR/configs/config_$ID.txt
LOGTP=$DIR/logs_treepl/treepl_$ID.log

cd "$PROY" || exit 1
mkdir -p $DIR/entradas $DIR/fechados $DIR/configs $DIR/logs_treepl

# ---- Notificaciones (opcionales) ----
[ -f "$PROY/secrets.env" ] && source "$PROY/secrets.env"
tg() {
  [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ] || return 0
  curl -s -m 20 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" --data-urlencode text="$1" > /dev/null 2>&1
}

# ---- Verificar insumos ----
for F in "$SIF" "$ARBOLES" "$CONFIG_BASE"; do
  [ -s "$F" ] || { echo "ERROR: falta $F" >&2; tg "❌ $NOMBRE: falta $F"; exit 1; }
done

OBJETIVO=$(grep -c ";" "$ARBOLES")
NTAREAS=$(( (OBJETIVO + TAMANO - 1) / TAMANO ))
if [ "$TAREA" -gt "$NTAREAS" ]; then
  echo "Bloque $ID fuera de rango ($NTAREAS bloques para $OBJETIVO árboles)" >&2
  exit 0
fi

bloques_listos() { ls $DIR/.listo_* 2>/dev/null | wc -l; }
arboles_fechados() { cat $DIR/fechados/fechados_*.tre 2>/dev/null | grep -c ";"; }
unir() {
  mkdir "$DIR/.unido_$JOBA" 2>/dev/null || return 0      # solo una tarea une
  cat $DIR/fechados/fechados_*.tre > "$FINAL"
  N=$(grep -c ';' "$FINAL")
  echo "Fechado completo: $N árboles en $FINAL"
  tg "✅ $NOMBRE COMPLETO: $N árboles fechados
Archivo: $FINAL
Siguiente: Step 7 (TreeAnnotator)"
}

# ---- ¿Bloque ya terminado? ----
if [ -f "$DIR/.listo_$ID" ]; then
  [ "$(bloques_listos)" -ge "$NTAREAS" ] && unir
  exit 0
fi

# ---- Preparar entrada y config de este bloque ----
INI=$(( (TAREA - 1) * TAMANO + 1 ))
FIN=$(( TAREA * TAMANO ))
sed -n "${INI},${FIN}p" "$ARBOLES" > "$ENTRADA"
N_ENT=$(grep -c ";" "$ENTRADA")
[ "$N_ENT" -gt 0 ] || { tg "❌ $NOMBRE bloque $ID: sin árboles de entrada"; exit 1; }

sed -e "s|^treefile *=.*|treefile = $PROY/$ENTRADA|" \
    -e "s|^outfile *=.*|outfile = $PROY/$SALIDA|" \
    -e "s|^nthreads *=.*|nthreads = $SLURM_CPUS_PER_TASK|" \
    "$CONFIG_BASE" > "$CONFIG"

if mkdir "$DIR/.inicio_$JOBA" 2>/dev/null; then
  tg "🍄 $NOMBRE INICIANDO | Array $JOBA
$NTAREAS bloques x $TAMANO árboles ($OBJETIVO réplicas)"
fi
INICIO_ARRAY=$(stat -c %Y "$DIR/.inicio_$JOBA")
INICIO=$(date +%s)

# ---- Resumen periódico (solo lo envía la tarea activa con número más bajo) ----
reporte() {
  while true; do
    sleep "$REPORTE"
    MIN=$(squeue -h -r -j "$JOBA" -t R -o "%K" 2>/dev/null | sort -n | head -1)
    [ "$MIN" = "$TAREA" ] || continue
    H=$(( ($(date +%s) - INICIO_ARRAY) / 3600 ))
    CORR=$(squeue -h -r -j "$JOBA" -t R 2>/dev/null | wc -l)
    PEND=$(squeue -h -r -j "$JOBA" -t PD 2>/dev/null | wc -l)
    tg "⏱ $NOMBRE | ${H} h | $(arboles_fechados)/$OBJETIVO árboles fechados
Bloques: $(bloques_listos) listos, $CORR corriendo, $PEND en espera"
  done
}
reporte &
PID_REP=$!

# ---- Señales: límite de tiempo y cancelación ----
REENCOLANDO=0
al_limite() {
  REENCOLANDO=1
  tg "⚠️ $NOMBRE bloque $ID llegó al límite de tiempo. Re-encolando (reinicia el bloque)..."
  kill $PID_TP 2>/dev/null; wait $PID_TP 2>/dev/null
  scontrol requeue "$SLURM_JOB_ID" 2>/dev/null || tg "❌ Bloque $ID no se pudo re-encolar"
  exit 0
}
al_cancelar() {
  [ "$REENCOLANDO" = 1 ] && exit 0
  mkdir "$DIR/.cancelado_$JOBA" 2>/dev/null && \
    tg "🛑 $NOMBRE interrumpido. Bloques terminados se conservan. Para retomar: sbatch scripts/treePL/treepl_fechado.sh"
  kill $PID_TP 2>/dev/null
  exit 143
}
trap al_limite USR1
trap al_cancelar TERM
trap 'kill $PID_REP 2>/dev/null' EXIT

# ---- treePL ----
apptainer exec --bind "$PROY":"$PROY" "$SIF" treePL "$CONFIG" > "$LOGTP" 2>&1 &
PID_TP=$!
wait $PID_TP
EXIT_TP=$?
kill $PID_REP 2>/dev/null

# ---- Resultado del bloque ----
H=$(( ($(date +%s) - INICIO) / 3600 ))
N_SAL=$(grep -c ";" "$SALIDA" 2>/dev/null)
if [ $EXIT_TP -eq 0 ] && [ "${N_SAL:-0}" -ge "$N_ENT" ]; then
  touch "$DIR/.listo_$ID"
  echo "Bloque $ID listo: $N_SAL árboles en ${H} h"
  tg "✅ Bloque $ID/$NTAREAS listo ($N_SAL árboles, ${H} h) | Total: $(arboles_fechados)/$OBJETIVO"
  [ "$(bloques_listos)" -ge "$NTAREAS" ] && unir
else
  echo "Bloque $ID falló (código $EXIT_TP, ${N_SAL:-0}/$N_ENT árboles). Ver $LOGTP" >&2
  tg "❌ $NOMBRE bloque $ID falló (código $EXIT_TP, ${N_SAL:-0}/$N_ENT árboles)
$(tail -n 3 $LOGTP 2>/dev/null)"
  exit 1
fi
