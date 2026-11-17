# Formato "Diseño de detalle procedimental con patrones de diseño"

Sacado de un ejemplo real de entrega (PDF de 7 páginas, segundo parcial de la materia Arquitectura de Software) con dos casos de uso: **Strategy** y **Template Method**. Sirve como **modelo de qué se espera** cuando piden "diagrama de detalle procedimental con patrones" y de cómo ampliar los casos de uso que ya existen. Todo lo de aquí se reproduce en Enterprise Architect con `scripts\ejemplo_patrones_detalle.ps1` (dominio neutro, probado).

## 1. Estructura de la entrega (por cada caso de uso)

1. **Encabezado del caso de uso:** `CU1: Servicios Adicionales`.
2. **Nombre del patrón** como subtítulo: `Strategy`.
3. **Diagrama genérico del patrón** (la estructura de libro: roles y flechas, sin dominio), con su **cita** debajo (formato APA; en el ejemplo, Shvets, 2021, *Dive into design patterns*, Refactoring.Guru). El diagrama genérico responde "¿cómo es el patrón?".
4. **Diagrama de clases específico del caso de uso**, dentro del marco `class <nombre del caso de uso>` que dibuja EA. Responde "¿cómo lo aplicamos en nuestro sistema?".

La portada y el índice llevan el nombre de la universidad, la materia, el parcial, el registro y el docente; el índice lista cada caso de uso con su página.

## 2. Qué contiene el diagrama específico

No es el patrón aislado: es **la rebanada completa de la arquitectura del caso de uso con el patrón integrado**.

```
<X>View ──► <X>Controller ──► <Modelo A>  ──► Conexion (Singleton)
                  │    ├────► <Modelo B>  ──►    │
                  │    └────► <Modelo C>  ──►    │
                  └─ (patrón) ──► <Participantes del patrón>
```

- **Vista → Controlador → Modelos → Conexión.** La vista a la izquierda, el controlador al centro, los modelos en columna a la derecha y la `Conexion` al extremo derecho. Cada modelo depende de `Conexion`.
- **`Conexion` es un Singleton:** atributo `- instancia: ?PDO` y operación `+ getConexion(): PDO`, **ambos estáticos (subrayados)**.
- **El controlador** guarda un arreglo con las variantes del patrón (`strategies: array` o `tipos: array`), los modelos y la vista, y tiene un método privado `- procesarCon<Patrón>(array, bool): array`. Eso muestra dónde se usa el patrón dentro del flujo.
- **Los participantes del patrón** van abajo o al costado del controlador, y **sus relaciones se resaltan en azul** frente al rojo de la arquitectura.
- Nombres con sufijo del rol: `<X>View`, `<X>Controller`, `<X>Model`, `<X>Context`, `<X>Template`, `<X>Strategy`. Tipos del lenguaje real del proyecto (en el ejemplo, PHP: `array`, `?array`, `float`, `PDO`); sácalos del código.

### Strategy dentro de MVC
`Controller → Context` (asociación con flecha); `Context ◇→ «interface» Strategy` (agregación, rombo del lado del Context); cada estrategia concreta → `Strategy` con **realización** (línea punteada y triángulo hueco). El `Context` tiene `- strategy: <Interfaz>`, `+ setStrategy(...)` y una operación que procesa usando la estrategia. La interfaz se pinta en lila.

### Template Method dentro de MVC
`Controller → Template` (clase **abstracta**, en cursiva). El `Template` tiene el **método plantilla público** (`+ templateMethod(...)`), pasos comunes **protegidos** (`# validar...`, `# calcular...`, `# aplicar...`) y pasos **abstractos en cursiva** que cada subclase implementa (`+ calcularX()`, `+ generarY()`). Las clases concretas heredan (**generalización**, triángulo hueco, línea continua) y **solo sobrescriben los pasos abstractos**, nunca el método plantilla.

## 3. Notación y presentación observadas

