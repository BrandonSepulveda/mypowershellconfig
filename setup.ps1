<#
.SYNOPSIS
    Script para configurar automáticamente un entorno de desarrollo en PowerShell.
    Versión 2.0 - Mejorada (TLS, reintentos, backups con timestamp, fuente dinámica, idempotencia).
.PARAMETER SkipFonts
    Omite la instalación de la fuente Nerd Font.
.PARAMETER SkipTerminalSettings
    Omite la sobreescritura de settings.json de Windows Terminal (recomendado si ya tienes personalizaciones).
.PARAMETER SkipProfile
    Omite la actualización del perfil de PowerShell.
#>

[CmdletBinding()]
param(
    [switch]$SkipFonts,
    [switch]$SkipTerminalSettings,
    [switch]$SkipProfile
)

# --- INICIO: CONFIGURACIÓN DEL SCRIPT ---
Clear-Host
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host "    INICIANDO CONFIGURACIÓN AUTOMÁTICA DEL ENTORNO    " -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host

# Forzar TLS 1.2 - crítico en PowerShell 5.1, evita fallos silenciosos de Invoke-WebRequest contra GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repoUrl   = "https://raw.githubusercontent.com/BrandonSepulveda/mypowershellconfig/main/config-files"
$isAdmin   = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# --- Helper: descarga con reintentos ---
function Invoke-WebRequestWithRetry {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2
    )
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            return $true
        } catch {
            Write-Host "    -> Intento $i/$MaxRetries falló para $Uri : $($_.Exception.Message)" -ForegroundColor DarkYellow
            if ($i -lt $MaxRetries) { Start-Sleep -Seconds $DelaySeconds }
        }
    }
    Write-Host "  -> ERROR: No se pudo descargar $Uri tras $MaxRetries intentos." -ForegroundColor Red
    return $false
}

# --- Helper: backup con timestamp (nunca sobrescribe backups anteriores) ---
function Backup-ExistingFile {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -Path $Path) {
        $backupPath = "$Path.bak_$timestamp"
        Move-Item -Path $Path -Destination $backupPath -Force
        Write-Host "  -> Backup creado: $backupPath" -ForegroundColor DarkGray
    }
}

if (-not $isAdmin) {
    Write-Host "  -> Aviso: no estás corriendo como Administrador. La instalación de fuentes y algunos paquetes de winget pueden fallar." -ForegroundColor Yellow
}

# --- PASO 1: Preparando el sistema ---
Write-Host "[Paso 1/4] Preparando el sistema..." -ForegroundColor Cyan
Set-ExecutionPolicy Bypass -Scope Process -Force

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  -> Winget no encontrado. Por favor, instálalo desde la Microsoft Store (App Installer)." -ForegroundColor Red
    exit 1
}
Write-Host "  -> Winget encontrado ($(winget --version))." -ForegroundColor Green

# --- PASO 2: Instalando herramientas y fuentes ---
Write-Host "[Paso 2/4] Instalando herramientas..." -ForegroundColor Cyan
winget source update | Out-Null

$packages = @(
    @{ Name = "Oh My Posh"; Id = "JanDeDobbeleer.OhMyPosh" },
    @{ Name = "Fastfetch";  Id = "fastfetch-cli.fastfetch" }
)

foreach ($pkg in $packages) {
    $installed = winget list --id $pkg.Id --accept-source-agreements 2>$null | Select-String -Pattern $pkg.Id
    if ($installed) {
        Write-Host "  -> $($pkg.Name) ya está instalado. Omitiendo." -ForegroundColor Green
    } else {
        Write-Host "  -> Instalando $($pkg.Name)..."
        winget install --id $pkg.Id --source winget --accept-package-agreements --accept-source-agreements
    }
}

