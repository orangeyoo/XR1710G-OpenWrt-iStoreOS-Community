param(
    [string]$ContainerName = 'xr1710g-hostapd-wds-build',
    [string]$WorkVolume = 'xr1710g-istoreos-final',
    [string]$Image = 'xr1710g-istoreos-build-env:20260728'
)

$ErrorActionPreference = 'Stop'
$builder = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

docker info *> $null
$existing = docker ps -a --filter "name=^/$ContainerName$" --format '{{.Names}}'
if ($existing -eq $ContainerName) {
    docker rm -f $ContainerName | Out-Null
}

docker run --name $ContainerName `
    --mount "type=bind,source=$builder,target=/builder,readonly" `
    --mount "type=volume,source=$WorkVolume,target=/work" `
    $Image `
    bash /builder/scripts/build-hostapd-wds-package.sh

if ($LASTEXITCODE -ne 0) {
    throw "Hostapd WDS package build failed with exit code $LASTEXITCODE"
}

$workspace = Split-Path $builder -Parent
$out = Join-Path $workspace 'output\hostapd-wds-baseline'
New-Item -ItemType Directory -Force $out | Out-Null
$outMount = $out -replace '\\', '/'
docker run --rm `
    --mount "type=volume,source=$WorkVolume,target=/work,readonly" `
    --mount "type=bind,source=$outMount,target=/export" `
    $Image `
    bash -c 'cp -a /work/hostapd-wds-baseline/. /export/'
if ($LASTEXITCODE -ne 0) {
    throw "Unable to copy hostapd WDS packages from the build volume"
}
Write-Host "Hostapd WDS packages copied to $out"
