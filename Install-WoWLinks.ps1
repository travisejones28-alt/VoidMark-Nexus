# Link the flattened repository root directly into the WoW Forever AddOns folder.
# Existing files and SavedVariables are never deleted by this installer.
$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$oldSource = Join-Path $source 'VoidMarkNexus'
if (-not (Test-Path -LiteralPath (Join-Path $source 'VoidMarkNexus.toc') -PathType Leaf)) {
    throw 'VoidMarkNexus.toc is missing from the repository root. Pull the latest GitHub changes.'
}
$addons = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
if (-not (Test-Path -LiteralPath $addons -PathType Container)) {
    throw "WoW Forever AddOns folder not found: $addons"
}
$dest = Join-Path $addons 'VoidMarkNexus'
$existing = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
function EqualsPath($a, $b) {
    if (-not $a -or -not $b) { return $false }
    return [IO.Path]::GetFullPath([string]$a).TrimEnd('\') -ieq [IO.Path]::GetFullPath([string]$b).TrimEnd('\')
}
if ($existing) {
    if ($existing.LinkType -ne 'Junction') {
        throw "Existing $dest is not a junction. Leave it intact and inspect it manually."
    }
    if (EqualsPath $existing.Target $source) {
        Write-Host "Already installed correctly: $dest -> $source"
        exit 0
    }
    if (-not (EqualsPath $existing.Target $oldSource)) {
        throw "Existing $dest points to an unrelated folder. No changes made."
    }
    # Remove only this verified obsolete junction, never its source files.
    [IO.Directory]::Delete($dest)
}
New-Item -ItemType Junction -Path $dest -Target $source | Out-Null
Write-Host "SUCCESS: $dest -> $source"
