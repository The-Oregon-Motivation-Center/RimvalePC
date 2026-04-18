Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RIMVALE DLL DIAGNOSTIC" -ForegroundColor Cyan
Write-Host "============================================================"

$dllPath = "C:\Users\Acata\RimvaleGodot\addons\rimvale_engine\bin\Debug\librimvale_engine.windows.debug.x86_64.dll"
$dotGodot = "C:\Users\Acata\RimvaleGodot\.godot"
$extList  = "$dotGodot\extension_list.cfg"

# ── Step 1: Can Windows load the DLL? ─────────────────────────────────────────
Write-Host ""
Write-Host "Step 1: Testing Windows DLL load..." -ForegroundColor Yellow

if (-not (Test-Path $dllPath)) {
    Write-Host "[FAIL] DLL file not found at: $dllPath" -ForegroundColor Red
} else {
    Write-Host "[OK]   DLL exists ($([Math]::Round((Get-Item $dllPath).Length / 1MB, 1)) MB)" -ForegroundColor Green
    try {
        $handle = [System.Runtime.InteropServices.NativeLibrary]::Load($dllPath)
        Write-Host "[OK]   Windows loaded DLL successfully! Handle: 0x$($handle.ToString('X'))" -ForegroundColor Green
        [System.Runtime.InteropServices.NativeLibrary]::Free($handle)
    } catch {
        Write-Host "[FAIL] Windows CANNOT load DLL:" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "This is why the extension isn't loading in Godot." -ForegroundColor Yellow
    }
}

# ── Step 2: Check dependencies exist ──────────────────────────────────────────
Write-Host ""
Write-Host "Step 2: Checking dependency DLLs..." -ForegroundColor Yellow

$deps = @("MSVCP140.dll", "VCRUNTIME140.dll", "VCRUNTIME140_1.dll")
foreach ($dep in $deps) {
    $found = Get-ChildItem -Path "C:\Windows\System32", "C:\Windows\SysWOW64" -Filter $dep -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        Write-Host "[OK]   $dep found at $($found.FullName)" -ForegroundColor Green
    } else {
        Write-Host "[MISS] $dep NOT FOUND in System32/SysWOW64" -ForegroundColor Red
    }
}

# ── Step 3: extension_list.cfg status ─────────────────────────────────────────
Write-Host ""
Write-Host "Step 3: extension_list.cfg status..." -ForegroundColor Yellow

Write-Host ".godot folder contents:"
if (Test-Path $dotGodot) {
    Get-ChildItem $dotGodot | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  .godot folder NOT FOUND" -ForegroundColor Red
}

Write-Host ""
if (Test-Path $extList) {
    Write-Host "[OK]   extension_list.cfg exists:" -ForegroundColor Green
    Write-Host (Get-Content $extList -Raw)
} else {
    Write-Host "[MISS] extension_list.cfg does NOT exist" -ForegroundColor Red
    Write-Host "       Writing it now..."
    Set-Content -Path $extList -Value "res://addons/rimvale_engine/rimvale_engine.gdextension" -Encoding UTF8
    Write-Host "[OK]   Written." -ForegroundColor Green
}

# ── Step 4: Search all drives ─────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 4: Searching for extension_list.cfg on all drives..." -ForegroundColor Yellow
Get-ChildItem -Path "C:\Users\Acata" -Filter "extension_list.cfg" -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host "  Found: $($_.FullName)" }

Write-Host ""
Write-Host "============================================================"
Write-Host "Done. Press any key to exit."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
