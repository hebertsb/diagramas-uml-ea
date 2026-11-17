# Guía general: construir y modificar diagramas UML en Enterprise Architect (EA 15) por COM

Sirve para **cualquier sistema**: en vez de dibujar a mano en EA, se escribe un script de PowerShell que crea los paquetes, elementos, relaciones y diagramas, exporta cada diagrama a PNG y permite revisarlo. Nació en un proyecto real (27 diagramas UML 2.5 construidos y verificados), pero nada de lo que sigue depende de ese proyecto.

Qué hay en la carpeta:

```
GUIA_TECNICA.md                        <- esta guía
FORMATO_DISENO_DETALLE_PROCEDIMENTAL.md <- cómo se entrega un "diseño de detalle con patrones" y cómo ampliarlo
scripts\
  ea_lib.ps1                           <- biblioteca de funciones (la base de todo)
  nuevo_eapx.ps1                       <- crea un .eapx NUEVO y vacío (no sobrescribe si ya existe)
  ejemplo_generico.ps1                 <- ejemplo autónomo con un dominio neutro: casos de uso, clases con
                                          Chain of Responsibility, secuencia, paquetes y actividad
  ejemplo_tipos_adicionales.ps1        <- comunicación, objetos, estados y robustez ICONIX (dominio neutro)
  ejemplo_patrones_detalle.ps1         <- Strategy y Template Method: diagrama genérico + diagrama específico dentro de
                                          Vista-Controlador-Modelos-Conexión (con colores, Singleton, abstractas, Note)
  inspeccionar_eapx.ps1                <- radiografía de un .eapx: diagramas, clases, secuencias, huérfanos, PNG de todo
  guardar_enlaces_de_diagramas.ps1     <- hace aparecer en un diagrama (no secuencia) conectores que ya existían
  ejemplos_de_otro_proyecto\           <- 5 scripts de otro sistema: solo para ver la técnica (despliegue, modelo de
                                          datos, actividad con calles, secuencias largas); no se ejecutan tal cual
ejemplo_resultado_png\                 <- los 5 diagramas que produce ejemplo_generico.ps1 (para ver qué esperar)
```

---

## 1. Inicio rápido (10 minutos)

1. Copia tu `.eapx` a otra carpeta (trabajarás solo sobre la copia). Cierra EA. Si **no tienes** un `.eapx` base, crea uno vacío con `scripts\nuevo_eapx.ps1 -Archivo "C:\trabajo\proyecto.eapx"` (se niega a sobrescribir uno existente).
2. Corre la radiografía para ver qué tiene:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\inspeccionar_eapx.ps1 -Archivo "C:\trabajo\copia.eapx" -Salida "C:\trabajo\inspeccion.txt" -ImgDir "C:\trabajo\png"
   ```
3. Prueba el ejemplo genérico en la copia (agrega un paquete "Ejemplo general" con 5 diagramas):
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ejemplo_generico.ps1 -Trabajo "C:\trabajo\copia.eapx" -Salida "C:\trabajo\log.txt" -ImgDir "C:\trabajo\png_ejemplo"
   ```
4. Mira los PNG y abre la copia en EA para ver el paquete nuevo. Si se ve bien, copia `ejemplo_generico.ps1`, cambia el contenido por el de tu sistema y repite (sobre una copia nueva cada vez).

## 2. Dónde trabajar

Abre en VS Code la carpeta **del proyecto cuyo sistema vas a diagramar** y trabaja ahí (con tu asistente de código, si usas uno). Así puede leer el código real, y lo que se dibuja se comprueba contra lo que existe. EA y PowerShell trabajan sobre una **ruta de archivo**, así que los scripts pueden vivir en cualquier carpeta; mejor fuera del repositorio del proyecto, o en una carpeta ignorada por git.

## 3. Requisitos y reglas de seguridad

- Windows con **Enterprise Architect 15** (objeto COM `EA.Repository`).
- Los scripts se corrieron con **Windows PowerShell 5.1**:
  `powershell -NoProfile -ExecutionPolicy Bypass -File script.ps1 -Trabajo "C:\ruta\copia.eapx" -Salida "C:\ruta\log.txt"`
- **Trabaja siempre sobre una copia del `.eapx`.** El original no se toca hasta validar el resultado.
- **EA no debe tener abierto ese archivo** (queda bloqueado por el `.ldb`). Ciérralo antes de correr un script.
- **EA puede colgarse** (por ejemplo, con una consulta SQL a una columna que no existe). Lanza los scripts con `timeout` (en bash) o `Start-Process` con espera limitada y, si se cuelga, `taskkill /F /IM EA.exe`. Dentro de los scripts usa `try/finally` con `$repo.CloseFile(); $repo.Exit()`.
- Los `.ps1` con acentos o `ñ` **deben guardarse como UTF-8 con BOM**; sin BOM, PowerShell 5.1 rompe los textos. Los de esta carpeta ya lo tienen.
- Escribe los logs a un archivo con `StreamWriter` UTF-8 (como hacen los ejemplos) y lee el archivo; la consola mezcla codificaciones.
- `$global:CarpetaImg = 'C:\ruta\png'` define dónde salen los PNG de `Exporta` (por defecto `C:\tmp\ea\build_img`).

