param([string]$Trabajo, [string]$Salida, [string]$ImgDir = 'C:\tmp\ea_ejemplo_puds')
# Ejemplo autonomo (dominio neutro: pedidos) de un modelo organizado por FLUJOS DE TRABAJO del Proceso Unificado:
#   Analisis -> Diseno -> Implementacion, con un paquete por actividad y un diagrama por actividad o por caso de uso.
# Lo importante: cada elemento se crea UNA vez en su paquete "duenio" y los demas diagramas lo REUTILIZAN
# (EA muestra "(from <paquete>)"), y las relaciones entre fases son conectores reales:
#   Actor -> CU: conector 'UseCase'.   Paquete -> CU: 'Abstraction' con estereotipo 'trace'.
#   Paquete -> Paquete: 'Dependency' con estereotipo 'import'.   Clase de diseno -> clase de dominio: 'trace'.
#   Componente -> paquete que implementa: 'Realisation'.
# Corre solo sobre una COPIA del .eapx y con EA cerrado.
. "$PSScriptRoot\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$global:CarpetaImg = $ImgDir
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Trace($de, $a) { return (Add-Conn $de $a 'Abstraction' '' 'trace') }
function Fin($repo, $d, $png) { [void]$repo.ReloadDiagram($d.DiagramID); Log ("{0}: {1}" -f $d.Name, (Exporta $repo $d $png)) }
# Atributos sin tipo y publicos (modelo de dominio: "+ nombre")
function Add-Dominio($pk, $nombre, $attrs) {
    $c = Add-Elem $pk $nombre 'Class'
    # Ojo: en clases con atributos SIN tipo, EA 15 los muestra en orden alfabetico aunque se indique Pos (probado);
    # en las tablas del modelo fisico si respeta el orden.
    $i = 0; foreach ($a in $attrs) { Add-Attr $c $a '' 'Public' $false $i; $i++ }
    [void]$c.Refresh(); return $c
}
function Estilo-Mas($d) { $d.StyleEx = $global:StyleBase -replace 'HideQuals=1', 'HideQuals=0'; [void]$d.Update() }

