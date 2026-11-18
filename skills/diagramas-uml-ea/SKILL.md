---
name: diagramas-uml-ea
description: Construir, ampliar o modificar diagramas UML en Sparx Enterprise Architect (archivo .eapx real, por COM/PowerShell) a partir de la documentación y el código de CUALQUIER proyecto. Cubre casos de uso, actividades, secuencia, comunicación, clases, objetos, componentes, despliegue, paquetes, estados, robustez ICONIX, modelo de dominio y de datos, y agregar patrones de diseño (por ejemplo Chain of Responsibility) a diagramas existentes. Usar cuando pidan "créame los diagramas de este proyecto", un .eapx, diagramas en Enterprise Architect o Sparx, o diagramas UML con elementos y conectores editables. Palabras clave - Enterprise Architect, Sparx, EA, .eapx, UML, diagramas, casos de uso, secuencia, clases, componentes, despliegue, ICONIX, robustez, navegación web, prototipos, requisitos, patrones de diseño, Chain of Responsibility, modelo de datos.
license: CC BY-NC-ND 4.0 (ver LICENSE)
---

<!-- Copyright (c) 2026 Hebert Suárez Burgos. Licencia CC BY-NC-ND 4.0: https://creativecommons.org/licenses/by-nc-nd/4.0/deed.es -->
<!-- Puedes usar y compartir esta skill SIN CAMBIOS, dando crédito al autor. No se permite uso comercial ni publicar versiones modificadas. -->


# Diagramas UML en Enterprise Architect (por COM)

