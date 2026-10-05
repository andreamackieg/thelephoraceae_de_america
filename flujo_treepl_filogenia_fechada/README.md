# Flujo de trabajo: filogenia datada con treePL

## Introducción

Este flujo produce una filogenia datada con treePL a partir de un árbol de máxima verosimilitud (ML) obtenido con IQ-TREE y de 1,000 réplicas bootstrap con la topología fijada a ese árbol. Sigue el protocolo de Maurin (2020). Los valores y archivos de ejemplo provienen de un alineamiento ITS de 603 sitios.

> Maurin, K. J. L. (2020). An empirical guide for producing a dated phylogeny with treePL in a maximum likelihood framework. *arXiv*, 2008.07054. <https://doi.org/10.48550/arXiv.2008.07054>. Material suplementario: <https://doi.org/10.5281/zenodo.3989030>

| Paso de este flujo | Step de Maurin (2020) | Árbol que se usa |
| --- | --- | --- |
| 1–2. Edades fósiles y numsites | Step 3 (preparar config) | — |
| 3. Config para prime | Step 3 | Árbol ML sin soporte, enraizado |
| 4. Tiny branches | Step 4.5 | Árbol ML y réplicas multiplicados en R (genera los archivos \_x10000 que se usan desde el Paso 5) |
| 5. Priming | Step 4 | Árbol ML |
| 6. Validación cruzada | Steps 5 y 5.5 | Árbol ML |
| 7. Fechado | Step 6 | 1,000 réplicas bootstrap |
| 8. Resumen | Step 7 | 1,000 réplicas fechadas |

**Archivos principales:**

- `its_paso1_enraizado_treePL_x10000.tre`: árbol ML (Paso 1 de IQ-TREE), sin valores de soporte, enraizado y con longitudes de rama multiplicadas.
- `its_paso2_boot_treePL_x10000.tre`: 1,000 réplicas bootstrap con la misma topología, enraizamiento y factor.
- `alineamiento_ITS_final.fasta`: alineamiento usado para numsites.

## Paso 1. Edades fósiles y calibración secundaria

Se usaron cinco calibraciones fósiles y una calibración secundaria en la raíz. Cada nodo se define en treePL con dos terminales cuyo ancestro común más reciente (`mrca`) es el nodo calibrado.

