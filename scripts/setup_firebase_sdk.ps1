$target = 806016001
$url = "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_windows_12.7.0.zip"
$zipPath = "build\windows\x64\firebase_cpp_sdk_windows_12.7.0.zip"
$extractedPath = "build\windows\x64\extracted"
$sdkDirInBuild = "$extractedPath\firebase_cpp_sdk_windows"
$persistentDir = "E:\firebase_cpp_sdk_windows_12.7.0"

if (-not (Test-Path "build\windows\x64")) {
    New-Item -ItemType Directory -Path "build\windows\x64" -Force | Out-Null
}

Write-Host "--- Checking Firebase SDK Archive ---"
while ($true) {
    if (Test-Path $zipPath) {
        $len = (Get-Item $zipPath).Length
        Write-Host "Current zip size: $len bytes ($([math]::Round($len / 1MB, 2)) MB / $([math]::Round($target / 1MB, 2)) MB)"
        if ($len -ge $target) {
            Write-Host "Zip download complete!"
            break
        }
    }
    Write-Host "Resuming download via curl (HTTP/1.1)..."
    curl.exe -C - --http1.1 --retry 10 --retry-delay 2 --retry-max-time 300 -o $zipPath $url
    Start-Sleep -Seconds 2
}

Write-Host "--- Extracting to build directory: $extractedPath ---"
if (-not (Test-Path $extractedPath)) {
    New-Item -ItemType Directory -Path $extractedPath -Force | Out-Null
}

if (-not (Test-Path "$sdkDirInBuild\include\firebase\version.h")) {
    Write-Host "Extracting using tar.exe..."
    tar.exe -xf $zipPath -C $extractedPath
}

if (Test-Path "$sdkDirInBuild\include\firebase\version.h") {
    Write-Host "Successfully extracted Firebase SDK to: $sdkDirInBuild"
    
    # Also copy to persistent directory E:\firebase_cpp_sdk_windows_12.7.0 so flutter clean will never re-download it
    if (-not (Test-Path "$persistentDir\firebase_cpp_sdk_windows\include\firebase\version.h")) {
        Write-Host "Setting up persistent SDK at $persistentDir..."
        New-Item -ItemType Directory -Path $persistentDir -Force | Out-Null
        Copy-Item -Path $sdkDirInBuild -Destination $persistentDir -Recurse -Force
    }

    # Set User environment variable for persistent future builds
    [Environment]::SetEnvironmentVariable("FIREBASE_CPP_SDK_DIR", "$persistentDir\firebase_cpp_sdk_windows", "User")
    Write-Host "FIREBASE_CPP_SDK_DIR configured successfully!"
    Write-Host "=== READY FOR FLUTTER BUILD ==="
} else {
    Write-Error "Extraction failed: $sdkDirInBuild\include\firebase\version.h not found."
}
