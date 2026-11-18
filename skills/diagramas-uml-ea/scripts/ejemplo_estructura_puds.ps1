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

    # 4) Analizar casos de uso: robustez por CU (Collaboration + Object con estereotipo); actor reutilizado
    $sub = Add-Pkg $pAna 'CU01 Registrar pedido'
    $d = Add-Diag $sub 'CU01 Registrar pedido' 'Collaboration'
    $iu = Add-Elem $sub 'IU Registrar pedido' 'Object' 'boundary'
    $ct = Add-Elem $sub 'Control registrar pedido' 'Object' 'control'
    $en = Add-Elem $sub 'Pedido' 'Object' 'entity'
    [void](Place $d $ven 40 80 60 90); [void](Place $d $iu 200 90 70 70); [void](Place $d $ct 380 90 70 70); [void](Place $d $en 560 90 70 70)
    [void](Add-Conn $ven $iu 'Association'); [void](Add-Conn $iu $ct 'Association'); [void](Add-Conn $ct $en 'Association')
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

    # BD: tablas con PK y FK y tipos
    $d = Add-Diag $pBD 'Diseno de BD' 'Logical'; Estilo-Mas $d
    $tCli = Add-Class $pBD 'cliente' 'table' @('id_cliente:INT PK', 'nombre:VARCHAR(100)', 'telefono:VARCHAR(20)') @()
    $tPed = Add-Class $pBD 'pedido' 'table' @('id_pedido:INT PK', 'fecha:DATE', 'total:NUMERIC(14,2)', 'id_cliente:INT FK') @()
    [void](Place $d $tCli 60 60 210 90); [void](Place $d $tPed 380 60 210 110)
    $r = Add-Conn $tPed $tCli 'Association' 'id_cliente'
    $r.ClientEnd.Cardinality = '0..*'; [void]$r.ClientEnd.Update(); $r.SupplierEnd.Cardinality = '1'; [void]$r.SupplierEnd.Update(); [void]$r.Update()
    Fin $repo $d 'd2_bd'

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

    # ======================= IMPLEMENTACION =======================
    $im = Add-Pkg $raiz 'Implementacion'
    $pArq = Add-Pkg $im 'Arquitectura del Sistema'
    $d = Add-Diag $pArq 'Arquitectura del Sistema' 'Component'
    $cFront = Add-Elem $pArq 'Frontend' 'Component'
    $cBack = Add-Elem $pArq 'Backend' 'Component'
    $cBD = Add-Elem $pArq 'PostgreSQL' 'Component' 'database'
    [void](Place $d $cFront 40 80 150 70); [void](Place $d $cBack 300 80 150 70); [void](Place $d $cBD 560 80 150 70)
    [void](Place $d $paq['Pedidos'].Element 220 240 150 90); [void](Place $d $paq['Clientes'].Element 400 240 150 90)
    [void](Add-Conn $cFront $cBack 'Dependency'); [void](Add-Conn $cBack $cBD 'Dependency')
    [void](Add-Conn $cBack $paq['Pedidos'].Element 'Realisation'); [void](Add-Conn $cBack $paq['Clientes'].Element 'Realisation')
    Fin $repo $d 'i1_arquitectura'
} catch { Log ("ERROR general: " + $_.Exception.Message + ' ' + $_.InvocationInfo.ScriptLineNumber) }
finally { if ($repo) { $repo.CloseFile(); $repo.Exit() }; $sw.Close() }
