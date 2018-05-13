$StartListener = {
    $schtaskname = "Coolblue Live Stream Listener"
    If (Get-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue) {
        SCHTASKS /Delete /TN $schtaskname /F | Out-Null
    }
    $schtaskfilter = "*[System[Provider[@Name='Coolblue Live Stream Controller'] and (EventID=1337)]]"
    SCHTASKS /Create /TN $schtaskname /S $ENV:COMPUTERNAME /RU BUILTIN\Users /TR notepad.exe /SC ONEVENT /EC Application /MO $schtaskfilter | Out-Null
    
    $counter = 5
    $schtask = Get-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue
    While (!($schtask) -and ($counter -gt 0)) {
        Start-Sleep 1
        $counter --
        $schtask = Get-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue
    }
    If ($counter -le 0) {
        Return "Could not create Scheduled Task."
        Exit
    }    
    Try {
        Write-EventLog -LogName "Application" -Source "Coolblue Live Stream Controller" -Message "Starting Coolblue Live Stream Listener" -EventId "1337" -ErrorAction Stop
    }
    Catch {
        New-EventLog -LogName "Application" -Source "Coolblue Live Stream Controller"
        Write-EventLog -LogName "Application" -Source "Coolblue Live Stream Controller" -Message "Starting Coolblue Live Stream Listener" -EventId "1337"
    }
    $counter = 5
    $schtask = Get-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue
    While (($schtask.State -ne "Running") -and ($counter -gt 0)) {
        Start-Sleep 1
        $counter --
        $schtask = Get-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue
    }
    If ($counter -le 0) {
        Return "Could not start Scheduled Task."
        Exit
    } 
    Return "Listener started."
}

$StopListener = {
    $schtaskname = "Coolblue Live Stream Listener"
    $schtask = Get-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue
    If (!($schtask)) {
        Return "There is no Scheduled Task."
        Exit
    }
    If ($schtask.State -eq "Ready") {
        Return "Scheduled Task already stopped."
        Exit
    }
    Stop-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue
    $counter = 5
        While (($schtask.State -eq "Running") -and ($counter -gt 0)) {
        Start-Sleep 1
        $counter --
        $schtask = Get-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue
    }
    If ($counter -le 0) {
        Return "Could not stop Scheduled Task."
        Exit
    } 
    Return "Listener stopped."
}

$StatusListener = {
    $schtaskname = "Coolblue Live Stream Listener"
    $schtask = Get-ScheduledTask -TaskName $schtaskname -ErrorAction SilentlyContinue
    If ((!$schtask)) {
        Return "There is no Scheduled Task."
        Exit
    }
    If ($schtask.State -ne "Running") {
        Return "Not listening."
        Exit
    }
    Return "Listening."
}

[array]$systems = ($ENV:COMPUTERNAME,"192.168.178.111")
ForEach ($system in $systems) {
    Invoke-Command -ComputerName $system -ScriptBlock $StatusListener -AsJob -ErrorAction SilentlyContinue | Out-Null
}
Clear-Host
Get-Job | Wait-Job | Out-Null
$jobs = Get-Job
ForEach ($job in $jobs) {
    $remotehost = $job.Location
    If ($job.State -eq "Completed") {
        $remoteresult = Receive-Job -Name $job.Name
    }
    Else {
        $remoteresult = "Could not connect."
    }
    $compilation = "[" + $remotehost + "]" + " " + $remoteresult
    $compilation
}
Get-Job | Remove-Job | Out-Null