## 4. Flujo de trabajo

1. **Inspeccionar** el `.eapx` (si ya tiene diagramas): `inspeccionar_eapx.ps1`.
2. **Copiar el estilo** del `.eapx` de referencia (el de tu docente, el de tu equipo o el que ya usas): lee `StyleEx` y `PDATA` con `SELECT Diagram_ID, Name, Diagram_Type, StyleEx, PDATA FROM t_diagram` y úsalos en `Add-Diag` (`$global:StyleBase` y `$global:StyleSec` de `ea_lib.ps1`). Los diagramas nuevos quedan iguales a los viejos.
3. **Plan por escrito** antes de programar (ver la plantilla de la sección 5). Los nombres de clases, métodos y tablas, sácalos del código con una herramienta (AST, grep), no de memoria.
4. **Script de construcción**, un `try/catch` por diagrama y un registro por diagrama.
5. **Exportar el PNG y mirarlo.** Revisa solapamientos, textos cortados y líneas que se cruzan. Los conteos no dicen si un diagrama se lee bien.
6. **Ajustar coordenadas** y repetir sobre una **copia nueva** (correr un script dos veces sobre el mismo archivo duplica todo).
7. **Cerrar, reabrir y verificar** con `inspeccionar_eapx.ps1` (conteos por tipo, conectores por diagrama, `SeqNo` consecutivos, elementos huérfanos, paquetes vacíos). Compara los conteos con el plan de diagramas.
8. Solo entonces, pasar el resultado al archivo definitivo.

## 5. Cómo adaptarlo a tu sistema

Para cada diagrama que necesites, llena esta ficha antes de escribir el script:

| Campo | Ejemplo |
|---|---|
| Diagrama y tipo | Clases — módulo de pedidos |
| Qué cuenta | Cómo se procesa un pedido y quién decide cada paso |
| Elementos (nombre exacto) | `Pedido`, `ServicioPedidos`, `Validador`... (del código) |
| Relaciones | `ServicioPedidos → Validador` (dependencia), `Validador ← ValidadorStock` (herencia) |
| De dónde salió cada dato | `backend/servicios/pedidos.py`, línea... |
| Archivo de salida | `clases_pedidos.png` |

De dónde sacar la información real: casos de uso, de los requerimientos y las historias de usuario; clases, del código (nombres, atributos, métodos, herencia); secuencias, de seguir una petición en el código de punta a punta; paquetes, de la estructura de carpetas; despliegue, de la configuración (Docker, servidores, servicios externos); modelo de datos, del esquema de la base (tablas, columnas, claves).

Para un sistema nuevo, copia `ejemplo_generico.ps1`, borra el dominio de ejemplo (aprobación de solicitudes) y reemplázalo por el tuyo conservando la estructura (un `try/catch` por diagrama, `Exporta` al final de cada uno).

## 6. API de EA que se usó (resumen)

| Para qué | Cómo |
|---|---|
| Abrir / cerrar | `$repo = New-Object -ComObject EA.Repository; $repo.OpenFile($ruta); ... $repo.CloseFile(); $repo.Exit()` |
| Raíz del modelo | `$repo.Models.GetAt(0)` |
| Paquete nuevo | `$padre.Packages.AddNew($nombre,"")` + `.Update()` |
| Diagrama nuevo | `$pkg.Diagrams.AddNew($nombre,$tipo)`; tipos usados: `Use Case`, `Class`, `Package`, `Sequence`, `Deployment`, `Activity`, `Logical`, `Component` |
| Elemento | `$pkg.Elements.AddNew($nombre,$tipo)`; tipos: `Class`, `Actor`, `UseCase`, `Boundary`, `Component`, `Sequence` (línea de vida), `InteractionFragment`, `ActivityPartition`, `Action`, `Decision`, `StateNode` |
| Ponerlo en un diagrama | `$diag.DiagramObjects.AddNew("l=X;r=X+W;t=-Y;b=-(Y+H);","")` y `.ElementID = ...` (**la Y va en negativo**) |
| Atributos / operaciones | `$el.Attributes.AddNew(...)`, `$el.Methods.AddNew(...)`, `$m.Parameters.AddNew(...)` |
| Relaciones | `$origen.Connectors.AddNew($nombre,$tipo)`, `.SupplierID = destino`, `.Stereotype`; tipos: `Association`, `Generalization`, `Aggregation`, `Dependency`, `ControlFlow`, `Sequence` |
| Consultas SQL | `$repo.SQLQuery("SELECT ...")` devuelve XML; `$repo.Execute("UPDATE ...")` escribe. Tablas útiles: `t_object`, `t_package`, `t_diagram`, `t_diagramobjects`, `t_diagramlinks`, `t_connector`, `t_attribute`, `t_operation`, `t_xref` |
| Refrescar | `$repo.ReloadDiagram($diag.DiagramID)` |
| Exportar imagen | `$repo.GetProjectInterface().PutDiagramImageToFile($diag.DiagramGUID, $archivo, 1)` |

