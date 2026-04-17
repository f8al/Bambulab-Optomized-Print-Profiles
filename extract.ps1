param(
    [Parameter(Mandatory=$true)]
    [string]$PrinterType,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    
    [string]$SourceDir = "."
)

$SourceDir = Resolve-Path $SourceDir
$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Build pattern and exclusion lists based on printer type
function Get-PrinterPatterns {
    param([string]$Printer)
    
    $p = $Printer.ToUpper()
    
    switch ($p) {
        "A1" {
            return @{
                Patterns = @("A1")
                Exclusions = @("A1M", "A1_mini", "A1 mini")
            }
        }
        "A1M" {
            return @{
                Patterns = @("A1M", "A1_mini", "A1 mini", "A1_M")
                Exclusions = @()
            }
        }
        "P1P" {
            return @{
                Patterns = @("P1P")
                Exclusions = @()
            }
        }
        "P1S" {
            return @{
                Patterns = @("P1S")
                Exclusions = @()
            }
        }
        "X1" {
            return @{
                Patterns = @("X1")
                Exclusions = @("X1C", "X1E", "X1_Carbon", "X1 Carbon")
            }
        }
        "X1C" {
            return @{
                Patterns = @("X1C", "X1_Carbon", "X1 Carbon", "X1_carbon")
                Exclusions = @()
            }
        }
        "X1E" {
            return @{
                Patterns = @("X1E")
                Exclusions = @()
            }
        }
        "X1-ALL" {
            return @{
                Patterns = @("X1")
                Exclusions = @()
            }
        }
        "P2S" {
            return @{
                Patterns = @("P2S")
                Exclusions = @()
            }
        }
        "H2C" {
            return @{
                Patterns = @("H2C")
                Exclusions = @()
            }
        }
        "H2D" {
            return @{
                Patterns = @("H2D")
                Exclusions = @()
            }
        }
        "H2S" {
            return @{
                Patterns = @("H2S")
                Exclusions = @()
            }
        }
        default {
            Write-Error "Unknown printer type: $Printer"
            Write-Error "Valid: A1, A1M, P1P, P1S, X1, X1C, X1E, X1-ALL, P2S, H2C, H2D, H2S"
            exit 1
        }
    }
}

function Test-MatchesPrinter {
    param(
        [string]$Str,
        [hashtable]$Config
    )
    
    $strLower = $Str.ToLower()
    
    foreach ($pat in $Config.Patterns) {
        if ($strLower -like "*$($pat.ToLower())*") {
            $excluded = $false
            foreach ($excl in $Config.Exclusions) {
                if ($strLower -like "*$($excl.ToLower())*") {
                    $excluded = $true
                    break
                }
            }
            if (-not $excluded) {
                return $true
            }
        }
    }
    return $false
}

function Get-NozzleSize {
    param([string]$Str)
    
    if ($Str -match '(0\.[0-9])') {
        return $matches[1]
    }
    return "unspecified"
}

function Get-Sanitized {
    param([string]$Str)
    
    $s = $Str -replace ' ', '_'
    $s = $s -replace '[/\\+]', '_'
    $s = $s -replace '_+', '_'
    $s = $s.Trim('_')
    return $s
}

function Remove-PrinterNoise {
    param(
        [string]$Str,
        [hashtable]$Config
    )
    
    $s = $Str
    # Remove printer pattern references
    foreach ($pat in $Config.Patterns) {
        $s = $s -ireplace [regex]::Escape($pat), ''
    }
    # Remove common printer/slicer noise
    $noisePatterns = @(
        '@Bambu Lab',
        '@BBL',
        'Bambu Lab',
        '0\.4 nozzle',
        '0\.6 nozzle',
        '0\.2 nozzle',
        '0\.8 nozzle',
        ' nozzle',
        'nozzle'
    )
    foreach ($noise in $noisePatterns) {
        $s = $s -ireplace $noise, ''
    }
    $s = Get-Sanitized $s
    return $s
}

$PrinterConfig = Get-PrinterPatterns -Printer $PrinterType

# Known printer tags used to identify files that belong to a specific printer
# Used in pass 3 to skip files that are printer-specific but not our target
$KnownPrinterTags = @(
    'A1M', 'A1_mini', 'A1 mini',
    'A1',
    'P1P', 'P1S', 'P2S',
    'X1C', 'X1_Carbon', 'X1 Carbon', 'X1E', 'X1',
    'H2C', 'H2D', 'H2S',
    'Bambu', 'BBL', 'Qidi'
)