if (-not $SkipFonts) {
    Write-Host "  -> Verificando si JetBrainsMono Nerd Font ya está instalada..."
    Add-Type -AssemblyName System.Drawing
    $installedFonts = New-Object System.Drawing.Text.InstalledFontCollection
    $fontAlreadyInstalled = $installedFonts.Families.Name -like "*JetBrainsMono*" | Where-Object { $_ }

    if (-not $fontAlreadyInstalled) {
        Write-Host "  -> La fuente no está instalada. Buscando la última versión disponible..."
        $tempDir     = Join-Path -Path $env:TEMP -ChildPath "JetBrainsMonoNerdFont"
        $fontZipPath = Join-Path -Path $tempDir -ChildPath "JetBrainsMonoNerd.zip"
        try {
            if (-not (Test-Path -Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory | Out-Null }

            # Resuelve dinámicamente la última versión del release en vez de una fija (v3.2.1 quedaba obsoleta)
            $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" -UseBasicParsing
            $fontZipUrl = ($latestRelease.assets | Where-Object { $_.name -eq "JetBrainsMono.zip" }).browser_download_url
            if (-not $fontZipUrl) { throw "No se encontró JetBrainsMono.zip en el último release ($($latestRelease.tag_name))." }

            Write-Host "    -> Descargando release $($latestRelease.tag_name)..."
            if (Invoke-WebRequestWithRetry -Uri $fontZipUrl -OutFile $fontZipPath) {
                Expand-Archive -Path $fontZipPath -DestinationPath $tempDir -Force
                $fontFiles = Get-ChildItem -Path $tempDir -Filter "*.ttf" -Recurse
                if ($fontFiles) {
                    Write-Host "    -> Instalando $($fontFiles.Count) archivos de fuente (sin ventanas emergentes)..."

                    # Instalación silenciosa por usuario (sin admin, sin el cuadro de copiado de Shell.Application):
                    # 1) Copiamos el .ttf directo a la carpeta de fuentes del usuario
                    # 2) Registramos el nombre real de la fuente (leído del propio archivo) en el registro
                    # 3) Avisamos a Windows con WM_FONTCHANGE para que las apps abiertas la vean sin reiniciar sesión
                    $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
                    if (-not (Test-Path -Path $userFontsDir)) { New-Item -Path $userFontsDir -ItemType Directory -Force | Out-Null }
                    $fontsRegPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

                    if (-not ([System.Management.Automation.PSTypeName]'Win32Font.NativeMethods').Type) {
                        Add-Type -Namespace Win32Font -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern int SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
                    }

                    $installedCount = 0
                    foreach ($fontFile in $fontFiles) {
                        try {
                            $destPath = Join-Path $userFontsDir $fontFile.Name
                            Copy-Item -Path $fontFile.FullName -Destination $destPath -Force

                            # Leemos el nombre REAL de la fuente desde el archivo (más confiable que adivinarlo del nombre del archivo)
                            $privateFonts = New-Object System.Drawing.Text.PrivateFontCollection
                            $privateFonts.AddFontFile($destPath)
                            $fontDisplayName = $privateFonts.Families[0].Name
                            $privateFonts.Dispose()

                            Set-ItemProperty -Path $fontsRegPath -Name "$fontDisplayName (TrueType)" -Value $fontFile.Name -Type String -Force
                            $installedCount++
                        } catch {
                            Write-Host "    -> No se pudo instalar $($fontFile.Name): $($_.Exception.Message)" -ForegroundColor DarkYellow
                        }
                    }

                    # Broadcast WM_FONTCHANGE para que Windows Terminal y demás apps abiertas la reconozcan ya mismo
                    [UIntPtr]$wmResult = [UIntPtr]::Zero
                    [Win32Font.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x1D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$wmResult) | Out-Null

                    Write-Host "  -> $installedCount fuentes de JetBrainsMono Nerd Font instaladas (sin ventanas emergentes)." -ForegroundColor Green
                } else {
                    Write-Host "  -> No se encontraron archivos .ttf en el ZIP descargado." -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "  -> Ocurrió un error al instalar las fuentes: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            if (Test-Path -Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
        }
    } else {
        Write-Host "  -> Fuentes JetBrainsMono Nerd Font ya están instaladas. Omitiendo." -ForegroundColor Green
    }
} else {
    Write-Host "  -> Instalación de fuentes omitida (-SkipFonts)." -ForegroundColor DarkGray
}

# --- PASO 3: Configurar el perfil de PowerShell ---
if (-not $SkipProfile) {
    Write-Host "[Paso 3/4] Configurando el perfil de PowerShell..." -ForegroundColor Cyan
    $profileUrl = "$repoUrl/profile.ps1"
    $profileDir = Split-Path -Path $PROFILE -Parent

    if (-not (Test-Path -Path $profileDir)) {
        Write-Host "  -> Creando directorio para el perfil de PowerShell: $profileDir"
        New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
    }

    Backup-ExistingFile -Path $PROFILE
    if (Invoke-WebRequestWithRetry -Uri $profileUrl -OutFile $PROFILE) {
        Write-Host "  -> Perfil de PowerShell configurado." -ForegroundColor Green
    }
} else {
    Write-Host "[Paso 3/4] Configuración de perfil omitida (-SkipProfile)." -ForegroundColor DarkGray
}

# --- PASO 4: Configurar Fastfetch y Windows Terminal ---
Write-Host "[Paso 4/4] Configurando Fastfetch y Windows Terminal..." -ForegroundColor Cyan
$configDir     = Join-Path -Path $HOME -ChildPath ".config"
$fastfetchDir  = Join-Path -Path $configDir -ChildPath "fastfetch"
New-Item -Path $configDir -ItemType Directory -Force | Out-Null
New-Item -Path $fastfetchDir -ItemType Directory -Force | Out-Null

$ffOk1 = Invoke-WebRequestWithRetry -Uri "$repoUrl/fastfetch/ascii.txt" -OutFile (Join-Path $fastfetchDir "ascii.txt")
$ffOk2 = Invoke-WebRequestWithRetry -Uri "$repoUrl/fastfetch/config.jsonc" -OutFile (Join-Path $fastfetchDir "config.jsonc")
if ($ffOk1 -and $ffOk2) { Write-Host "  -> Fastfetch configurado." -ForegroundColor Green }

if (-not $SkipTerminalSettings) {
    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $wtSettingsUrl  = "$repoUrl/settings.json"
    if (Test-Path $wtSettingsPath) {
        Backup-ExistingFile -Path $wtSettingsPath
    }
    if (Invoke-WebRequestWithRetry -Uri $wtSettingsUrl -OutFile $wtSettingsPath) {
        Write-Host "  -> Windows Terminal configurado." -ForegroundColor Green
    }
} else {
    Write-Host "  -> Configuración de Windows Terminal omitida (-SkipTerminalSettings)." -ForegroundColor DarkGray
}

# --- FINALIZACIÓN ---
Write-Host
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "         ¡CONFIGURACIÓN COMPLETADA CON ÉXITO!         " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "Por favor, CIERRA y VUELVE A ABRIR la terminal para ver todos los cambios." -ForegroundColor White
Write-Host "Para que las fuentes se apliquen correctamente, es posible que necesites REINICIAR TU COMPUTADORA." -ForegroundColor Yellow
