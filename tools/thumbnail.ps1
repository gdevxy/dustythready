# Renders promo\youtube-thumbnail.png (1280x720) from Media\icon-source.jpg.
# Optional: -Screenshot <path to an in-game screenshot> puts a framed shot of the addon on the right.
# Usage (from the repository root):
#   powershell -ExecutionPolicy Bypass -File tools\thumbnail.ps1
#   powershell -ExecutionPolicy Bypass -File tools\thumbnail.ps1 -Screenshot "F:\...\Screenshots\WoWScrnShot_x.jpg"
param([string]$Screenshot)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$W, $H = 1280, 720

function Col($hex, $a = 255) {
    $hex = $hex.TrimStart('#')
    [System.Drawing.Color]::FromArgb($a, [Convert]::ToInt32($hex.Substring(0, 2), 16),
        [Convert]::ToInt32($hex.Substring(2, 2), 16), [Convert]::ToInt32($hex.Substring(4, 2), 16))
}

$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
$g.TextRenderingHint = 'AntiAliasGridFit'; $g.PixelOffsetMode = 'HighQuality'

# --- Background: deep violet radial glow -------------------------------------------
$g.Clear((Col '0a0710'))
function Glow($cx, $cy, $r, $hex, $alpha) {
    # Stacked translucent discs (PathGradientBrush leaves banding artifacts on large radii).
    $steps = 40
    $per = [Math]::Max(1, [int]($alpha / $steps * 1.6))
    for ($k = $steps; $k -ge 1; $k--) {
        $rr = $r * $k / $steps
        $br = New-Object System.Drawing.SolidBrush (Col $hex $per)
        $g.FillEllipse($br, [single]($cx - $rr), [single]($cy - $rr), [single](2 * $rr), [single](2 * $rr))
        $br.Dispose()
    }
}
# Big background glows are computed per pixel (GDI+ draws huge soft shapes with banding).
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class DtGlow {
    // glows: cx, cy, radius, r, g, b, strength(0..1) per glow
    public static void Paint(Bitmap bmp, double[] glows, int br, int bg, int bb) {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var data = bmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        var px = new byte[data.Stride * bmp.Height];
        for (int y = 0; y < bmp.Height; y++) for (int x = 0; x < bmp.Width; x++) {
            double r = br, g = bg, b = bb;
            for (int i = 0; i < glows.Length; i += 7) {
                double dx = x - glows[i], dy = y - glows[i + 1];
                double d = Math.Sqrt(dx * dx + dy * dy) / glows[i + 2];
                if (d >= 1) continue;
                double t = (1 - d) * (1 - d) * glows[i + 6];   // smooth falloff
                r += (glows[i + 3] - r) * t; g += (glows[i + 4] - g) * t; b += (glows[i + 5] - b) * t;
            }
            int o = y * data.Stride + x * 4;
            px[o] = (byte)Math.Min(255, b); px[o + 1] = (byte)Math.Min(255, g); px[o + 2] = (byte)Math.Min(255, r); px[o + 3] = 255;
        }
        Marshal.Copy(px, 0, data.Scan0, px.Length);
        bmp.UnlockBits(data);
    }
    public static void Vignette(Bitmap bmp, double strength) {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        var px = new byte[data.Stride * bmp.Height];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        double cx = bmp.Width / 2.0, cy = bmp.Height / 2.0;
        for (int y = 0; y < bmp.Height; y++) for (int x = 0; x < bmp.Width; x++) {
            double dx = (x - cx) / cx, dy = (y - cy) / cy;
            double d = Math.Sqrt(dx * dx + dy * dy) / Math.Sqrt(2);
            double f = 1 - strength * Math.Pow(Math.Max(0, d - 0.35) / 0.65, 2);
            int o = y * data.Stride + x * 4;
            for (int c = 0; c < 3; c++) px[o + c] = (byte)(px[o + c] * f);
        }
        Marshal.Copy(px, 0, data.Scan0, px.Length);
        bmp.UnlockBits(data);
    }
}
'@
[DtGlow]::Paint($bmp, [double[]](
    330, 380, 700, 0x3a, 0x1a, 0x66, 1.0,
    330, 370, 380, 0x7b, 0x3f, 0xd1, 0.7,
    1080, 120, 460, 0xe8, 0xc1, 0x70, 0.18,
    900, 680, 520, 0x5b, 0x2a, 0xa3, 0.45,
    325, 380, 380, 0xb9, 0x8c, 0xff, 0.55), 0x0a, 0x07, 0x10)  # last one: halo behind the icon

