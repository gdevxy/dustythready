# Generates Data\Coords.lua: map position of every NPC named in Data\Places.lua (trainers, recipe
# vendors) plus the extra supply NPCs listed below, read from the QuestieDB addon's baked database.
#
# Usage (from the repository root, with QuestieDB installed in the game):
#   powershell -ExecutionPolicy Bypass -File tools\extract-npc-coords.ps1 [-AddOns "<path to Interface\AddOns>"]
#
# QuestieDB stores each NPC in its TOC as base64 CBOR metadata: "X-Npc-<id>-S" (scalar fields;
# field 1 = name) and "X-Npc-<id>-7" (spawns: {[areaId] = {{x, y}, ...}}, x/y 0-100).
# Area IDs become UiMap IDs through support\Forever\Zones\areaIdToUiMapId.lua, whose comments
# name the zones; we use those names to pick the spawn in the zone Places.lua says.
param(
    [string]$AddOns = 'F:\Battle.net\World of Warcraft\_forever_\Interface\AddOns'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# NPCs not in Places.lua tables but mentioned in its texts: name -> zone.
$extra = [ordered]@{
    'Jeeda'          = 'Stonetalon Mountains'
    'Kulwia'         = 'Stonetalon Mountains'
    'Dawn Brightstar' = 'Elwynn Forest'
    'Mishta'         = 'Silithus'
    'Abigail Shiel'  = 'Tirisfal Glades'
    "Kal'tinzan"     = 'Mount Hyjal'
}

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Text;
public class DtCbor {
    byte[] b; int p;
    public static object Decode(string b64) { var d = new DtCbor(); d.b = Convert.FromBase64String(b64); d.p = 0; return d.Read(); }
    ulong Arg(int ai) {
        if (ai < 24) return (ulong)ai;
        if (ai == 24) return b[p++];
        if (ai == 25) { ulong v = ((ulong)b[p] << 8) | b[p+1]; p += 2; return v; }
        if (ai == 26) { ulong v = 0; for (int i = 0; i < 4; i++) v = (v << 8) | b[p++]; return v; }
        if (ai == 27) { ulong v = 0; for (int i = 0; i < 8; i++) v = (v << 8) | b[p++]; return v; }
        throw new Exception("indefinite length not supported");
    }
    object Read() {
        int ib = b[p++]; int major = ib >> 5, ai = ib & 31;
        switch (major) {
            case 0: return (double)Arg(ai);
            case 1: return -1.0 - (double)Arg(ai);
            case 2: { int n = (int)Arg(ai); var s = Encoding.UTF8.GetString(b, p, n); p += n; return s; } // QuestieDB stores text as byte strings
            case 3: { int n = (int)Arg(ai); var s = Encoding.UTF8.GetString(b, p, n); p += n; return s; }
            case 4: { int n = (int)Arg(ai); var l = new List<object>(); for (int i = 0; i < n; i++) l.Add(Read()); return l; }
            case 5: { int n = (int)Arg(ai); var m = new Dictionary<object, object>(); for (int i = 0; i < n; i++) { var k = Read(); m[k] = Read(); } return m; }
            case 6: Arg(ai); return Read();
            default:
                if (ai == 20) return false; if (ai == 21) return true; if (ai == 22 || ai == 23) return null;
                if (ai == 25) { int h = (b[p] << 8) | b[p+1]; p += 2; return Half(h); }
                if (ai == 26) { var t = new byte[4]; for (int i = 0; i < 4; i++) t[3-i] = b[p+i]; p += 4; return (double)BitConverter.ToSingle(t, 0); }
                if (ai == 27) { var t = new byte[8]; for (int i = 0; i < 8; i++) t[7-i] = b[p+i]; p += 8; return BitConverter.ToDouble(t, 0); }
                return null;
        }
    }
    static double Half(int h) {
        int e = (h >> 10) & 31, m = h & 1023; double v = e == 0 ? m * Math.Pow(2, -24) : (e == 31 ? double.PositiveInfinity : (m + 1024) * Math.Pow(2, e - 25));
        return (h & 0x8000) != 0 ? -v : v;
    }
}
'@

$tocPath = Join-Path $AddOns 'QuestieDB\QuestieDB_Forever.toc'
$zonePath = Join-Path $AddOns 'QuestieDB\support\Forever\Zones\areaIdToUiMapId.lua'
if (-not (Test-Path $tocPath)) { throw "QuestieDB not found at $tocPath" }

# Area ID -> UiMap ID, and zone name -> area IDs (from the comments).
$areaToMap = @{}; $nameToAreas = @{}
foreach ($line in [IO.File]::ReadAllLines($zonePath)) {
    if ($line -match '^\s*\[(\d+)\]\s*=\s*(\d+),\s*--\s*(.+?)\s*$') {
        $area = [int]$Matches[1]; $map = [int]$Matches[2]; $zn = $Matches[3]
        if (-not $areaToMap.ContainsKey($area)) { $areaToMap[$area] = $map }
        if (-not $nameToAreas.ContainsKey($zn)) { $nameToAreas[$zn] = New-Object System.Collections.ArrayList }
        [void]$nameToAreas[$zn].Add($area)
    }
}

# Wanted NPCs: { "Name", "Zone", ... } entries in Places.lua, plus $extra.
$wanted = [ordered]@{}
$places = [IO.File]::ReadAllText((Join-Path $root 'Data\Places.lua'))
$places = $places.Substring(0, $places.IndexOf('ns.SUPPLIES'))  # TRAINERS + RECIPE_SOURCES only
foreach ($m in [regex]::Matches($places, '\{\s*"((?:[^"\\]|\\.)+)",\s*"((?:[^"\\]|\\.)+)"')) {
    $n = $m.Groups[1].Value; $z = $m.Groups[2].Value -replace '\s*\(.*\)$', ''
    if ($z -eq 'Stormwind') { $z = 'Stormwind City' }
    if ($n -match '^(Quest:|World drop)') { continue }
    if (-not $wanted.Contains($n)) { $wanted[$n] = $z }
}
foreach ($k in $extra.Keys) { if (-not $wanted.Contains($k)) { $wanted[$k] = $extra[$k] } }

# Index the TOC metadata we need.
$rows = @{}; $spawns = @{}
foreach ($line in [IO.File]::ReadLines($tocPath)) {
    if (-not $line.StartsWith('## X-Npc-')) { continue }
    if ($line -match '^## X-Npc-(\d+)-S: (.+)$') { $rows[[int]$Matches[1]] = $Matches[2] }
    elseif ($line -match '^## X-Npc-(\d+)-7: (.+)$') { $spawns[[int]$Matches[1]] = $Matches[2] }
}

# name -> ids
$byName = @{}
foreach ($id in $rows.Keys) {
    $row = [DtCbor]::Decode($rows[$id])
    $nm = $null
    foreach ($k in $row.Keys) { if ($k -is [double] -and $k -eq 1) { $nm = $row[$k] } }
    if ($nm -and $wanted.Contains($nm)) {
        if (-not $byName.ContainsKey($nm)) { $byName[$nm] = New-Object System.Collections.ArrayList }
        [void]$byName[$nm].Add($id)
    }
}

$out = New-Object System.Text.StringBuilder
[void]$out.AppendLine('-- GENERATED by tools\extract-npc-coords.ps1 from QuestieDB. Do not edit by hand: add the NPC to')
[void]$out.AppendLine('-- Data\Places.lua (or the script''s extra list) and run the script again.')
[void]$out.AppendLine('-- name = { m = UiMapID, x = 0-100, y = 0-100 }')
[void]$out.AppendLine('local _, ns = ...')
[void]$out.AppendLine('')
[void]$out.AppendLine('ns.NPC_COORDS = {')
$missing = @()
foreach ($nm in $wanted.Keys) {
    $zone = $wanted[$nm]
    $best = $null
    if ($byName.ContainsKey($nm)) {
        $zoneAreas = if ($nameToAreas.ContainsKey($zone)) { $nameToAreas[$zone] } else { @() }
        foreach ($id in ($byName[$nm] | Sort-Object)) {
            if (-not $spawns.ContainsKey($id)) { continue }
            $sp = [DtCbor]::Decode($spawns[$id])
            foreach ($k in $sp.Keys) {
                $area = [int]$k
                $pts = @($sp[$k] | Where-Object { [double]$_[0] -ge 0 -and [double]$_[1] -ge 0 })  # -1,-1 = inside an instance
                if ($pts.Count -eq 0) { continue }
                $map = if ($areaToMap.ContainsKey($area)) { $areaToMap[$area] } else { 0 }
                if ($map -le 0) { continue }
                $cand = @{ id = $id; area = $area; map = $map; x = [double]$pts[0][0]; y = [double]$pts[0][1]; inZone = ($zoneAreas -contains $area) }
                if (-not $best -or ($cand.inZone -and -not $best.inZone)) { $best = $cand }
            }
        }
    }
    $lname = $nm.Replace('\', '\\').Replace('"', '\"')
    if ($best) {
        $note = if ($best.inZone) { '' } else { "  -- not found in $zone, using area $($best.area)" }
        [void]$out.AppendLine(('    ["{0}"] = {{ m = {1}, x = {2}, y = {3} }}, -- npc {4}{5}' -f $lname, $best.map,
            [math]::Round($best.x, 1).ToString([Globalization.CultureInfo]::InvariantCulture),
            [math]::Round($best.y, 1).ToString([Globalization.CultureInfo]::InvariantCulture), $best.id, $note))
        if (-not $best.inZone) { $missing += "$nm (zone '$zone' not matched, used area $($best.area))" }
    } else {
        $missing += "$nm ($zone): not in QuestieDB"
    }
}
[void]$out.AppendLine('}')

$enc = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $root 'Data\Coords.lua'), $out.ToString(), $enc)
Write-Host ("Wrote Data\Coords.lua: {0} of {1} NPCs located." -f ($wanted.Count - ($missing | Where-Object { $_ -like '*not in QuestieDB' }).Count), $wanted.Count)
if ($missing.Count) { Write-Host "Check these:"; $missing | ForEach-Object { Write-Host "  $_" } }
