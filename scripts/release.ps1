# Release Automation Script for Windows
# Usage: .\scripts\release.ps1

$projectName = "somang_reading_jesus_admin"
$secondaryRemote = "somang_reading_jesus"

# 1. Get version from pubspec.yaml
Write-Host "Reading version from pubspec.yaml..." -ForegroundColor Cyan
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version:\s*([^\s+]+)") {
    $version = $Matches[1]
    Write-Host "Detected version: $version" -ForegroundColor Green
} else {
    Write-Error "Could not find version in pubspec.yaml"
    exit 1
}

$tagName = "v$version"

# 2. Check GitHub CLI status
Write-Host "Checking GitHub CLI status..." -ForegroundColor Cyan
gh auth status
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub CLI is not authenticated. Please run 'gh auth login'."
    exit 1
}

# 3. Confirmation
$confirmation = Read-Host "Proceed with release $tagName? (y/n)"
if ($confirmation -ne "y") {
    Write-Host "Release cancelled."
    exit 0
}

# 4. Build Windows
Write-Host "Building Windows application..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed"; exit 1 }

# 5. Build MSIX
Write-Host "Creating MSIX installer..." -ForegroundColor Cyan
dart run msix:create
if ($LASTEXITCODE -ne 0) { Write-Error "MSIX creation failed"; exit 1 }

# 6. Create Portable ZIP
$zipName = "${projectName}_v${version}_portable.zip"
$buildPath = "build\windows\x64\runner\Release\*"
Write-Host "Creating portable ZIP: $zipName..." -ForegroundColor Cyan
if (Test-Path $zipName) { Remove-Item $zipName }
Compress-Archive -Path $buildPath -DestinationPath $zipName -Force
if ($LASTEXITCODE -ne 0) { Write-Error "ZIP creation failed"; exit 1 }

# 7. Git Operations
Write-Host "Tagging and pushing to origin..." -ForegroundColor Cyan
git tag $tagName
git push origin main
git push origin $tagName

# 8. GitHub Release
Write-Host "Creating GitHub release and uploading assets..." -ForegroundColor Cyan
$msixPath = "build\windows\x64\runner\Release\${projectName}.msix"
gh release create $tagName $zipName $msixPath --title "$tagName Release" --notes "Automated release for $tagName"

# 9. Optional Sync to Secondary Remote
$syncTarget = Read-Host "Sync tags to $secondaryRemote? (y/n)"
if ($syncTarget -eq "y") {
    Write-Host "Pushing to $secondaryRemote..." -ForegroundColor Cyan
    git push $secondaryRemote main
    git push $secondaryRemote $tagName
}

Write-Host "Release $tagName completed successfully!" -ForegroundColor Green
