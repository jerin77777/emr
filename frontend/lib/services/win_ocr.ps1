param (
    [Parameter(Mandatory=$true)][string]$ImagePath
)

$ErrorActionPreference = 'Stop'

try {
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Runtime.WindowsRuntime")
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq "AsTask" -and $_.GetParameters().Length -eq 1 -and $_.IsGenericMethod })[0]

    function Await($asyncOp, $type) {
        $m = $asTask.MakeGenericMethod($type)
        $t = $m.Invoke($null, @($asyncOp))
        $t.Wait()
        return $t.Result
    }

    $sfType = [System.Type]::GetType("Windows.Storage.StorageFile, Windows, ContentType=WindowsRuntime")
    $famType = [System.Type]::GetType("Windows.Storage.FileAccessMode, Windows, ContentType=WindowsRuntime")
    $streamInterface = [System.Type]::GetType("Windows.Storage.Streams.IRandomAccessStream, Windows, ContentType=WindowsRuntime")
    $bdType = [System.Type]::GetType("Windows.Graphics.Imaging.BitmapDecoder, Windows, ContentType=WindowsRuntime")
    $sbType = [System.Type]::GetType("Windows.Graphics.Imaging.SoftwareBitmap, Windows, ContentType=WindowsRuntime")
    $ocrType = [System.Type]::GetType("Windows.Media.Ocr.OcrEngine, Windows, ContentType=WindowsRuntime")
    $ocrResultType = [System.Type]::GetType("Windows.Media.Ocr.OcrResult, Windows, ContentType=WindowsRuntime")
    $langType = [System.Type]::GetType("Windows.Globalization.Language, Windows, ContentType=WindowsRuntime")

    $getFileMethod = $sfType.GetMethod("GetFileFromPathAsync", [type[]]@([string]))
    $file = Await ($getFileMethod.Invoke($null, @($ImagePath))) $sfType
    
    $readMode = [System.Enum]::Parse($famType, "Read")
    $openMethod = $file.GetType().GetMethod("OpenAsync", [type[]]@($famType))
    $stream = Await ($openMethod.Invoke($file, @($readMode))) $streamInterface
    
    $createMethod = $bdType.GetMethods() | Where-Object { $_.Name -eq 'CreateAsync' -and $_.GetParameters().Count -eq 1 } | Select-Object -First 1
    $decoder = Await ($createMethod.Invoke($null, @($stream))) $bdType
    
    $getBitmapMethod = $decoder.GetType().GetMethod("GetSoftwareBitmapAsync", [type[]]@())
    $bitmap = Await ($getBitmapMethod.Invoke($decoder, @())) $sbType

    $tryCreateMethod = $ocrType.GetMethod("TryCreateFromUserProfileLanguages", [type[]]@())
    $engine = $tryCreateMethod.Invoke($null, @())
    if ($null -eq $engine) {
        $lang = [System.Activator]::CreateInstance($langType, @("en-US"))
        $tryCreateLangMethod = $ocrType.GetMethod("TryCreateFromLanguage", [type[]]@($langType))
        $engine = $tryCreateLangMethod.Invoke($null, @($lang))
    }

    if ($null -eq $engine) {
        Write-Output "ERROR: Windows OCR Engine is not enabled on this device."
        exit 1
    }

    $recognizeMethod = $engine.GetType().GetMethod("RecognizeAsync", [type[]]@($sbType))
    $ocrResult = Await ($recognizeMethod.Invoke($engine, @($bitmap))) $ocrResultType

    $lines = $ocrResult.Lines
    $ocrLines = @()

    foreach ($line in $lines) {
        $words = $line.Words
        
        $minX = [double]::MaxValue
        $minY = [double]::MaxValue
        $maxX = [double]::MinValue
        $maxY = [double]::MinValue
        
        foreach ($w in $words) {
            $rect = $w.BoundingRect
            if ($rect.X -lt $minX) { $minX = $rect.X }
            if ($rect.Y -lt $minY) { $minY = $rect.Y }
            if (($rect.X + $rect.Width) -gt $maxX) { $maxX = ($rect.X + $rect.Width) }
            if (($rect.Y + $rect.Height) -gt $maxY) { $maxY = ($rect.Y + $rect.Height) }
        }
        
        $ocrLines += [PSCustomObject]@{
            Text = $line.Text
            MinX = $minX
            MinY = $minY
            MaxX = $maxX
            MaxY = $maxY
        }
    }

    # Group lines into horizontal rows based on Y-coordinates (within 12 pixels)
    $yThreshold = 12
    $rows = @()

    # Sort lines by MinY first
    $sortedOcrLines = $ocrLines | Sort-Object MinY

    foreach ($line in $sortedOcrLines) {
        $placed = $false
        for ($r = 0; $r -lt $rows.Count; $r++) {
            $sumY = 0
            foreach ($rl in $rows[$r]) { $sumY += $rl.MinY }
            $avgY = $sumY / $rows[$r].Count

            if ([Math]::Abs($line.MinY - $avgY) -le $yThreshold) {
                $rows[$r] += $line
                $placed = $true
                break
            }
        }

        if (-not $placed) {
            $rows += ,@($line)
        }
    }

    # Sort each row horizontally by MinX and print the joined line
    foreach ($row in $rows) {
        $sortedRow = $row | Sort-Object MinX
        $rowText = ($sortedRow | ForEach-Object { $_.Text }) -join " "
        Write-Output $rowText
    }
} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
}
