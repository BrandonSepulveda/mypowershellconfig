<#
.SYNOPSIS
    Script para configurar automáticamente un entorno de desarrollo en PowerShell.
#>

# --- INICIO: CONFIGURACIÓN DEL SCRIPT ---
Clear-Host
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host "    INICIANDO CONFIGURACIÓN AUTOMÁTICA DEL ENTORNO    " -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host

$repoUrl = "https://raw.githubusercontent.com/BrandonSepulveda/mypowershellconfig/main/config-files"

# --- PASO 1: Preparando el sistema ---
Write-Host "[Paso 1/4] Preparando el sistema..." -ForegroundColor Cyan
Set-ExecutionPolicy Bypass -Scope Process -Force
try {
    winget --version | Out-Null
    Write-Host "  -> Winget encontrado." -ForegroundColor Green
} catch {
    Write-Host "  -> Winget no encontrado. Por favor, instálalo desde la Microsoft Store." -ForegroundColor Red; exit
}

# --- PASO 2: Instalando herramientas y fuentes ---
Write-Host "[Paso 2/4] Instalando herramientas y fuentes..." -ForegroundColor Cyan
winget source update
$packages = @(
    @{ Name = "Oh My Posh"; Id = "JanDeDobbeleer.OhMyPosh" },
    @{ Name = "Fastfetch"; Id = "fastfetch-cli.fastfetch" }
)
foreach ($pkg in $packages) {
    Write-Host "  -> Instalando $($pkg.Name)..."
    winget install --id $pkg.Id --source winget --accept-package-agreements --accept-source-agreements
}

Write-Host "  -> Instalando JetBrainsMono Nerd Font (Método Avanzado)..."
$fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"
$tempDir = Join-Path -Path $env:TEMP -ChildPath "JetBrainsMonoNerdFont"
$fontZipPath = Join-Path -Path $tempDir -ChildPath "JetBrainsMonoNerd.zip"

try {
    if (-not (Test-Path -Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory | Out-Null }
    Invoke-WebRequest -Uri $fontZipUrl -OutFile $fontZipPath
    Expand-Archive -Path $fontZipPath -DestinationPath $tempDir -Force
    $fontFiles = Get-ChildItem -Path $tempDir -Filter "*.ttf" -Recurse
    
    if ($fontFiles) {
        Write-Host "    -> Registrando $($fontFiles.Count) archivos de fuente..."
        # --- MÉTODO DE INSTALACIÓN DE FUENTES MEJORADO ---
        $shell = New-Object -ComObject Shell.Application
        $fontsFolder = $shell.Namespace(0x14) # Carpeta especial de Fuentes de Windows
        foreach ($fontFile in $fontFiles) {
            $fontsFolder.CopyHere($fontFile.FullName, 0x10) # 0x10 para no mostrar diálogo de progreso
        }
        Write-Host "  -> Fuentes de JetBrainsMono Nerd Font registradas." -ForegroundColor Green
    } else {
        Write-Host "  -> No se encontraron archivos .ttf en el ZIP descargado." -ForegroundColor Red
    }
} catch {
    Write-Host "  -> Ocurrió un error al instalar las fuentes: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path -Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
}

# --- PASO 3: Configurar el perfil de PowerShell 7 ---
Write-Host "[Paso 3/4] Configurando el perfil de PowerShell 7..." -ForegroundColor Cyan
$profileUrl = "$repoUrl/profile.ps1"
if (Test-Path $PROFILE) { Move-Item -Path $PROFILE -Destination "$PROFILE.bak" -Force }
Invoke-WebRequest -Uri $profileUrl -OutFile $PROFILE
Write-Host "  -> Perfil de PowerShell 7 configurado." -ForegroundColor Green

# --- PASO 4: Configurar Fastfetch y Windows Terminal ---
Write-Host "[Paso 4/4] Configurando Fastfetch y Windows Terminal..." -ForegroundColor Cyan
$configDir = Join-Path -Path $HOME -ChildPath ".config"
$fastfetchDir = Join-Path -Path $configDir -ChildPath "fastfetch"
New-Item -Path $configDir -ItemType Directory -Force | Out-Null
# --- LÍNEA PROBLEMÁTICA ELIMINADA PARA SIMPLIFICAR ---
New-Item -Path $fastfetchDir -ItemType Directory -Force | Out-Null
Invoke-WebRequest -Uri "$repoUrl/fastfetch/ascii.txt" -OutFile (Join-Path $fastfetchDir "ascii.txt")
Invoke-WebRequest -Uri "$repoUrl/fastfetch/config.jsonc" -OutFile (Join-Path $fastfetchDir "config.jsonc")
Write-Host "  -> Fastfetch configurado." -ForegroundColor Green

$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtSettingsUrl = "$repoUrl/settings.json"
if (Test-Path $wtSettingsPath) { Move-Item -Path $wtSettingsPath -Destination "$wtSettingsPath.bak" -Force }
Invoke-WebRequest -Uri $wtSettingsUrl -OutFile $wtSettingsPath
Write-Host "  -> Windows Terminal configurado." -ForegroundColor Green

# --- FINALIZACIÓN ---
Write-Host
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "          ¡CONFIGURACIÓN COMPLETADA CON ÉXITO!         " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "Por favor, CIERRA y VUELVE A ABRIR la terminal para ver todos los cambios." -ForegroundColor White
Write-Host "Para que las fuentes se apliquen correctamente, REINICIA TU COMPUTADORA." -ForegroundColor Yellow
