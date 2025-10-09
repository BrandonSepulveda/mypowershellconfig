<#
.SYNOPSIS
    Script para configurar automáticamente un entorno de desarrollo en PowerShell.
    Instala herramientas, configura oh-my-posh, fastfetch y Windows Terminal.
#>

# --- INICIO: CONFIGURACIÓN DEL SCRIPT ---
Clear-Host
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host "    INICIANDO CONFIGURACIÓN AUTOMÁTICA DEL ENTORNO    " -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host

# URL base de tu repositorio de GitHub (CORREGIDA A LA VERSIÓN RAW)
$repoUrl = "https://raw.githubusercontent.com/BrandonSepulveda/mypowershellconfig/main/config-files"

# --- PASO 1: Establecer política de ejecución y verificar Winget ---
Write-Host "[Paso 1/5] Preparando el sistema..." -ForegroundColor Cyan
Set-ExecutionPolicy Bypass -Scope Process -Force
try {
    Get-Command winget | Out-Null
    Write-Host "  -> Winget encontrado." -ForegroundColor Green
} catch {
    Write-Host "  -> Winget no encontrado. Por favor, instálalo desde la Microsoft Store." -ForegroundColor Red
    exit
}

Write-Host "[Paso 2/5] Instalando herramientas necesarias..." -ForegroundColor Cyan

# Esta línea es clave para evitar que la instalación de fuentes falle
Write-Host "  -> Actualizando fuentes de Winget..."
winget source update

$packages = @(
    @{ Name = "Oh My Posh"; Id = "JanDeDobbeleer.OhMyPosh" },
    @{ Name = "Fastfetch"; Id = "fastfetch-cli.fastfetch" },
    @{ Name = "JetBrainsMono Nerd Font"; Id = "JetBrains.JetBrainsMono.NerdFont" }
)

foreach ($pkg in $packages) {
    Write-Host "  -> Instalando $($pkg.Name)..."
    winget install --id $pkg.Id --source winget --accept-package-agreements --accept-source-agreements
}

# --- PASO 3: Configurar el perfil de PowerShell 7 ---
Write-Host "[Paso 3/5] Configurando el perfil de PowerShell 7..." -ForegroundColor Cyan

# Descargar el tema de Oh My Posh, que es una dependencia del perfil
Write-Host "  -> Descargando tema de Oh My Posh..."
$themeUrl = "$repoUrl/toolbox-theme.omp.json" # Asumiendo que el tema está en tu repo
$themePath = Join-Path -Path $HOME -ChildPath "toolbox-theme.omp.json"
Invoke-WebRequest -Uri $themeUrl -OutFile $themePath

# Configurar el archivo profile.ps1
$profilePath = $PROFILE
$profileUrl = "$repoUrl/profile.ps1"

if (Test-Path $profilePath) {
    Write-Host "  -> Perfil existente encontrado. Creando copia de seguridad en $profilePath.bak" -ForegroundColor Yellow
    Move-Item -Path $profilePath -Destination "$profilePath.bak" -Force
}

Write-Host "  -> Descargando perfil desde GitHub..."
Invoke-WebRequest -Uri $profileUrl -OutFile $profilePath
Write-Host "  -> Perfil de PowerShell 7 configurado." -ForegroundColor Green

# --- PASO 4: Configurar Fastfetch ---
Write-Host "[Paso 4/5] Configurando Fastfetch..." -ForegroundColor Cyan
$configDir = Join-Path -Path $HOME -ChildPath ".config"
$fastfetchDir = Join-Path -Path $configDir -ChildPath "fastfetch"

New-Item -Path $configDir -ItemType Directory -Force | Out-Null
# Ocultar la carpeta .config
(Get-Item -Path $configDir).Attributes += 'Hidden'
New-Item -Path $fastfetchDir -ItemType Directory -Force | Out-Null

Write-Host "  -> Descargando archivos de configuración para Fastfetch..."
Invoke-WebRequest -Uri "$repoUrl/fastfetch/ascii.txt" -OutFile (Join-Path $fastfetchDir "ascii.txt")
Invoke-WebRequest -Uri "$repoUrl/fastfetch/config.jsonc" -OutFile (Join-Path $fastfetchDir "config.jsonc")
Write-Host "  -> Fastfetch configurado." -ForegroundColor Green

# --- PASO 5: Configurar Windows Terminal ---
Write-Host "[Paso 5/5] Configurando Windows Terminal..." -ForegroundColor Cyan
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtSettingsUrl = "$repoUrl/settings.json"

if (Test-Path $wtSettingsPath) {
    Write-Host "  -> Configuración de Terminal encontrada. Creando copia de seguridad." -ForegroundColor Yellow
    Move-Item -Path $wtSettingsPath -Destination "$wtSettingsPath.bak" -Force
}

Write-Host "  -> Descargando configuración de Windows Terminal desde GitHub..."
Invoke-WebRequest -Uri $wtSettingsUrl -OutFile $wtSettingsPath
Write-Host "  -> Windows Terminal configurado." -ForegroundColor Green

# --- FINALIZACIÓN ---
Write-Host
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "          ¡CONFIGURACIÓN COMPLETADA CON ÉXITO!         " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "Por favor, CIERRA y VUELVE A ABRIR la terminal para ver todos los cambios." -ForegroundColor White

