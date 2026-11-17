param([string]$Trabajo, [string]$Salida)
. "$PSScriptRoot\..\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
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
    $an = Add-Pkg $raiz 'Anexos - Actividades'

    # ======================= SITUACION PROBLEMATICA =======================
    try {
        $pk = Add-Pkg $an 'Situacion Problematica'
        $d = Add-Diag $pk 'Diagrama de actividades con particiones — Situación problemática' 'Activity'
        $pj = Add-Elem $pk 'Jugador' 'ActivityPartition'
        $pi = Add-Elem $pk 'Instructor / Asociación' 'ActivityPartition'
        [void](Place $d $pj 20 20 330 640 90); [void](Place $d $pi 350 20 330 640 90)
        $ini = Nodo $pk $pj '' 'StateNode' 100
        $a1 = Nodo $pk $pj 'Se inscribe a un curso o club presencial' 'Action'
        $a2 = Nodo $pk $pj 'Juega con conocidos o contra un programa sin ajuste de nivel' 'Action'
        $a3 = Nodo $pk $pj 'Pierde una partida' 'Action'
        $dec = Nodo $pk $pi '¿Hay instructor disponible?' 'Decision'
        $a4 = Nodo $pk $pj 'Queda sin explicación del error' 'Action'
        $a5 = Nodo $pk $pi 'Explica el error al grupo (poca atención individual)' 'Action'
        $a6 = Nodo $pk $pj 'Repite los mismos errores, sin ruta de progreso' 'Action'
        $fin = Nodo $pk $pj '' 'StateNode' 101
        [void](Place $d $ini 170 80 24 24 5)
        [void](Place $d $a1 70 130 210 60 5); [void](Place $d $a2 70 230 210 70 5); [void](Place $d $a3 70 340 210 60 5)
        [void](Place $d $dec 450 420 120 70 5); [void](Place $d $a4 70 450 210 60 5)
        [void](Place $d $a5 410 560 230 70 5); [void](Place $d $a6 70 570 210 60 5); [void](Place $d $fin 170 660 24 24 5)
        Flujo $ini $a1; Flujo $a1 $a2; Flujo $a2 $a3; Flujo $a3 $dec
        Flujo $dec $a4 'No'; Flujo $dec $a5 'Sí'; Flujo $a4 $a6; Flujo $a5 $a6; Flujo $a6 $fin
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("anexo problematica: " + (Exporta $repo $d 'an_problematica'))
    } catch { Log ("ERROR problematica: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= SITUACION DESEADA =======================
    try {
        $pk = Add-Pkg $an 'Situacion Deseada'
        $d = Add-Diag $pk 'Diagrama de actividades con particiones — Situación deseada' 'Activity'
        $pj = Add-Elem $pk 'Jugador' 'ActivityPartition'
        $ps = Add-Elem $pk 'Sistema tutor' 'ActivityPartition'
        $pf = Add-Elem $pk 'Facilitador' 'ActivityPartition'
        [void](Place $d $pj 20 20 300 900 90); [void](Place $d $ps 320 20 320 900 90); [void](Place $d $pf 640 20 300 900 90)
        $ini = Nodo $pk $pj '' 'StateNode' 100
        $a1 = Nodo $pk $pj 'Ingresa y realiza el onboarding educativo' 'Action'
        $a2 = Nodo $pk $pj 'Juega 3 partidas de diagnóstico' 'Action'
        $s1 = Nodo $pk $ps 'Mide la precisión y estima el nivel (0-20)' 'Action'
        $a3 = Nodo $pk $pj 'Configura la partida (oponente y nivel)' 'Action'
        $s2 = Nodo $pk $ps 'Asigna oponente: Stockfish o Turing al nivel indicado' 'Action'
        $a4 = Nodo $pk $pj 'Mueve en el tablero (digital o físico)' 'Action'
        $s3 = Nodo $pk $ps 'Reconoce la jugada, la califica y actualiza la barra Win %' 'Action'
        $dec = Nodo $pk $ps '' 'Decision'
        $s4 = Nodo $pk $ps 'Genera resumen y explicación adaptada al nivel' 'Action'
        $a5 = Nodo $pk $pj 'Consulta al tutor Turing y revisa sus errores' 'Action'
        $s5 = Nodo $pk $ps 'Recalibra el nivel y registra el progreso' 'Action'
        $f1 = Nodo $pk $pf 'Supervisa al grupo y ajusta el estilo de enseñanza' 'Action'
        $fin = Nodo $pk $pf '' 'StateNode' 101
        [void](Place $d $ini 160 80 24 24 5)
        [void](Place $d $a1 60 120 210 60 5); [void](Place $d $a2 60 220 210 60 5); [void](Place $d $s1 380 220 220 70 5)
        [void](Place $d $a3 60 330 210 60 5); [void](Place $d $s2 380 330 220 70 5)
        [void](Place $d $a4 60 440 210 60 5); [void](Place $d $s3 380 440 220 70 5)
        [void](Place $d $dec 430 550 120 70 5)
        [void](Place $d $s4 380 670 220 70 5); [void](Place $d $a5 60 670 210 60 5)
        [void](Place $d $s5 380 790 220 70 5); [void](Place $d $f1 680 790 230 70 5); [void](Place $d $fin 770 890 24 24 5)
        Flujo $ini $a1; Flujo $a1 $a2; Flujo $a2 $s1; Flujo $s1 $a3; Flujo $a3 $s2; Flujo $a3 $a4
        Flujo $a4 $s3; Flujo $s2 $s3; Flujo $s3 $dec; Flujo $dec $a4 'No terminó'; Flujo $dec $s4 'Terminó'
        Flujo $s4 $a5; Flujo $s4 $s5; Flujo $a5 $s5; Flujo $s5 $f1; Flujo $f1 $fin
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("anexo deseada: " + (Exporta $repo $d 'an_deseada'))
    } catch { Log ("ERROR deseada: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    $repo.CloseFile(); $repo.Exit()
}
catch { Log ("ERROR general: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
finally { $sw.Close() }
