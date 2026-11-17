param([string]$Trabajo, [string]$Salida, [string]$ImgDir = 'C:\tmp\ea_ejemplo_patrones')
# "Diseño de detalle procedimental con patrones": por cada caso de uso, (1) el diagrama GENÉRICO del patrón y
# (2) el diagrama de clases ESPECÍFICO del caso de uso, con el patrón integrado en la arquitectura real
# (Vista -> Controlador -> Modelos -> Conexión Singleton). Dominio neutro (tienda en línea).
# Patrones: Strategy (descuento por categoría de cliente) y Template Method (emisión de comprobante).
# Convenciones que se ven en los diagramas:
#   * relaciones de la arquitectura en ROJO; relaciones propias del patrón en AZUL; la interfaz del patrón en lila
#   * signos de visibilidad (+ - #); abstractas en cursiva; miembros estáticos subrayados (Singleton Conexion)
#   * las clases compartidas (modelos, Conexion) son UN solo elemento del modelo que aparece en varios diagramas
# Corre solo sobre una COPIA del .eapx y con EA cerrado.
. "$PSScriptRoot\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$global:CarpetaImg = $ImgDir
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
$global:Dim = @{}   # alto de cada clase: cuantos atributos y operaciones tiene
function Cls-H($na, $no) { return [int](38 + 17 * ($na + $no) + $(if ($na -gt 0 -and $no -gt 0) { 10 } else { 0 })) }
function Cab($el, $x, $y, $w, $d, $na, $no) { return (Place $d $el $x $y $w (Cls-H $na $no)) }
function Flecha($a, $b, $nombre = '') {
    $c = Add-Conn $a $b 'Association' $nombre
    $c.Direction = 'Source -> Destination'; [void]$c.Update()
    return $c
}
function Clase($pk, $nombre, $est, $attrs, $ops, $abs = $false) {
    $c = Add-Class $pk $nombre $est $attrs $ops $abs
    $global:Dim[$c.ElementID] = @(@($attrs).Count, @($ops).Count)
    return $c
}
function Nota($pk, $texto) { $n = Add-Elem $pk 'nota' 'Note'; $n.Notes = $texto; [void]$n.Update(); return $n }
function Agregacion($a, $b) {
    $c = Add-Conn $a $b 'Aggregation'; $c.ClientEnd.Aggregation = 1; $c.ClientEnd.Navigable = 'Unspecified'; $c.Direction = 'Source -> Destination'
    [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update(); [void]$c.Update()
    return $c
}
function Interfaz($pk, $nombre, $op, $ret, $param, $tipoParam) {
    $i = Add-Elem $pk $nombre 'Interface'
    $m = $i.Methods.AddNew($op, $ret); [void]$m.Update()
    $p = $m.Parameters.AddNew($param, $tipoParam); [void]$p.Update(); [void]$m.Parameters.Refresh()
    [void]$i.Refresh()
    return $i
}
# Vista, Controlador y los modelos que usa, con la Conexión a la derecha (la arquitectura del caso de uso)
function Arquitectura($pk, $d, $nombreCU, $ctrlAttrs, $ctrlOps, $modelos, $conexion, $yCtrl) {
    $r = @{ rojos = @() }
    $r.vista = Clase $pk "${nombreCU}View" '' @() @('render(datos:array, extra:array, error:?array):void')
    $r.ctrl = Clase $pk "${nombreCU}Controller" '' $ctrlAttrs $ctrlOps
    [void](Cab $r.vista 40 ($yCtrl + 80) 290 $d 0 1)
    [void](Cab $r.ctrl 390 $yCtrl 480 $d @($ctrlAttrs).Count @($ctrlOps).Count)
    [void](Cab $conexion 1340 ($yCtrl + 60) 190 $d 1 1)
    $y = 30
    foreach ($m in $modelos) {
        $na = $global:Dim[$m.ElementID][0]; $no = $global:Dim[$m.ElementID][1]
        [void](Cab $m 980 $y 270 $d $na $no)
        $y += (Cls-H $na $no) + 40
        $r.rojos += (Flecha $r.ctrl $m)
    }
    $r.rojos += (Flecha $r.vista $r.ctrl)
    return $r
}
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $raiz = $repo.Models.GetAt(0)
    $pat = Add-Pkg $raiz 'Ejemplo: diseño de detalle con patrones'

    # ---- elementos compartidos (un solo elemento del modelo, reutilizado en varios diagramas)
    $comun = Add-Pkg $pat 'Diseño de detalle (CU1 y CU2)'
    $conexion = Clase $comun 'Conexion' '' @('-$instancia:?PDO') @('$getConexion():PDO')
    $mProducto = Clase $comun 'ProductoModel' '' @('id:int', 'nombre:string', 'precio:float') @('__construct()', 'obtenerTodos():array', 'buscarPorId(id:int):?array')
    $mPedido = Clase $comun 'PedidoModel' '' @('id:int', 'clienteId:int', 'subtotal:float', 'descuento:float', 'total:float', 'createdAt:string') @('__construct()', 'registrar(datos:array):int', 'obtenerHistorial(id:int):array')
    $mCliente = Clase $comun 'ClienteModel' '' @('id:int', 'nombre:string', 'email:string', 'categoria:string') @('__construct()', 'buscarPorId(id:int):?array', 'obtenerTodos():array')
    $mComprobante = Clase $comun 'ComprobanteModel' '' @('id:int', 'pedidoId:int', 'tipo:string', 'montoBase:float', 'impuesto:float', 'montoFinal:float', 'createdAt:string') @('__construct()', 'registrar(datos:array):int', 'existeComprobante(id:int, tipo:string):bool', 'obtenerHistorial(id:int):array')
    $aConexion = @()
    foreach ($m in @($mProducto, $mPedido, $mCliente, $mComprobante)) { $aConexion += (Flecha $m $conexion) }

    # ======================= GENÉRICO: STRATEGY =======================
    try {
        $pk = Add-Pkg $pat 'Strategy'
        $d = Add-Diag $pk 'Strategy — estructura genérica' 'Class'; Mostrar-Visibilidad $d
        $ctx = Clase $pk 'Context' '' @('-strategy:Strategy') @('setStrategy(strategy:Strategy):void', 'doSomething():void')
        $itf = Interfaz $pk 'Strategy' 'execute' 'void' 'data' 'any'
        $ca = Clase $pk 'ConcreteStrategyA' '' @() @('execute(data:any):void')
        $cb = Clase $pk 'ConcreteStrategyB' '' @() @('execute(data:any):void')
        $cli = Clase $pk 'Client' '' @() @()
        $nt = Nota $pk "strategy.execute()"
        [void](Cab $ctx 40 40 280 $d 1 2); [void](Place $d $itf 460 40 260 55)
        [void](Cab $ca 380 240 240 $d 0 1); [void](Cab $cb 690 240 240 $d 0 1)
        [void](Place $d $cli 60 300 140 40); [void](Place $d $nt 60 190 150 40)
        $azul = @(); $azul += (Agregacion $ctx $itf)
        $azul += (Add-Conn $ca $itf 'Realization'); $azul += (Add-Conn $cb $itf 'Realization')
        [void](Flecha $cli $ctx); [void](Add-Conn $cli $ca 'Dependency'); [void](Add-Conn $nt $ctx 'NoteLink')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Set-ColorConectores $repo $d $azul 0 0 255
        Set-ColorElemento $repo $d $itf 230 220 250
        Log ("strategy generico: " + (Exporta $repo $d 'p1_strategy_generico'))
    } catch { Log ("ERROR strategy generico: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= ESPECÍFICO CU1: STRATEGY dentro de MVC =======================
    try {
        $pk = $comun
        $d = Add-Diag $pk 'CU1: Aplicar descuento por categoría de cliente — Strategy' 'Class'; Mostrar-Visibilidad $d
        $a = Arquitectura $pk $d 'Pedido' @('strategies:array', 'clienteModel:ClienteModel', 'pedidoModel:PedidoModel', 'vista:PedidoView') @('__construct(c:ClienteModel, p:PedidoModel, v:PedidoView)', 'handle(accion:string, datos:array):void', '-procesarConEstrategia(datos:array, esPost:bool):array') @($mProducto, $mPedido, $mCliente) $conexion 250
        $ctx = Clase $pk 'DescuentoContext' '' @('-strategy:CategoriaClienteStrategy', 'cliente:array', 'subtotal:float', 'descuento:float') @('setStrategy(s:CategoriaClienteStrategy):void', 'procesarDescuento(subtotal:float, cliente:array):array')
        $itf = Interfaz $pk 'CategoriaClienteStrategy' 'calcular' 'float' 'subtotal' 'float'
        $n1 = Clase $pk 'ClienteNormal' '' @() @('calcular(subtotal:float, cliente:array):float'); $n2 = Clase $pk 'ClienteVIP' '' @() @('calcular(subtotal:float, cliente:array):float'); $n3 = Clase $pk 'ClienteMayorista' '' @() @('calcular(subtotal:float, cliente:array):float')
        [void](Cab $ctx 390 580 420 $d 4 2); [void](Place $d $itf 960 640 330 55)
        [void](Cab $n1 380 860 260 $d 0 1); [void](Cab $n2 690 860 260 $d 0 1); [void](Cab $n3 1000 860 260 $d 0 1)
        $azul = @(); $azul += (Flecha $a.ctrl $ctx); $azul += (Agregacion $ctx $itf)
        foreach ($k in @($n1, $n2, $n3)) { $azul += (Add-Conn $k $itf 'Realization') }
        [void]$repo.ReloadDiagram($d.DiagramID)
        Set-ColorConectores $repo $d ($a.rojos + $aConexion) 200 30 30
        Set-ColorConectores $repo $d $azul 0 0 255
        Set-ColorElemento $repo $d $itf 230 220 250
        Log ("CU1 strategy: " + (Exporta $repo $d 'p2_cu1_strategy'))
    } catch { Log ("ERROR CU1: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= GENÉRICO: TEMPLATE METHOD =======================
    try {
        $pk = Add-Pkg $pat 'Template Method'
        $d = Add-Diag $pk 'Template Method — estructura genérica' 'Class'; Mostrar-Visibilidad $d
        $ab = Clase $pk 'AbstractClass' '' @() @('templateMethod():void', 'step1():void', 'step2():bool', '*step3():void', '*step4():void') $true
        $c1 = Clase $pk 'ConcreteClass1' '' @() @('step3():void', 'step4():void')
        $c2 = Clase $pk 'ConcreteClass2' '' @() @('step1():void', 'step3():void', 'step4():void')
        $nt = Nota $pk ("step1()`r`nif (step2()) {`r`n    step3()`r`n} else {`r`n    step4()`r`n}")
        [void](Cab $ab 300 40 300 $d 0 5); [void](Cab $c1 150 280 250 $d 0 2); [void](Cab $c2 480 280 250 $d 0 3); [void](Place $d $nt 700 70 170 110)
        $azul = @(); $azul += (Add-Conn $c1 $ab 'Generalization'); $azul += (Add-Conn $c2 $ab 'Generalization'); [void](Add-Conn $nt $ab 'NoteLink')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Set-ColorConectores $repo $d $azul 0 0 255
        Log ("template generico: " + (Exporta $repo $d 'p3_template_generico'))
    } catch { Log ("ERROR template generico: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= ESPECÍFICO CU2: TEMPLATE METHOD dentro de MVC =======================
    try {
        $pk = $comun
        $d = Add-Diag $pk 'CU2: Emitir comprobante de venta — Template Method' 'Class'; Mostrar-Visibilidad $d
        $a = Arquitectura $pk $d 'Comprobante' @('tipos:array', 'pedidoModel:PedidoModel', 'comprobanteModel:ComprobanteModel', 'vista:ComprobanteView') @('__construct(p:PedidoModel, c:ComprobanteModel, v:ComprobanteView)', 'handle(accion:string, datos:array):void', '-procesarConTemplate(datos:array, esPost:bool):array') @($mPedido, $mComprobante, $mCliente) $conexion 250
        $tp = Clase $pk 'ComprobanteTemplate' '' @('pedido:array', 'cliente:array', 'yaEmitido:bool', 'montoBase:float', 'impuesto:float', 'montoFinal:float') @('templateMethod(pedido:array, cliente:array, yaEmitido:bool):array', '#validarDuplicado():void', '#calcularMontoBase():void', '#aplicarImpuesto():void', '*calcularImpuesto():float', '*generarDocumento():array') $true
        $f1 = Clase $pk 'ComprobanteFactura' '' @() @('calcularImpuesto():float', 'generarDocumento():array')
        $f2 = Clase $pk 'ComprobanteBoleta' '' @() @('calcularImpuesto():float', 'generarDocumento():array')
        $f3 = Clase $pk 'ComprobanteNotaVenta' '' @() @('calcularImpuesto():float', 'generarDocumento():array')
        [void](Cab $tp 420 580 440 $d 6 6)
        [void](Cab $f1 330 920 260 $d 0 2); [void](Cab $f2 640 920 260 $d 0 2); [void](Cab $f3 950 920 260 $d 0 2)
        $azul = @(); $azul += (Flecha $a.ctrl $tp)
        foreach ($k in @($f1, $f2, $f3)) { $azul += (Add-Conn $k $tp 'Generalization') }
        [void]$repo.ReloadDiagram($d.DiagramID)
        Set-ColorConectores $repo $d ($a.rojos + $aConexion) 200 30 30
        Set-ColorConectores $repo $d $azul 0 0 255
        Log ("CU2 template: " + (Exporta $repo $d 'p4_cu2_template'))
    } catch { Log ("ERROR CU2: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    $repo.CloseFile(); $repo.Exit()
} catch { Log ("ERROR: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) } finally { $sw.Close() }
