# prtgreports
PRTG SNMP Disk utilization CSV report

## Usage
Configure a PRTG user and obtain users passhash. Update the script variables:
$PRTGServer = "prtg.example.com"
$PRTGUser = "prtguser"
$Passhash = "123456789"

Execiute in Powershell
Example:
* .\prtgreporting.ps1

A CSV file will be saved into the current directory EG: prtgsnmpdiskreport-29102018-1117.csv