| Elemento | Cómo se ve |
|---|---|
| Visibilidad | signos `+`, `-`, `#` delante de cada atributo y operación |
| Clase/operación abstracta | cursiva |
| Miembro estático (Singleton) | subrayado |
| Interfaz | `«interface»`, fondo lila |
| Relaciones de la arquitectura | líneas rojas con flecha abierta |
| Relaciones del patrón | líneas azules (agregación, realización, generalización) |
| Parámetros | solo los tipos: `calcular(float, array): float` |
| Marco | `class <nombre del caso de uso>` |

## 4. Cómo ampliar los casos de uso que ya tienes (método)

1. **Elige el patrón que de verdad usa ese caso de uso en el código** (mira las clases: ¿hay una clase abstracta con subclases?, ¿quién elige la variante?). Si el patrón es una propuesta, rotúlalo así.
2. **Dibuja primero el diagrama genérico** del patrón (con la misma notación) y cita la fuente.
3. **Luego el específico:** la rebanada Vista → Controlador → Modelos → Conexión con los participantes del patrón en azul. Reutiliza los **mismos elementos** del modelo (`Conexion`, `UsuarioModel`...) en todos los diagramas; no los copies.
4. **Mismos nombres, mismos tipos** en todo el documento.
5. Revisa cada PNG antes de entregar: sin solapamientos, sin líneas que se crucen sin necesidad.

Cómo se vería en este formato cada patrón (para casos de uso nuevos):

| Patrón | Participantes y cómo se conectan al Controlador |
|---|---|
| **Chain of Responsibility** | `Handler` abstracto que **se agrega a sí mismo** (rombo + flecha abierta, `siguiente`, como el libro y como el código); los `ConcreteHandler` heredan de él; el controlador depende (punteada) de la cadena que arma |
| Factory Method | `Controller → Creator`; `Creator` crea `Product` (dependencia `«create»`); `ConcreteProduct` hereda de `Product` |
| Observer | `Subject` agrega `Observer` (1..*); `ConcreteObserver` hereda de `Observer`; el controlador dispara `Subject.notificar()` |
| Decorator | `Component` ← `Decorator` (herencia **y** agregación a `Component`) ← `ConcreteDecorator` |
| Facade | `Controller → Facade`; `Facade` depende de varios servicios/modelos |
| Adapter | `Controller → Target`; `Adapter` hereda de `Target` y se asocia con `Adaptee` |
| State | como Strategy, pero el contexto cambia de estado y los estados concretos conocen al siguiente |
| Repository / DAO | `Controller → Repository`; `Repository` depende de `Entity` y de `Conexion` |

## 5. Cómo se reproduce en Enterprise Architect (probado)

- Marcas al inicio de cada atributo/operación en `Add-Class`: `-` privado, `#` protegido, `$` estático, `*` abstracta (operaciones). Clase abstracta: último parámetro `$true`.
- `Mostrar-Visibilidad $diagrama` muestra `+ - #` y los **tipos** de los parámetros.
- `Set-ColorConectores` (rojo para la arquitectura, azul para el patrón) y `Set-ColorElemento` (interfaz en lila).
- Interfaz: elemento `Interface` con su operación; nota: elemento `Note` con conector `NoteLink`.
- **Todos los elementos de los casos de uso en un solo paquete** (si no, con `HideQuals=0` EA escribe `Paquete::Clase`).
- Las clases compartidas (`Conexion`, modelos) se crean una vez y se colocan en cada diagrama con `Place`.
- **Orden:** `Pos` guarda el orden de creación, pero EA en esta máquina muestra atributos y operaciones en orden alfabético. Si el orden natural importa, revisa en EA la opción de ordenar miembros alfabéticamente (no se pudo comprobar cuál es la opción exacta).

## 6. Lista de comprobación antes de entregar

- [ ] Cada caso de uso tiene: título, nombre del patrón, diagrama genérico con cita y diagrama específico.
- [ ] El patrón del diagrama existe en el código (o está rotulado "propuesto").
- [ ] La arquitectura (vista, controlador, modelos, conexión) coincide con el código.
- [ ] Atributos y operaciones con visibilidad, tipos y marcas de abstracto/estático correctos.
- [ ] Relaciones del patrón resaltadas y legibles; nada se solapa.
- [ ] Los diagramas genéricos son propios o están citados; no se pegan imágenes de terceros sin cita.
