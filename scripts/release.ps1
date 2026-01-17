# Release Automation Script for Windows
# Usage: .\scripts\release.ps1

$projectName = "somang_reading_jesus_admin"

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
flutter build windows --release --dart-define-from-file=secrets.json
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed"; exit 1 }

# 5. Build Web
$webDeploy = Read-Host "Build and deploy to Web? (y/n)"
if ($webDeploy -eq "y") {
    Write-Host "Building Web application..." -ForegroundColor Cyan
    # Adjust base-href if needed. For yj7-park.github.io/somang_reading_jesus_admin/, it should be:
    flutter build web --release --base-href "/somang_reading_jesus_admin/" --dart-define-from-file=secrets.json
    if ($LASTEXITCODE -ne 0) { Write-Error "Web build failed"; exit 1 }
}

# 6. Build MSIX
Write-Host "Creating MSIX installer..." -ForegroundColor Cyan
dart run msix:create
if ($LASTEXITCODE -ne 0) { Write-Error "MSIX creation failed"; exit 1 }

# 7. Create Portable ZIP
$zipName = "${projectName}_v${version}_portable.zip"
$buildPath = "build\windows\x64\runner\Release\*"
Write-Host "Creating portable ZIP: $zipName..." -ForegroundColor Cyan
if (Test-Path $zipName) { Remove-Item $zipName }
Compress-Archive -Path $buildPath -DestinationPath $zipName -Force
if ($LASTEXITCODE -ne 0) { Write-Error "ZIP creation failed"; exit 1 }

# 8. Git Operations
Write-Host "Tagging and pushing to origin..." -ForegroundColor Cyan
# Check if tag exists
if (git tag -l $tagName) {
    Write-Host "Tag $tagName already exists. Skipping tag creation." -ForegroundColor Yellow
} else {
    git tag $tagName
}
git push origin main
git push origin $tagName --force

# 9. GitHub Release
Write-Host "Creating/Updating GitHub release and uploading assets..." -ForegroundColor Cyan
$msixPath = "build\windows\x64\runner\Release\${projectName}.msix"

# Check if release exists
gh release view $tagName > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Release $tagName already exists. Uploading assets..." -ForegroundColor Yellow
    gh release upload $tagName $zipName $msixPath --clobber
} else {
    gh release create $tagName $zipName $msixPath --title "$tagName Release" --notes "Automated release for $tagName"
}

# 10. Web Deployment to gh-pages
if ($webDeploy -eq "y") {
    Write-Host "Deploying to GitHub Pages (gh-pages branch)..." -ForegroundColor Cyan
    
    $tempDir = [System.IO.Path]::GetTempFileName()
    Remove-Item $tempDir
    New-Item -ItemType Directory -Path $tempDir
    
    Copy-Item -Path "build\web\*" -Destination $tempDir -Recurse -Force
    
    $currentDir = Get-Location
    Set-Location $tempDir
    
    git init
    git add .
    git commit -m "deploy: web version $tagName"
    
    $remoteUrl = (git -C $currentDir remote get-url origin)
    git remote add origin $remoteUrl
    git push origin "master:refs/heads/gh-pages" --force
    
    Set-Location $currentDir
    Remove-Item -Recurse -Force $tempDir
    
    Write-Host "Web deployment successfully pushed to gh-pages." -ForegroundColor Green
}

Write-Host "Release $tagName completed successfully!" -ForegroundColor Green
