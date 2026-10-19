Add-Type -AssemblyName System.Drawing
$pages = Get-Content -Raw -Encoding utf8 -LiteralPath 'tmp/pdfs/manual-ops.json' | ConvertFrom-Json
$scale = 1.35
$pageW = [int](595.28 * $scale)
$pageH = [int](841.89 * $scale)
$thumbW = 300
$thumbH = [int]($pageH * ($thumbW / $pageW))
New-Item -ItemType Directory -Force -Path 'tmp/pdfs/previews' | Out-Null
function Color($s) { [System.Drawing.ColorTranslator]::FromHtml($s) }
for ($pi = 0; $pi -lt $pages.Count; $pi++) {
  $bmp = New-Object System.Drawing.Bitmap($pageW, $pageH)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::White)
  foreach ($o in $pages[$pi]) {
    switch ($o.k) {
      'r' {
        $r = New-Object System.Drawing.RectangleF([single]($o.x*$scale),[single]($o.y*$scale),[single]($o.w*$scale),[single]($o.h*$scale))
        $b = New-Object System.Drawing.SolidBrush((Color $o.fill)); $g.FillRectangle($b,$r); $b.Dispose()
        if ($o.stroke) { $p = New-Object System.Drawing.Pen((Color $o.stroke),[single]0.8); $g.DrawRectangle($p,$r.X,$r.Y,$r.Width,$r.Height); $p.Dispose() }
      }
      'l' { $p = New-Object System.Drawing.Pen((Color $o.color),[single]($o.width*$scale)); $g.DrawLine($p,[single]($o.x1*$scale),[single]($o.y1*$scale),[single]($o.x2*$scale),[single]($o.y2*$scale)); $p.Dispose() }
      't' {
        $style = [System.Drawing.FontStyle]::Regular; if ($o.bold) { $style = [System.Drawing.FontStyle]::Bold }
        $font = New-Object System.Drawing.Font('Arial',[single]($o.size*$scale),$style,[System.Drawing.GraphicsUnit]::Pixel)
        $brush = New-Object System.Drawing.SolidBrush((Color $o.color))
        $g.DrawString([string]$o.s,$font,$brush,[single]($o.x*$scale),[single](($o.y-$o.size*.78)*$scale))
        $font.Dispose(); $brush.Dispose()
      }
    }
  }
  $bmp.Save("tmp/pdfs/previews/page-$($pi+1).png",[System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
$sheet = New-Object System.Drawing.Bitmap(930,1000)
$sg = [System.Drawing.Graphics]::FromImage($sheet); $sg.Clear([System.Drawing.Color]::FromArgb(235,239,235))
for ($pi=0; $pi -lt $pages.Count; $pi++) {
  $img=[System.Drawing.Image]::FromFile((Resolve-Path "tmp/pdfs/previews/page-$($pi+1).png"))
  $col=$pi%3; $row=[Math]::Floor($pi/3); $x=10+$col*308; $y=10+$row*330
  $sg.DrawImage($img,$x,$y,$thumbW,$thumbH); $img.Dispose()
}
$sheet.Save('tmp/pdfs/previews/contact.png',[System.Drawing.Imaging.ImageFormat]::Png)
$sg.Dispose(); $sheet.Dispose()