| Nodo (nombre en el config) | Orden | Calibración | Edad usada (Ma) | Terminales del mrca | Localidad | Referencia |
| --- | --- | --- | --- | --- | --- | --- |
| RAIZ | Hymenochaetales + Corticiales vs. resto | Secundaria | min = max = 243.9 | *Hymenochaete tropica* | — | Sánchez-García et al., 2020 |
| HYMENOCHAETACEAE | Hymenochaetales | *Quatsinoporites cranhamii* (127–129 Ma) | min 127, max 129 | *Hymenochaete tropica*, *Fuscoporia ferrea* | Columbia Británica, Canadá | Smith et al., 2004 |
| RUSSULA\_LACTARIUS | Russulales | *Edaphagaricites conicus* (113–121 Ma) | min 113 | *Russula nigricans*, *Lactarius deliciosus* | Ceará, Brasil | Gobo et al., 2025 |
| TRAMETES | Polyporales | *Trametites eocenicus* (35–38 Ma) | min 35 | *Trametes pavonia*, *Trametes polyzona* | Radvanov, República Checa | Knobloch & Kotlaba, 1994 |
| GANODERMA | Polyporales | *Ganodermites lybicus* (18–19 Ma) | min 18 | *Ganoderma brownii*, *Ganoderma meredithae* | Norte de África | Fleischmann et al., 2007 |
| SUILLINEAE | Boletales | Fósil ectomicorrízico *Suillus*/*Rhizopogon* (\~50 Ma) | min 50 | *Suillus luteus*, *Rhizopogon villosulus* | Columbia Británica, Canadá | Lepage et al., 1997 |

**Criterio de mínimos y máximos.** Siguiendo a Maurin (2020), solo el nodo más antiguo lleva edad máxima; los demás fósiles se usan como edad mínima, porque un fósil indica que el linaje ya existía, no cuándo surgió. La excepción es *Quatsinoporites*, que lleva mínimo y máximo.

**Calibración de la raíz.** Edad de la divergencia entre (Hymenochaetales + Corticiales) y el resto de los órdenes muestreados, tomada de Sánchez-García et al. (2020). Se fijó como valor puntual (243.9 Ma), por lo que su incertidumbre no se propaga a los intervalos de confianza; esto se reporta como limitación.

> Sánchez-García, M., Ryberg, M., Khan, F. K., Varga, T., Nagy, L. G., & Hibbett, D. S. (2020). Fruiting body form, not nutritional mode, is the major driver of diversification in mushroom-forming fungi. *Proceedings of the National Academy of Sciences*, 117(51), 32528–32534. <https://doi.org/10.1073/pnas.1922539117>

## Paso 2. Obtener numsites del alineamiento

`numsites` es el número de sitios (columnas) del alineamiento con que se construyó el árbol. treePL lo necesita para convertir longitudes de rama en tasas. Resultado: **603 sitios**.

```bash
awk '/^>/{if(seq){print length(seq); exit} next} {seq=seq$0} END{print length(seq)}' \
  /home/andrea/Documentos/treepl/alineamiento_ITS_final.fasta
```

El comando suma las líneas de la primera secuencia y reporta su longitud. En un alineamiento todas las secuencias miden lo mismo, así que basta con la primera. IQ-TREE reporta el mismo valor en su log (`603 columns`).

Maurin (2020) recomienda que el alineamiento no tenga sitios con bases ambiguas, porque algunos programas los descartan y el conteo deja de coincidir. IQ-TREE no descarta sitios, así que 603 corresponde a lo que usó el análisis.

## Paso 3. Archivo de configuración para prime (config\_prime.txt)

El primer config usa el **árbol ML** y activa solo el comando `prime`. Las calibraciones se quedan sin comentar durante todo el proceso; los bloques de validación cruzada, smoothing y salida se quedan comentados (`#`) hasta su paso.

```bash
nano /home/andrea/Documentos/treepl/config_prime.txt
```

```
[Input files containing the ML trees]
treefile = /home/andrea/Documentos/treepl/its_paso1_enraizado_treePL_x10000.tre
#treefile = /home/andrea/Documentos/treepl/its_paso2_boot_treePL_x10000.tre

[General commands]
numsites = 603
nthreads = 4
thorough
log_pen

[Calibrations]
# (las seis calibraciones del Paso 1, sin comentar)

[Priming command]
prime

[Best optimisation parameters]
# aquí se pegará la salida de prime

[Cross-validation analysis]
# comentado en este paso

[Best smoothing value]
#smooth =

[Output file of dating step]
#outfile = /home/andrea/Documentos/treepl/its_treePL_fechado.tre
```

**Cómo leer las dos líneas `treefile`.** El símbolo `#` al inicio de una línea la desactiva completa: treePL ignora todo lo que sigue, incluida la palabra `treefile`. Por eso el config lleva las dos rutas, cada una en su propia línea con `treefile =`, y se comenta la que no se usa en ese paso. Aquí está activo el árbol ML (`its_paso1_...`) y desactivadas las réplicas (`#treefile = .../its_paso2_...`); en el Paso 7 se invierte. Escribir solo la ruta sin `treefile =` no es válido para treePL.

Qué hace cada comando general:

- `numsites`: sitios del alineamiento (Paso 2).
- `nthreads`: núcleos que usa treePL.
- `thorough`: optimización más exhaustiva (más lenta, más confiable).
- `log_pen`: penalización logarítmica; Maurin no observó diferencias al usarla, pero es la opción usada en filogenias publicadas.

Correr con:

```bash
treePL /home/andrea/Documentos/treepl/config_prime.txt
```

## Paso 4. Mensajes de tiny branch: multiplicar longitudes de rama

Al iniciar `prime`, treePL avisó de ramas demasiado cortas (`tiny branch length`). treePL reemplaza esas longitudes por un valor estándar, lo que borra diferencias reales entre ramas cortas. La solución de Maurin (Step 4.5) es multiplicar **todas** las longitudes de rama por un mismo factor: las ramas se alargan, pero sus proporciones no cambian.

Factor usado: **×10,000** (de ahí el sufijo `_x10000` de los archivos).

1. Encontrar la longitud de rama más pequeña del árbol ML y de las réplicas, en R.
2. Elegir un factor que deje esa rama por encima del mínimo que tolera treePL.
3. Multiplicar por ese factor el árbol ML **y las 1,000 réplicas**.
4. Cambiar `treefile` en el config al árbol multiplicado y volver a correr `prime`.

```r
library(ape)
ml   <- read.tree("its_paso1_enraizado_treePL.tre")
reps <- read.tree("its_paso2_boot_treePL.tre")
min(ml$edge.length[ml$edge.length > 0])           # rama más corta del árbol ML
factor <- 10000
ml$edge.length <- ml$edge.length * factor
reps <- lapply(reps, function(t) { t$edge.length <- t$edge.length * factor; t })
class(reps) <- "multiPhylo"
write.tree(ml,   "its_paso1_enraizado_treePL_x10000.tre")
write.tree(reps, "its_paso2_boot_treePL_x10000.tre")
```

**Importante:** el árbol ML y las réplicas deben llevar el mismo enraizamiento y el mismo factor. Si no, el Step 6 fecharía árboles distintos al usado en los Steps 4–5.

Si aparece **un solo** mensaje de tiny branch al iniciar la validación cruzada o el fechado, Maurin lo atribuye a la rama de la raíz y recomienda ignorarlo.

## Paso 5. Priming: elegir los parámetros de optimización

`prime` busca los mejores parámetros de optimización para este árbol. Al terminar, imprime unas líneas bajo el mensaje `PLACE THE LINES BELOW IN THE CONFIGURATION FILE`.

1. Correr `prime` al menos **3 veces** con el árbol multiplicado.
2. De cada corrida, anotar los valores de `opt`, `optad` y `optcvad`.
3. Quedarse con la corrida de valores **más bajos** y pegar esas líneas en el bloque `[Best optimisation parameters]`.
4. Comentar `prime` (`#prime`) para los pasos siguientes.

Mensajes como `Linear search failed`, `Unable to progress` o `Maximum number of function evaluations reached` son normales; según Maurin no afectan el resultado.

Resultado del priming final, con el árbol multiplicado (×10,000), 4 hilos y log guardado en `prime_1.log`:

```bash
treePL /home/andrea/Documentos/treepl/config_prime.txt 2>&1 | tee /home/andrea/Documentos/treepl/prime_1.log
```

| Optimizador | Mejor valor sugerido por `prime` |
| --- | --- |
| `opt` | 5 |
| `optad` | 5 |
| `optcvad` | 3 |

```
[Best optimisation parameters]
opt = 5
optad = 5
optcvad = 3
```

- Con el factor ×10,000 quedó **un solo** mensaje de *tiny branch* (`setting to 0.0016583748`). Según Maurin, un mensaje aislado se puede ignorar.
- `optcvad` solo interviene en la validación cruzada (Paso 6). El fechado (Paso 7) usa `opt` y `optad`, así que el cambio de `optcvad` de 2 a 3 no afecta las edades.

## Paso 6. Validación cruzada y elección del smoothing

La validación cruzada (CV) busca el **valor de smoothing**, el parámetro clave de la verosimilitud penalizada: valores bajos permiten mucha variación de tasas entre ramas; valores altos se acercan a un reloj estricto. Se corre sobre el **árbol ML**, no sobre las réplicas. Valor elegido: **smooth = 0.000000001 (10⁻⁹)**.

Cambios en el config respecto al Paso 5: `prime` comentado, parámetros de optimización pegados y bloque de CV activo.

```
[Priming command]
#prime

[Best optimisation parameters]
opt = 5
optad = 5
optcvad = 2

[Cross-validation analysis]
randomcv
cviter = 5
cvsimaniter = 1000000000
cvstart = 10
cvstop = 0.00000001
cvmultstep = 0.1
seed = 12345
cvoutfile = /home/andrea/Documentos/treepl/randomcv_its_1.txt
```

Qué hace cada comando:

- `randomcv`: validación cruzada aleatoria, más rápida y estable que la de “dejar uno fuera” (`cv`).
- `cvstart` y `cvstop`: rango de smoothing evaluado, de 10 a 10⁻⁸.
- `cvmultstep = 0.1`: cada valor probado es el anterior × 0.1.
- `cviter` y `cvsimaniter`: iteraciones de la CV y del recocido simulado.
- `seed`: semilla para reproducibilidad.
- `cvoutfile`: archivo con el chi² de cada smoothing; el mejor es el de **chi² más bajo**.

Procedimiento:

1. Correr la CV al menos **3 veces** y comparar los chi² entre corridas.
2. Si el mejor valor cae justo en `cvstop`, bajar ese límite y repetir.
3. Si los resultados son inestables entre corridas, subir `opt`, `optad` y `optcvad` (Step 5.5) hasta que se estabilicen. En este análisis, prime sugirió subir optcvad de 2 a 3 (Paso 5), y ninguna corrida mostró mensajes de "might want to try a different opt/optad".
4. Si siguen variando, usar el valor más bajo que sea consistentemente bueno, como recomienda Maurin para filogenias con alta heterogeneidad de tasas. Aquí: **10⁻⁹**.

**Primera ronda: smoothing de 10 a 10⁻⁸** (archivos `randomcv_its_1.txt` a `randomcv_its_3.txt`; en negritas, el chi² más bajo de cada corrida):

| Smoothing | Corrida 1 | Corrida 2 | Corrida 3 |
| --- | --- | --- | --- |
| 10 | 937,950 | 1,063,200 | 973,337 |
| 1 | 934,645 | 1,054,300 | 980,847 |
| 0.1 | 892,626 | 1,044,250 | 960,373 |
| 0.01 | 908,677 | 1,010,190 | 1,022,860 |
| 0.001 | 847,604 | 56,632,400 | 31,270,800 |
| 10⁻⁴ | **692,364** | 644,825 | 509,862 |
| 10⁻⁵ | 833,225 | 407,354 | 393,995 |
| 10⁻⁶ | 784,123 | 287,858 | **288,867** |
| 10⁻⁷ | 798,867 | 271,314 | 292,170 |
| 10⁻⁸ | 793,583 | **267,893** | 290,597 |

**Interpretación.** Las corridas no coinciden en un solo valor: el mínimo cae en 10⁻⁴, 10⁻⁸ y 10⁻⁶. Las corridas 2 y 3 sí coinciden en que el chi² baja hacia los valores más pequeños, con 10⁻⁶ a 10⁻⁸ casi iguales; 10⁻⁸ está entre los tres mejores en las tres corridas. Esto indica alta heterogeneidad de tasas, caso en el que Maurin recomienda el valor bajo.

En la corrida 2 el mínimo cayó justo en `cvstop` (10⁻⁸). Como indica Maurin, se repitió la CV con un rango extendido hacia abajo.

**Segunda ronda: smoothing de 10⁻⁴ a 10⁻¹²** (`cvstart = 0.0001`, `cvstop = 0.000000000001`; archivos `randomcv_r2_1.txt` a `randomcv_r2_3.txt`; en negritas, el chi² más bajo de cada corrida):

| Smoothing | Corrida 1 | Corrida 2 | Corrida 3 |
| --- | --- | --- | --- |
| 10⁻⁴ | **956,206** | 697,548 | 569,523 |
| 10⁻⁵ | 1,078,150 | 386,541 | 372,666 |
| 10⁻⁶ | 1,028,640 | 297,387 | 320,435 |
| 10⁻⁷ | 1,037,970 | 278,337 | **304,050** |
| 10⁻⁸ | 1,054,010 | 274,671 | 313,236 |
| 10⁻⁹ | 1,057,370 | **272,536** | 307,910 |
| 10⁻¹⁰ | 1,041,940 | 277,192 | 319,934 |
| 10⁻¹¹ | 1,066,660 | 280,026 | 321,141 |
| 10⁻¹² | 1,052,770 | 281,539 | 328,254 |

Ninguna corrida mostró mensajes de “might want to try a different opt/optad”.

**Elección final: smooth = 10⁻⁹.** En las corridas 2 y 3 el óptimo queda entre 10⁻⁷ y 10⁻⁹: el mínimo de la corrida 2 es 10⁻⁹ y el de la corrida 3 es 10⁻⁷, con 10⁻⁹ como segundo mejor. Dentro de ese intervalo se eligió el valor más bajo, como recomienda Maurin (2020) cuando se espera alta heterogeneidad de tasas, esperable en un muestreo que abarca seis órdenes de Agaricomycetes.

La corrida 1 se comportó distinto en ambas rondas: su chi² es casi plano (\~1,000,000) y su mínimo cae en 10⁻⁴. Lo más probable es que el optimizador no convergiera en esa corrida, por lo que no se usó para la elección.

Correr con:

```bash
treePL /home/andrea/Documentos/treepl/config_prime.txt
```

## Paso 7. Fechado de las réplicas bootstrap (config\_dating.txt)

Con los parámetros de optimización y el smoothing ya elegidos, treePL fecha cada una de las 1,000 réplicas. Las edades de estas réplicas dan los intervalos de confianza de cada nodo.

Cambios en el config respecto al Paso 6: `treefile` apunta a las **réplicas**, la CV se comenta, se activan `smooth` y `outfile`, y se agrega `seed`.

```
[Input files containing the ML trees]
#treefile = /home/andrea/Documentos/treepl/its_paso1_enraizado_treePL_x10000.tre
treefile = /home/andrea/Documentos/treepl/its_paso2_boot_treePL_x10000.tre

[General commands]
numsites = 603
nthreads = 4
thorough
log_pen
seed = 12345

[Calibrations]
# (las seis calibraciones del Paso 1)

[Priming command]
#prime

[Best optimisation parameters]
opt = 5
optad = 5
optcvad = 2

[Cross-validation analysis]
# todo comentado

[Best smoothing value]
smooth = 0.000000001

[Output file of dating step]
outfile = /home/andrea/Documentos/treepl/its_boot_fechados_s1e-9.tre
```

Correr con:

```bash
treePL /home/andrea/Documentos/treepl/config_dating.txt
```

**Ejecución en bloques (opcional).** Cada réplica tardó unos 25 minutos con 2 hilos, por lo que fechar las 1,000 en serie tomaría unos 17 días. Para acortarlo, las réplicas se dividieron en 50 bloques de 20 y cada bloque se fechó por separado, con el mismo config y cambiando solo `treefile` y `outfile`. Antes se fechó una sola réplica como prueba, para confirmar que treePL leía las calibraciones y medir el tiempo por árbol.

```bash
# Dividir las 1,000 réplicas en bloques de 20 (una réplica por línea)
split -l 20 -d -a 2 its_paso2_boot_treePL_x10000.tre boot_

# Al terminar todos los bloques, unirlos en orden
cat fechados_*.tre > its_boot_fechados_s1e-9.tre
grep -c ";" its_boot_fechados_s1e-9.tre        # debe dar 1000
```

## Paso 8. Siguiente: resumen de las réplicas fechadas

Las 1,000 réplicas fechadas se resumen en un solo árbol con la edad media y el intervalo de confianza del 95 % de cada nodo (Step 7 de Maurin).

Configuración, siguiendo a Maurin (2020): TreeAnnotator (BEAST 2), **0 % de burn-in** y **alturas medias de nodo**. Las demás opciones no cambian el resultado, porque todas las réplicas tienen la misma topología.

1. Convertir las réplicas fechadas a NEXUS, el formato que lee TreeAnnotator (en R):

```r
library(ape)
fechados <- read.tree("its_boot_fechados_s1e-9.tre")
length(fechados)                                   # debe dar 1000
write.nexus(fechados, file = "its_boot_fechados_s1e-9.nex")
```

2. Resumir con TreeAnnotator:

```bash
treeannotator -burnin 0 -heights mean \
  its_boot_fechados_s1e-9.nex \
  its_treePL_fechado_resumen.tre
```

- `-burnin 0`: se usan las 1,000 réplicas; no hay fase de calentamiento como en un MCMC.
- `-heights mean`: la edad de cada nodo es la media de las 1,000 réplicas.
- Salida: árbol en NEXUS con la edad media y el intervalo del 95 % de cada nodo (anotado como `height_95%_HPD`), visible en FigTree.
