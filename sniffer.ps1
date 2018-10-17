#! /snap/powershell/11/opt/powershell/pwsh

$sleep_interval_sec = 2

$header = New-Object PSObject -Property ([ordered]@{Time=""; Watcher=""; BlkDiff=""; ChildChain="" })

function Parse-Time($ts) {
    $now = ((Get-Date "01/01/1970") + (New-TimeSpan -Seconds $ts))
    return (Get-Date -Date $now -Format "HH:mm:ss")
}

function Get-BlkDiff($cc, $wa) {
    return ([int]$cc - [int]$wa) / 1000
}

function Parse-Status($response) {
    $data = $response.data
    $status = @{
        Time       = (Parse-Time $data.last_mined_child_block_timestamp);
        Watcher    = $data.last_validated_child_block_number
        BlkDiff    = (Get-BlkDiff $data.last_mined_child_block_number $data.last_validated_child_block_number)
        ChildChain = $data.last_mined_child_block_number
    }
    
    return (New-Object PSObject -Property $status)
}

function Out-Result($tab) {
    $header.Time = $global:i++
    return $header, ($tab | select -Last 2)
}

function Get-Status {
    try {
        $r = Invoke-RestMethod "http://localhost:4000/status"
    } catch {
        Write-Host $_.Exception.Message
        return $header
    }
    return (Parse-Status $r)
}

function Run {
    $all = @()
    $inc = @()

    While($true) {
        $new = (Get-Status)
        $prev = $all[-1]
        $all += $new

        if ($prev.Watcher -ne $new.Watcher) { $inc += $new }
     
        echo (Out-Result $inc) 
        Start-Sleep -s $global:sleep_interval_sec
    }
}

Run