try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $raiz = Add-Pkg $repo.Models.GetAt(0) 'Sistema de Pedidos'

    # ======================= ANALISIS =======================
    $an = Add-Pkg $raiz 'Analisis'
    $pAct = Add-Pkg (Add-Pkg $an 'Identificar Actores') 'Actores'
    $pEst = Add-Pkg $an 'Estructurar Casos de Uso'
    $pDet = Add-Pkg $an 'Detallar Casos de Uso'
    $pAna = Add-Pkg $an 'Analizar Casos de Uso'
    $pIdP = Add-Pkg $an 'Identificar Paquetes'
    $pRel = Add-Pkg $an 'Relacion de Paquete y Casos de Uso'
    $pEnc = Add-Pkg $an 'Encapsulamiento'
    $pAnP = Add-Pkg $an 'Analisis de Paquetes'
    $pDom = Add-Pkg $an 'Modelo de Dominio'

    # 1) Actores: se crean aqui y SOLO aqui
    $d = Add-Diag $pAct 'Actores' 'Use Case'
    $cli = Add-Elem $pAct 'Cliente' 'Actor' '' 'Persona que realiza pedidos.'
    $ven = Add-Elem $pAct 'Vendedor' 'Actor' '' 'Registra y atiende los pedidos.'
    [void](Place $d $cli 80 60 60 90); [void](Place $d $ven 280 60 60 90)
    Fin $repo $d 'a1_actores'

    # 2) Estructurar casos de uso: los CU se crean aqui; los actores se REUTILIZAN
    $d = Add-Diag $pEst 'Estructurar Casos de Uso' 'Use Case'
    $cu = [ordered]@{}
    $cu['CU01'] = Add-Elem $pEst 'CU01 Registrar pedido' 'UseCase'
    $cu['CU02'] = Add-Elem $pEst 'CU02 Consultar pedidos' 'UseCase'
    $cu['CU03'] = Add-Elem $pEst 'CU03 Gestionar clientes' 'UseCase'
    [void](Place $d $ven 40 150 60 90); [void](Place $d $cli 620 150 60 90)
    [void](Place $d $cu['CU01'] 250 40 190 70); [void](Place $d $cu['CU02'] 250 160 190 70); [void](Place $d $cu['CU03'] 250 280 190 70)
    [void](Add-Conn $ven $cu['CU01'] 'UseCase'); [void](Add-Conn $ven $cu['CU03'] 'UseCase')
    [void](Add-Conn $cli $cu['CU02'] 'UseCase'); [void](Add-Conn $ven $cu['CU02'] 'UseCase')
    Fin $repo $d 'a2_estructurar_cu'

    # 3) Detallar casos de uso: un paquete y un diagrama por CU, reutilizando el MISMO CU y sus actores
    #    (los conectores Actor->CU ya existen y EA los muestra solos)
    foreach ($k in @('CU01', 'CU02')) {
        $sub = Add-Pkg $pDet $cu[$k].Name
        $d = Add-Diag $sub $cu[$k].Name 'Use Case'
        [void](Place $d $cu[$k] 250 80 190 70)
        [void](Place $d $ven 40 70 60 90)
        if ($k -eq 'CU02') { [void](Place $d $cli 560 70 60 90) }
        Fin $repo $d ("a3_detallar_" + $k)
    }

    # 4) Analizar casos de uso: diagrama de COMUNICACION de analisis por CU (Collaboration + Object boundary/control/entity,
    #    enlaces Association y mensajes numerados 1, 1.1, 1.2...). El diagrama se llama igual que el CU. Actor reutilizado.
    $sub = Add-Pkg $pAna 'CU01 Registrar pedido'
    $d = Add-Diag $sub 'CU01 Registrar pedido' 'Collaboration'
    $iu = Add-Elem $sub 'PedidoView' 'Object' 'boundary'
    $ct = Add-Elem $sub 'PedidoController' 'Object' 'control'
    $en = Add-Elem $sub 'pedido' 'Object' 'entity'
    [void](Place $d $ven 70 240 60 90); [void](Place $d $iu 260 260 60 60); [void](Place $d $ct 430 260 60 60); [void](Place $d $en 600 260 60 60)
    [void](Add-Conn $ven $iu 'Association'); [void](Add-Conn $iu $ct 'Association'); [void](Add-Conn $ct $en 'Association')
    $mc = @(@($ven, $iu, 'registrar', '1', ''), @($iu, $ct, 'registrarPedido', '1.1', 'pedido'), @($ct, $en, 'create', '1.2', 'pedido'),
            @($ven, $iu, 'listar', '2', ''), @($iu, $ct, 'listar', '2.1', ''), @($ct, $en, 'find', '2.2', ''))
    $i = 1; foreach ($m in $mc) { [void](Add-MsgCom $repo $d $m[0] $m[1] $m[2] $i $m[3] $m[4]); $i++ }
    Build-Comunicacion $repo $d
    Fin $repo $d 'a4_analizar_cu01'

    # 5) Identificar paquetes: los paquetes de analisis se crean aqui
    $d = Add-Diag $pIdP 'Identificar Paquetes' 'Package'
    $paq = [ordered]@{}
    $paq['Pedidos'] = Add-Pkg $pIdP 'Pedidos'
    $paq['Clientes'] = Add-Pkg $pIdP 'Clientes'
    [void](Place $d $paq['Pedidos'].Element 60 60 160 100); [void](Place $d $paq['Clientes'].Element 320 60 160 100)
    Fin $repo $d 'a5_identificar_paquetes'

    # 6) Relacion paquete -> casos de uso con <<trace>> (un diagrama por paquete)
    $traza = @{ 'Pedidos' = @('CU01', 'CU02'); 'Clientes' = @('CU03') }
    foreach ($n in $paq.Keys) {
        $sub = Add-Pkg $pRel ("Relacion Paquete " + $n)
        $d = Add-Diag $sub ("Relacion Paquete " + $n) 'Use Case'
        $pe = $paq[$n].Element
        [void](Place $d $pe 40 100 160 100)
        $y = 40
        foreach ($k in $traza[$n]) { [void](Place $d $cu[$k] 330 $y 190 70); [void](Trace $pe $cu[$k]); $y += 110 }
        Fin $repo $d ("a6_relacion_" + $n)
    }

    # 7) Encapsulamiento: paquete + sus CU + los actores que los usan (todo reutilizado)
    $sub = Add-Pkg $pEnc 'Encapsulamiento de Paquete Pedidos'
    $d = Add-Diag $sub 'Encapsulamiento de Paquete Pedidos' 'Use Case'
    [void](Place $d $paq['Pedidos'].Element 200 20 420 300 50)
    [void](Place $d $cu['CU01'] 300 90 190 70); [void](Place $d $cu['CU02'] 300 200 190 70)
    [void](Place $d $ven 40 130 60 90); [void](Place $d $cli 720 130 60 90)
    Fin $repo $d 'a7_encapsulamiento_pedidos'

    # 8) Analisis de paquetes: dependencias <<import>> entre paquetes
    $d = Add-Diag $pAnP 'Analisis de Paquetes' 'Package'
    [void](Place $d $paq['Pedidos'].Element 60 60 160 100); [void](Place $d $paq['Clientes'].Element 360 60 160 100)
    [void](Add-Conn $paq['Pedidos'].Element $paq['Clientes'].Element 'Dependency' '' 'import')
    Fin $repo $d 'a8_analisis_paquetes'

    # 9) Modelo de dominio: "+ atributo", con su id, SIN FK ni tipos
    $d = Add-Diag $pDom 'Modelo de Dominio' 'Logical'; Estilo-Mas $d
    $dCli = Add-Dominio $pDom 'Cliente' @('id_cliente', 'nombre', 'telefono')
    $dPed = Add-Dominio $pDom 'Pedido' @('id_pedido', 'fecha', 'total')
    [void](Place $d $dCli 60 60 170 90); [void](Place $d $dPed 360 60 170 90)
    $r = Add-Conn $dCli $dPed 'Association' 'realiza'
    $r.ClientEnd.Cardinality = '1'; [void]$r.ClientEnd.Update(); $r.SupplierEnd.Cardinality = '0..*'; [void]$r.SupplierEnd.Update(); [void]$r.Update()
    Fin $repo $d 'a9_modelo_dominio'

    # ======================= DISENO =======================
    $di = Add-Pkg $raiz 'Diseno'
    $pCla = Add-Pkg $di 'Diseno de Clases'
    $pBD = Add-Pkg $di 'Diseno de BD'
    $pDCU = Add-Pkg $di 'Diseno de Casos de Uso'

    # Clases de diseno: tipos y metodos, SIN FK; cada una con <<trace>> a su clase del dominio
    $d = Add-Diag $pCla 'Diseno de Clases' 'Logical'
    $kCli = Add-Class $pCla 'Cliente' '' @('-idCliente:int', '-nombre:String', '-telefono:String') @('registrar():void')
    $kPed = Add-Class $pCla 'Pedido' '' @('-idPedido:int', '-fecha:Date', '-total:decimal', '-cliente:Cliente') @('calcularTotal():decimal')
    [void](Place $d $kCli 60 60 200 110); [void](Place $d $kPed 380 60 220 120)
    [void](Add-Conn $kPed $kCli 'Association')
    [void](Trace $kCli $dCli); [void](Trace $kPed $dPed)
    Fin $repo $d 'd1_clases'

    # BD: SIEMPRE los dos diagramas sobre las mismas tablas (el usuario usa el que pida su docente)
    function Rel($hijo, $padre, $etq) {
        $r = Add-Conn $hijo $padre 'Association' $etq
        $r.ClientEnd.Cardinality = '0..*'; [void]$r.ClientEnd.Update(); $r.SupplierEnd.Cardinality = '1..1'; [void]$r.SupplierEnd.Update(); [void]$r.Update()
    }
    #   a) LOGICO: "+ atributo", id, SIN tipos y SIN columnas FK; la FK es la linea con cardinalidad
    $pBDL = Add-Pkg $pBD 'Modelo de Datos - Logico'
    $d = Add-Diag $pBDL 'Modelo de Datos - Logico' 'Logical'; Estilo-Mas $d
    $lCli = Add-Dominio $pBDL 'cliente' @('id', 'nombre', 'telefono')
    $lPed = Add-Dominio $pBDL 'pedido' @('id', 'fecha', 'total')
    [void](Place $d $lCli 60 60 170 90); [void](Place $d $lPed 380 60 170 90)
    Rel $lPed $lCli 'realiza'
    Fin $repo $d 'd2_bd_logico'
    #   b) FISICO: todas las columnas con tipo, PK y FK
    $pBDF = Add-Pkg $pBD 'Modelo de Datos - Fisico'
    $d = Add-Diag $pBDF 'Modelo de Datos - Fisico' 'Logical'; Estilo-Mas $d
    $tCli = Add-Class $pBDF 'cliente' 'table' @('id_cliente:INT PK', 'nombre:VARCHAR(100)', 'telefono:VARCHAR(20)') @()
    $tPed = Add-Class $pBDF 'pedido' 'table' @('id_pedido:INT PK', 'fecha:DATE', 'total:NUMERIC(14,2)', 'id_cliente:INT FK') @()
    [void](Place $d $tCli 60 60 210 90); [void](Place $d $tPed 380 60 210 110)
    Rel $tPed $tCli 'id_cliente'
    Fin $repo $d 'd2_bd_fisico'

    # Diseno de CU: secuencia de DISENO (cajitas) por CU, con <<trace>> desde el paquete del diseno al CU
    $sub = Add-Pkg $pDCU 'Diseno CU01 Registrar pedido'
    [void](Trace $sub.Element $cu['CU01'])
    $part = @(@{ e = $ven }, @{ n = 'pedidoPage'; t = '' }, @{ n = 'PedidoController'; t = '' }, @{ n = 'Postgres'; t = '' })
    $msgs = @(
        @{ d = 0; a = 1; t = 'click Registrar pedido()' },
        @{ d = 1; a = 1; t = 'seleccionarCliente()' },
        @{ d = 1; a = 2; t = 'crearPedido(data)' },
        @{ d = 2; a = 3; t = 'insert(pedido)' },
        @{ d = 3; a = 2; t = 'success()' },
        @{ d = 2; a = 1; t = 'ok()' },
        @{ d = 1; a = 0; t = 'mostrarPedido()' })
    $d = Build-Sequence $repo $sub 'Diseno CU01 Registrar pedido' $part $msgs @() 220
    Log ("Diseno CU01: " + (Exporta $repo $d 'd3_secuencia_cu01'))

    # Elemento anidado (dentro de otro): ParentID; al colocarlo, el contenedor lleva un z MAYOR para quedar atras
    function Hijo($pk, $padre, $nombre, $tipo, $st = '') { $e = Add-Elem $pk $nombre $tipo $st; $e.ParentID = $padre.ElementID; [void]$e.Update(); return $e }

    # Diseno de Arquitectura: DESPLIEGUE. Nodos (nube, router, servicios externos), Device (celular o PC) y, DENTRO,
    # los componentes que corren ahi (cluster de BD > motor; plataforma > API y front; SO > app). Enlaces Association 'http/https'.
    $pDA = Add-Pkg $di 'Diseno de Arquitectura'
    $d = Add-Diag $pDA 'Diseno de Arquitectura' 'Deployment'
    $nube = Add-Elem $pDA 'Nube (AWS)' 'Node'
    $clu = Hijo $pDA $nube 'Database Cluster' 'Component'; $pg = Hijo $pDA $clu 'PostgreSQL 16' 'Component'
    $plat = Hijo $pDA $nube 'App Platform Service' 'Component'; $api = Hijo $pDA $plat 'API web' 'Component'; $fw = Hijo $pDA $plat 'Front web' 'Component'
    $rou = Add-Elem $pDA 'Router' 'Node'
    $cel = Add-Elem $pDA 'Smartphone' 'Device'
    $so = Hijo $pDA $cel 'Android SO' 'Component'; $app = Hijo $pDA $so 'App de pedidos' 'Component'
    $pag = Add-Elem $pDA 'Pasarela de pagos' 'Node'; $lnk = Hijo $pDA $pag 'API de pagos' 'Component'
    [void](Place $d $nube 40 60 560 330 3); [void](Place $d $clu 60 110 200 200 2); [void](Place $d $pg 80 160 160 110 1)
    [void](Place $d $plat 290 110 290 260 2); [void](Place $d $api 320 160 200 80 1); [void](Place $d $fw 320 265 200 80 1)
    [void](Place $d $rou 700 150 140 60)
    [void](Place $d $cel 650 300 290 290 3); [void](Place $d $so 670 355 250 210 2); [void](Place $d $app 700 410 180 120 1)
    [void](Place $d $pag 40 470 220 130 2); [void](Place $d $lnk 70 520 150 60 1)
    [void](Add-Conn $nube $rou 'Association' 'http/https'); [void](Add-Conn $rou $cel 'Association' 'http/https'); [void](Add-Conn $pag $nube 'Association' 'http/https')
    Fin $repo $d 'd4_despliegue'

    # ======================= IMPLEMENTACION =======================
    $im = Add-Pkg $raiz 'Implementacion'
    # Arquitectura del Sistema: paquetes con <<import>>, subsistemas (<<subsystem>>), servicios externos (<<service>>, en verde)
    # con su interfaz provista, y la BD; todo con Dependency (Backend -> cada paquete que implementa).
    $pArq = Add-Pkg $im 'Arquitectura del Sistema'
    $d = Add-Diag $pArq 'Arquitectura del Sistema' 'Component'
    $cFront = Add-Elem $pArq 'Frontend' 'Component' 'subsystem'
    $cBack = Add-Elem $pArq 'Backend' 'Component' 'subsystem'
    $cBD = Add-Elem $pArq 'PostgreSQL DB' 'Component'
    $cPay = Add-Elem $pArq 'Pagos Api' 'Component' 'service'
    # la interfaz provista (circulito) va en EmbeddedElements del componente; con Elements.AddNew falla
    $iPay = $cPay.EmbeddedElements.AddNew('Native Interface', 'ProvidedInterface'); [void]$iPay.Update()
    [void](Place $d $paq['Pedidos'].Element 120 40 170 90); [void](Place $d $paq['Clientes'].Element 420 40 170 90)
    [void](Place $d $cFront 60 230 150 70); [void](Place $d $cBack 340 230 150 70)
    [void](Place $d $cPay 60 400 150 70); [void](Place $d $iPay 125 390 20 20); [void](Place $d $cBD 400 400 150 70)
    [void](Add-Conn $cFront $cBack 'Dependency'); [void](Add-Conn $cBack $cBD 'Dependency'); [void](Add-Conn $cBack $cPay 'Dependency')
    [void](Add-Conn $cFront $iPay 'Dependency')
    [void](Add-Conn $cBack $paq['Pedidos'].Element 'Dependency'); [void](Add-Conn $cBack $paq['Clientes'].Element 'Dependency')
    Set-ColorElemento $repo $d $cPay 80 220 170
    Fin $repo $d 'i1_arquitectura'

    # Arquitectura de Subsistemas: un diagrama de componentes por subsistema (paquete), en tres capas anidadas:
    # Usuario (paginas) -> Servidor (controller, interfaz del service, DTO, <<entity>>) -> Base de datos (<<table>>).
    $pSub = Add-Pkg (Add-Pkg $im 'Arquitectura de Subsistemas') 'Subsistema Pedidos'
    $d = Add-Diag $pSub 'Diagrama de Componentes Subsistema Pedidos' 'Component'
    $u = Add-Elem $pSub 'Usuario' 'Component'
    $p1 = Hijo $pSub $u 'Pedido Page' 'Component'; $p2 = Hijo $pSub $u 'Registrar Pedido Page' 'Component'
    $sv = Add-Elem $pSub 'Servidor' 'Component'
    $ctl = Hijo $pSub $sv 'Pedido Controller' 'Component'; $srv = Hijo $pSub $sv 'Pedido Service' 'Interface'
    $dto1 = Hijo $pSub $sv 'create-Pedido DTO' 'Component'; $dto2 = Hijo $pSub $sv 'update-Pedido DTO' 'Component'
    $ent = Hijo $pSub $sv 'Pedido' 'Component' 'entity'
    $bd = Add-Elem $pSub 'Base de datos' 'Component'
    $tb1 = Hijo $pSub $bd 'pedido' 'Component' 'table'; $tb2 = Hijo $pSub $bd 'cliente' 'Component' 'table'
    [void](Place $d $u 40 40 640 150 2); [void](Place $d $p1 100 90 160 70 1); [void](Place $d $p2 400 90 180 70 1)
    [void](Place $d $sv 40 240 640 330 2); [void](Place $d $ctl 280 280 160 60 1); [void](Place $d $srv 280 380 160 60 1)
    [void](Place $d $dto1 70 480 160 60 1); [void](Place $d $dto2 490 380 160 60 1); [void](Place $d $ent 290 490 150 60 1)
    [void](Place $d $bd 40 620 640 130 2); [void](Place $d $tb1 140 665 150 60 1); [void](Place $d $tb2 420 665 150 60 1)
    [void](Add-Conn $u $sv 'Dependency'); [void](Add-Conn $sv $bd 'Dependency'); [void](Add-Conn $ctl $srv 'Dependency')
    [void](Add-Conn $srv $dto1 'Dependency'); [void](Add-Conn $srv $dto2 'Dependency'); [void](Add-Conn $srv $ent 'Dependency')
    Fin $repo $d 'i2_subsistema_pedidos'
} catch { Log ("ERROR general: " + $_.Exception.Message + ' ' + $_.InvocationInfo.ScriptLineNumber) }
finally { if ($repo) { $repo.CloseFile(); $repo.Exit() }; $sw.Close() }
