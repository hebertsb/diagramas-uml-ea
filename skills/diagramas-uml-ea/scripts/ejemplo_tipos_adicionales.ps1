param([string]$Trabajo, [string]$Salida, [string]$ImgDir = 'C:\tmp\ea_ejemplo_tipos')
# Ejemplo autonomo de los tipos de diagrama "menos comunes", probados en EA 15 con dominio neutro (pedidos):
#   comunicacion, objetos, estados, robustez ICONIX (dos variantes).
# Corre solo sobre una COPIA del .eapx y con EA cerrado.
. "$PSScriptRoot\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$global:CarpetaImg = $ImgDir
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $raiz = $repo.Models.GetAt(0)
    $pk = Add-Pkg $raiz 'Ejemplo de tipos adicionales'

    # ---- COMUNICACION: diagrama 'Collaboration', participantes como Object y enlaces como Association con el mensaje numerado
    # (el conector de tipo 'Collaboration' NO dibuja la linea por COM; con 'Association' si, y el numero va en el nombre)
    try {
        $d = Add-Diag $pk 'Comunicación — registrar pedido' 'Collaboration'
        $a = Add-Elem $pk 'Cliente' 'Actor'
        $o1 = Add-Elem $pk ':ServicioPedidos' 'Object'
        $o2 = Add-Elem $pk ':RepositorioPedidos' 'Object'
        [void](Place $d $a 40 120 80 90); [void](Place $d $o1 300 120 150 60); [void](Place $d $o2 580 120 160 60)
        [void](Add-Conn $a $o1 'Association' '1: registrar(pedido)')
        [void](Add-Conn $o1 $o2 'Association' '2: guardar(pedido)')
        [void]$repo.ReloadDiagram($d.DiagramID)
        [void]$repo.OpenDiagram($d.DiagramID); [void]$repo.SaveDiagram($d.DiagramID); [void]$repo.CloseDiagram($d.DiagramID)
        Log ("comunicacion: " + (Exporta $repo $d 'e1_comunicacion'))
    } catch { Log ("ERROR comunicacion: " + $_.Exception.Message) }

    # ---- OBJETOS: instancia de una clase (ClassifierID) -> se ve "p1: Pedido"
    try {
        $d = Add-Diag $pk 'Objetos — un pedido concreto' 'Object'
        $cl = Add-Class $pk 'Pedido' '' @('total:int') @()
        $ob = Add-Elem $pk 'p1' 'Object'; $ob.ClassifierID = $cl.ElementID; [void]$ob.Update()
        [void](Place $d $ob 60 60 160 70)
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("objetos: " + (Exporta $repo $d 'e2_objetos'))
    } catch { Log ("ERROR objetos: " + $_.Exception.Message) }

    # ---- ESTADOS: 'Statechart'; StateNode con Subtype 3 = inicial y 4 = final; transiciones StateFlow con evento y guarda
    try {
        $d = Add-Diag $pk 'Estados — ciclo de vida del pedido' 'Statechart'
        $i = Add-Elem $pk '' 'StateNode'; $i.Subtype = 3; [void]$i.Update()
        $s1 = Add-Elem $pk 'Pendiente' 'State'; $s2 = Add-Elem $pk 'Aprobado' 'State'
        $f = Add-Elem $pk '' 'StateNode'; $f.Subtype = 4; [void]$f.Update()
        [void](Place $d $i 60 60 24 24); [void](Place $d $s1 150 40 140 60); [void](Place $d $s2 400 40 140 60); [void](Place $d $f 640 60 24 24)
        [void](Add-Conn $i $s1 'StateFlow')
        $c = Add-Conn $s1 $s2 'StateFlow'; $c.TransitionEvent = 'aprobar'; $c.TransitionGuard = 'monto valido'; [void]$c.Update()
        [void](Add-Conn $s2 $f 'StateFlow')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("estados: " + (Exporta $repo $d 'e3_estados'))
    } catch { Log ("ERROR estados: " + $_.Exception.Message) }

    # ---- ROBUSTEZ ICONIX, variante A: diagrama 'Analysis' con elementos Boundary / Control / Entity (notacion de cajas de EA)
    try {
        $d = Add-Diag $pk 'Robustez (Analysis)' 'Analysis'
        $a = Add-Elem $pk 'Usuario' 'Actor'
        $b = Add-Elem $pk 'PantallaPedido' 'Boundary'; $c1 = Add-Elem $pk 'RegistrarPedido' 'Control'; $e = Add-Elem $pk 'Pedido' 'Entity'
        [void](Place $d $a 40 100 80 90); [void](Place $d $b 220 100 100 80); [void](Place $d $c1 420 100 100 80); [void](Place $d $e 620 100 100 80)
        [void](Add-Conn $a $b 'Association'); [void](Add-Conn $b $c1 'Association'); [void](Add-Conn $c1 $e 'Association')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("robustez Analysis: " + (Exporta $repo $d 'e4_robustez_analysis'))
    } catch { Log ("ERROR robustez A: " + $_.Exception.Message) }

    # ---- ROBUSTEZ ICONIX, variante B: 'Collaboration' con Object y estereotipos boundary/control/entity (iconos ICONIX clasicos)
    try {
        $d = Add-Diag $pk 'Robustez (Collaboration con estereotipos)' 'Collaboration'
        $a = Add-Elem $pk 'Usuario' 'Actor'
        $b = Add-Elem $pk 'PantallaPedido' 'Object'; $b.Stereotype = 'boundary'; [void]$b.Update()
        $c1 = Add-Elem $pk 'RegistrarPedido' 'Object'; $c1.Stereotype = 'control'; [void]$c1.Update()
        $e = Add-Elem $pk 'Pedido' 'Object'; $e.Stereotype = 'entity'; [void]$e.Update()
        [void](Place $d $a 40 100 80 90); [void](Place $d $b 220 100 110 80); [void](Place $d $c1 420 100 110 80); [void](Place $d $e 620 100 110 80)
        [void](Add-Conn $a $b 'Association'); [void](Add-Conn $b $c1 'Association'); [void](Add-Conn $c1 $e 'Association')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("robustez Collaboration: " + (Exporta $repo $d 'e5_robustez_collaboration'))
    } catch { Log ("ERROR robustez B: " + $_.Exception.Message) }

    $repo.CloseFile(); $repo.Exit()
} catch { Log ("ERROR: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) } finally { $sw.Close() }
