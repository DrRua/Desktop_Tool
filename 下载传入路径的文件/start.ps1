$psPath = Join-Path $PSScriptRoot "download.ps1"
Start-Process powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$psPath`"" -WindowStyle Hidden
