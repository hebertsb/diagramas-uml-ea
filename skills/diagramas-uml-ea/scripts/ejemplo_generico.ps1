param([string]$Trabajo, [string]$Salida, [string]$ImgDir = 'C:\tmp\ea_ejemplo_generico')
# Ejemplo GENERICO y autonomo: construye, en una copia de tu .eapx, un paquete "Ejemplo general" con
#   1) casos de uso, 2) clases con el patron Chain of Responsibility, 3) secuencia de la cadena, 4) paquetes y 5) actividad con calles.
# El dominio es neutro (aprobacion de solicitudes de compra) para que se vea la tecnica, no un sistema concreto.
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File ejemplo_generico.ps1 -Trabajo "C:\trabajo\copia.eapx" -Salida "C:\trabajo\log.txt"
# IMPORTANTE: corre esto solo sobre una COPIA del .eapx y con EA cerrado.
. "$PSScriptRoot\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$global:CarpetaImg = $ImgDir
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
# altura de una clase segun cuantos atributos y operaciones tiene (regla practica)
function Cls-H($na, $no) { return [int](38 + 17 * ($na + $no) + $(if ($na -gt 0 -and $no -gt 0) { 10 } else { 0 })) }
function Cab($el, $x, $y, $w, $d, $na, $no) { return (Place $d $el $x $y $w (Cls-H $na $no)) }
function Nodo($pk, $part, $nombre, $tipo, [int]$sub = 0) {
    $e = Add-Elem $pk $nombre $tipo
    if ($sub -gt 0) { $e.Subtype = $sub }
    $e.ParentID = $part.ElementID
    [void]$e.Update()
    return $e
}
function Flujo($a, $b, $guarda = '') {
    $c = Add-Conn $a $b 'ControlFlow'
    if ($guarda) { $c.TransitionGuard = $guarda; [void]$c.Update() }
}
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $raiz = $repo.Models.GetAt(0)
    $ej = Add-Pkg $raiz 'Ejemplo general (aprobación de solicitudes)'

    # ======================= 1. CASOS DE USO =======================
    try {
        $pk = Add-Pkg $ej 'Casos de uso'
        $d = Add-Diag $pk 'Casos de uso — Aprobación de solicitudes de compra' 'Use Case'
        $b = Add-Elem $pk 'Sistema de solicitudes de compra' 'Boundary'
        $empleado = Add-Elem $pk 'Empleado' 'Actor'
        $aprobador = Add-Elem $pk 'Aprobador' 'Actor'
        $cu1 = Add-Elem $pk 'CU01 Registrar solicitud de compra' 'UseCase'
        $cu2 = Add-Elem $pk 'CU02 Aprobar solicitud (cadena de aprobación)' 'UseCase'
        $cu3 = Add-Elem $pk 'CU03 Consultar estado de la solicitud' 'UseCase'
        $cu4 = Add-Elem $pk 'CU04 Notificar el resultado' 'UseCase'
        [void](Place $d $b 200 20 520 520 90)
        [void](Place $d $cu1 250 70 280 74); [void](Place $d $cu2 250 200 280 74)
        [void](Place $d $cu3 250 330 280 74); [void](Place $d $cu4 480 440 220 60)
        [void](Place $d $empleado 40 190 70 90); [void](Place $d $aprobador 800 190 70 90)
        [void](Add-Conn $empleado $cu1 'Association'); [void](Add-Conn $empleado $cu3 'Association')
        [void](Add-Conn $aprobador $cu2 'Association')
        [void](Add-Conn $cu2 $cu4 'Dependency' '' 'include')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("casos de uso: " + (Exporta $repo $d 'g1_casos_de_uso'))
    } catch { Log ("ERROR casos de uso: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 2. CLASES: CHAIN OF RESPONSIBILITY =======================
    $pkC = $null; $clases = @{}
    try {
        $pkC = Add-Pkg $ej 'Chain of Responsibility'
        $d = Add-Diag $pkC 'Clases — Chain of Responsibility (cadena de aprobación)' 'Class'
        $cl = Add-Class $pkC 'ServicioSolicitudes' '' @() @('enviar(s:Solicitud):void')
        # versión del libro: el manejador abstracto se AGREGA a sí mismo (rombo + flecha abierta, rotulado 'siguiente'); el cliente solo se asocia con él
        $ha = Add-Class $pkC 'Aprobador' '' @('-siguiente:Aprobador') @('establecerSiguiente(a:Aprobador):Aprobador', 'procesar(s:Solicitud):void', '*puedeAprobar(s:Solicitud):bool') $true
        $h1 = Add-Class $pkC 'JefeDeArea' '' @('limite:decimal') @('puedeAprobar(s:Solicitud):bool')
        $h2 = Add-Class $pkC 'Gerente' '' @('limite:decimal') @('puedeAprobar(s:Solicitud):bool')
        $h3 = Add-Class $pkC 'Director' '' @() @('puedeAprobar(s:Solicitud):bool')
        $so = Add-Class $pkC 'Solicitud' '' @('id:int', 'monto:decimal', 'descripcion:str', 'estado:str') @()
        [void](Cab $cl 40 90 250 $d 0 1); [void](Cab $ha 400 70 380 $d 1 3)
        [void](Cab $so 880 90 230 $d 4 0)
        [void](Cab $h1 40 330 250 $d 1 1); [void](Cab $h2 400 330 250 $d 1 1); [void](Cab $h3 760 330 250 $d 0 1)
        [void](Add-Conn $h1 $ha 'Generalization'); [void](Add-Conn $h2 $ha 'Generalization'); [void](Add-Conn $h3 $ha 'Generalization')
        $c = Add-Conn $cl $ha 'Association' 'inicia la cadena'; $c.Direction = 'Source -> Destination'; [void]$c.Update()
        $auto = Add-AutoAgregacion $ha 'siguiente'
        [void](Add-Conn $ha $so 'Dependency' '' 'use')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Guardar-Enlaces $repo $d
        Set-LazoPropioArriba $repo $d.DiagramID $auto.ConnectorID 700 -70 80 32   # lazo sobre el borde superior del manejador
        Log ("clases CoR: " + (Exporta $repo $d 'g2_clases_cor'))
    } catch { Log ("ERROR clases CoR: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 3. SECUENCIA: LA CADENA EN EJECUCION =======================
    try {
        $pk = Add-Pkg $ej 'Secuencia de la cadena'
        $part = @(
            @{ n = 'Empleado'; t = 'actor'; e = $empleado },
            @{ n = 'ServicioSolicitudes'; t = 'control' },
            @{ n = 'JefeDeArea'; t = 'control' },
            @{ n = 'Gerente'; t = 'control' },
            @{ n = 'Director'; t = 'control' })
        $msgs = @(
            @{ d = 0; a = 1; t = 'enviar(solicitud)' },
            @{ d = 1; a = 2; t = 'procesar(solicitud)' },
            @{ d = 2; a = 1; t = 'aprobada(estado)' },
            @{ d = 2; a = 3; t = 'procesar(solicitud)' },
            @{ d = 3; a = 4; t = 'procesar(solicitud)' },
            @{ d = 4; a = 1; t = 'aprobada(estado)' },
            @{ d = 1; a = 0; t = 'notificar(estado)' })
        # el fragmento alt abarca desde el mensaje 2 hasta el 5; el segundo operando empieza en el mensaje 3.
        # Se evitan los autoenvios dentro y en los bordes del fragmento: EA les da mas altura y el marco queda desalineado.
        $frags = @(@{ de = 2; hasta = 5; tipo = 0; guardas = @('el jefe puede aprobar', 'el jefe no puede: pasa al siguiente'); cortes = @(3) })
        $d = Build-Sequence $repo $pk 'Secuencia — la solicitud recorre la cadena' $part $msgs $frags
        Log ("secuencia CoR: " + (Exporta $repo $d 'g3_secuencia_cor'))
    } catch { Log ("ERROR secuencia: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 4. PAQUETES =======================
    try {
        $pk = Add-Pkg $ej 'Paquetes'
        $raizP = Add-Pkg $pk 'sistema de solicitudes'
        $pPres = Add-Pkg $raizP 'presentacion'; $pNeg = Add-Pkg $raizP 'negocio'; $pDat = Add-Pkg $raizP 'datos'
        [void](Add-Elem $pPres 'PantallaSolicitud' 'Component'); [void](Add-Elem $pPres 'PantallaAprobacion' 'Component')
        [void](Add-Elem $pNeg 'ServicioSolicitudes' 'Component'); [void](Add-Elem $pNeg 'CadenaDeAprobacion' 'Component')
        [void](Add-Elem $pDat 'RepositorioSolicitudes' 'Component')
        $d = Add-Diag $pk 'Paquetes — arquitectura en capas' 'Package'
        [void](Place $d $pPres.Element 40 40 260 140); [void](Place $d $pNeg.Element 40 260 260 140); [void](Place $d $pDat.Element 40 480 260 120)
        foreach ($par in @(@($pPres, $pNeg), @($pNeg, $pDat))) {
            $c = $par[0].Element.Connectors.AddNew('', 'Dependency'); $c.SupplierID = $par[1].Element.ElementID; $c.Stereotype = 'import'; [void]$c.Update()
        }
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("paquetes: " + (Exporta $repo $d 'g4_paquetes'))
    } catch { Log ("ERROR paquetes: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 5. ACTIVIDAD CON CALLES =======================
    try {
        $pk = Add-Pkg $ej 'Actividad'
        $d = Add-Diag $pk 'Actividad — flujo de aprobación con calles' 'Activity'
        $pe = Add-Elem $pk 'Empleado' 'ActivityPartition'
        $ps = Add-Elem $pk 'Sistema' 'ActivityPartition'
        $pa = Add-Elem $pk 'Aprobador' 'ActivityPartition'
        [void](Place $d $pe 20 20 300 560 90); [void](Place $d $ps 320 20 300 560 90); [void](Place $d $pa 620 20 300 560 90)
        $ini = Nodo $pk $pe '' 'StateNode' 100
        $a1 = Nodo $pk $pe 'Registra la solicitud' 'Action'
        $a2 = Nodo $pk $ps 'Envía la solicitud al aprobador actual' 'Action'
        $dec = Nodo $pk $pa '¿Puede aprobar?' 'Decision'
        $a3 = Nodo $pk $pa 'Aprueba o rechaza' 'Action'
        $a4 = Nodo $pk $ps 'Pasa la solicitud al siguiente aprobador' 'Action'
        $a5 = Nodo $pk $ps 'Notifica el resultado' 'Action'
        $fin = Nodo $pk $pe '' 'StateNode' 101
        [void](Place $d $ini 160 70 24 24 5)
        [void](Place $d $a1 70 120 200 56 5); [void](Place $d $a2 370 200 200 56 5)
        [void](Place $d $dec 700 280 130 70 5); [void](Place $d $a3 665 400 200 56 5)
        [void](Place $d $a4 370 300 200 56 5); [void](Place $d $a5 370 480 200 56 5); [void](Place $d $fin 160 500 24 24 5)
        # la cadena en el flujo: si no puede aprobar, pasa al siguiente y vuelve a empezar con ese aprobador
        Flujo $ini $a1; Flujo $a1 $a2; Flujo $a2 $dec
        Flujo $dec $a3 'Sí'; Flujo $dec $a4 'No'; Flujo $a4 $a2; Flujo $a3 $a5; Flujo $a5 $fin
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("actividad: " + (Exporta $repo $d 'g5_actividad'))
    } catch { Log ("ERROR actividad: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    $repo.CloseFile(); $repo.Exit()
} catch { Log ("ERROR: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) } finally { $sw.Close() }