# ============================================================
Write-Host ""
Write-Host "=== PASS 1: Hierarchical profiles (preset_filament.json) ===" -ForegroundColor Cyan

Get-ChildItem -Path $SourceDir -Recurse -Filter "preset_filament.json" | ForEach-Object {
    $filepath = $_.FullName
    
    # Skip output dir
    if ($filepath.StartsWith($OutputDir)) { return }
    
    # Get path relative to source, split into parts
    $rel = $filepath.Substring($SourceDir.ToString().Length).TrimStart('\','/')
    $parts = $rel -split '[/\\]'
    
    # Need at least BRAND/MATERIAL/PRINTER/NOZZLE/filename
    if ($parts.Count -lt 5) { return }
    
    $brand     = $parts[0]
    $material  = $parts[1]
    $printer   = $parts[2]
    $nozzle    = $parts[3]
    
    if (-not (Test-MatchesPrinter -Str $printer -Config $PrinterConfig)) { return }
    
    $outname = "$(Get-Sanitized $brand)_$(Get-Sanitized $material)_$(Get-Sanitized $printer)_$(Get-Sanitized $nozzle).json"
    $dest = Join-Path $OutputDir $outname
    
    Copy-Item -Path $filepath -Destination $dest -Force
    Write-Host "Copied: $outname"
}

# ============================================================
Write-Host ""
Write-Host "=== PASS 2: Flat profiles with printer in filename ===" -ForegroundColor Cyan

Get-ChildItem -Path $SourceDir -Recurse -Filter "*.json" | Where-Object {
    # Only files exactly 2 levels deep (brand dir -> file)
    $rel = $_.FullName.Substring($SourceDir.ToString().Length).TrimStart('\','/')
    ($rel -split '[/\\]').Count -eq 2
} | ForEach-Object {
    $filepath = $_.FullName
    if ($filepath.StartsWith($OutputDir)) { return }
    
    $filename  = $_.Name
    $brandDir  = $_.Directory.Name
    
    if ($filename -eq "preset_filament.json") { return }
    if ($filename -like "*bundle_structure*") { return }
    
    if (-not (Test-MatchesPrinter -Str $filename -Config $PrinterConfig)) { return }
    
    $nozzle   = Get-NozzleSize -Str $filename
    $brand_s  = Get-Sanitized $brandDir
    $material = Remove-PrinterNoise -Str ($filename -replace '\.json$', '') -Config $PrinterConfig
    
    $outname = "${brand_s}_${material}_${PrinterType}_${nozzle}.json"
    $dest = Join-Path $OutputDir $outname
    
    Copy-Item -Path $filepath -Destination $dest -Force
    Write-Host "Copied: $outname"
}

# ============================================================
Write-Host ""
Write-Host "=== PASS 3: Generic/base profiles (no printer tag in filename) ===" -ForegroundColor Cyan

Get-ChildItem -Path $SourceDir -Recurse -Filter "*.json" | Where-Object {
    $rel = $_.FullName.Substring($SourceDir.ToString().Length).TrimStart('\','/')
    ($rel -split '[/\\]').Count -eq 2
} | ForEach-Object {
    $filepath = $_.FullName
    if ($filepath.StartsWith($OutputDir)) { return }
    
    $filename = $_.Name
    $brandDir = $_.Directory.Name
    
    if ($filename -eq "preset_filament.json") { return }
    if ($filename -like "*bundle_structure*") { return }
    
    # Skip if it mentions any known printer tag
    $hasPrinterTag = $false
    foreach ($tag in $KnownPrinterTags) {
        if ($filename -imatch [regex]::Escape($tag)) {
            $hasPrinterTag = $true
            break
        }
    }
    if ($hasPrinterTag) { return }
    
    $brand_s  = Get-Sanitized $brandDir
    $material = Get-Sanitized ($filename -replace '\.json$', '')
    
    $outname = "${brand_s}_${material}_${PrinterType}_generic.json"
    $dest = Join-Path $OutputDir $outname
    
    Copy-Item -Path $filepath -Destination $dest -Force
    Write-Host "Copied: $outname"
}

Write-Host ""
$count = (Get-ChildItem -Path $OutputDir -Filter "*.json").Count
Write-Host "Done. $count files in $OutputDir" -ForegroundColor Green
