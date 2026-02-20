#Código para generar árboles mediante Máxima Verosimilitud. Desarrollado por Susana Magallón y editado por Andrea Mackie Greene.

#Debe instalarse RaxMl versión 8 de Alexandros Stamatakis y FigTree v1.4.4

#Primero alinear las secuencias con MAFFT:
mafft --auto \
/home/andrea/Documentos/secuencias/Ecuador.fasta \
> /home/andrea/Documentos/secuencias/Ecuador_alineado.fasta

#Activar ambiente biophyton:
micromamba activate convert_env

#Las secuencias FASTA ya alineadas deben estar en formato PHYLIP, para convertirlas:
python - <<EOF
from Bio import AlignIO
AlignIO.convert(
    "/home/andrea/Documentos/secuencias/Ecuador_alineado.fasta",
    "fasta",
    "/home/andrea/Documentos/secuencias/Ecuador.phy",
    "phylip-relaxed"
)
EOF 

>

#Luego activar el ambiente de análisis (donde está figtree):
micromamba deactivate
micromamba activate figtree_env


#Los paquetes fueron instalados en micromamba, activar el ambiente figtree:
micromamba activate figtree_env

#Ejecutar RaxMl:
raxmlHPC-PTHREADS \
-f a \
-m GTRGAMMA \
-s /home/andrea/Documentos/secuencias/Ecuador.phy \
-n arbol.prueba \
-w /home/andrea/Documentos/output \
-T 4 \
-p 12345 \
-x 12345 \
-# 100

#Luego abrir en FigTree:
figtree /home/andrea/Documentos/output/RAxML_bipartitions.arbol.prueba

#Comando para mapear bootstrap al aŕbol de ML:
raxmlHPC-PTHREADS \
-f b \
-m GTRGAMMA \
-s /home/andrea/Documentos/secuencias/Ecuador.phy \
-t /home/andrea/Documentos/output/RAxML_bestTree.arbol.prueba \
-z /home/andrea/Documentos/output/RAxML_bootstrap.arbol.prueba \
-n BS_TREE.arbol.prueba \
-w /home/andrea/Documentos/output \
-T 4

#Luego abrir en Figtree:
figtree /home/andrea/Documentos/output/RAxML_bipartitions.BS_TREE.arbol.prueba
