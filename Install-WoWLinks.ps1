# Run in Windows PowerShell. Requires permission to create junctions in WoW's installation directory.
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'VoidMarkNexus'
if (-not (Test-Path -LiteralPath (Join-Path $source 'VoidMarkNexus.toc') -PathType Leaf)) {
    throw "Cannot find VoidMarkNexus.toc under $source. Run this script from the repository root."
}
$installs = @(
    'C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns',
    'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
)
foreach ($addons in $installs) {
    if (-not (Test-Path -LiteralPath $addons -PathType Container)) {
        Write-Warning "WoW installation not present: $addons"
        continue
    }
    $dest = Join-Path $addons 'VoidMarkNexus'
    $existing = Get-ChildItem -LiteralPath $addons -Force | Where-Object { $_.Name -eq 'VoidMarkNexus' } | Select-Object -First 1
    if ($existing) {
        if ($existing.LinkType -ne 'Junction') {
            Write-Warning "Skipping existing non-junction path (no files removed): $dest"
            continue
        }
        if ($existing.Target -eq $source -or (@($existing.Target) -contains $source)) {
            Write-Host "Already linked correctly: $dest"
            continue
        }
        # Remove only the junction itself, never the source folder.
        Remove-Item -LiteralPath $dest -Force
    }
    New-Item -ItemType Junction -Path $dest -Target $source | Out-Null
    Write-Host "Linked: $dest -> $source"
}
