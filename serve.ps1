# Serves the "site" folder on http://localhost and opens it in the default browser.
# Uses only what ships with Windows (PowerShell 5.1 + .NET HttpListener). No install, no admin rights.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'site'))
if (-not (Test-Path (Join-Path $root 'index.html'))) {
  Write-Host 'The "site" folder is missing. Extract the whole zip first, then run start.bat again.'
  Read-Host 'Press Enter to close'
  exit 1
}

$listener = $null
$port = 5180
while ($port -lt 5200) {
  try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")
    $listener.Start()
    break
  } catch {
    $listener = $null
    $port++
  }
}
if ($null -eq $listener) {
  Write-Host 'Could not open a local port between 5180 and 5199.'
  Read-Host 'Press Enter to close'
  exit 1
}

$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'
  '.mjs'  = 'text/javascript; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.svg'  = 'image/svg+xml'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.ico'  = 'image/x-icon'
  '.woff2' = 'font/woff2'
  '.bin'  = 'application/octet-stream'
}

$url = "http://localhost:$port/"
Write-Host ''
Write-Host "  Isoline is running at $url"
Write-Host '  Keep this window open while you look at the page.'
Write-Host '  Close this window to stop.'
Write-Host ''
Start-Process $url

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    try {
      $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
      if ($path.EndsWith('/')) { $path = $path + 'index.html' }
      $file = [IO.Path]::GetFullPath((Join-Path $root $path.TrimStart('/')))
      $inside = $file.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
      if ($inside -and [IO.File]::Exists($file)) {
        $bytes = [IO.File]::ReadAllBytes($file)
        $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
        $type = 'application/octet-stream'
        if ($types.ContainsKey($ext)) { $type = $types[$ext] }
        $ctx.Response.ContentType = $type
        $ctx.Response.ContentLength64 = $bytes.Length
        if ($ctx.Request.HttpMethod -ne 'HEAD') {
          $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
      } else {
        $ctx.Response.StatusCode = 404
      }
    } catch {
      try { $ctx.Response.StatusCode = 500 } catch { }
    } finally {
      try { $ctx.Response.Close() } catch { }
    }
  }
} finally {
  $listener.Stop()
}