## 7. Funciones de `ea_lib.ps1`

| Función | Qué hace |
|---|---|
| `Add-Pkg $padre $nombre` | Crea un paquete. |
| `Add-Diag $pkg $nombre $tipo` | Crea un diagrama con el estilo de la guía (`StyleSec` para secuencia, `StyleBase` para los demás) y con los parámetros de las operaciones visibles. |
| `Add-Elem $pkg $nombre $tipo $estereotipo $notas` | Crea un elemento. |
| `Add-Class $pkg $nombre $estereotipo @('atributo:tipo') @('operacion(p:tipo):retorno') $abstracta` | Clase completa de una vez. Marcas opcionales al inicio de cada atributo u operación: `-` privado, `#` protegido, `$` estático, `*` abstracta (solo operaciones); por ejemplo `'#validar():void'`, `'*calcular():float'`, `'-$instancia:?PDO'`. Atributos y operaciones guardan su orden en `Pos`. |
| `Place $diag $elemento x y ancho alto [z]` | Lo coloca en el diagrama. `z` mayor = más al frente (un contenedor debe tener `z` mayor que lo que contiene). |
| `Add-Conn $origen $destino $tipo $nombre $estereotipo` | Conector. `include`/`extend` son `Dependency` con ese estereotipo; la dependencia entre paquetes es `Dependency` con estereotipo `import`. |
| `Add-Attr`, `Add-Oper` | Atributo y operación sueltos. |
| `Find-Elem`, `Find-Pkg`, `Get-Or-Add` | Buscan por nombre (SQL) para **reutilizar** un elemento que ya existe en vez de duplicarlo. |
| `Build-Sequence $repo $pkg $nombre $participantes $mensajes $fragmentos` | Construye un diagrama de secuencia completo: líneas de vida, mensajes en orden y fragmentos (`alt`, `opt`, `loop`, `par`, `break`) con sus guardas. |
| `Set-Guardas` | Escribe las condiciones de un fragmento (en `t_xref`). |
| `Exporta $repo $diag $nombre` | Exporta el PNG (antes llama a `Guardar-Enlaces`). |
| `Guardar-Enlaces $repo $diag` | Abre y guarda el diagrama para que sus líneas queden en el archivo (no actúa en secuencias). |
| `Set-OpFlags $repo $el $nombre $vis $abstracta $estatica` | Visibilidad, abstracta y estática de una operación ya creada (por SQL; cambiar esas propiedades en el objeto `Method` no persiste). |
| `Set-ColorConectores $repo $diag $conectores r g b` | Color de las líneas de los conectores indicados (RGB; EA lo guarda en BGR). |
| `Set-ColorElemento $repo $diag $elemento r g b` | Color de fondo de un elemento en ese diagrama. |
| `Clonar-Paquete $repo $idPaquete $idPadre $nombre` | **Copia profunda** de un paquete (elementos, conectores, zonas de color, estilos y diagramas idénticos) bajo otro paquete. Sirve para duplicar un diseño que ya existe y trabajar sobre la copia. |
| `Copiar-Elemento $repo $idElemento $idPaqueteDestino` | Copia un elemento con sus atributos y operaciones dentro de otro paquete. |
| `Mover-Objetos $repo $idDiagrama $dx $dy [$ids]` | Desplaza todos los objetos de un diagrama, o solo los elementos indicados (dy positivo = hacia abajo). |
| `Set-LazoPropio $repo $idDiagrama $idConector $xDer $yArriba $ancho $alto [$invertir]` | Agranda el lazo de una relación de un elemento consigo mismo. Llamarlo después de `Guardar-Enlaces`.  |
| `Set-ColorZona $repo $idDiagrama $idElemento r g b` | Color de fondo de una zona (`Boundary`) en un diagrama. |
| `Add-AutoAgregacion $elemento $rotulo` | Relación de un elemento consigo mismo con rombo hueco y flecha abierta (el sucesor de Chain of Responsibility). |
| `Set-LazoPropioArriba $repo $idDiagrama $idConector $x $yTop $ancho $alto` | Dibuja ese lazo sobre el borde superior del elemento (dejar espacio libre encima). Llamarlo después de `Guardar-Enlaces`. |
| `Add-Interfaz $pkg $nombre @(@('op','retorno',@('p:tipo')))` | Elemento `Interface` con varias operaciones. |
| `Separar-Enlace $repo $idDiagrama $idConector $dy` | Separa dos líneas que unen el mismo par de elementos (usar +12 y -12), llamándolo después de `Guardar-Enlaces`. |
| `Mostrar-Visibilidad $diag` | Muestra los signos `+ - #` y los **tipos** de los parámetros (`HideQuals=0`). |
| `Sql-Rows $repo $sql` | Devuelve las filas de una consulta. |