Archivos en esta carpeta (junto a este `SKILL.md`; funciona con cualquier agente que lea skills en formato `SKILL.md` y pueda ejecutar PowerShell):
- `GUIA_TECNICA.md`: cómo automatizar EA 15, funciones, recetas por tipo de diagrama, trampas, patrones de diseño (con Chain of Responsibility). **Léela completa antes de construir.**
- `scripts\`: `ea_lib.ps1` (biblioteca), `nuevo_eapx.ps1`, `inspeccionar_eapx.ps1`, `guardar_enlaces_de_diagramas.ps1`, `ejemplo_generico.ps1`, `ejemplo_tipos_adicionales.ps1`, `ejemplo_patrones_detalle.ps1`, `ejemplo_navegacion_prototipos_requisitos.ps1` y `ejemplos_de_otro_proyecto\` (solo para ver técnicas).
- `FORMATO_DISENO_DETALLE_PROCEDIMENTAL.md`: cómo se entrega un "diseño de detalle procedimental con patrones" (diagrama genérico del patrón + diagrama específico del caso de uso dentro de la arquitectura), con la notación y el método para ampliar casos de uso.
- `ejemplo_resultado_png\`: lo que producen los ejemplos.

## Cuándo usarla y cuándo no

- **Sí:** pedir los diagramas de un proyecto en EA, ampliar o corregir un `.eapx`, agregar un patrón de diseño a diagramas ya hechos, reproducir el estilo de un `.eapx` de referencia.
- **No:** diagramas sueltos en Mermaid o PlantUML, o imágenes sin repositorio de EA. Tampoco generes XMI salvo que lo pidan.

## Principios (no negociables)

1. **Pedido genérico.** No asumas ICONIX, Scrum, PUDS u otra metodología, ni una lista fija de diagramas. La metodología, el tipo y la cantidad de diagramas salen de la documentación, de las instrucciones del usuario y de las necesidades del proyecto.
2. **No inventes** requisitos, historias de usuario, casos de uso, componentes, estados ni relaciones para completar un diagrama. Si faltan datos indispensables o hay contradicciones importantes, **pregunta**. Las suposiciones menores se documentan (cuáles y por qué). Lo que sea propuesta, rotúlalo como propuesto.
3. **Resultado real:** un `.eapx` auténtico con elementos y conectores editables; nunca un PDF, imagen o HTML presentado como repositorio. Si EA o su interfaz COM no están disponibles, explica la limitación y **detente**.
4. **No destruyas nada.** Trabaja sobre una copia. Si el archivo de salida ya existe, no lo sobrescribas ni lo borres sin preguntar. Conserva intactos la documentación, el código y los archivos de referencia (no modifiques el `.eapx` de referencia).
5. **Verifica antes de afirmar.** Nada "funciona" o "se ve bien" si no lo comprobaste; lo que no pudiste comprobar, dilo.

## Flujo de trabajo

**1. Entorno.** Comprueba que EA y su COM están disponibles:
`powershell -NoProfile -Command "$r = New-Object -ComObject EA.Repository; 'EA COM disponible'; $r.Exit()"`.
Los scripts se corren con Windows PowerShell 5.1 y EA debe estar cerrado sobre el archivo que se toca. Detalles y límite de tiempo en la guía (sección 3).

**2. Análisis inicial.** Identifica el proyecto, su documentación y su código, y cualquier `.eapx` disponible. Revisa los documentos para determinar: objetivo y alcance; metodología mencionada; actores, requisitos, casos de uso, historias de usuario, procesos y componentes; los diagramas pedidos explícitamente y los adicionales necesarios. Si hay código, úsalo para contrastar entidades, servicios, componentes y arquitectura (con herramientas: AST, grep, esquema de la base; no de memoria). Si hay varios proyectos o documentos y no está claro cuáles usar, **pregunta antes de empezar**.

**3. Plan de diagramas.** Antes de construir, prepara una lista con: los diagramas pedidos explícitamente; los adicionales que recomiendas y por qué; el alcance de cada uno (global, por módulo, proceso, caso de uso o historia); sus elementos principales; y la fuente documental o de código que lo respalda (usa la ficha de la guía, sección 5). Si lo pedido está claro, sigue sin esperar confirmación. Si hay varias interpretaciones, o quieres añadir diagramas que cambian mucho el alcance, **muestra el plan y pregunta** cuáles incluir.

**4. `.eapx` de referencia (si hay).** Inspecciónalo con `scripts\inspeccionar_eapx.ps1` (organización, tipos de diagrama, notación, estereotipos, conectores, estilo). Sigue sus convenciones cuando apliquen; **no copies** requisitos ni elementos de otro proyecto como si fueran de este; no lo modifiques. Sin referencia, usa las convenciones de UML, BPMN, ICONIX o modelado de datos que correspondan.

**4b. Diseño que hay que respetar.** Si el usuario tiene diagramas con un diseño impuesto (zonas de color, orden, estilo del docente) y pide "lo mismo pero con X" (otro patrón, otro caso de uso), **duplica el diseño, no lo redibujes**: `Clonar-Paquete` (copia profunda con zonas, colores y conectores) y agrega encima lo nuevo; mira `scripts\ejemplos_de_otro_proyecto\ejemplo_replicar_diseno_y_agregar_patron.ps1` y la guía, sección 10. Nunca modifiques el archivo del usuario: trabaja en una copia y entrégala aparte.

**5. Crear o abrir.** Archivo nuevo: `scripts\nuevo_eapx.ps1 -Archivo "ruta\proyecto.eapx"` (se niega a sobrescribir). Archivo existente: trabaja en una copia.

**6. Organizar el modelo** en paquetes claros según los diagramas y el alcance (por ejemplo: visión general, requisitos, casos de uso, procesos y actividades, dominio y clases, interacciones, arquitectura, datos, otros); adapta nombres y carpetas a lo que el proyecto necesite. No crees paquetes vacíos. Si hay un diagrama por caso de uso, proceso, módulo o historia, organízalos para que se encuentren fácil.

**7. Construir** con `scripts\ea_lib.ps1`: un script por grupo de diagramas, un `try/catch` y un registro por diagrama, elementos reutilizados con `Find-Elem` en vez de copias incoherentes, y `Exporta` al final de cada diagrama (guarda también las líneas del diagrama en el archivo). Empieza por `ejemplo_generico.ps1` y `ejemplo_tipos_adicionales.ps1` como plantillas.

**8. Reglas por tipo** (aplica solo las de los tipos del plan; recetas y código en la guía). **Cada diagrama sigue las normas de su propio tipo**: no mezcles la notación de uno con la de otro (por ejemplo, nada de mensajes numerados en robustez, ni tipos de dato en el modelo conceptual). Si el `.eapx` de referencia o el docente usan otra convención, sigue la de ellos y dilo.
- *Casos de uso:* actores, casos de uso y relaciones justificadas; `include`/`extend` solo cuando corresponda; vistas globales o individuales según los requisitos.
- *Actividades y procesos:* actividades, decisiones, inicio, fin y responsables (calles); UML o BPMN según lo pedido; flujos coherentes con la documentación.
- *Clases de diseño:* clases con atributos (con visibilidad y tipo) y operaciones reales, relaciones justificadas, multiplicidades, herencias y dependencias. **Sin claves foráneas como atributo**: la asociación entre clases (o un atributo que es el objeto, `- cliente: Cliente`) ya representa la relación. Guarda y **verifica cada atributo y operación individualmente** tras reabrir.
- *Secuencia:* hay **dos variantes**; si no está claro cuál piden, pregunta o haz las dos, y no mezcles sus notaciones en un mismo diagrama:
  - **Secuencia de análisis (ICONIX):** sale del diagrama de robustez. Participantes con estereotipo `boundary`, `control` y `entity` (EA los dibuja como **círculos**); mensajes en lenguaje del negocio (`Obtener sugerencia()`). En `Build-Sequence`, `t = 'boundary' | 'control' | 'entity'`.
  - **Secuencia de diseño:** la que se pide para implementación (por ejemplo en taller de grado). Participantes como **cajitas** (rectángulos) con nombre de objeto `:Clase` tomado del **diagrama de clases de diseño o del código real** (`:PedidoView`, `:PedidoController`, `:PedidoService`, `:PedidoRepository`, `:Pedido`); el actor puede ir al inicio. Mensajes = **métodos reales con parámetros** (`crear(PedidoDTO)`, `guardar(pedido)`), retornos punteados con el valor devuelto, autollamadas para validaciones, `new Clase(...)` para crear objetos y fragmentos `alt`/`opt`/`loop` con su condición. En `Build-Sequence`, `t = ''` (sin estereotipo). Cada mensaje debe existir como operación en la clase que lo recibe.
  - En las dos: verifica explícitamente el orden (`SequenceNo`) y que **persista al cerrar y volver a abrir**. Las condiciones de los fragmentos se escriben **sin corchetes** (EA los agrega).
- *Comunicación:* participantes y mensajes numerados, coherentes con la secuencia de la misma funcionalidad.
- *Modelo de dominio / mapeo conceptual:* solo las clases del negocio con sus relaciones y multiplicidades. Cada clase lleva sus atributos con visibilidad `+` y su identificador (clave primaria, por ejemplo `+ id_campana`). **No pongas claves foráneas** (la relación con la otra clase ya las representa), **ni tipos de dato** (`int`, `varchar`, `String`, `Date`...), **ni operaciones**. Los tipos, las claves foráneas y los métodos van en el diagrama de clases de diseño y en el modelo de datos.
- *Robustez ICONIX:* solo si está pedida o la metodología/documentos la justifican; actores y objetos boundary, control y entity; si el `.eapx` de referencia usa `Collaboration` con `Object` y estereotipos, sigue esa convención; comprueba que los estereotipos se guarden y se vean. Reglas de conexión: Actor ↔ Boundary; Boundary ↔ Control; Control ↔ Entity; Control ↔ Control. **Nunca** Actor ↔ Control, Actor ↔ Entity, Boundary ↔ Entity ni Entity ↔ Entity. Una entidad **no inicia** una consulta hacia un control: el control es quien usa la entidad. Usa asociaciones simples, sin mensajes numerados ni flechas de llamada; el orden de los mensajes (por ejemplo, los pasos y las compensaciones de una SAGA) va en el diagrama de secuencia. Cada control representa una acción o responsabilidad del caso de uso; no lo dejes en un único control que lo haga todo.
- *Navegación web (WAE / Conallen), uno por actor:* es el diagrama más completo para sistemas web y se pide **un diagrama por actor** (`Diagrama de Navegacion - <Actor>`), con **todas** las pantallas, formularios, páginas servidor y tablas a las que llega ese actor. Diagrama `Logical` (de clases) con `HideQuals=0`. Elementos (todos `Class`):
  - **Página cliente** (estereotipo `Client Page`, EA dibuja el icono de página): cada pantalla (Login, Dashboard, Lista X, Perfil). Atributos = datos que muestra; operaciones = acciones del usuario (`abrirCrear()`, `buscar()`, `navigateTo()`).
  - **Formulario** (estereotipo `Formulario`): cada formulario o modal (Registrar X, Editar X). Atributos = campos; operaciones = `guardar()`, `cerrarForm()`, `listarX()` para cargar combos.
  - **Página servidor** (estereotipo `Server Page`, icono de engranaje), con nombre `ps <Acción>` (ps Listar X, ps Registrar X, ps Actualizar X, ps Eliminar X, ps Toggle X). Atributos = parámetros que recibe; operación = método del controlador (`index()`, `store()`, `update()`, `destroy()`).
  - **Tabla**: elemento `Artifact` (no `Class`) con estereotipo `database` y nombre `BD: <tabla>` (o `BD: tabla1 / tabla2` si se usan juntas); EA la pinta verde con icono de documento. Atributos = columnas que se usan.
  - Todos los elementos salvo el actor y las tablas son `Class`.
  - Atributos: privados (`-`), **sin tipo** y como colección (`IsCollection` + `AllowDuplicates` → EA muestra `{bag}`). Operaciones: públicas (`+`), sin parámetros; el nombre se guarda **sin** `()`.
  - Conectores `Association` cuyo nombre es `<tipo> <acción>`: Actor → Login `link usa el sistema`; página cliente → página cliente `link <destino>`; página cliente → formulario `link abrirCrear()` / `link abrirEditar()`; formulario o página cliente → página servidor `submit guardar()` / `submit toggle` / `submit eliminar`; página servidor → página cliente `build page load` (carga datos) o `build redirect back` (vuelve tras guardar); página servidor → tabla `access SELECT|INSERT|UPDATE|DELETE`. Nunca conectes una página cliente o un formulario directamente con una tabla.
  - Variantes de `build` según cómo responde el servidor: `build page load`, `build redirect`, `build redirect back`, `build redirect login`, `build JSON` (respuesta a una petición asíncrona) o el método real del framework (por ejemplo `build Inertia::render`). Las de `submit` llevan el método o la acción real (`submit guardar()`, `submit eliminar`, `submit cambiarPassword()`); si la acción tiene una condición de rol, va entre paréntesis (`submit eliminar (propietario/director)`).
  - Cada operación CRUD tiene su propia página servidor (`ps Listar X`, `ps Registrar X`, `ps Actualizar X`, `ps Eliminar X`, `ps Toggle X`), cada una con su `access` a las tablas que toca. El perfil del actor (ver, editar datos, cambiar contraseña) y el login van en **todos** los diagramas.
  - Tamaño de referencia (proyecto académico con 5 actores): el actor con más funciones tenía 11 páginas cliente, 15 formularios, 35 páginas servidor y 8 tablas; el más simple, 5, 4, 7 y 4. Si un actor sale con muchos menos, probablemente faltan acciones del código.
  - Para que tu compañero o el usuario puedan reimportar, exporta también cada diagrama a XMI (`Diagrama de Navegacion - <Actor>.xml`) además del PNG. **No probado por COM** (`GetProjectInterface().ExportPackageXMI`); pruébalo antes en una copia, y si falla, se exporta a mano desde EA (Publicar → Exportar XML).
  - Saca pantallas, formularios, rutas y tablas del **código real** (rutas/controladores, componentes de la interfaz, esquema de BD) y no los inventes. Ejemplo: `ejemplo_navegacion_prototipos_requisitos.ps1`, diagrama 1.
- *Prototipos de interfaz:* uno por pantalla principal. Diagrama `Custom`; la pantalla es un elemento `Screen` y cada control es un `GUIElement` con estereotipo (`label`, `text`, `combobox`, `button`, `list`, `checkbox`...) y `ParentID` = pantalla. Los campos deben coincidir con los del formulario del diagrama de navegación y de la descripción del caso de uso.
- *Requisitos:* diagrama `Custom`; cada requisito es un `Requirement` con su código (`RF01 ...`, `RNF01 ...`); la trazabilidad es `Realisation` del caso de uso al requisito que cumple. Todo RF debe quedar cubierto por algún caso de uso.
- *Componentes, paquetes y despliegue:* módulos, servicios, nodos, dispositivos, bases de datos según la arquitectura documentada o implementada; distingue lo existente de lo propuesto.
- *Estados:* estados, transiciones y eventos de las entidades o procesos que lo requieran; no inventes ni estados ni transiciones.
- *Modelo de datos (lógico/físico, relacional):* es el **único** de los diagramas de datos que lleva claves foráneas. Cada tabla lleva su clave primaria (`PK`) y una columna `FK` por cada relación (en el lado "muchos" de una 1:N; en las N:M, una tabla intermedia con las dos FK); el físico agrega los tipos de dato (`INT`, `VARCHAR(100)`, `DATE`...) y restricciones, coherentes con el esquema real; **no modifiques la base de datos**.
- *Resumen de claves foráneas:* modelo conceptual / de dominio → **no**; diagrama de clases de diseño → **no** (la asociación las representa); modelo lógico y físico de datos → **sí**. Si el docente o el `.eapx` de referencia piden otra cosa, sigue eso y dilo.
- *Otros:* usa el tipo, los elementos y la notación apropiados; si EA no soporta exactamente la notación pedida, dilo y pregunta antes de reemplazarla.
- *Patrones de diseño:* guía, secciones 10 y 11, y `FORMATO_DISENO_DETALLE_PROCEDIMENTAL.md`. Crear diagramas "con patrón" que reutilizan las mismas clases; confirmar en el código que el patrón existe; por cada caso de uso, diagrama genérico del patrón (con cita) + diagrama específico dentro de la arquitectura real.

**9. Coherencia y presentación.** Mismos nombres e identificadores en todo el repositorio; elementos reutilizados entre diagramas; diagramas relacionados que no se contradigan; conectores con dirección, tipo y etiqueta correctos; cada diagrama legible, sin solapamientos ni elementos de relleno.

**10. Verificación final** (antes de decir que está terminado): guarda, cierra y **reabre** el `.eapx` (`inspeccionar_eapx.ps1`); cuenta diagramas por tipo y compara con el plan; comprueba que hay elementos y conectores reales (`con=` mayor que 0 en los diagramas que no son de secuencia); verifica nombres, relaciones, estereotipos, atributos, operaciones y orden de mensajes; compara con la documentación; **exporta los PNG y míralos** (muestra representativa como mínimo); indica lo que no pudiste comprobar.

**11. Entrega.** Informa: ruta absoluta del `.eapx`; lista de diagramas por tipo y cantidad; documentos y archivos de código usados como fuente; metodología identificada (si está documentada); cómo se creó y qué comprobaciones se hicieron; si se revisó visualmente en EA o solo por COM/PNG; suposiciones, discrepancias, omisiones, limitaciones, errores y trabajo pendiente.

## Qué está probado (EA 15, por COM)

| Tipo | Estado | Dónde verlo |
|---|---|---|
| Casos de uso, clases, paquetes, secuencia (con `alt`, `opt`, `loop`...), actividad con calles | Probado | `ejemplo_generico.ps1` |
| Patrón Chain of Responsibility (clases, secuencia, actividad) | Probado | `ejemplo_generico.ps1`, guía sección 11 |
| Comunicación, objetos, estados, robustez ICONIX (2 variantes) | Probado | `ejemplo_tipos_adicionales.ps1` |
| Strategy y Template Method (genérico + específico), Singleton, abstractas/estáticas/protegidas, interfaz, notas, colores | Probado | `ejemplo_patrones_detalle.ps1` |
| Despliegue, componentes, modelo de datos, secuencias largas | Probado (otro sistema) | `ejemplos_de_otro_proyecto\` |
| Navegación web por actor (página cliente, formulario, página servidor, tabla), prototipo de interfaz, requisitos | Probado | `ejemplo_navegacion_prototipos_requisitos.ps1` |
| Crear `.eapx` nuevo | Probado | `nuevo_eapx.ps1` |
| Duplicar un diseño existente (paquete completo con zonas de color) y agregarle un patrón | Probado | `ejemplos_de_otro_proyecto\ejemplo_replicar_diseno_y_agregar_patron.ps1` |
| BPMN 2.0, ocurrencias de colaboración, duplicar diagramas, fragmentos anidados, interfaces "piruleta" | **No probado** | probar primero en una copia y mirar el PNG |

## Trampas que más cuestan (el resto, en la guía, sección 9)

1. Sin abrir y guardar el diagrama, **sus líneas no quedan en el archivo** (el PNG de la misma sesión se ve bien; al abrir el `.eapx` los elementos aparecen sueltos). `Exporta` ya lo hace; en secuencias no se debe.
2. Una consulta SQL a una columna inexistente **cuelga EA**: usa límite de tiempo y `taskkill /F /IM EA.exe` si pasa.
3. Los `.ps1` con acentos deben ir en **UTF-8 con BOM**.
4. Correr un script de construcción dos veces sobre el mismo archivo **duplica** los elementos: copia nueva cada vez.
5. Los autoenvíos dentro o en el borde de un fragmento de secuencia desalinean el marco.
6. Mira siempre el PNG: los conteos no dicen si un diagrama se lee bien.

## Corregir un diagrama que el usuario ya acomodó

1. **Respaldo con fecha y hora** antes de escribir (`archivo.eapx.backup_AAAAMMDD_HHMMSS`).
2. **Cierra EA por completo** antes de editar (`Get-Process EA` debe salir vacío): con EA abierto el archivo queda bloqueado o se pisan los cambios.
3. **Solo agrega.** No borres, reemplaces, renombres ni muevas elementos o conectores que ya existen; respeta los tamaños y el acomodo que dejó el usuario. Coloca lo nuevo en espacio libre, sin solaparlo con lo existente.
4. Antes de agregar, busca si el elemento ya existe en el paquete (`Find-Elem`) para no duplicarlo.
5. Toca **solo el diagrama pedido**; anota el estado de los demás (sobre todo los que el usuario ya dio por buenos) y comprueba al final que no cambiaron.
6. Guarda, cierra, **reabre** y verifica que lo agregado persistió y lo anterior sigue igual. Informa los IDs de lo agregado y la ruta del respaldo.