# --- Sparkles ------------------------------------------------------------------------
$rnd = New-Object System.Random 42
for ($i = 0; $i -lt 140; $i++) {
    $x = $rnd.Next(0, $W); $y = $rnd.Next(0, $H)
    $s = $rnd.NextDouble() * 3 + 0.6
    $hex = @('b98cff', 'e8c170', 'ffffff', 'd9c2ff')[$rnd.Next(0, 4)]
    $br = New-Object System.Drawing.SolidBrush (Col $hex ($rnd.Next(60, 220)))
    $g.FillEllipse($br, $x, $y, $s, $s); $br.Dispose()
}
function Star($cx, $cy, $r, $hex, $alpha) {
    $pen = New-Object System.Drawing.Pen (Col $hex $alpha), 2
    $g.DrawLine($pen, $cx - $r, $cy, $cx + $r, $cy); $g.DrawLine($pen, $cx, $cy - $r, $cx, $cy + $r)
    $pen.Dispose(); Glow $cx $cy ($r * 0.8) $hex $alpha
}
Star 620 110 22 'ffffff' 200; Star 95 120 14 'e8c170' 200; Star 560 640 16 'b98cff' 220
Star 1210 420 12 'e8c170' 180; Star 700 470 10 'ffffff' 160

# --- Icon in a glowing gold ring ---------------------------------------------------------
$icon = [System.Drawing.Image]::FromFile((Join-Path $root 'Media\icon-source.jpg'))
$ix, $iy, $is = 95, 150, 460
$clip = New-Object System.Drawing.Drawing2D.GraphicsPath
$clip.AddEllipse($ix, $iy, $is, $is)
$g.SetClip($clip); $g.DrawImage($icon, $ix, $iy, $is, $is); $g.ResetClip()
$ring = New-Object System.Drawing.Pen (Col 'e8c170'), 10
$g.DrawEllipse($ring, $ix, $iy, $is, $is)
$ring2 = New-Object System.Drawing.Pen (Col 'b98cff' 160), 3
$g.DrawEllipse($ring2, $ix - 14, $iy - 14, $is + 28, $is + 28)
$icon.Dispose()

# --- Outlined text helper ----------------------------------------------------------------
function OutlinedText($text, $family, $size, $style, $x, $y, $fillHex, $outline = 10, [switch]$Measure) {
    $fam = New-Object System.Drawing.FontFamily $family
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $path.AddString($text, $fam, [int]$style, $size, (New-Object System.Drawing.PointF $x, $y), $fmt)
    if ($Measure) { $b = $path.GetBounds(); $path.Dispose(); return $b }
    # soft shadow
    $m = New-Object System.Drawing.Drawing2D.Matrix; $m.Translate(6, 8)
    $shadow = $path.Clone(); $shadow.Transform($m)
    $sb = New-Object System.Drawing.SolidBrush (Col '000000' 150); $g.FillPath($sb, $shadow); $sb.Dispose()
    $pen = New-Object System.Drawing.Pen (Col '120a1c'), $outline
    $pen.LineJoin = 'Round'; $g.DrawPath($pen, $path); $pen.Dispose()
    $fill = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, ([int]$y), 10, ([int]$size + 10)), (Col 'ffffff'), (Col $fillHex), 90
    $blend = New-Object System.Drawing.Drawing2D.Blend
    $blend.Factors = [single[]](0.35, 1, 1); $blend.Positions = [single[]](0, 0.45, 1); $fill.Blend = $blend
    $g.FillPath($fill, $path); $fill.Dispose(); $path.Dispose()
}

