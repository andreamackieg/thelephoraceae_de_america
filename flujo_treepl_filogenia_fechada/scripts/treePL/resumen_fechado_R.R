# =============================================================
# Paso 7 (Maurin 2020) en R: resumir las 1000 réplicas fechadas
# Edad media + intervalo del 95% por nodo (equivale a TreeAnnotator
# con burn-in 0 y mean heights)
# =============================================================
library(ape)
library(treeio)

setwd("C:/Users/andre/Documents/filogenia_fechada")
fechados <- read.tree("its_boot_fechados_s1e-9.tre")
ref <- fechados[[1]]
n   <- Ntip(ref)
cat("Réplicas:", length(fechados), "| puntas:", n, "\n")

# ---- 1. Verificar que la numeración de nodos sea igual en todas ----
misma <- all(sapply(fechados, function(t)
  identical(t$tip.label, ref$tip.label) && identical(t$edge, ref$edge)))
cat("Misma estructura en todas las réplicas:", misma, "\n")

if (!misma) {
  # Reasignar nodos por contenido de clados (más lento, pero seguro)
  clave <- function(t) {
    pp <- prop.part(t)
    sapply(pp, function(x) paste(sort(attr(pp, "labels")[x]), collapse = "|"))
  }
  k_ref <- clave(ref)
}

# ---- 2. Edades de cada nodo en cada réplica ----------------------
edades <- sapply(fechados, function(t) {
  bt <- branching.times(t)                    # nombres = número de nodo
  if (misma) return(bt[as.character((n + 1):(n + t$Nnode))])
  bt[match(k_ref, clave(t))]
})
# filas = nodos internos de 'ref' (n+1 ... n+Nnode), columnas = réplicas

media <- rowMeans(edades)
ic    <- t(apply(edades, 1, quantile, probs = c(0.025, 0.975)))

# ---- 3. Árbol resumen con edades medias --------------------------
edad_nodo <- c(rep(0, n), media)              # puntas = 0 Ma
resumen   <- ref
resumen$edge.length <- edad_nodo[resumen$edge[, 1]] - edad_nodo[resumen$edge[, 2]]
cat("Ramas negativas:", sum(resumen$edge.length < 0), "(debe ser 0)\n")
cat("Edad de la raíz:", round(max(media), 2), "Ma\n")

# ---- 4. Guardar ---------------------------------------------------
# a) Árbol de edades medias (Newick) -> para el DEC en RevBayes
write.tree(resumen, "its_treePL_fechado_media.tre")

# b) Tabla con edad media e intervalo de cada nodo
tabla <- data.frame(nodo = (n + 1):(n + ref$Nnode),
                    edad_media = round(media, 3),
                    ic95_min = round(ic[, 1], 3),
                    ic95_max = round(ic[, 2], 3))
write.csv(tabla, "its_treePL_edades_nodos.csv", row.names = FALSE)

# c) Árbol para FigTree (barras de intervalo)
td <- as.treedata(resumen)
td@data <- tibble::tibble(
  node   = (n + 1):(n + ref$Nnode),
  height = media,
  height_0.95_HPD = lapply(seq_along(media), function(i) unname(ic[i, ])))
write.beast(td, file = "its_treePL_fechado_resumen.tre")

cat("\nListo. Archivos guardados en la carpeta.\n")
