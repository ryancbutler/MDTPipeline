Import-Module "D:\MDTProduction\ServerScripts\Send-XDSlackMSG.ps1"
try{
$imports = Import-Csv "C:\temp\frombuild.csv"
}
catch
{
    throw "CAN'T IMPORT CSV"
}

Connect-VIServer -server "vcenter01.lab.local" -user $env:vmwarecreds_USR -password $env:vmwarecreds_PSW  -ErrorAction Stop
#Deletes build VM
$vm = get-vm $imports.vm |Remove-VM -DeletePermanently -confirm:$false
#Sends slack message
send-xdslackmsg -slackurl $env:slackChannelurl -msg "$($imports.vm) has been deleted" -emoji ":joy:"

Disconnect-VIServer -Confirm:$false