#!/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile

function GetFullPath($filename)
{
    if ([System.IO.Path]::IsPathRooted($filename))
    {
        [System.IO.Path]::GetFullPath($filename)
    }
    else
    {
        [System.IO.Path]::GetFullPath((Join-Path (pwd) $filename))
    }
}

# Why ish? See http://pdh11.blogspot.co.uk/2009/05/pathcanonicalize-versus-what-it-says-on.html
function GetCanonicalishPath($file, $proj)
{
    if (![System.IO.Path]::IsPathRooted($file))
    {
        $proj = GetFullPath $proj
        $projdir = [System.IO.Path]::GetDirectoryName($proj)
        $file = "$projdir\$file"
    }
    else
    {
        $file = GetFullPath $file
    }
    $file.ToLower()
}

function ReadErrorLog($logLines)
{
    $files = @{}

    $logLines |
        foreach {
            $_ -match '^(.*)\(([^\)]*)\):.*\[([^]]*)\]$' > $null
            $file, $line, $proj = $Matches[1], $Matches[2], $Matches[3]

            $file = GetCanonicalishPath $file $proj

            if (!$files.contains($file))
            {
                $files[$file] = @()
            }
            if (!$files[$file].contains($line))
            {
                $files[$file] += [int]$line
            }
        }

    $files
}

function GetEncoding($filename)
{
    [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 $filename
    if ($byte.Count -eq 4 -and $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf){
        [System.Text.Encoding]::GetEncoding('utf-8')
    }
    else {
        [System.Text.Encoding]::GetEncoding('iso-8859-1')
    }
}

function InsertLegacyMarker($file, $lines, $legacyHeaderDir, $legacyMarker)
{
    $encoding = GetEncoding $file
    $fileContents = [System.IO.File]::ReadAllLines($file, $encoding)

    $includeWildcard = "#include `"${legacyHeaderDir}/*"
    $totalIncludes = ($fileContents | where { $_ -like $includeWildcard }).count

    if ($totalIncludes -eq 0)
    {
        $includeWildcard = '#include "*'
        $totalIncludes = ($fileContents | where { $_ -like $includeWildcard }).count
    }

    $line = 1
    $includes = 0
    $newContents = $fileContents | foreach {
        if ($lines.contains($line))
        {
            $_ -match '^(\s*)' > $null
            $Matches[1] + $legacyMarker
        }
        $_
        if ($_ -like $includeWildcard)
        {
            ++$includes
            if ($includes -eq $totalIncludes)
            {
                "#include `"$legacyHeaderDir/LegacyCodeCompilerWarnings.hpp`""
            }
        }
        ++$line
    }
    [System.IO.File]::WriteAllLines($file, $newContents, $encoding)
}

$legacyHeaderDir, $legacyMarker, $logFile = @($args)
$logLines = $input
if ($logFile -ne $null)
{
    $logLines = Get-Content $logFile
}

$files = ReadErrorLog $logLines
foreach ($entry in $files.GetEnumerator())
{
    $entry.Name
    InsertLegacyMarker $entry.Name $entry.Value $legacyHeaderDir $legacyMarker
}
