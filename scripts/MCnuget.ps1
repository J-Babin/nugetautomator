function Get-NuGetDependencies {
    param (
        [string]$PackageName,
        [string]$Version = "",
        [string]$DownloadPath = ".\NuGetPackages",
        [switch]$DownloadPackages = $false,
        [int]$DelaySeconds = 0,
        [hashtable]$VisitedDependencies = @{}
    )

    # Initialisation
    if ($null -eq $VisitedDependencies) {
        $VisitedDependencies = @{}
    }

    # Verifier si le package a dejà ete traite
    if ($VisitedDependencies.ContainsKey($PackageName.ToLower())) {
        return $VisitedDependencies
    }

    # URL du package
    $url = "https://www.nuget.org/packages/$PackageName"
    if ($Version) {
        $url += "/$Version"
    }

    Write-Host "Analyse de $PackageName $Version" -ForegroundColor Yellow

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $html = $response.Content

        # Extraire la version si non specifiee
        if (-not $Version) {
            if ($html -match '([0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9]+)?)') {
                $Version = $matches[1]
                Write-Host "  Version detectee: $Version" -ForegroundColor Gray
            }
        }


        $VisitedDependencies[$PackageName.ToLower()] = $Version


        if ($DownloadPackages) {
            if (-not (Test-Path -Path $DownloadPath)) {
                New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
            }
            
            $downloadUrl = "https://www.nuget.org/api/v2/package/$PackageName/$Version"
            $outputFile = Join-Path $DownloadPath "$PackageName.$Version.nupkg"
            
            if (-not (Test-Path $outputFile)) {
                Write-Host "  Telechargement de $PackageName v$Version..." -ForegroundColor Blue
                Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile
                Write-Host "  Telecharge: $outputFile" -ForegroundColor Green
            }
        }

        # Trouver les dependances
        $pattern = '<a href="/packages/([^/"]+)[^>]*>([^<]+)</a>\s*<span[^>]*>\([^0-9]*([0-9]+\.[0-9]+\.[0-9]+)[^)]*\)</span>'
        $dependencyMatches = [regex]::Matches($html, $pattern)

        foreach ($match in $dependencyMatches) {
            $depName = $match.Groups[1].Value
            $depVersion = $match.Groups[3].Value
            
            Write-Host "  Dependance trouvee: $depName v$depVersion" -ForegroundColor Magenta
            
            # Appliquer le delai si specifie
            if ($DelaySeconds -gt 0) {
                Write-Host "  + Pause de $DelaySeconds seconde(s)..." -ForegroundColor Gray
                Start-Sleep -Seconds $DelaySeconds
            }
            
            # Appel recursif si la dependance n'est pas dejà traitee
            if (-not $VisitedDependencies.ContainsKey($depName.ToLower())) {
                $VisitedDependencies = Get-NuGetDependencies -PackageName $depName -Version $depVersion -DownloadPath $DownloadPath -DownloadPackages:$DownloadPackages -DelaySeconds $DelaySeconds -VisitedDependencies $VisitedDependencies
            }
        }
    }
    catch {
        Write-Host "Erreur pour $PackageName : $($_.Exception.Message)" -ForegroundColor Red
    }

    if ($VisitedDependencies.Count -gt 0 -and $VisitedDependencies.ContainsKey($PackageName.ToLower())) {
        Write-Host "Resume des dependances pour $PackageName :" -ForegroundColor Cyan
        Write-Host "Total: $($VisitedDependencies.Count) packages" -ForegroundColor Green
        
        $VisitedDependencies.GetEnumerator() | Sort-Object Name | ForEach-Object {
            Write-Host "- $($_.Key) v$($_.Value)"
        }
    }

    return $VisitedDependencies
}

# Exemples d'utilisation avec delai:
# 
# Analyser avec un delai de 2 secondes entre chaque requête:
# Get-NuGetDependencies -PackageName "NUnit" -DelaySeconds 2
#
# Telecharger les package avec le package initial dans une version specifique:
# Get-NuGetDependencies -PackageName "NUnit" -Version "3.13.2" -DownloadPackages -DownloadPath "C:\Temp\NuGetPackages"
#
# Telecharger avec un delai de 3 secondes:
# Get-NuGetDependencies -PackageName "NUnit" -DownloadPackages -DelaySeconds 3 -DownloadPath "C:\Temp\NuGetPackages"