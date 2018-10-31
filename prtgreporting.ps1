
$logo = @'
                                                                                                                        
========================================================================================================================
=                                       ____    ____    ______  ____                                                   =
=                                      /\  _`\ /\  _`\ /\__  _\/\  _`\                                                 =
=                                      \ \ \L\ \ \ \L\ \/_/\ \/\ \ \L\_\                                               =
=                                       \ \ ,__/\ \ ,  /  \ \ \ \ \ \L_L       _______                                 =
=                                        \ \ \/  \ \ \\ \  \ \ \ \ \ \/, \    /\______\                                =
=                                         \ \_\   \ \_\ \_\ \ \_\ \ \____/    \/______/                                =
=                                          \/_/    \/_/\/ /  \/_/  \/___/                                              =
=                                                                                                                      =
=                                                                                                                      =
= ____    __  __           ____        ____                 __          ____                                   __      =
=/\  _`\ /\ \/\ \  /'\_/`\/\  _`\     /\  _`\   __         /\ \        /\  _`\                                /\ \__   =
=\ \,\L\_\ \ `\\ \/\      \ \ \L\ \   \ \ \/\ \/\_\    ____\ \ \/'\    \ \ \L\ \     __   _____     ___   _ __\ \ ,_\  =
= \/_\__ \\ \ , ` \ \ \__\ \ \ ,__/    \ \ \ \ \/\ \  /',__\\ \ , <     \ \ ,  /   /'__`\/\ '__`\  / __`\/\`'__\ \ \/  =
=  /\ \L\ \ \ \`\ \ \ \_/\ \ \ \/      \ \ \_\ \ \ \/\__, `\\ \ \\`\    \ \ \\ \ /\  __/\ \ \L\ \/\ \L\ \ \ \/ \ \ \_  =
=   \ `\____\ \_\ \_\ \_\\ \_\ \_\       \ \____/\ \_\/\____/ \ \_\ \_\   \ \_\ \_\ \____\\ \ ,__/\ \____/\ \_\  \ \__\=
=    \/_____/\/_/\/_/\/_/ \/_/\/_/        \/___/  \/_/\/___/   \/_/\/_/    \/_/\/ /\/____/ \ \ \/  \/___/  \/_/   \/__/=
=                                                                                           \ \_\                      =
=     By: Martin Sustaric                                                                    \/_/                      =
=         28-10-2018                                                                                                   =
=                                                                                                                      =
========================================================================================================================
=                                                                                                                      =
=     Script usage: Executing the script will query the specified PRTG server for all SNMP Disk sensors                =
=                   and extract the latest recorded values for usage which then will be saved into a csv               =
=                   stored in the local path that this script was run from.                                            =
=                                                                                                                      =
========================================================================================================================
'@

#Art form http://patorjk.com/software/taag/#p=display&f=Larry%203D&t=%20%20%20%20%20%20%20%20%20%20PRTG%20-%20%0ASNMP%20Disk%20Report
write-host $logo -ForegroundColor Green -BackgroundColor Black

#-------------Script variables------------
$PRTGServer = "prtg.example.com"
$PRTGUser = "prtguser"
$Passhash = "123456789"
#-------------Script variables------------


$invocation = (Get-Item -Path ".\").FullName
$filedate= get-date -f ddMMyyyy-HHmm
$csv = "prtgsnmpdiskreport-$filedate.csv"
$log = "error.log"

try {    
	Write-host "Info - Gathering full sensor list from $PRTGServer" -ForegroundColor Green -BackgroundColor Black
	$url = "https://$PRTGServer/api/table.xml?content=sensors&output=csvtable&columns=objid,probe,group,device,sensor,status,message,lastvalue,type,lastcheck&count=100000&login=$PRTGUser&passhash=$Passhash"
	$data = Invoke-WebRequest -Uri $url -ErrorAction Stop
	$result = $data.Content | convertfrom-csv

	$sensorlist = $result | where-object {$_.Type -eq "SNMP Disk Free"}
	
	Write-host "Info - Completed gathering full sensor list" -ForegroundColor Green -BackgroundColor Black
	
	Write-host "Info - Gathering SNMP Disk Sensor Data from $PRTGServer" -ForegroundColor Green -BackgroundColor Black
	$report = @()
	$i = 0
	foreach($sensor in $sensorlist){
        $CurrentOperation = "Checking Sensor " + $i + " of " + $sensorlist.count
		Write-Progress -Activity "Querying PRTG SNMP Disck Sensor data" -status "Processing Sensor data" -percentComplete ($i / $sensorlist.Count*100) -CurrentOperation $CurrentOperation
		$i++
	
		$sensorid = $sensor.ID
		$sensorprobe = $sensor.Probe
		$sensorgroup = $sensor.Group
		$sensordevice = $sensor.Device
		$sensorsensor = $sensor.Sensor
		$sensorstatus = $sensor.Status
		$sensortype = $sensor.Type
        
        try {
            [datetime]$timestamp = [System.DateTime]::FromOADate($sensor.'Last Check(RAW)')
            $sensorlastckecked = $timestamp | get-date -Format G
        }
        catch {
            $sensorlastckecked = "Unknown"
        }

		$sensordataurl = "https://$PRTGServer/api/table.xml?content=channels&output=csvtable&columns=name,lastvalue_&id=$sensorid&login=$PRTGUser&passhash=$Passhash"
		$sensordataraw = Invoke-WebRequest -Uri $sensordataurl -ErrorAction Stop
		$sensordata = $sensordataraw.Content | ConvertFrom-CSV
	
		$SensorFreeBytes = ($sensordata -match 'Free Bytes').'Last Value'
		$SensorFreeSpace = ($sensordata -match 'Free Space').'Last Value'
		$SensorTotal = ($sensordata -match 'Total').'Last Value'
		$Object = New-Object PSObject -Property @{            
			ID =  $sensorid
			Probe = $sensorprobe                 
			Group = $sensorgroup             
			Device = $sensordevice          
			Sensor =  $sensorsensor                       
			SensorStatus = $sensorstatus
            LastChecked = $sensorlastckecked
			SensorType = $sensortype
			FreeBytes = $SensorFreeBytes
			FreeSpace = $SensorFreeSpace
			Total = $SensorTotal      
		} 
		$report += $Object
	}
	Write-host "Info - Completed gathering Sensor Data from $PRTGServer" -ForegroundColor Green -BackgroundColor Black
    $invocation = (Get-Variable MyInvocation).Value
	Write-host "Info - Exporting Results to $invocation\$csv" -ForegroundColor Green -BackgroundColor Black
	$report | Select-Object "ID", "Probe", "Group", "Device", "Sensor", "SensorStatus", "LastChecked", "SensorType", "FreeBytes", "FreeSpace", "Total" | Export-Csv -Path $csv -NoTypeInformation
	Write-host "Info - Script Completed" -ForegroundColor Green -BackgroundColor Black
}
catch {
    Write-host "Error - Script Failed due to some processing or networking error. For details please see $log" -ForegroundColor Green -BackgroundColor Black
    $error_message = @"
##################
$(Get-Date)
##################
$($error[0].InvocationInfo.MyCommand.Name): $($error[0].ToString())
$($error[0].InvocationInfo.PositionMessage)
+ CategoryInfo: $($error[0].CategoryInfo)
+ FullyQualifiedErrorId: $($error[0].FullyQualifiedErrorId)
"@
    $error_message|Out-File $log -Append
}

