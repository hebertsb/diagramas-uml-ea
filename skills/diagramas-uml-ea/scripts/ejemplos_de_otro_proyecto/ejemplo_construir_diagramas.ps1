param([string]$Trabajo, [string]$Salida)
. "$PSScriptRoot\..\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Cls-H($na, $no) { return [int](38 + 17 * ($na + $no) + $(if ($na -gt 0 -and $no -gt 0) { 10 } else { 0 })) }
function Cab($el, $x, $y, $w, $d, $na, $no) { return (Place $d $el $x $y $w (Cls-H $na $no)) }
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $raiz = $repo.Models.GetAt(0)
    $pkS1 = Find-Pkg $repo 'Casos de Uso Sprint 1'
    $jugador = Find-Elem $repo 'Jugador' 'Actor' $pkS1.PackageID
    $facilitador = Find-Elem $repo 'Facilitador' 'Actor' $pkS1.PackageID
    $s2 = Add-Pkg $raiz 'Sprint 2'

    # ======================= 1. CASOS DE USO SPRINT 2 =======================
    try {
        $pk = Add-Pkg $s2 'Casos de Uso'
        $d = Add-Diag $pk 'Casos de Uso Sprint 2' 'Use Case'
        $b = Add-Elem $pk 'Sistema Tutor Inteligente de Ajedrez — Sprint 2' 'Boundary'
        $leng = Get-Or-Add $repo $pk 'Servicio de lenguaje' 'Actor' 'external system'
        $cu = [ordered]@{
            'CU07' = 'CU07 Realizar el onboarding educativo (HU12)'; 'CU08' = 'CU08 Completar el diagnóstico de nivel (HU13)'
            'CU09' = 'CU09 Configurar la partida (HU10)'; 'CU10' = 'CU10 Jugar con análisis en tiempo real (HU6)'
            'CU11' = 'CU11 Ver retroalimentación post-partida (HU5)'; 'CU12' = 'CU12 Consultar estadísticas personales (HU14)'
            'CU13' = 'CU13 Conversar con el tutor Turing (HU5)'; 'CU14' = 'CU14 Gestionar usuarios y roles'
            'CU15' = 'CU15 Generar código de invitación'; 'CU16' = 'CU16 Exportar partidas y reentrenar el modelo (HU4)' }
        $e = @{}
        foreach ($k in $cu.Keys) { $e[$k] = Add-Elem $pk $cu[$k] 'UseCase' }
        [void](Place $d $b 250 20 620 840 90)
        $izq = 'CU07', 'CU08', 'CU09', 'CU10', 'CU11', 'CU12', 'CU13'
        for ($i = 0; $i -lt $izq.Count; $i++) { [void](Place $d $e[$izq[$i]] 290 (90 + $i * 110) 250 74) }
        $der = 'CU14', 'CU15', 'CU16'
        for ($i = 0; $i -lt $der.Count; $i++) { [void](Place $d $e[$der[$i]] 560 (90 + $i * 110) 250 74) }
        [void](Place $d $jugador 40 340 70 90); [void](Place $d $leng 40 740 90 90); [void](Place $d $facilitador 960 190 70 90)
        foreach ($k in $izq) { [void](Add-Conn $jugador $e[$k] 'Association') }
        [void](Add-Conn $leng $e['CU13'] 'Association')
        foreach ($k in $der) { [void](Add-Conn $facilitador $e[$k] 'Association') }
        [void](Add-Conn $e['CU10'] $e['CU09'] 'Dependency' '' 'include')
        [void](Add-Conn $e['CU11'] $e['CU10'] 'Dependency' '' 'extend')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S2 casos de uso: " + (Exporta $repo $d 's2_casos_uso'))
    } catch { Log ("ERROR S2 CU: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 2. PAQUETES DEL BACKEND (cierre Sprint 2) =======================
    try {
        $pk = Add-Pkg $s2 'Paquetes del Backend'
        $raizB = Add-Pkg $pk 'backend (cierre Sprint 2)'
        $pRu = Add-Pkg $raizB 'rutas'; $pSe = Add-Pkg $raizB 'servicios'; $pRe = Add-Pkg $raizB 'repositorios'
        $pEs = Add-Pkg $raizB 'esquemas'; $pMo = Add-Pkg $raizB 'modelos'; $pDb = Add-Pkg $raizB 'database'
        foreach ($n in 'ruta_jugada', 'ruta_partida', 'ruta_vision', 'ruta_tutor', 'ruta_aprendizaje', 'ruta_usuario', 'ruta_auth', 'ruta_entrenamiento') { [void](Add-Elem $pRu $n 'Component') }
        foreach ($n in 'motor', 'vision', 'aprendizaje', 'partida', 'retroalimentacion', 'tutor', 'calibracion', 'estrategias', 'auth', 'entrenamiento', 'facilitador') { [void](Add-Pkg $pSe $n) }
        foreach ($n in 'repositorio_partida', 'repositorio_tutor') { [void](Add-Elem $pRe $n 'Component') }
        [void](Add-Elem $pEs 'DTO de entrada y salida (Pydantic)' 'Component')
        foreach ($n in 'UsuarioORM', 'ParticipanteORM', 'SesionORM', 'PartidaORM', 'JugadaORM', 'MensajeTutorORM', 'CalibracionORM', 'ExportacionDatasetORM', 'CodigoInvitacionORM') { [void](Add-Elem $pMo $n 'Class') }
        [void](Add-Elem $pDb 'sesión SQLAlchemy / PostgreSQL' 'Component')
        $d = Add-Diag $pk 'Paquetes del Backend al cierre del Sprint 2' 'Package'
        [void](Place $d $pRu.Element 320 30 280 190); [void](Place $d $pSe.Element 30 300 280 250)
        [void](Place $d $pEs.Element 560 430 300 100); [void](Place $d $pRe.Element 30 630 280 100)
        [void](Place $d $pMo.Element 30 810 280 230); [void](Place $d $pDb.Element 30 1130 280 100)
        foreach ($par in @(@($pRu, $pSe), @($pRu, $pEs), @($pSe, $pRe), @($pSe, $pEs), @($pRe, $pMo), @($pMo, $pDb))) {
            $c = $par[0].Element.Connectors.AddNew('', 'Dependency'); $c.SupplierID = $par[1].Element.ElementID; $c.Stereotype = 'import'; [void]$c.Update()
        }
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S2 paquetes: " + (Exporta $repo $d 's2_paquetes'))
    } catch { Log ("ERROR S2 paquetes: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 3. CLASES DEL SPRINT 2 =======================
    try {
        $pk = Add-Pkg $s2 'Clases'
        $d = Add-Diag $pk 'Clases del Sprint 2: usuario, partida, jugada, calibración y estrategias de jugada' 'Class'
        $ej = Add-Class $pk 'EstrategiaJugada' 'abstract' @() @('decidir_jugada(fen:str):str') $true
        $es = Add-Class $pk 'EstrategiaStockfish' '' @('nivel:int') @('decidir_jugada(fen:str):str')
        $em = Add-Class $pk 'EstrategiaModelo' '' @('nivel:int', 'checkpoint:Path') @('decidir_jugada(fen:str):str')
        $fa = Add-Class $pk 'FabricaEstrategias' 'factory' @() @('crear_estrategia_jugada(tipo:str, nivel:int):EstrategiaJugada')
        $sp = Add-Class $pk 'ServicioPartida' 'service' @() @('mover(partida_id:str, uci:str):dict', 'responder(partida_id:str):dict', 'analisis_completo(partida_id:str):dict')
        $sr = Add-Class $pk 'ServicioRetroalimentacion' 'service' @() @('explicar_jugada()', 'clasificar_calidad_jugada()', 'generar_resumen_partida()')
        $sc = Add-Class $pk 'ServicioCalibracion' 'service' @() @('registrar_calibracion()', 'estado_nivel_jugador(usuario)')
        $st = Add-Class $pk 'ServicioTutor' 'service' @('MAX_RONDAS_HERRAMIENTAS:int') @('responder(usuario, mensaje)')
        $pa = Add-Class $pk 'Partida' '' @('id:str', 'nivel:int', 'tipo_oponente:str', 'control_tiempo_ms:int')
        $ju = Add-Class $pk 'Jugada' '' @('numero:int', 'movimiento:str', 'evaluacion_cp:int', 'explicacion:str')
        $ca = Add-Class $pk 'Calibracion' '' @('precision_global:float', 'nivel_partida:int', 'rango_partida:str')
        $us = Add-Class $pk 'Usuario' '' @('id:int', 'rol:str', 'nivel_estimado:int', 'rango_estimado:str')
        $ci = Add-Class $pk 'CodigoInvitacion' '' @('codigo_hash:str', 'expira_en:datetime', 'usado_en:datetime')
        $mt = Add-Class $pk 'MensajeTutor' '' @('rol:str', 'contenido:str', 'creado_en:datetime')
        [void](Cab $ej 760 110 270 $d 0 1); [void](Cab $es 400 20 260 $d 1 1); [void](Cab $em 400 150 260 $d 2 1)
        [void](Cab $fa 360 310 340 $d 0 1); [void](Cab $sp 30 400 300 $d 0 3); [void](Cab $sr 400 440 300 $d 0 3)
        [void](Cab $pa 400 600 230 $d 4 0); [void](Cab $ju 760 600 230 $d 4 0); [void](Cab $sc 30 600 280 $d 0 2)
        [void](Cab $ca 400 770 230 $d 3 0); [void](Cab $us 30 790 230 $d 4 0); [void](Cab $ci 400 920 230 $d 3 0)
        [void](Cab $mt 400 1050 230 $d 3 0); [void](Cab $st 30 1100 300 $d 1 1)
        [void](Add-Conn $es $ej 'Generalization'); [void](Add-Conn $em $ej 'Generalization')
        [void](Add-Conn $fa $ej 'Dependency' '' 'create')
        [void](Add-Conn $sp $fa 'Dependency' '' 'use'); [void](Add-Conn $sp $sr 'Dependency' '' 'use'); [void](Add-Conn $sp $pa 'Dependency' '' 'use')
        [void](Add-Conn $sc $ca 'Dependency' '' 'use'); [void](Add-Conn $st $mt 'Dependency' '' 'use')
        $c = Add-Conn $pa $ju 'Aggregation'; $c.ClientEnd.Aggregation = 2; $c.ClientEnd.Navigable = 'Unspecified'; $c.Direction = 'Unspecified'; $c.ClientEnd.Cardinality = '1'; $c.SupplierEnd.Cardinality = '0..*'; [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update(); [void]$c.Update(); $c.Direction = 'Unspecified'; [void]$c.Update()
        $c = Add-Conn $us $pa 'Association' 'juega'; $c.ClientEnd.Cardinality = '1'; $c.SupplierEnd.Cardinality = '0..*'; [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update()
        $c = Add-Conn $us $ca 'Aggregation'; $c.ClientEnd.Aggregation = 2; $c.ClientEnd.Navigable = 'Unspecified'; $c.Direction = 'Unspecified'; $c.ClientEnd.Cardinality = '1'; $c.SupplierEnd.Cardinality = '0..*'; [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update(); [void]$c.Update(); $c.Direction = 'Unspecified'; [void]$c.Update()
        $c = Add-Conn $us $ci 'Association' 'crea'; $c.ClientEnd.Cardinality = '1'; $c.SupplierEnd.Cardinality = '0..*'; [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update()
        $c = Add-Conn $us $mt 'Aggregation'; $c.ClientEnd.Aggregation = 2; $c.ClientEnd.Navigable = 'Unspecified'; $c.Direction = 'Unspecified'; $c.ClientEnd.Cardinality = '1'; $c.SupplierEnd.Cardinality = '0..*'; [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update(); [void]$c.Update(); $c.Direction = 'Unspecified'; [void]$c.Update()
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S2 clases: " + (Exporta $repo $d 's2_clases'))
    } catch { Log ("ERROR S2 clases: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 4. SECUENCIA SPRINT 2 =======================
    try {
        $pk = Add-Pkg $s2 'Secuencia Mover con Analisis'
        $part = @(
            @{ n = 'Jugador'; t = 'actor'; e = $jugador },
            @{ n = 'Sala de Control'; t = 'boundary' },
            @{ n = 'ruta_partida'; t = 'control' },
            @{ n = 'ServicioPartida'; t = 'control' },
            @{ n = 'Motor (Stockfish)'; t = 'control' },
            @{ n = 'Retroalimentación'; t = 'control' },
            @{ n = 'FabricaEstrategias'; t = 'control' },
            @{ n = 'EstrategiaModelo'; t = 'control' },
            @{ n = 'PostgreSQL'; t = 'entity' })
        $msgs = @(
            @{ d = 0; a = 1; t = 'mueve una pieza' },
            @{ d = 1; a = 2; t = 'POST /partida/{id}/mover' },
            @{ d = 2; a = 3; t = 'mover(partida_id, uci)' },
            @{ d = 3; a = 4; t = 'analizar_posicion(fen_antes), analizar_posicion(fen_despues)' },
            @{ d = 4; a = 3; t = 'evaluación en cp / mate' },
            @{ d = 3; a = 5; t = 'clasificar_calidad_jugada(...) y explicar_jugada(...)' },
            @{ d = 5; a = 3; t = 'calidad, Win %, explicación' },
            @{ d = 3; a = 8; t = 'guardar jugada con calidad y explicación' },
            @{ d = 3; a = 6; t = 'crear_estrategia_jugada(tipo_oponente, nivel)' },
            @{ d = 6; a = 3; t = 'estrategia' },
            @{ d = 3; a = 7; t = 'decidir_jugada(fen)' },
            @{ d = 7; a = 3; t = 'jugada del oponente (UCI)' },
            @{ d = 3; a = 8; t = 'guardar jugada del oponente' },
            @{ d = 3; a = 5; t = 'generar_resumen_partida(...) y registrar_calibracion(...)' },
            @{ d = 3; a = 8; t = 'INSERT calibracion' },
            @{ d = 3; a = 2; t = 'respuesta (calidad, jugada rival, fen)' },
            @{ d = 2; a = 1; t = '200 JSON' },
            @{ d = 1; a = 0; t = 'barra Win %, calidad y explicación' })
        $frags = @(@{ de = 8; hasta = 14; tipo = 0; guardas = @('la partida no terminó', 'mate o tablas'); cortes = @(13) })
        $d = Build-Sequence $repo $pk 'Secuencia: mover con análisis, estrategia y calibración (Sprint 2)' $part $msgs $frags 175
        Log ("S2 secuencia: " + (Exporta $repo $d 's2_secuencia'))
    } catch { Log ("ERROR S2 secuencia: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 5. DESPLIEGUE SPRINT 2 =======================
    try {
        $pk = Add-Pkg $s2 'Despliegue'
        $d = Add-Diag $pk 'Despliegue Sprint 2' 'Deployment'
        $dev = Add-Elem $pk 'Dispositivo del usuario' 'Device'
        $a1 = Add-Elem $pk 'Navegador (React SPA / PWA)' 'Artifact'; $a1.ParentID = $dev.ElementID; [void]$a1.Update()
        $lab = Add-Elem $pk 'Servidor home-lab (Tailscale)' 'Node' 'node'
        $fun = Add-Elem $pk 'Tailscale Funnel' 'Node' 'execution environment'; $fun.ParentID = $lab.ElementID; [void]$fun.Update()
        $a2 = Add-Elem $pk 'HTTPS → 127.0.0.1:8090' 'Artifact'; $a2.ParentID = $fun.ElementID; [void]$a2.Update()
        $dc = Add-Elem $pk 'Docker Compose' 'Node'; $dc.ParentID = $lab.ElementID; [void]$dc.Update()
        $web = Add-Elem $pk 'Contenedor ajedrez_web' 'Node' 'execution environment'; $web.ParentID = $dc.ElementID; [void]$web.Update()
        $a3 = Add-Elem $pk 'Backend FastAPI + frontend compilado' 'Artifact'; $a3.ParentID = $web.ElementID; [void]$a3.Update()
        $a4 = Add-Elem $pk 'Stockfish' 'Artifact'; $a4.ParentID = $web.ElementID; [void]$a4.Update()
        $a5 = Add-Elem $pk 'checkpoints (volumen solo lectura)' 'Artifact'; $a5.ParentID = $web.ElementID; [void]$a5.Update()
        $db = Add-Elem $pk 'Contenedor ajedrez_db' 'Node' 'database'; $db.ParentID = $dc.ElementID; [void]$db.Update()
        $a6 = Add-Elem $pk 'PostgreSQL (volumen persistente)' 'Artifact'; $a6.ParentID = $db.ElementID; [void]$a6.Update()
        $col = Add-Elem $pk 'Google Colab (GPU)' 'Node' 'execution environment'
        $a7 = Add-Elem $pk 'entrenamiento y reentrenamiento' 'Artifact'; $a7.ParentID = $col.ElementID; [void]$a7.Update()
        $gq = Add-Elem $pk 'Servicio de lenguaje (Groq)' 'Node' 'node'
        $a8 = Add-Elem $pk 'API chat completions' 'Artifact'; $a8.ParentID = $gq.ElementID; [void]$a8.Update()
        [void](Place $d $dev 20 110 250 130 90); [void](Place $d $a1 40 165 210 55 5)
        [void](Place $d $lab 380 20 1000 370 90)
        [void](Place $d $fun 410 130 260 170 70); [void](Place $d $a2 430 190 220 60 5)
        [void](Place $d $dc 740 70 610 300 70)
        [void](Place $d $web 760 110 290 250 50); [void](Place $d $a3 775 165 260 45 5); [void](Place $d $a4 775 215 260 45 5); [void](Place $d $a5 775 265 260 45 5)
        [void](Place $d $db 1090 140 240 180 50); [void](Place $d $a6 1105 205 210 60 5)
        [void](Place $d $col 380 480 320 120 90); [void](Place $d $a7 395 535 290 50 5)
        [void](Place $d $gq 1080 480 280 120 90); [void](Place $d $a8 1095 535 250 50 5)
        [void](Add-Conn $dev $fun 'Association' 'HTTPS'); [void](Add-Conn $fun $web 'Association' 'HTTP :8090→:8000')
        [void](Add-Conn $web $db 'Association' 'TCP 5432'); [void](Add-Conn $web $gq 'Association' 'HTTPS')
        [void](Add-Conn $col $web 'Dependency' 'checkpoint .pt')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S2 despliegue: " + (Exporta $repo $d 's2_despliegue'))
    } catch { Log ("ERROR S2 despliegue: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    $repo.CloseFile(); $repo.Exit()
}
catch { Log ("ERROR general: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
finally { $sw.Close() }
