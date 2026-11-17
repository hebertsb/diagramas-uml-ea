param([string]$Trabajo, [string]$Salida)
. "$PSScriptRoot\..\ea_lib.ps1"
$ErrorActionPreference = 'Continue'
$sw = New-Object System.IO.StreamWriter($Salida, $false, [Text.UTF8Encoding]::new($false))
$sw.AutoFlush = $true
function Log($t) { $sw.WriteLine($t) }
function Cls-H($na, $no) { return [int](38 + 17 * ($na + $no) + $(if ($na -gt 0 -and $no -gt 0) { 10 } else { 0 })) }
function Cab($el, $x, $y, $w, $d, $na, $no) { return (Place $d $el $x $y $w (Cls-H $na $no)) }
function Rel($a, $b, $card1, $card2, $nombre = '', $compuesta = $false, $hueca = $false) {
    $tipo = if ($compuesta -or $hueca) { 'Aggregation' } else { 'Association' }
    $c = Add-Conn $a $b $tipo $nombre
    if ($compuesta) { $c.ClientEnd.Aggregation = 2 } elseif ($hueca) { $c.ClientEnd.Aggregation = 1 }
    if ($compuesta -or $hueca) { $c.ClientEnd.Navigable = 'Unspecified' }
    $c.ClientEnd.Cardinality = $card1; $c.SupplierEnd.Cardinality = $card2
    [void]$c.ClientEnd.Update(); [void]$c.SupplierEnd.Update(); [void]$c.Update()
    if ($compuesta -or $hueca) { $c.Direction = 'Unspecified'; [void]$c.Update() }
}
try {
    $repo = New-Object -ComObject EA.Repository
    [void]$repo.OpenFile($Trabajo)
    $global:Repo = $repo
    $raiz = $repo.Models.GetAt(0)
    $pkS1 = Find-Pkg $repo 'Casos de Uso Sprint 1'
    $jugador = Find-Elem $repo 'Jugador' 'Actor' $pkS1.PackageID
    $facilitador = Find-Elem $repo 'Facilitador' 'Actor' $pkS1.PackageID
    $s3 = Add-Pkg $raiz 'Sprint 3'

    # ======================= 1. CASOS DE USO SPRINT 3 =======================
    try {
        $pk = Add-Pkg $s3 'Casos de Uso'
        $d = Add-Diag $pk 'Casos de Uso Sprint 3' 'Use Case'
        $b = Add-Elem $pk 'Sistema Tutor Inteligente de Ajedrez — Sprint 3' 'Boundary'
        $admin = Get-Or-Add $repo $pk 'Administrador de institución' 'Actor'
        $brazo = Get-Or-Add $repo $pk 'Brazo Dobot CR5AS' 'Actor' 'external system'
        $cu = [ordered]@{
            'CU17' = 'CU17 Conectar y calibrar el brazo (HU9)'; 'CU18' = 'CU18 Ejecutar la jugada del oponente en el brazo (HU9)'
            'CU19' = 'CU19 Ver el gemelo digital 3D (HU9)'; 'CU20' = 'CU20 Jugar una partida física con cámaras (HU1/HU9)'
            'CU21' = 'CU21 Ver rostro y expresiones del sistema (HU7)'; 'CU22' = 'CU22 Consultar el panel de progreso y medallas (HU8)'
            'CU23' = 'CU23 Administrar cursos, tareas y torneos (HU11)'; 'CU24' = 'CU24 Unirse a un curso con código (HU11)'
            'CU25' = 'CU25 Gestionar institución y suscripción'; 'CU26' = 'CU26 Auditar acciones y cuentas' }
        $e = @{}
        foreach ($k in $cu.Keys) { $e[$k] = Add-Elem $pk $cu[$k] 'UseCase' }
        [void](Place $d $b 250 20 620 840 90)
        $izq = 'CU20', 'CU21', 'CU22', 'CU24'
        for ($i = 0; $i -lt $izq.Count; $i++) { [void](Place $d $e[$izq[$i]] 290 (90 + $i * 110) 250 74) }
        [void](Place $d $e['CU25'] 290 600 250 74); [void](Place $d $e['CU26'] 290 710 250 74)
        $der = 'CU17', 'CU18', 'CU19', 'CU23'
        for ($i = 0; $i -lt $der.Count; $i++) { [void](Place $d $e[$der[$i]] 560 (90 + $i * 110) 250 74) }
        [void](Place $d $jugador 40 250 70 90); [void](Place $d $admin 40 640 90 90)
        [void](Place $d $facilitador 960 150 70 90); [void](Place $d $brazo 950 470 90 90)
        foreach ($k in $izq) { [void](Add-Conn $jugador $e[$k] 'Association') }
        foreach ($k in 'CU17', 'CU18', 'CU19', 'CU23') { [void](Add-Conn $facilitador $e[$k] 'Association') }
        [void](Add-Conn $brazo $e['CU18'] 'Association')
        foreach ($k in 'CU25', 'CU26') { [void](Add-Conn $admin $e[$k] 'Association') }
        [void](Add-Conn $e['CU18'] $e['CU17'] 'Dependency' '' 'include')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S3 casos de uso: " + (Exporta $repo $d 's3_casos_uso'))
    } catch { Log ("ERROR S3 CU: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 2. PAQUETES DEL BACKEND (cierre Sprint 3) =======================
    try {
        $pk = Add-Pkg $s3 'Paquetes del Backend'
        $raizB = Add-Pkg $pk 'backend (cierre Sprint 3)'
        $pRu = Add-Pkg $raizB 'rutas'; $pSe = Add-Pkg $raizB 'servicios'; $pRe = Add-Pkg $raizB 'repositorios'
        $pEs = Add-Pkg $raizB 'esquemas'; $pMo = Add-Pkg $raizB 'modelos'; $pDb = Add-Pkg $raizB 'database'
        foreach ($n in 'ruta_aprendizaje', 'ruta_auditoria', 'ruta_auth', 'ruta_brazo', 'ruta_brazo_control', 'ruta_curso', 'ruta_doble_factor', 'ruta_entrenamiento', 'ruta_facilitador', 'ruta_institucion', 'ruta_jugada', 'ruta_medallas', 'ruta_partida', 'ruta_partida_fisica', 'ruta_progreso', 'ruta_sala', 'ruta_simulacion', 'ruta_social', 'ruta_suscripcion', 'ruta_torneo', 'ruta_tutor', 'ruta_usuario', 'ruta_vision', 'ruta_vision_calibracion', 'ruta_vision_lente') { [void](Add-Elem $pRu $n 'Component') }
        foreach ($n in 'aprendizaje', 'auditoria', 'auth', 'brazo', 'calibracion', 'curso', 'entrenamiento', 'estrategias', 'facilitador', 'institucion', 'medallas', 'motor', 'partida', 'retroalimentacion', 'sala', 'simulacion', 'social', 'suscripcion', 'tutor', 'usuario', 'vision') { [void](Add-Pkg $pSe $n) }
        foreach ($n in 'repositorio_partida', 'repositorio_tutor') { [void](Add-Elem $pRe $n 'Component') }
        [void](Add-Elem $pEs 'DTO de entrada y salida (Pydantic)' 'Component')
        foreach ($n in 'UsuarioORM', 'ParticipanteORM', 'SesionORM', 'PartidaORM', 'JugadaORM', 'MensajeTutorORM', 'CalibracionORM', 'ExportacionDatasetORM', 'CodigoInvitacionORM', 'AuditoriaORM', 'InstitucionORM', 'SuscripcionORM', 'PagoORM', 'CursoORM', 'InscripcionORM', 'MedallaGanadaORM', 'MedallaPersonalizadaORM', 'AmistadORM', 'EloMovimientoORM', 'DenunciaORM', 'TorneoORM', 'TorneoJugadorORM', 'TorneoPartidaORM', 'AvisoCursoORM', 'TareaCursoORM') { [void](Add-Elem $pMo $n 'Class') }
        [void](Add-Elem $pDb 'sesión SQLAlchemy / PostgreSQL' 'Component')
        $d = Add-Diag $pk 'Paquetes del Backend al cierre del Sprint 3' 'Package'
        [void](Place $d $pRu.Element 30 30 290 470); [void](Place $d $pSe.Element 430 30 290 410)
        [void](Place $d $pEs.Element 30 600 300 100); [void](Place $d $pRe.Element 430 540 290 100)
        [void](Place $d $pMo.Element 430 720 290 470); [void](Place $d $pDb.Element 430 1270 290 100)
        foreach ($par in @(@($pRu, $pSe), @($pRu, $pEs), @($pSe, $pRe), @($pSe, $pEs), @($pRe, $pMo), @($pMo, $pDb))) {
            $c = $par[0].Element.Connectors.AddNew('', 'Dependency'); $c.SupplierID = $par[1].Element.ElementID; $c.Stereotype = 'import'; [void]$c.Update()
        }
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S3 paquetes: " + (Exporta $repo $d 's3_paquetes'))
    } catch { Log ("ERROR S3 paquetes: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 3. CLASES DEL MODULO DEL BRAZO =======================
    try {
        $pk = Add-Pkg $s3 'Clases del Brazo Robotico'
        $d = Add-Diag $pk 'Clases del módulo del brazo robótico' 'Class'
        $em = Add-Class $pk 'EjecutorMovimiento' 'abstract' @() @('ejecutar_movimiento(tablero_antes, jugada)') $true
        $esim = Add-Class $pk 'EjecutorSimulado' '' @() @('ejecutar_movimiento(tablero_antes, jugada)', 'cerrar()')
        $er = Add-Class $pk 'EjecutorReal' '' @('parametros:ParametrosAgarre', 'cliente:ClienteDobot', 'pinza:PinzaDH') @('conectar()', 'bajar_a(casilla, tipo_pieza)', 'subir_de(casilla, tipo_pieza)', 'ejecutar_pasos(pasos)', 'ejecutar_movimiento(tablero_antes, jugada)')
        $sb = Add-Class $pk 'ServicioBrazo' 'service' @() @('ejecutar_respuesta_en_brazo()', 'estado_brazo():dict')
        $fe = Add-Class $pk 'FabricaEjecutores' 'factory' @() @('crear_ejecutor_movimiento(modo):EjecutorMovimiento')
        $pa = Add-Class $pk 'ParametrosAgarre' '' @('z_tope:float', 'margen_agarre_mm:float', 'giro_diagonal_grados:float', 'apertura_aproximacion:int', 'largo_pinza_mm:float', 'alturas_piezas_mm:dict', 'aperturas_por_pieza:dict', 'margenes_por_pieza:dict')
        $pn = Add-Class $pk 'PiezaNoAgarrada' 'exception'
        $cd = Add-Class $pk 'ClienteDobot' '' @('host:str', 'puerto:int') @('conectar()', 'mover_a_pose()', 'mover_a_angulos()', 'esperar_fin()', 'detener()')
        $pd = Add-Class $pk 'PinzaDH' '' @() @('mover_a(posicion):EstadoPinza', 'abrir()', 'cerrar()', 'abrir_a_ancho_mm(ancho_mm)', 'estado():EstadoPinza')
        $pl = Add-Class $pk 'PlanificadorMovimiento' '' @() @('planificar(tablero_antes, jugada):list', 'cementerio(indice):str')
        $ps = Add-Class $pk 'Paso' '' @('pieza:str', 'origen:str', 'destino:str', 'si_falla:Paso')
        [void](Cab $esim 40 30 300 $d 0 2); [void](Cab $sb 30 200 300 $d 0 2); [void](Cab $fe 420 200 340 $d 0 1)
        [void](Cab $em 840 90 340 $d 0 1); [void](Cab $er 380 400 330 $d 3 5); [void](Cab $pa 820 340 320 $d 8 0)
        [void](Cab $pn 840 570 260 $d 0 0); [void](Cab $pl 30 480 310 $d 0 2); [void](Cab $ps 30 680 240 $d 4 0)
        [void](Cab $pd 400 700 290 $d 0 5); [void](Cab $cd 820 700 260 $d 2 5)
        [void](Add-Conn $esim $em 'Generalization'); [void](Add-Conn $er $em 'Generalization')
        [void](Add-Conn $fe $em 'Dependency' '' 'create'); [void](Add-Conn $sb $fe 'Dependency' '' 'use')
        [void](Add-Conn $er $pa 'Dependency' '' 'use'); [void](Add-Conn $er $pn 'Dependency' '' 'throw'); [void](Add-Conn $er $pl 'Dependency' '' 'use')
        Rel $er $cd '1' '1' '' $true; Rel $er $pd '1' '1' '' $true
        Rel $pl $ps '1' '0..*' 'produce'
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S3 clases brazo: " + (Exporta $repo $d 's3_clases_brazo'))
    } catch { Log ("ERROR S3 clases brazo: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 4. CLASES DE LA PLATAFORMA =======================
    try {
        $pk = Add-Pkg $s3 'Clases de la Plataforma'
        $d = Add-Diag $pk 'Clases de la plataforma: instituciones, cursos, torneos, medallas y auditoría' 'Class'
        $in = Add-Class $pk 'Institucion' '' @('id:int', 'nombre:str', 'tipo:str', 'dominio_correo:str')
        $su = Add-Class $pk 'Suscripcion' '' @('plan:str', 'ciclo:str', 'vigente_hasta:datetime')
        $pg = Add-Class $pk 'Pago' '' @('plan:str', 'monto_bs:int', 'estado:str')
        $us = Add-Class $pk 'Usuario' '' @('id:int', 'rol:str', 'institucion_id:int', 'totp_activo:bool')
        $cu = Add-Class $pk 'Curso' '' @('id:int', 'nombre:str', 'codigo:str', 'cupo:int', 'permite_retos:bool')
        $ic = Add-Class $pk 'Inscripcion' '' @('unido_en:datetime')
        $to = Add-Class $pk 'Torneo' '' @('nombre:str', 'rondas:int', 'ronda_actual:int', 'estado:str')
        $tp = Add-Class $pk 'TorneoPartida' '' @('ronda:int', 'resultado:str')
        $tc = Add-Class $pk 'TareaCurso' '' @('titulo:str', 'tipo:str', 'meta:int', 'desde:datetime', 'hasta:datetime')
        $ac = Add-Class $pk 'AvisoCurso' '' @('texto:str', 'enlace:str')
        $mg = Add-Class $pk 'MedallaGanada' '' @('codigo:str', 'ganada_en:datetime')
        $el = Add-Class $pk 'EloMovimiento' '' @('elo_antes:int', 'elo_despues:int', 'resultado:float')
        $au = Add-Class $pk 'Auditoria' '' @('accion:str', 'objetivo_tipo:str', 'creado_en:datetime')
        [void](Cab $su 290 20 230 $d 3 0); [void](Cab $ic 600 20 230 $d 1 0); [void](Cab $in 30 140 250 $d 4 0)
        [void](Cab $pg 330 180 230 $d 3 0); [void](Cab $us 330 360 250 $d 4 0); [void](Cab $cu 720 200 260 $d 5 0)
        [void](Cab $to 1100 200 250 $d 4 0); [void](Cab $tp 1450 200 220 $d 2 0); [void](Cab $tc 1060 430 260 $d 5 0); [void](Cab $ac 1060 660 260 $d 2 0)
        [void](Cab $mg 30 430 230 $d 2 0); [void](Cab $el 30 590 230 $d 3 0); [void](Cab $au 330 600 230 $d 3 0)
        Rel $in $su '1' '0..1' '' $true; Rel $in $pg '1' '0..*' '' $true; Rel $in $us '0..1' '0..*' 'agrupa' $false $true
        Rel $us $ic '1' '0..*'; Rel $us $cu '1' '0..*' 'facilita'
        Rel $cu $ic '1' '0..*' '' $true; Rel $cu $to '1' '0..*' '' $true; Rel $to $tp '1' '1..*' '' $true
        Rel $cu $tc '1' '0..*' '' $true; Rel $cu $ac '1' '0..*' '' $true
        Rel $us $mg '1' '0..*' '' $true; Rel $us $el '1' '0..*' '' $true; Rel $us $au '0..1' '0..*' 'actor de'
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S3 clases plataforma: " + (Exporta $repo $d 's3_clases_plataforma'))
    } catch { Log ("ERROR S3 clases plataforma: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 5. SECUENCIA: EL BRAZO EJECUTA LA JUGADA =======================
    try {
        $pk = Add-Pkg $s3 'Secuencia del Brazo'
        $part = @(
            @{ n = 'Sala de Control'; t = 'boundary' }, @{ n = 'ServicioPartida'; t = 'control' }, @{ n = 'ServicioBrazo'; t = 'control' },
            @{ n = 'FabricaEjecutores'; t = 'control' }, @{ n = 'EjecutorReal'; t = 'control' }, @{ n = 'PlanificadorMovimiento'; t = 'control' },
            @{ n = 'ClienteDobot'; t = 'control' }, @{ n = 'PinzaDH'; t = 'control' }, @{ n = 'Cámara'; t = 'control' })
        $msgs = @(
            @{ d = 0; a = 1; t = 'responder(partida_id)' },
            @{ d = 1; a = 2; t = 'ejecutar_respuesta_en_brazo(tablero, jugada)' },
            @{ d = 2; a = 3; t = 'crear_ejecutor_movimiento(modo)' },
            @{ d = 3; a = 2; t = 'EjecutorReal' },
            @{ d = 2; a = 4; t = 'ejecutar_movimiento(tablero_antes, jugada)' },
            @{ d = 4; a = 5; t = 'planificar(tablero_antes, jugada)' },
            @{ d = 5; a = 4; t = 'lista de Paso (captura, mover, enroque...)' },
            @{ d = 4; a = 6; t = 'mover_a_pose(sobre el origen)' },
            @{ d = 4; a = 7; t = 'mover_a(apertura de la pieza)' },
            @{ d = 4; a = 6; t = 'mover_a_pose(altura de agarre)' },
            @{ d = 4; a = 7; t = 'cerrar()' },
            @{ d = 7; a = 4; t = 'EstadoPinza' },
            @{ d = 4; a = 6; t = 'mover_a_pose(sube con la pieza y va al destino)' },
            @{ d = 4; a = 7; t = 'mover_a(apertura de soltar)' },
            @{ d = 4; a = 6; t = 'mover_a_angulos(posición cero)' },
            @{ d = 4; a = 4; t = 'lanzar PiezaNoAgarrada' },
            @{ d = 4; a = 2; t = 'error al facilitador' },
            @{ d = 1; a = 8; t = 'verificar posición con la cámara' },
            @{ d = 8; a = 1; t = 'fen reconocido' },
            @{ d = 2; a = 1; t = 'ejecutado' },
            @{ d = 1; a = 0; t = 'estado de la partida y del brazo' })
        $frags = @(@{ de = 12; hasta = 16; tipo = 0; guardas = @('la pinza detectó pieza agarrada', 'no hay pieza en la pinza'); cortes = @(15) })
        $d = Build-Sequence $repo $pk 'Secuencia: el brazo ejecuta la jugada (Sprint 3)' $part $msgs $frags 175
        Log ("S3 secuencia brazo: " + (Exporta $repo $d 's3_secuencia_brazo'))
    } catch { Log ("ERROR S3 secuencia: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    # ======================= 6. DESPLIEGUE FINAL (reutiliza los elementos del Sprint 2) =======================
    try {
        $pkD = Find-Pkg $repo 'Despliegue'
        $pid2 = $pkD.PackageID
        function Reuse($n, $t) { $x = Find-Elem $repo $n $t $pid2; if (-not $x) { Log ("NO ENCONTRADO: $n ($t)") }; return $x }
        $pk = Add-Pkg $s3 'Despliegue Final'
        $d = Add-Diag $pk 'Despliegue final: servidor doméstico con Docker Compose, acceso por Tailscale Funnel y estación robótica' 'Deployment'
        $dev = Reuse 'Dispositivo del usuario' 'Device'; $a1 = Reuse 'Navegador (React SPA / PWA)' 'Artifact'
        $lab = Reuse 'Servidor home-lab (Tailscale)' 'Node'; $fun = Reuse 'Tailscale Funnel' 'Node'; $a2 = Reuse 'HTTPS → 127.0.0.1:8090' 'Artifact'
        $dc = Reuse 'Docker Compose' 'Node'; $web = Reuse 'Contenedor ajedrez_web' 'Node'
        $a3 = Reuse 'Backend FastAPI + frontend compilado' 'Artifact'; $a4 = Reuse 'Stockfish' 'Artifact'; $a5 = Reuse 'checkpoints (volumen solo lectura)' 'Artifact'
        $db = Reuse 'Contenedor ajedrez_db' 'Node'; $a6 = Reuse 'PostgreSQL (volumen persistente)' 'Artifact'
        $col = Reuse 'Google Colab (GPU)' 'Node'; $a7 = Reuse 'entrenamiento y reentrenamiento' 'Artifact'
        $gq = Reuse 'Servicio de lenguaje (Groq)' 'Node'; $a8 = Reuse 'API chat completions' 'Artifact'
        $cam = Add-Elem $pk 'Dos cámaras del tablero' 'Device'; $b1 = Add-Elem $pk 'MJPG / USB' 'Artifact'; $b1.ParentID = $cam.ElementID; [void]$b1.Update()
        $pc = Add-Elem $pk 'PC de la sala (Mac)' 'Device'
        $b2 = Add-Elem $pk 'Backend local (mismo código)' 'Artifact'; $b2.ParentID = $pc.ElementID; [void]$b2.Update()
        $b3 = Add-Elem $pk 'Simulador PyBullet' 'Artifact'; $b3.ParentID = $pc.ElementID; [void]$b3.Update()
        $br = Add-Elem $pk 'Brazo Dobot CR5AS' 'Device'; $b4 = Add-Elem $pk 'Controlador V4' 'Artifact'; $b4.ParentID = $br.ElementID; [void]$b4.Update()
        $pz = Add-Elem $pk 'Pinza DH PGE-50-26' 'Device'; $b5 = Add-Elem $pk 'Modbus RTU' 'Artifact'; $b5.ParentID = $pz.ElementID; [void]$b5.Update()
        [void](Place $d $cam 20 30 240 120 90); [void](Place $d $b1 35 85 210 45 5)
        [void](Place $d $pc 340 30 340 190 90); [void](Place $d $b2 355 85 310 45 5); [void](Place $d $b3 355 140 310 45 5)
        [void](Place $d $br 790 30 260 120 90); [void](Place $d $b4 805 85 230 45 5)
        [void](Place $d $pz 1140 30 250 120 90); [void](Place $d $b5 1155 85 220 45 5)
        [void](Place $d $dev 20 340 260 120 90); [void](Place $d $a1 35 395 230 50 5)
        [void](Place $d $col 340 300 330 110 90); [void](Place $d $a7 355 350 300 45 5)
        [void](Place $d $lab 340 480 1050 380 90)
        [void](Place $d $fun 370 590 260 170 70); [void](Place $d $a2 390 650 220 60 5)
        [void](Place $d $dc 710 530 650 300 70)
        [void](Place $d $web 730 570 290 250 50); [void](Place $d $a3 745 625 260 45 5); [void](Place $d $a4 745 675 260 45 5); [void](Place $d $a5 745 725 260 45 5)
        [void](Place $d $db 1060 600 240 180 50); [void](Place $d $a6 1075 665 210 60 5)
        [void](Place $d $gq 1090 930 280 120 90); [void](Place $d $a8 1105 985 250 50 5)
        [void](Add-Conn $cam $pc 'Association' 'imágenes'); [void](Add-Conn $pc $br 'Association' 'TCP/IP :29999')
        [void](Add-Conn $br $pz 'Association' 'Modbus vía controlador'); [void](Add-Conn $dev $pc 'Association' 'HTTP local')
        [void]$repo.ReloadDiagram($d.DiagramID)
        Log ("S3 despliegue final: " + (Exporta $repo $d 's3_despliegue_final'))
    } catch { Log ("ERROR S3 despliegue: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }

    $repo.CloseFile(); $repo.Exit()
}
catch { Log ("ERROR general: " + $_.Exception.Message + " | " + $_.ScriptStackTrace) }
finally { $sw.Close() }