$tx = 600
if ($Screenshot) { $tx = 600 }

# Badge
$badgeFont = New-Object System.Drawing.Font 'Segoe UI', 22, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$badge = 'WOW FOREVER  ADDON'
$bw = $g.MeasureString($badge, $badgeFont).Width + 30
$bp = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 18; $bx = $tx + 6; $by = 70; $bh = 40
$bp.AddArc($bx, $by, $r * 2, $bh, 90, 180); $bp.AddArc($bx + $bw - $r * 2, $by, $r * 2, $bh, 270, 180); $bp.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush (Col 'e8c170')), $bp)
$g.DrawString($badge, $badgeFont, (New-Object System.Drawing.SolidBrush (Col '1a1024')), $bx + 15, $by + 6)

# Title
OutlinedText 'DUSTY' 'Impact' 168 0 ($tx) 118 'b98cff' 13
OutlinedText 'THREADY' 'Impact' 168 0 ($tx) 286 'e8c170' 13

# Tagline: the loop
$chipFont = New-Object System.Drawing.Font 'Segoe UI', 29, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$arrowFont = New-Object System.Drawing.Font 'Segoe UI', 29, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$x = $tx + 4; $y = 520
$chips = @(@('CLOTH', 'ffffff'), @('GREENS', '1eff00'), @('DUST', 'b98cff'), @('GOLD', 'ffd100'))
for ($i = 0; $i -lt $chips.Count; $i++) {
    $t = $chips[$i][0]; $c = $chips[$i][1]
    $w = $g.MeasureString($t, $chipFont).Width + 18
    $cp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cr = 11; $ch = 48
    $cp.AddArc($x, $y, $cr * 2, $cr * 2, 180, 90); $cp.AddArc($x + $w - $cr * 2, $y, $cr * 2, $cr * 2, 270, 90)
    $cp.AddArc($x + $w - $cr * 2, $y + $ch - $cr * 2, $cr * 2, $cr * 2, 0, 90); $cp.AddArc($x, $y + $ch - $cr * 2, $cr * 2, $cr * 2, 90, 90); $cp.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush (Col '120a1c' 220)), $cp)
    $g.DrawPath((New-Object System.Drawing.Pen (Col $c), 3), $cp)
    $g.DrawString($t, $chipFont, (New-Object System.Drawing.SolidBrush (Col $c)), $x + 9, $y + 4)
    $x += $w
    if ($i -lt $chips.Count - 1) {
        $g.DrawString([string][char]0x2192, $arrowFont, (New-Object System.Drawing.SolidBrush (Col 'ffffff' 230)), $x + 3, $y + 3)
        $x += 40
    }
}
$subFont = New-Object System.Drawing.Font 'Segoe UI', 30, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('Tailoring + Enchanting, leveled together', $subFont, (New-Object System.Drawing.SolidBrush (Col 'e6dcf5')), $tx + 6, 600)

# Optional screenshot, small and tilted in the bottom-right corner
if ($Screenshot) {
    $shot = [System.Drawing.Image]::FromFile($Screenshot)
    $sw = 420; $sh = [int]($shot.Height * $sw / $shot.Width)
    $state = $g.Save()
    $g.TranslateTransform(1050, 560); $g.RotateTransform(-6)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush (Col '000000' 140)), -$sw / 2 + 10, -$sh / 2 + 12, $sw, $sh)
    $g.DrawImage($shot, -$sw / 2, -$sh / 2, $sw, $sh)
    $g.DrawRectangle((New-Object System.Drawing.Pen (Col 'e8c170'), 5), -$sw / 2, -$sh / 2, $sw, $sh)
    $g.Restore($state); $shot.Dispose()
}

# Vignette: soft darkening towards the corners, per pixel
$g.Flush()
[DtGlow]::Vignette($bmp, 0.45)

$out = Join-Path $root 'promo'
New-Item -ItemType Directory -Force $out | Out-Null
$file = Join-Path $out 'youtube-thumbnail.png'
$bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "Saved $file"
