# Vendors the webfonts into the site so no request ever reaches Google.
#
# The marketing site was loading Inter and JetBrains Mono from
# fonts.googleapis.com - the exact two hosts LiteCord's own blocklist drops as
# telemetry. Shipping the files ourselves removes the contradiction and the
# third-party request.
#
# Only the latin and latin-ext subsets are kept. The full css2 response also
# serves cyrillic, greek and vietnamese, which this site never renders.

param([string]$OutDir)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..\public\assets\fonts' }
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# A modern UA is required or Google serves ttf instead of woff2.
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

$families = @(
    'Inter:opsz,wght@14..32,400;14..32,500;14..32,600;14..32,700;14..32,800',
    'JetBrains+Mono:wght@400;500'
)
$keep = @('latin', 'latin-ext')

$css = ''
foreach ($f in $families) {
    $url = "https://fonts.googleapis.com/css2?family=$f&display=swap"
    Write-Host "fetching css: $f"
    $css += (Invoke-WebRequest -Uri $url -Headers @{ 'User-Agent' = $ua } -UseBasicParsing -TimeoutSec 45).Content + "`n"
}

# Split into "/* subset */ @font-face { ... }" chunks.
$blocks = [regex]::Matches($css, '/\*\s*([a-z0-9-]+)\s*\*/\s*(@font-face\s*\{[^}]*\})')
Write-Host "parsed $($blocks.Count) font-face blocks"

# Group by (family, subset). Both families are variable fonts, so Google serves
# the *same* woff2 for every requested weight - downloading one file per weight
# duplicated the payload 5x. One file per family+subset, declared with a weight
# range, covers all of them.
$groups = @{}
foreach ($b in $blocks) {
    $subset = $b.Groups[1].Value
    $face = $b.Groups[2].Value
    if ($keep -notcontains $subset) { continue }

    $family = [regex]::Match($face, "font-family:\s*'([^']+)'").Groups[1].Value
    $weight = [regex]::Match($face, 'font-weight:\s*([^;]+);').Groups[1].Value.Trim()
    $style  = [regex]::Match($face, 'font-style:\s*([^;]+);').Groups[1].Value.Trim()
    $range  = [regex]::Match($face, 'unicode-range:\s*([^;]+);').Groups[1].Value.Trim()
    $src    = [regex]::Match($face, 'url\((https://[^)]+\.woff2)\)').Groups[1].Value
    if (-not $src) { continue }

    $key = "$family|$subset"
    if (-not $groups.ContainsKey($key)) {
        $groups[$key] = [pscustomobject]@{
            family = $family; subset = $subset; style = $style
            range = $range; src = $src; weights = @()
        }
    }
    if ($weights = $weight) { }
    if (-not $groups[$key].weights.Contains($weight)) { $groups[$key].weights += $weight }
}

$out = New-Object System.Text.StringBuilder
$count = 0
$totalBytes = 0

foreach ($g in $groups.Values) {
    $slug = ($g.family -replace '\s+', '') + '-' + $g.subset + '.woff2'
    $dest = Join-Path $OutDir $slug

    if (-not (Test-Path -LiteralPath $dest)) {
        Write-Host "  downloading $slug (weights: $($g.weights -join ','))"
        Invoke-WebRequest -Uri $g.src -OutFile $dest -Headers @{ 'User-Agent' = $ua } -UseBasicParsing -TimeoutSec 45
    }
    $totalBytes += (Get-Item -LiteralPath $dest).Length
    $count++

    # A single file spanning several weights is a variable font: declare the
    # whole span so the browser can interpolate.
    $nums = @($g.weights | ForEach-Object { [int]$_ } | Sort-Object)
    $wDecl = if ($nums.Count -gt 1) { "$($nums[0]) $($nums[-1])" } else { $nums[0] }

    [void]$out.AppendLine("@font-face{")
    [void]$out.AppendLine("  font-family:'$($g.family)';")
    [void]$out.AppendLine("  font-style:$($g.style);")
    [void]$out.AppendLine("  font-weight:$wDecl;")
    [void]$out.AppendLine("  font-display:swap;")
    [void]$out.AppendLine("  src:url('/assets/fonts/$slug') format('woff2');")
    if ($g.range) { [void]$out.AppendLine("  unicode-range:$($g.range);") }
    [void]$out.AppendLine("}")
    [void]$out.AppendLine()
}

$cssPath = Join-Path $OutDir 'fonts.css'
Set-Content -LiteralPath $cssPath -Value $out.ToString() -Encoding UTF8

$written = @(Get-ChildItem -LiteralPath $OutDir -Filter *.woff2)
$sum = ($written | Measure-Object -Property Length -Sum).Sum
Write-Host ""
Write-Host ("wrote {0} woff2 files, {1:N0} KB" -f $written.Count, ($sum / 1KB))
Write-Host "css: $cssPath ($count faces)"
