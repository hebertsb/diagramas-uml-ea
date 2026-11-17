# TÉCNICA: agregar Chain of Responsibility (versión del libro de Shvets, tal como está en el código: el manejador abstracto ManejadorFilaBase se AGREGA A SÍ MISMO,
# rombo + flecha abierta rotulada 'siguiente'; los manejadores concretos heredan de él; el cliente depende de la cadena con una dependencia punteada) a un caso de uso
# con diseño impuesto (zonas de color): Clonar-Paquete, hacer lugar arriba, ajustar 'importador_excel' a lo que dice el código, zona nueva clonada de una existente,
# Add-AutoAgregacion + Set-LazoPropioArriba para el lazo del sucesor, relaciones del patrón en azul y los dos diagramas genéricos.
# Los ids (57 = caso de uso original, 60 = PARCIAL2) son de un .eapx concreto: cámbialos por los tuyos.
# Corre solo sobre una COPIA del .eapx y con EA cerrado.
param([string]$Archivo, [string]$Salida, [string]$ImgDir)
. "$PSScriptRoot\..\ea_lib.ps1"
$global:CarpetaImg = $ImgDir
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false)); $sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Cls-H($na, $no) { return [int](38 + 17 * ($na + $no) + $(if ($na -gt 0 -and $no -gt 0) { 10 } else { 0 })) }
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Archivo)
    $global:Repo = $repo
    $raiz = $repo.Models.GetAt(0)

    # ======================= CU8 con Chain of Responsibility (como está en el código: ManejadorFilaBase guarda su siguiente con su propio tipo) =======================
    $pkg = Clonar-Paquete $repo 57 60 'CU8 - Importar Estudiantes (Chain of Responsibility)'
    $pid2 = $pkg.PackageID; $did = $pkg.Diagrams.GetAt(0).DiagramID
    Log ("CU8 clon: paquete $pid2, diagrama $did")
    # hacer lugar arriba (bajar todo 480) y correr 'index' 130 a la derecha: deja libre el pasillo por donde sube la dependencia
    Mover-Objetos $repo $did 0 480
    $idx = Find-Elem $repo 'index' 'Class' $pid2
    Mover-Objetos $repo $did 130 0 @($idx.ElementID)

    # importador_excel: en el segundo parcial solo queda importar y armar la cadena (las validaciones pasaron a los manejadores)
    $imp = Find-Elem $repo 'importador_excel' 'Class' $pid2
    for ($i = $imp.Methods.Count - 1; $i -ge 0; $i--) { $m = $imp.Methods.GetAt($i); if ($m.Name -ne 'importarEstudiantesDesdeExcel') { [void]$imp.Methods.Delete($i) } }
    [void]$imp.Methods.Refresh()
    Add-Oper $imp 'construirCadenaDeFila' 'ManejadorFilaBase' @('pdo:PDO', 'grupoId:int|null') 1
    [void]$imp.Refresh()
    [void]$repo.Execute("UPDATE t_diagramobjects SET RectBottom = RectTop - $(Cls-H 0 2) WHERE Diagram_ID = $did AND Object_ID = $($imp.ElementID)")
    # bajar 50 unidades 'importador_excel': así la flecha ApiGateway -> index pasa por encima de su esquina y no sobre la tabla
    Mover-Objetos $repo $did 0 50 @($imp.ElementID)

    # clases del patrón (según ms-estudiantes/src/cadena/*.php)
    $base = Add-Class $pkg 'ManejadorFilaBase' '' @('-siguiente:ManejadorFilaBase') @('*manejar(fila:array):array', 'setSiguiente(siguiente:ManejadorFilaBase):ManejadorFilaBase', '#pasarAlSiguiente(fila:array):array', '#rechazar(fila:array, motivo:string):array') $true
    $h1 = Add-Class $pkg 'ValidarEncabezadosHandler' '' @('-$COLUMNAS_OBLIGATORIAS:array') @('manejar(fila:array):array')
    $h2 = Add-Class $pkg 'ValidarRegistroHandler' '' @() @('manejar(fila:array):array')
    $h3 = Add-Class $pkg 'ValidarCiNoDuplicadoHandler' '' @('-pdo:PDO') @('__construct(pdo:PDO)', 'manejar(fila:array):array')
    $h4 = Add-Class $pkg 'GuardarEstudianteHandler' '' @('-pdo:PDO', '-grupoId:?int') @('__construct(pdo:PDO, grupoId:?int)', 'manejar(fila:array):array', '-crearOActualizar(fila:array):array', '-inscribirSiNoExiste(registro:int):void')
    $nota = Add-Elem $pkg 'orden' 'Note'
    $nota.Notes = "Orden de la cadena (construirCadenaDeFila):`r`n1. ValidarEncabezadosHandler`r`n2. ValidarRegistroHandler`r`n3. ValidarCiNoDuplicadoHandler`r`n4. GuardarEstudianteHandler"; [void]$nota.Update()

    # zona nueva copiada de una zona existente (hereda el borde discontinuo)
    $zsrc = Find-Elem $repo 'ms-Estudiantes' 'Boundary' $pid2
    $z0 = $zsrc.Clone(); $z0.Name = 'ms-Estudiantes: patrón Chain of Responsibility (validación de cada fila del Excel)'; $z0.PackageID = $pid2; [void]$z0.Update()
    $zona = $repo.GetElementByID($z0.ElementID)
    $dg = $repo.GetDiagramByID($did)
    # Base centrada sobre 'importador_excel' (x=1092) y un hueco entre los manejadores 2 y 3: la dependencia sube en vertical sin pasar sobre ninguna tabla.
    # La base queda 25 unidades más abajo para dejar sitio al lazo de la agregación sobre su borde superior.
    [void](Place $dg $zona 480 60 1300 420 40)
    [void](Place $dg $base 922 125 340 (Cls-H 1 4) 1)
    [void](Place $dg $nota 1360 100 400 105 1)
    [void](Place $dg $h1 500 340 250 (Cls-H 1 1) 1); [void](Place $dg $h2 775 340 200 (Cls-H 0 1) 1)
    [void](Place $dg $h3 1205 340 250 (Cls-H 1 2) 1); [void](Place $dg $h4 1480 290 270 (Cls-H 2 4) 1)

    # relaciones del patrón: herencia de los manejadores, el manejador base se agrega a sí mismo (rombo + flecha, versión del libro)
    # y el cliente depende (punteada) de la cadena, como el resto de dependencias del diseño
    $azul = @()
    foreach ($k in @($h1, $h2, $h3, $h4)) { $azul += (Add-Conn $k $base 'Generalization') }
    $auto = Add-AutoAgregacion $base 'siguiente'; $azul += $auto
    $azul += (Add-Conn $imp $base 'Dependency' 'construye y usa la cadena')
    [void]$repo.ReloadDiagram($did)
    Guardar-Enlaces $repo $dg
    Set-LazoPropioArriba $repo $did $auto.ConnectorID 1160 -125 85 32
    Set-ColorConectores $repo $dg $azul 0 0 255
    Set-ColorZona $repo $did $zona.ElementID 230 220 250
    Log ("CU8 export: " + (Exporta $repo $dg 'cu8_cor'))

    # ======================= Diagramas genéricos de los patrones =======================
    $gen = Add-Pkg (Find-Pkg $repo 'PARCIAL2') 'Patrones genéricos'
    # --- Strategy
    $d = Add-Diag $gen 'Patron Strategy - Diagrama Generico' 'Logical'; Mostrar-Visibilidad $d
    $ctx = Add-Class $gen 'Context' '' @('-strategy:Strategy') @('setStrategy(strategy:Strategy):void', 'doSomething():void')
    $itfS = Add-Elem $gen 'Strategy' 'Interface'; $m1 = $itfS.Methods.AddNew('execute', 'void'); [void]$m1.Update(); $p1 = $m1.Parameters.AddNew('data', 'any'); [void]$p1.Update(); [void]$itfS.Refresh()
    $ca = Add-Class $gen 'ConcreteStrategyA' '' @() @('execute(data:any):void'); $cb = Add-Class $gen 'ConcreteStrategyB' '' @() @('execute(data:any):void')
    $cli = Add-Class $gen 'Client' '' @() @()
    $nt = Add-Elem $gen 'n1' 'Note'; $nt.Notes = 'strategy.execute()'; [void]$nt.Update()
    [void](Place $d $ctx 40 40 290 (Cls-H 1 2) 1); [void](Place $d $itfS 470 40 260 60 1)
    [void](Place $d $ca 390 250 240 (Cls-H 0 1) 1); [void](Place $d $cb 700 250 240 (Cls-H 0 1) 1)
    [void](Place $d $cli 60 310 140 45 1); [void](Place $d $nt 60 200 160 45 1)
    $ag = Add-Conn $ctx $itfS 'Aggregation'; $ag.ClientEnd.Aggregation = 1; $ag.ClientEnd.Navigable = 'Unspecified'; $ag.Direction = 'Source -> Destination'
    [void]$ag.ClientEnd.Update(); [void]$ag.SupplierEnd.Update(); [void]$ag.Update()
    [void](Add-Conn $ca $itfS 'Realization'); [void](Add-Conn $cb $itfS 'Realization')
    $f = Add-Conn $cli $ctx 'Association'; $f.Direction = 'Source -> Destination'; [void]$f.Update()
    [void](Add-Conn $cli $ca 'Dependency'); [void](Add-Conn $nt $ctx 'NoteLink')
    [void]$repo.ReloadDiagram($d.DiagramID)
    Set-ColorElemento $repo $d $itfS 230 220 250
    Log ("generico strategy: " + (Exporta $repo $d 'gen_strategy'))
    # --- Chain of Responsibility (estructura del libro: el manejador abstracto se agrega a sí mismo; el cliente se asocia con él; los concretos heredan)
    $d = Add-Diag $gen 'Patron Chain of Responsibility - Diagrama Generico' 'Logical'; Mostrar-Visibilidad $d
    $hd = Add-Class $gen 'AbstractHandler' '' @() @('*handleRequest(request:any):void') $true
    $c1 = Add-Class $gen 'ConcreteHandler1' '' @() @('handleRequest(request:any):void'); $c2 = Add-Class $gen 'ConcreteHandler2' '' @() @('handleRequest(request:any):void')
    $cl2 = Add-Class $gen 'Client' '' @() @()
    $nt2 = Add-Elem $gen 'n2' 'Note'; $nt2.Notes = "if (puedeManejar(request)) {`r`n    procesar(request)`r`n} else {`r`n    successor.handleRequest(request)`r`n}"; [void]$nt2.Update()
    [void](Place $d $hd 330 70 300 (Cls-H 0 1) 1); [void](Place $d $c1 200 290 240 (Cls-H 0 1) 1); [void](Place $d $c2 520 290 240 (Cls-H 0 1) 1)
    [void](Place $d $cl2 20 90 140 45 1); [void](Place $d $nt2 800 150 240 110 1)
    [void](Add-Conn $c1 $hd 'Generalization'); [void](Add-Conn $c2 $hd 'Generalization')
    $s = Add-AutoAgregacion $hd 'successor'
    $f2 = Add-Conn $cl2 $hd 'Association'; $f2.Direction = 'Source -> Destination'; [void]$f2.Update()
    [void](Add-Conn $nt2 $hd 'NoteLink')
    [void]$repo.ReloadDiagram($d.DiagramID)
    Guardar-Enlaces $repo $d
    Set-LazoPropioArriba $repo $d.DiagramID $s.ConnectorID 545 -70 70 32
    Log ("generico cor: " + (Exporta $repo $d 'gen_cor'))
    $repo.CloseFile(); $repo.Exit()
} catch { Log ("ERROR: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) } finally { $sw.Close() }
