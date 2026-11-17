param([string]$Trabajo, [string]$Salida)
. "$PSScriptRoot\..\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Conn-Nav($src, $dst, $type, $name = '', $stereo = '') {
    $c = Add-Conn $src $dst $type $name $stereo
    try { $c.Direction = 'Source -> Destination'; [void]$c.Update(); $c.SupplierEnd.Navigable = 'Navigable'; [void]$c.SupplierEnd.Update() } catch { Log ("nav: " + $_.Exception.Message) }
    return $c
}
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $raiz = $repo.Models.GetAt(0)
    $pkS1 = Find-Pkg $repo 'Casos de Uso Sprint 1'
    $jugador = Find-Elem $repo 'Jugador' 'Actor' $pkS1.PackageID
    $facilitador = Find-Elem $repo 'Facilitador' 'Actor' $pkS1.PackageID
    Log ("actores reutilizados: Jugador=" + $jugador.ElementID + " Facilitador=" + $facilitador.ElementID)

    $s0 = Add-Pkg $raiz 'Sprint 0 - Analisis'

    # ======================= 1. DIAGRAMA DE CONTEXTO =======================
    try {
        $pk = Add-Pkg $s0 'Contexto del Sistema'
        $d = Add-Diag $pk 'Diagrama de Contexto del Sistema' 'Component'
        $admin = Get-Or-Add $repo $pk 'Administrador de institución' 'Actor'
        $sis = Add-Elem $pk 'Sistema Tutor Inteligente de Ajedrez' 'Component' 'system'
        $web = Add-Elem $pk 'Aplicación web (React)' 'Component'; $web.ParentID = $sis.ElementID; [void]$web.Update()
        $api = Add-Elem $pk 'API de servicios (FastAPI)' 'Component'; $api.ParentID = $sis.ElementID; [void]$api.Update()
        $bd = Add-Elem $pk 'Base de datos (PostgreSQL)' 'Component'; $bd.ParentID = $sis.ElementID; [void]$bd.Update()
        $ext = @()
        foreach ($n in 'Stockfish (motor de ajedrez, UCI)', 'Servicio de lenguaje (Groq, tutor conversacional)', 'Google OAuth (inicio de sesión)', 'Lichess Open Database (partidas de referencia)', 'Cámaras del tablero (imágenes, USB/IP)', 'Brazo Dobot CR5AS + pinza DH (TCP/IP y Modbus)') { $ext += (Add-Elem $pk $n 'Component' 'external system') }
        [void](Place $d $jugador 30 40 70 90); [void](Place $d $facilitador 30 180 70 90); [void](Place $d $admin 30 320 70 90)
        [void](Place $d $sis 230 30 820 190 90)
        [void](Place $d $web 270 90 200 80 5); [void](Place $d $api 560 90 200 80 5); [void](Place $d $bd 850 90 170 80 5)
        $xs = @(260, 560, 860, 260, 560, 860); $yy = @(310, 310, 310, 430, 430, 430)
        for ($i = 0; $i -lt 6; $i++) { [void](Place $d $ext[$i] $xs[$i] $yy[$i] 230 80) }
        foreach ($a in @($jugador, $facilitador, $admin)) { [void](Conn-Nav $a $web 'Association' 'usa') }
        [void](Conn-Nav $web $api 'Association' 'HTTPS / JSON')
        [void](Conn-Nav $api $bd 'Association' 'SQL')
        foreach ($e in $ext) { [void](Add-Conn $api $e 'Dependency') }
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("contexto: " + (Exporta $repo $d 's0_contexto'))
    } catch { Log ("ERROR contexto: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 2. MODELO DE DOMINIO INICIAL =======================
    try {
        $pk = Add-Pkg $s0 'Modelo de Dominio Inicial'
        $d = Add-Diag $pk 'Modelo de Dominio Inicial' 'Class'
        Set-OpParams $repo $d 3
        $usu = Add-Class $pk 'Usuario' '' @('id:int', 'email:str', 'nombre:str', 'rol:str', 'nivel_estimado:int', 'rango_estimado:str', 'activo:bool') @('iniciarSesion()')
        $par = Add-Class $pk 'Participante' '' @('id:int', 'nombre:str')
        $ses = Add-Class $pk 'Sesion' '' @('id:int', 'facilitador:str', 'fecha:datetime', 'dificultad:int', 'tipo_oponente:str')
        $pa = Add-Class $pk 'Partida' '' @('id:str', 'fecha:datetime', 'tipo:str', 'fen:str', 'nivel:int', 'tipo_oponente:str', 'jugadas_uci:str', 'estado:str', 'resultado:str') @('mover(uci)', 'terminar(resultado)')
        $ju = Add-Class $pk 'Jugada' '' @('id:int', 'numero:int', 'fen_antes:str', 'movimiento:str', 'decidido_por:str', 'evaluacion_cp:int')
        [void](Place $d $usu 40 40 230 190); [void](Place $d $par 40 330 200 80); [void](Place $d $ses 40 470 230 130)
        [void](Place $d $pa 430 130 250 270); [void](Place $d $ju 840 170 230 150)
        $c1 = Add-Conn $usu $pa 'Association' 'juega'; $c1.ClientEnd.Cardinality = '1'; $c1.SupplierEnd.Cardinality = '0..*'; [void]$c1.ClientEnd.Update(); [void]$c1.SupplierEnd.Update()
        $c2 = Add-Conn $par $pa 'Association' 'participa en'; $c2.ClientEnd.Cardinality = '0..1'; $c2.SupplierEnd.Cardinality = '0..*'; [void]$c2.ClientEnd.Update(); [void]$c2.SupplierEnd.Update()
        $c3 = Add-Conn $ses $pa 'Association' 'agrupa'; $c3.ClientEnd.Cardinality = '0..1'; $c3.SupplierEnd.Cardinality = '0..*'; [void]$c3.ClientEnd.Update(); [void]$c3.SupplierEnd.Update()
        $c4 = Add-Conn $pa $ju 'Aggregation' 'registra'; $c4.ClientEnd.Aggregation = 2; $c4.ClientEnd.Navigable = 'Unspecified'; $c4.Direction = 'Unspecified'; $c4.ClientEnd.Cardinality = '1'; $c4.SupplierEnd.Cardinality = '0..*'
        $c4.Direction = 'Unspecified'; [void]$c4.Update()
        [void]$c4.ClientEnd.Update(); [void]$c4.SupplierEnd.Update(); [void]$c4.Update()
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("dominio: " + (Exporta $repo $d 's0_dominio'))
    } catch { Log ("ERROR dominio: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 3. COMPONENTES DE LA ARQUITECTURA INICIAL =======================
    try {
        $pk = Add-Pkg $s0 'Arquitectura Inicial'
        $d = Add-Diag $pk 'Componentes de la Arquitectura Inicial' 'Component'
        $sp = Add-Elem $pk 'Subsistema de presentación' 'Component' 'subsystem'
        $sa = Add-Elem $pk 'Subsistema de aplicación (FastAPI)' 'Component' 'subsystem'
        $sd = Add-Elem $pk 'Subsistema de datos' 'Component' 'subsystem'
        $iw = Add-Elem $pk 'Interfaz web (React + Vite)' 'Component'; $iw.ParentID = $sp.ElementID; [void]$iw.Update()
        $ca = Add-Elem $pk 'Cliente de API (fetch + estado)' 'Component'; $ca.ParentID = $sp.ElementID; [void]$ca.Update()
        $ru = Add-Elem $pk 'Rutas (controladores HTTP)' 'Component'; $ru.ParentID = $sa.ElementID; [void]$ru.Update()
        $se = Add-Elem $pk 'Servicios (lógica de negocio)' 'Component'; $se.ParentID = $sa.ElementID; [void]$se.Update()
        $re = Add-Elem $pk 'Repositorios (acceso a datos)' 'Component'; $re.ParentID = $sa.ElementID; [void]$re.Update()
        $mo = Add-Elem $pk 'Modelos y esquemas (ORM + Pydantic)' 'Component'; $mo.ParentID = $sa.ElementID; [void]$mo.Update()
        $ia = Add-Elem $pk 'Servicios de IA y visión (Stockfish, PyTorch, OpenCV)' 'Component'
        $pg = Add-Elem $pk 'PostgreSQL' 'Component'; $pg.ParentID = $sd.ElementID; [void]$pg.Update()
        [void](Place $d $sp 20 30 360 170 90); [void](Place $d $iw 40 90 150 90 5); [void](Place $d $ca 210 90 150 90 5)
        [void](Place $d $sa 440 30 820 170 90); [void](Place $d $ru 460 90 170 90 5); [void](Place $d $se 660 90 170 90 5); [void](Place $d $re 860 90 170 90 5); [void](Place $d $mo 1060 90 180 90 5)
        [void](Place $d $ia 600 280 260 90)
        [void](Place $d $sd 1000 270 260 130 90); [void](Place $d $pg 1050 320 160 70 5)
        [void](Add-Conn $iw $ca 'Dependency' '' 'use'); [void](Conn-Nav $ca $ru 'Association' 'API REST')
        [void](Add-Conn $ru $se 'Dependency' '' 'use'); [void](Add-Conn $se $re 'Dependency' '' 'use'); [void](Add-Conn $re $mo 'Dependency' '' 'use')
        [void](Add-Conn $se $ia 'Dependency' '' 'use'); [void](Conn-Nav $re $pg 'Association' 'SQL')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("arquitectura inicial: " + (Exporta $repo $d 's0_arquitectura'))
    } catch { Log ("ERROR arquitectura: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 4. SECUENCIA SPRINT 1: MOVER DESDE LA FOTO =======================
    try {
        $s1 = Add-Pkg $raiz 'Sprint 1 - Diagramas Adicionales'
        $pk = Add-Pkg $s1 'Secuencia Mover desde Foto'
        $part = @(
            @{ n = 'Jugador'; t = 'actor'; e = $jugador },
            @{ n = 'Interfaz web'; t = 'boundary' },
            @{ n = 'ruta_partida'; t = 'control' },
            @{ n = 'ServicioPartida'; t = 'control' },
            @{ n = 'Cámara / visión'; t = 'control' },
            @{ n = 'DetectorMovimiento'; t = 'control' },
            @{ n = 'PostgreSQL'; t = 'entity' })
        $msgs = @(
            @{ d = 0; a = 1; t = 'pulsa «Detecté un movimiento»' },
            @{ d = 1; a = 2; t = 'POST /partida/{id}/mover-desde-foto' },
            @{ d = 2; a = 3; t = 'mover_desde_foto(partida_id)' },
            @{ d = 3; a = 4; t = 'capturar_foto_tablero()' },
            @{ d = 4; a = 3; t = 'imagen' },
            @{ d = 3; a = 4; t = 'reconocer_tablero(imagen, turno)' },
            @{ d = 4; a = 3; t = 'fen_despues' },
            @{ d = 3; a = 5; t = 'detectar_jugada(fen_antes, fen_despues)' },
            @{ d = 5; a = 3; t = 'jugada (UCI)' },
            @{ d = 3; a = 6; t = 'INSERT jugada; UPDATE partida.fen' },
            @{ d = 6; a = 3; t = 'ok' },
            @{ d = 5; a = 3; t = 'sin coincidencia' },
            @{ d = 3; a = 2; t = '422 «no se reconoció la jugada»' },
            @{ d = 3; a = 2; t = 'partida actualizada' },
            @{ d = 2; a = 1; t = '200 JSON' },
            @{ d = 1; a = 0; t = 'tablero digital actualizado' })
        $frags = @(@{ de = 8; hasta = 12; tipo = 0; guardas = @('existe una jugada legal que produce fen_despues', 'ninguna jugada coincide'); cortes = @(11) })
        $d = Build-Sequence $repo $pk 'Secuencia: mover una pieza desde la foto (Sprint 1)' $part $msgs $frags 190
        Log ("secuencia S1: " + (Exporta $repo $d 's1_secuencia'))
    } catch { Log ("ERROR secuencia S1: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    $repo.CloseFile(); $repo.Exit()
}
catch { Log ("ERROR general: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
finally { $sw.Close() }