Ejemplo mínimo (dos clases, herencia y una asociación):

```powershell
. "$PSScriptRoot\ea_lib.ps1"
$repo = New-Object -ComObject EA.Repository
[void]$repo.OpenFile('C:\trabajo\copia.eapx'); $global:Repo = $repo
$raiz = $repo.Models.GetAt(0)
$pk = Add-Pkg $raiz 'Mi paquete'
$d  = Add-Diag $pk 'Clases del módulo X' 'Class'
$a = Add-Class $pk 'Base' '' @() @('ejecutar():void') $true
$b = Add-Class $pk 'Hija' '' @('valor:int') @('ejecutar():void')
[void](Place $d $a 40 40 220 80); [void](Place $d $b 40 220 220 100)
[void](Add-Conn $b $a 'Generalization')
[void]$repo.ReloadDiagram($d.DiagramID)
Exporta $repo $d 'clases_x'
$repo.CloseFile(); $repo.Exit()
```

## 8. Recetas por tipo de diagrama

- **Casos de uso.** El sistema es un `Boundary` grande con `z` alto (queda detrás de los casos de uso). Actores fuera del límite. `include`/`extend` como `Dependency` con estereotipo. Casos de uso con código y título ("CU02 Aprobar solicitud"). Ejemplo: `ejemplo_generico.ps1`, diagrama 1.
- **Clases.** Atributos y operaciones con `Add-Class`; herencia con `Generalization` del hijo al padre. Composición/agregación: crear `Aggregation` y poner `ClientEnd.Aggregation = 2` (composición) o `1` (agregación), `ClientEnd.Navigable = 'Unspecified'`, `Direction = 'Unspecified'` y las cardinalidades en `ClientEnd.Cardinality` / `SupplierEnd.Cardinality`; llamar a `.Update()` en ambos extremos y en el conector (ver `ejemplos_de_otro_proyecto\ejemplo_construir_diagramas.ps1`). Altura de una clase ≈ `38 + 17 × (atributos + operaciones)` (+10 si tiene de ambos). Relación de una clase consigo misma (`Add-Conn $c $c 'Aggregation'` o `'Association'`): EA la dibuja como un lazo diminuto en la esquina; `Set-LazoPropio` lo agranda.
- **Paquetes.** Paquetes con elementos dentro y `Dependency` con estereotipo `import` entre ellos.
- **Secuencia.** `Build-Sequence`: EA reparte los mensajes por orden y la función calcula las coordenadas. Los paréntesis de las etiquetas se cambian por los de ancho completo `（ ）` para que EA no los interprete. Un mensaje de derecha a izquierda se dibuja punteado (retorno). Cada fragmento indica entre qué mensajes va y dónde empiezan sus operandos (`cortes`).
- **Actividad con calles.** `ActivityPartition` por calle (con `z` alto) y cada nodo con `ParentID = calle.ElementID`. Inicio y fin son `StateNode` con subtipo 100 y 101; decisiones, `Decision`; flujos, `ControlFlow` con `TransitionGuard` para la condición. Ejemplo: `ejemplo_generico.ps1`, diagrama 5.
- **Modelo de datos.** Cada tabla es un elemento `Class` (sin estereotipo) cuyos atributos son las columnas; las relaciones son `Association` con cardinalidades en `ClientEnd`/`SupplierEnd`. Para mostrar el signo `+` delante de las columnas, `HideQuals=0` en el `StyleEx` del diagrama. Si se quieren solo las claves primarias y que las foráneas las muestre la línea de la relación, no se agregan las columnas de clave foránea. Ver `ejemplos_de_otro_proyecto\ejemplo_modelo_de_datos_y_secuencias.ps1`.
- **Comunicación.** Diagrama de tipo `Collaboration`; los participantes son `Object` (y `Actor`), y los enlaces son conectores `Association` con el mensaje numerado en el nombre (`'1: registrar(pedido)'`). El conector de tipo `Collaboration` **no dibuja la línea** por COM; con `Association` sí (probado). Mantén la numeración igual a la del diagrama de secuencia de la misma funcionalidad.
- **Objetos.** Diagrama `Object`; el elemento es un `Object` con `ClassifierID = clase.ElementID` y se ve como `p1: Pedido`.
- **Estados.** Diagrama `Statechart`; estados `State`; el inicio es `StateNode` con `Subtype = 3` y el final `StateNode` con `Subtype = 4` (no son los 100/101 de las actividades); transiciones `StateFlow` con `TransitionEvent`, `TransitionGuard` y `TransitionAction`.
- **Robustez ICONIX.** Dos variantes probadas: (A) diagrama `Analysis` con elementos `Boundary`, `Control`, `Entity` (notación de cajas de EA); (B) diagrama `Collaboration` con elementos `Object` y estereotipo `boundary`, `control` o `entity`, que dibuja los **iconos ICONIX clásicos**. Si el `.eapx` de referencia usa una, sigue esa.
- **Navegación web (WAE).** Diagrama `Logical` con `HideQuals=0` en el `StyleEx`. Elementos `Class` con estereotipo `Client Page` (icono de página), `Formulario` y `Server Page` (icono de engranaje; nombre `ps <Acción>`); las tablas son `Artifact` con estereotipo `database` (nombre `BD: <tabla>`, se ven verdes con icono de documento). Atributos con `Visibility='Private'`, tipo vacío, `IsCollection=$true` y `AllowDuplicates=$true` para que se vea `- campo {bag}`. Las operaciones se crean **sin** `()` en el nombre (EA las agrega; si no, sale `guardar()()`). Los conectores son `Association` con el nombre `link …`, `submit …`, `build page load`, `build redirect back` o `access SELECT|INSERT|UPDATE|DELETE`. Con muchos elementos, ordena por columnas: actor y páginas cliente a la izquierda, formularios al centro, páginas servidor a la derecha y tablas en el borde derecho. Ver `ejemplo_navegacion_prototipos_requisitos.ps1`.
- **Prototipo de interfaz.** Diagrama `Custom`; `Screen` como contenedor (con `z` alto) y `GUIElement` con estereotipo (`label`, `text`, `combobox`, `button`...) y `ParentID` = pantalla.
- **Requisitos.** Diagrama `Custom`; elementos `Requirement`; conector `Realisation` del `UseCase` al `Requirement`.
- **Despliegue y componentes.** Ver `ejemplos_de_otro_proyecto\ejemplo_clases_paquetes_secuencia_despliegue.ps1` y `ejemplo_contexto_dominio_arquitectura.ps1`.

