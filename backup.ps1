Param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$DestinationDirectory,

    [Parameter(Mandatory=$false)]
    [string]$LogDirectory = "C:\Logs",

    [Parameter(Mandatory=$false)]
    [int]$NumFilesModified = 1,

    [Parameter(Mandatory=$false)]
    [int]$ChkInterval = 30,

    [Parameter(Mandatory=$false)]
    [int]$ThreadsPerSource = 2,

    [Parameter(Mandatory=$false)]
    [switch]$Fake,

    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$SourceDirectory
)

$TimeStamp = Get-Date -Format "yyyy-MM-dd_hh-mm-ss"
$DateStamp = Get-Date -Format "yyyy-MM-dd"
$log_dir_base = [System.IO.Path]::GetFullPath("$(Join-Path -Path "$LogDirectory" "backup_robocopy\$DateStamp")")
$dest_dir_base = [System.IO.Path]::GetFullPath("$DestinationDirectory")
$Log = Join-Path -Path "$log_dir_base" "${TimeStamp}_main.log"
Write-Host "$Log"
$src_dirs = $SourceDirectory
$null = New-Item -ItemType "directory" -Path "$log_dir_base" -Force

Add-Content "$Log" "**********************************************"
Add-Content "$Log" "$TimeStamp"

function mirror_dirs {
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Source,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$Destination,

        [Parameter(Mandatory=$true, Position=2)]
        [string]$ProcLog
    )
    $command = "Robocopy.exe `"$Source`" `"$Destination`" /MIR /NP `"/LOG:$ProcLog`" /R:0 /XJ /DST /TBD /MON:$NumFilesModified /MOT:$ChkInterval /MT:$ThreadsPerSource /XF `"desktop.ini`""
    Add-Content "$Log" "$command"
    Write-Host "$command"
    if (! $Fake) {
        $null = New-Item -ItemType "directory" -Path "$Destination" -Force
        $sb = [scriptblock]::create("$command")
        Start-Job -Name "$Source" -ScriptBlock $sb
    }
}

foreach ($src_dir in $src_dirs) {
    $src_dir = [System.IO.Path]::GetFullPath($src_dir)
    $src_dir_leaf = Split-Path -Path "$src_dir" -Leaf
    $dest_dir = Join-Path -Path "$dest_dir_base" "$src_dir_leaf"
    $log_file = Join-Path -Path "$log_dir_base" "${TimeStamp}_$src_dir_leaf.log"
    mirror_dirs "$src_dir" "$dest_dir" "$log_file"
}

get-job | wait-job -Any

Add-Content "$Log" "ERROR! A job exited and wasn't supposed to!"
Add-Content "$Log" "$(Get-Job | Out-String)"

get-job | stop-job
