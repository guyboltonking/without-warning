[CmdletBinding()]

Param(
    [parameter(Mandatory=$true)]
    [string]$warningsFile
)

function ParseWarning($line)
{
    $source, $warning, $description = $line -split ": ", 3
    $description -match '(.*)\[(.*)\]' | Out-Null
    $description = $Matches[1]
    $project = $Matches[2]
    $action = ""
    if ($description -match '(.*) : (.*)') {
        $action = $Matches[1]
        $description = $Matches[2]
    }
    $warning = $warning -replace "warning "
    @{
        project = $project;
        source = $source;
        warning = $warning;
        action = $action;
        description = $description
    }
}

function ParseWarnings($warningsfile)
{
    Get-Content $warningsfile | % { ,(ParseWarning($_)) }
}

function SummariseByDescription($warnings, $prefix, [scriptblock]$subSummary = $null)
{
    $groupedByDescription = @($warnings | group { $_['description'] })
    if ($groupedByDescription.Count -eq 1) {
        "$prefix{0,4} {1} {2}" -f $_.Count, $_.Name, $_.Group[0]['description']
        if ($subSummary -ne $null) {
            &$subSummary $_.Group "$prefix  "
        }
    }
    else {
        "$prefix{0,4} {1}" -f $_.Count, $_.Name
        if ($_.Name -notlike 'LGHT*') {
            $groupedByDescription | sort -Descending { $_.Count } | % {
                "$prefix  {0,4} {1}" -f $_.Count, $_.Name
                if ($subSummary -ne $null) {
                    &$subSummary $_.Group "$prefix    "
                }
            }
        }
    }
}

function SummariseWarnings($warningsfile)
{
    $warnings = ParseWarnings $warningsfile

    "=== Warnings by project"
    ""
    $warnings | group { $_['project'] } | sort -Descending { $_.Count } | % {
        "{0,4} {1}" -f $_.Count, [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        $_.Group | group { $_['warning'] } | sort -Descending { $_.Count } | % {
            SummariseByDescription $_.Group "  "
        }
    }
    ""

    "=== Warnings by type"
    ""
    $warnings | group { $_['warning'] } | sort -Descending { $_.Count } | % {
        SummariseByDescription $_.Group "  " {
            $warnings, $prefix = $args
            $warnings | group { $_['project'] } | sort -Descending { $_.Count } | % {
                "$prefix{0, 4} {1}" -f $_.Count, [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            }
        }
    }
    ""

    "=== Warnings by file"
    ""
    $warnings | group { $_['source'] -replace "\(.*\)", ""} | sort -Descending { $_.Count } | % {
        "{0,4} {1}" -f $_.Count, $_.Name
        $_.Group | group { $_['warning'] } | sort -Descending { $_.Count } | % {
            SummariseByDescription $_.Group "  "
        }
    }
    ""

}

SummariseWarnings($warningsFile)