## 9. Trampas conocidas (cada una costó tiempo)

1. Una consulta SQL a una **columna que no existe cuelga EA** sin mensaje. Usa límite de tiempo y verifica los nombres de columna en un archivo de prueba.
2. `.ps1` sin BOM → acentos rotos.
3. Composición: sin `ClientEnd.Navigable = 'Unspecified'` aparece una flecha de navegación que no se quiere.
4. **Las líneas (conectores) de un diagrama que no es de secuencia solo quedan guardadas en el archivo si el diagrama se abre y se guarda** (`OpenDiagram`, `SaveDiagram`, `CloseDiagram`; así se crean las filas de `t_diagramlinks`). Sin eso, el PNG exportado en la misma sesión se ve perfecto, pero **al abrir el `.eapx` en EA los elementos aparecen sueltos, sin líneas**. `Exporta` ya lo hace por ti (función `Guardar-Enlaces` de `ea_lib.ps1`); si construyes un diagrama sin llamar a `Exporta`, llama a `Guardar-Enlaces $repo $diag` al terminar. **No lo hagas en secuencias**: envuelve las etiquetas de los mensajes (`Guardar-Enlaces` ya las salta). Para arreglar un archivo ya construido, `guardar_enlaces_de_diagramas.ps1`. Compruébalo siempre reabriendo el archivo: `inspeccionar_eapx.ps1` muestra `con=` (conectores) por diagrama.
5. En los fragmentos de secuencia, las guardas **no pueden llevar `;` ni `=`**. `Set-Guardas` ya maneja que EA guarde primero el operando de abajo.
6. **Autoenvíos (un participante que se llama a sí mismo) dentro de un fragmento o en su borde**: EA les da más altura de la que calcula la función y el marco del fragmento queda desalineado o cortado. Mantén los mensajes de los bordes y del interior como mensajes normales entre participantes distintos (como en `ejemplo_generico.ps1`) y, si necesitas un autoenvío, ponlo lejos de los bordes y revisa el PNG.
7. La barra de activación del primer participante puede cruzar el texto de las guardas del fragmento. Es solo estético; si molesta, cambia el orden de los participantes.
8. Varias relaciones entre el **mismo par** de elementos se dibujan encimadas en una sola línea. Si hacen falta dos, separa los elementos o usa una sola relación con etiqueta.
9. Parámetros de operaciones: EA los guarda en orden inverso; `Add-Oper` asigna `Position`. Para verlos en el diagrama, `OpParams=3` en `PDATA` (lo hace `Add-Diag`).
10. Elementos anidados (nodos dentro de una calle): `ParentID` más el orden de apilado `Sequence` (`Place` con `z`); el contenedor con número **mayor** queda detrás.
11. Correr un script de construcción dos veces sobre el mismo archivo **duplica** los elementos. Usa `Find-Elem` o `Get-Or-Add` cuando quieras reutilizar.
12. Los paquetes que se crean y quedan vacíos ensucian el modelo: revisa "paquetes vacíos" en la inspección.
13. Los números no sustituyen a los ojos: exporta el PNG y míralo siempre.
14. Cambiar `Abstract`, `IsStatic` o `Visibility` en el objeto `Method` **después** de crear la operación no persiste; usa `Set-OpFlags` (o las marcas de `Add-Class`). En atributos sí funciona por API.
15. Con `HideQuals=0` (necesario para ver `+ - #`), EA escribe el nombre calificado `Paquete::Clase` si el elemento vive en **otro paquete** que el diagrama. Pon en un mismo paquete los elementos de un conjunto de diagramas.
16. EA muestra atributos y operaciones en **orden alfabético** en esta instalación aunque `Pos` guarde el orden de creación; no es un error del script.
17. Un diagrama con `Interface`, `Note` + `NoteLink`, colores de conector (`DiagramLink.LineColor`) y de elemento (`DiagramObject.BackgroundColor`) está probado en `ejemplo_patrones_detalle.ps1`.
18. Las **zonas** (`Boundary`) guardan su color en `ObjectStyle` (`BCol`, en BGR), no en `BackgroundColor`: usa `Set-ColorZona`. Una zona creada de cero sale con borde continuo; **copiarla de una zona existente** (`.Clone()`) conserva el borde discontinuo del diseño.
22. En una relación de un elemento consigo mismo, el tipo `Aggregation` dibuja el rombo **sin** la flecha abierta; con un conector `Association` que tenga el rombo en el origen y `SupplierEnd.Navigable = 'Navigable'` salen los dos (`Add-AutoAgregacion`). El lazo por defecto es diminuto: `Set-LazoPropioArriba` (borde superior) o `Set-LazoPropio` (borde derecho) lo agrandan.
20. Las **notas** (`Note`) con varias líneas necesitan saltos `\r\n` (en PowerShell, `` `r`n ``); con solo `` `n `` EA las muestra en una línea corrida.
21. `armar_documento_parcial.py` (en `ejemplos_de_otro_proyecto`) arma con python-docx el documento de entrega: portada, índice con campo TOC, un diagrama genérico por patrón con su cita, el diagrama específico en página horizontal, un recorte de la zona del patrón y una tabla de roles contra el código; el índice se actualiza abriendo el .docx con Word (COM) y guardando.
19. Un diagrama copiado por `Clonar-Paquete` vive en un paquete nuevo con **copias** de los elementos (no los mismos): si quieres que los cambios del original se reflejen, no clones; coloca los mismos elementos en un diagrama nuevo (con `Place`). Para un diseño que se entrega aparte (parcial 2), la copia es lo correcto.

## 10. Patrones de diseño en los diagramas

Si tu entrega pide **agregar patrones de diseño a diagramas que ya existen**:

- **No sobrescribas los diagramas originales.** Crea diagramas nuevos "con patrón" en un paquete aparte que **reutilizan las mismas clases** (en EA un elemento puede aparecer en muchos diagramas: búscalo con `Find-Elem` y colócalo con `Place`) y agregan los participantes del patrón. Así se ve el antes y el después.
- **Cada caso de uso lleva dos diagramas:** uno de clases con el rol de cada clase marcado con un estereotipo (`«Handler»`, `«Strategy»`...) y uno de secuencia, **construido de nuevo** con `Build-Sequence` (no parchear el original: las secuencias son frágiles), que muestre cómo colaboran los participantes al ejecutarse.
- **Confirma en el código que el patrón existe** antes de dibujarlo. Si es una propuesta y no está en el código, rotúlalo "propuesto".
- Si los conectores que ya existían no aparecen en el diagrama nuevo, corre `guardar_enlaces_de_diagramas.ps1` sobre ese diagrama (nunca sobre una secuencia).
- Nombra los diagramas para que se vea la comparación: `CU05 Registrar pedido — clases (con Strategy)`.
- **Si ya tienes un diseño que debes respetar** (zonas de color, orden, estilo que pide el docente): **no lo redibujes, duplícalo**. `Clonar-Paquete` copia el paquete completo con sus zonas, colores y conectores; luego se hace lugar (`Mover-Objetos`), se traen las clases del patrón (`Copiar-Elemento`), se crea la zona del patrón **copiando una zona existente** (`.Clone()` del `Boundary`, hereda el borde discontinuo) y se colorea con `Set-ColorZona`. Ejemplo completo y probado: `scripts\ejemplos_de_otro_proyecto\ejemplo_replicar_diseno_y_agregar_patron.ps1` (copia de un caso de uso con zonas Cliente / API Gateway / ms-* y agregado del patrón Strategy en una zona nueva, con sus conectores en azul).
- **Formato de entrega con patrones** (diagrama genérico del patrón con cita + diagrama específico del caso de uso dentro de la arquitectura Vista → Controlador → Modelos → Conexión, con las relaciones del patrón en azul): ver `FORMATO_DISENO_DETALLE_PROCEDIMENTAL.md` y `scripts\ejemplo_patrones_detalle.ps1` (Strategy y Template Method). Ahí hay también cómo se vería cada otro patrón en ese formato.

Patrones frecuentes y su forma en UML:

| Patrón | Participantes (estereotipos) | Forma en el diagrama de clases |
|---|---|---|
| **Chain of Responsibility** | `Handler`, `ConcreteHandler`, `Client` | Ver la sección 11. |
| Strategy | `Context`, `Strategy` (abstracta/interfaz), `ConcreteStrategy` | Context → Strategy (asociación); ConcreteStrategy → Strategy (herencia/realización) |
| Factory Method / Abstract Factory | `Creator` / `Factory`, `Product`, `ConcreteProduct` | Factory → Product (dependencia `create`); ConcreteProduct → Product (herencia) |
| Singleton | `Singleton` | Clase con atributo estático `instancia` y operación estática `obtenerInstancia()` |
| Observer | `Subject`, `Observer`, `ConcreteObserver` | Subject agrega Observer (agregación 1..*); ConcreteObserver → Observer |
| Adapter | `Target`, `Adapter`, `Adaptee` | Adapter → Target (herencia/realización); Adapter → Adaptee (asociación) |
| Facade | `Facade` + subsistemas | Facade con dependencias hacia varias clases |
| Repository / DAO | `Repository`, `Entity` | Servicio → Repository → Entity (dependencias) |
| MVC | `Model`, `View`, `Controller` | Controller → Model, Controller → View, View observa Model |
| Template Method | `AbstractClass` con operaciones abstractas, `ConcreteClass` | Herencia; el método plantilla se anota con una nota |
| State | `Context`, `State`, `ConcreteState` | Igual que Strategy, con transiciones entre estados |
| Decorator | `Component`, `Decorator`, `ConcreteDecorator` | Decorator → Component (herencia y agregación) |

## 11. Patrón destacado: Chain of Responsibility (cadena de responsabilidad)

(En inglés se escribe *Responsibility*.)

**Idea.** Una solicitud pasa por una cadena de objetos. Cada uno decide si la atiende o se la pasa al siguiente. El que envía la solicitud solo conoce al **primero** de la cadena, no a quién la resuelve.

**Cuándo aparece en un sistema.** Aprobaciones por niveles (jefe → gerente → director), validaciones en serie, filtros o middlewares de una petición web, manejo de eventos que "burbujean", niveles de registro (log), soporte técnico escalonado, manejadores de errores.

**Participantes.**

| Participante | Estereotipo | Qué hace |
|---|---|---|
| Manejador base | `«Handler»` (clase abstracta o interfaz) | Declara el método para procesar la solicitud y guarda la referencia al **siguiente** manejador |
| Manejadores concretos | `«ConcreteHandler»` | Cada uno decide si puede atender; si no, delega en el siguiente |
| Cliente | `«Client»` | Arma o recibe la cadena y envía la solicitud al primer manejador |
| Solicitud (opcional) | — | El objeto que viaja por la cadena |

**Cómo se dibuja.**

1. **Diagrama de clases (versión del libro).** El `«Handler»` es una clase abstracta que **se agrega a sí misma**: relación de la clase consigo misma con **rombo hueco y flecha abierta**, rotulada `siguiente` (en el libro, *successor*). Es lo que hace el código: la base guarda su sucesor con su propio tipo. Cada `«ConcreteHandler»` hereda del `«Handler»` (`Generalization`). El `«Client»` se asocia **solo con el `«Handler»`** (flecha), no con cada manejador concreto; en un diseño que usa dependencias punteadas, una dependencia punteada de quien arma la cadena hacia el manejador base. Los manejadores concretos llevan sus atributos propios (por ejemplo, `limite`) y la operación que decide. En EA se dibuja con `Add-AutoAgregacion` (conector `Association` con rombo + navegabilidad) y `Set-LazoPropioArriba` (lazo sobre el borde superior); el tipo `Aggregation` dibuja el rombo pero no la flecha.
2. **Diagrama de secuencia.** El cliente llama al primer manejador. Un fragmento `alt` con guardas muestra las dos salidas: `[el jefe puede aprobar]` (responde y termina) y `[el jefe no puede: pasa al siguiente]` (llama al siguiente manejador, que repite el patrón hasta que alguien atiende). Mostrar la cadena completa en la rama de delegación (jefe → gerente → director). Sin autoenvíos en los bordes del fragmento (trampa 6).
3. **Diagrama de actividad** (opcional, muy claro para explicarlo): el bucle "¿puede atender?" → no → "pasa al siguiente" → vuelve a "recibe la solicitud".
4. **Caso de uso específico:** nómbralo por el comportamiento, p. ej. "Aprobar solicitud (cadena de aprobación)".

Todo esto está construido y verificado en `scripts\ejemplo_generico.ps1` (diagramas 2, 3 y 5) y, con zonas de color, en `scripts\ejemplos_de_otro_proyecto\ejemplo_cadena_de_responsabilidad_en_diseno.ps1`. Fragmento clave:

```powershell
$ha = Add-Class $pk 'Aprobador' '' @('-siguiente:Aprobador') @('establecerSiguiente(a:Aprobador):Aprobador','procesar(s:Solicitud):void','*puedeAprobar(s:Solicitud):bool') $true
$h1 = Add-Class $pk 'JefeDeArea' '' @('limite:decimal') @('puedeAprobar(s:Solicitud):bool')
[void](Add-Conn $h1 $ha 'Generalization')                       # los concretos heredan del manejador abstracto
$auto = Add-AutoAgregacion $ha 'siguiente'                      # la cadena: el manejador se agrega a sí mismo (rombo + flecha abierta)
$c = Add-Conn $cliente $ha 'Association' 'inicia la cadena'; $c.Direction = 'Source -> Destination'; [void]$c.Update()   # el cliente solo conoce al manejador abstracto
Guardar-Enlaces $repo $diag
Set-LazoPropioArriba $repo $diag.DiagramID $auto.ConnectorID 700 -70 80 32   # x, y del borde superior (negativa), ancho y alto del lazo
```

**Variantes.** *Cadena pura:* solo un manejador atiende (aprobaciones) → secuencia con `alt`. *Tubería (pipeline/middleware):* todos los manejadores procesan y pasan al siguiente (filtros, validaciones) → secuencia con mensajes en serie, sin `alt`, y la nota "cada manejador procesa y delega". Decide y rotula qué pasa **al final de la cadena** si nadie atiende (rechazar, error, valor por defecto).

**Cómo comprobar que de verdad es este patrón en el código.** Busca (1) un tipo base con un método de procesamiento, (2) una referencia al siguiente (`siguiente`, `next`, `successor`, `set_next`, o una lista ordenada de manejadores que se recorre), (3) un método que decide "atiendo / delego" y (4) quién arma la cadena (el cliente, una fábrica, la configuración). Si el código solo tiene un `if/elif` largo, **no** es Chain of Responsibility.

**Errores comunes al diagramarlo.** Dibujar la cadena como herencia entre manejadores; unir el cliente con cada manejador concreto; olvidar el rombo del sucesor (con solo una asociación simple el diagrama no es el del libro); no mostrar qué pasa cuando nadie atiende. Y si el docente pide una interfaz del manejador (variante con `IManejador`), el código debe tenerla; si no, el diagrama muestra una clase que no existe.

## 12. Lo que no se probó (probar primero sobre una copia)

- Notación de "ocurrencia de colaboración" de UML para patrones (`Collaboration` / `CollaborationOccurrence`).
- Interfaces con notación "piruleta" (la interfaz como caja `«interface»` y la relación `Realization` sí están probadas).
- Duplicar un diagrama completo por COM.
- BPMN (diagramas de procesos de negocio con la notación BPMN 2.0 de EA): no se probó. Para procesos, lo verificado es el diagrama de actividad con calles; si piden BPMN, probar primero en una copia y, si EA no da la notación, avisar antes de reemplazarla.
- Flechas de dirección en los enlaces de comunicación y estados compuestos o regiones en diagramas de estados.
- Fragmentos de secuencia anidados.

Si algo de esto falla o se cuelga, pasa a la alternativa más simple (estereotipos + título + notas del elemento) y sigue.

## 13. Preguntas que debe hacerse (o hacerte) quien use esta guía antes de empezar

1. ¿Cuál es el `.eapx` base? ¿Hay un prompt, una rúbrica o un formato que pida el docente o el cliente?
2. ¿Qué diagramas hay que producir, de qué módulos o casos de uso, y qué debe contar cada uno?
3. ¿Qué patrones lleva cada caso de uso y están implementados en el código o son propuestas?
4. ¿Cómo se entrega: `.eapx`, PNG, dentro de un documento Word? ¿Qué tamaño y estilo de figura?
5. ¿El proyecto tiene reglas sobre commits o sobre qué archivos pueden entrar al repositorio? Esas reglas mandan sobre esta guía.

## 14. Prompt de arranque para pegar en una sesión nueva (rellena lo que está entre corchetes)

```
Vas a construir/modificar diagramas UML en Enterprise Architect por COM para el sistema [NOMBRE Y DESCRIPCIÓN CORTA DEL SISTEMA].

Lee primero, en este orden:
1. El CLAUDE.md o las reglas de este proyecto, si existen.
2. [RUTA]\LEEME_PRIMERO.md (cómo automatizar EA, trampas, recetas, patrones).
3. [MI PROMPT O RÚBRICA DE DISEÑO DE DIAGRAMAS] y el .eapx base: [RUTA DEL .eapx].

Qué necesito: [QUÉ DIAGRAMAS, DE QUÉ MÓDULOS/CASOS DE USO; SI HAY PATRONES, CUÁL EN CADA CASO].

Reglas: trabaja solo sobre una copia del .eapx; no toques el original; no sobrescribas diagramas existentes, crea diagramas nuevos; saca los nombres de clases, métodos y tablas del código real; confirma en el código que cada patrón existe antes de dibujarlo; exporta cada diagrama a PNG y míralo antes de darlo por bueno; no agregues estos archivos de trabajo al repositorio.

Empieza corriendo scripts\inspeccionar_eapx.ps1 sobre una copia del .eapx base, muéstrame el resultado y propón un plan por diagrama usando la ficha de la sección 5. No construyas nada hasta que yo lo apruebe.
```
