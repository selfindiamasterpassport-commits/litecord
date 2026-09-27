# Undoes N levels of mojibake in an HTML file.
#
# How it happened: a PowerShell 5.1 `Get-Content -Raw` -> `Set-Content -Encoding
# UTF8` round trip. Without a BOM, Get-Content reads as Windows-1252, so an
# em-dash's bytes (E2 80 94) were read as three characters, then written back
# as UTF-8. The browser decoded the result correctly and displayed the mojibake.
#
# The reversal is: read the file as UTF-8 to recover the mangled string, then
# encode that string back to Windows-1252 - those bytes are the original UTF-8.
#
# ASCII passes through every step unchanged, so iterating is safe. The loop
# stops as soon as the text is clean, because one reversal too many would start
# eating genuinely-correct non-ASCII characters.

param(
    [Parameter(Mandatory)][string]$Path,
    [int]$MaxPasses = 4
)

$ErrorActionPreference = 'Stop'
$cp1252 = [System.Text.Encoding]::GetEncoding(1252)

function Get-State([byte[]]$b) {
    $t = [System.Text.Encoding]::UTF8.GetString($b)
    $mojibake = ([regex]::Matches($t, [string][char]0x00C3 + [string][char]0x00A2)).Count +
                ([regex]::Matches($t, [string][char]0x00E2 + [string][char]0x20AC)).Count +
                ([regex]::Matches($t, [string][char]0x00C3 + [string][char]0x201A)).Count
    [pscustomobject]@{
        text  = $t
        emdash = ([regex]::Matches($t, [char]0x2014)).Count
        middot = ([regex]::Matches($t, [char]0x00B7)).Count
        arrow  = ([regex]::Matches($t, [char]0x2192)).Count
        rsquo  = ([regex]::Matches($t, [char]0x2019)).Count
        times  = ([regex]::Matches($t, [char]0x00D7)).Count
        mojibake = $mojibake
    }
}

$bytes = [System.IO.File]::ReadAllBytes($Path)
$st = Get-State $bytes
Write-Host ("pass 0: emdash={0} mojibake={1} size={2}" -f $st.emdash, $st.mojibake, $bytes.Length)

for ($pass = 1; $pass -le $MaxPasses; $pass++) {
    if ($st.mojibake -eq 0) { Write-Host "already clean"; break }

    $bytes = $cp1252.GetBytes($st.text)
    $st = Get-State $bytes
    Write-Host ("pass {0}: emdash={1} mojibake={2} size={3}" -f $pass, $st.emdash, $st.mojibake, $bytes.Length)
}

if ($st.mojibake -ne 0) { throw "still $st.mojibake mojibake sequences after $MaxPasses passes" }

[System.IO.File]::WriteAllBytes($Path, $bytes)
Write-Host ""
Write-Host "written $Path"
Write-Host ("  em-dash U+2014 : {0}" -f $st.emdash)
Write-Host ("  middot  U+00B7 : {0}" -f $st.middot)
Write-Host ("  arrow  U+2192  : {0}" -f $st.arrow)
Write-Host ("  rsquo  U+2019  : {0}" -f $st.rsquo)
Write-Host ("  times  U+00D7  : {0}" -f $st.times)
Write-Host ("  mojibake       : {0}" -f $st.mojibake)
