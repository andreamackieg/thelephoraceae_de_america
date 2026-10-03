#!/bin/bash
#SBATCH -J test_treepl
#SBATCH -c 2
#SBATCH --mem=4G
#SBATCH --time=1-00:00:00
#SBATCH -o logs/%x_%j.out
#SBATCH -e logs/%x_%j.err
##SBATCH -p nombre_de_particion      # descomenta y ajusta si tu clúster lo requiere

# Prueba: fecha una sola réplica para confirmar que treePL lee las
# calibraciones y medir el tiempo por árbol.
# Uso (desde la raíz del proyecto): mkdir -p logs && sbatch scripts/treePL/test_treepl.sh

PROY="${SLURM_SUBMIT_DIR:-$(pwd)}"
SIF="${SIF:-$PROY/contenedores/treepl.sif}"
D=resultados/treepl/test
cd "$PROY" || exit 1
mkdir -p $D
head -n 1 datos/treepl/its_paso2_boot_treePL_x10000.tre > $D/un_arbol.tre
sed -e "s|^treefile *=.*|treefile = $PROY/$D/un_arbol.tre|" \
    -e "s|^outfile *=.*|outfile = $PROY/$D/un_arbol_fechado.tre|" \
    -e "s|^nthreads *=.*|nthreads = 2|" \
    scripts/treePL/config_base.txt > $D/config_test.txt
INICIO=$(date +%s)
apptainer exec --bind "$PROY":"$PROY" "$SIF" treePL $D/config_test.txt > $D/test.log 2>&1
echo "Código: $? | Minutos: $(( ($(date +%s) - INICIO) / 60 ))" >> $D/test.log
tail -n 1 $D/test.log
