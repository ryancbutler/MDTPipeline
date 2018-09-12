#Import Slack message module
Import-Module "D:\MDTProduction\ServerScripts\Send-XDSlackMSG.ps1"

#connect to vcenter
Connect-VIServer -server "vcenter01.lab.local" -user $env:vmwarecreds_USR -password $env:vmwarecreds_PSW  -ErrorAction Stop

#Params from Slack Command
write-host $env:imagetype
write-host $env:responseurl
write-host $env:email
write-host $env:whosubmitted

$time = get-date -UFormat %H%M%S
$VMNAME = "MDT-$time-MCS"

#Create VM Shell
$vmopts = @{
VMHost = "192.168.1.100"
Datastore = "MYDATASTORE"
Version = 'v10'
DiskGB = '40'
MemoryGB = '6'
NumCpu = '2'
NetworkName = "VLAN55"
CD = $true
DiskStorageFormat = "thin"
GuestId = 'windows9_64Guest'

}

$vm = New-VM @vmopts -Name $vmname
#Set SCSI adapter
$vm| Get-ScsiController | Set-ScsiController -Type VirtualLsiLogicSAS
#Set NIC to VMXNet3
$vm| Get-NetworkAdapter | Set-NetworkAdapter -Type VMXNet3 -Confirm:$False
$mac = $vm| Get-NetworkAdapter

#Get MAC
$mac = ($mac.MacAddress).ToUpper()
Import-Module "D:\MDTProduction\ServerScripts\MDTDB\MDTDB.psm1"

#Connect to SQL MDT Database
connect-mdtdatabase -sqlserver "localhost" -instance SQLEXPRESS -database "MDT01"
$pcsettings = @{
OSInstall='YES'; 
OSDComputerName=$VMNAME; 
ComputerName=$VMNAME; 
TaskSequenceID="W10X64-001"; 
WSUSserver="http://BASE01:8530"; 
Skipcomputername="YES"; 
Skiptasksequence="YES"; 
WindowsUpdate="True";
FinishAction="Shutdown";
GitBranch=$env:imagetype;
#KMS Key
ProductKey="NPPR9-FWDCX-D2C8J-H872K-2YT43";
#JoinDomain
JoinDomain="lab.local";
DomainAdmin=$env:domainadmin_USR;
DomainAdminDomain="lab.local";
DomainAdminPassword=$env:domainadmin_PSW;
MachineObjectOU="OU=image,DC=lab,DC=local";
}

#Create MDT entry in DB
new-mdtcomputer -macAddress $mac -settings $pcsettings -description $vmname
$slackChannelurl = $env:slackChannelurl
$slackurl = $env:responseurl
#Send SLACK status
Send-XDslackmsg -slackurl $slackChannelurl -msg "<@$env:whosubmitted> deployed $vmname for $env:imagetype (Job: $env:BUILD_NUMBER)"
Send-XDslackmsg -slackurl $slackurl -msg "SUCCESS! Deployed $vmname for $env:imagetype (Job: $env:BUILD_NUMBER) check out <#CHANNELID> for status"
#Boot VM to kick off MDT process
Start-VM $vm -Confirm:$false

#Get status of job
$target = $vmname
#Add-PSSnapin "Microsoft.BDD.PSSNAPIN"
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\Bin\Microsoft.BDD.PSSnapIn.dll"

#MDT Deployment share
$deploymentShare = "D:\MDTProduction"
#Mounts PSDrive
If (!(Test-Path MDT:)) { New-PSDrive -Name MDT -Root $deploymentShare -PSProvider MDTPROVIDER }
 
#Loops until sequence is done
do{
    $temp = Get-MDTMonitorData -Path MDT:|Where-Object { $_.Name -eq $target }
    write-host "Process still running on $target Status: $($temp.DeploymentStatus)" -ForegroundColor Green
    Start-Sleep -Seconds 30     
}until($temp.DeploymentStatus -eq 3 -or $temp.DeploymentStatus -eq 2)

Switch($temp.DeploymentStatus){ 
2 {
    Write-Host "Process Failed" -ForegroundColor Red
    Send-XDslackmsg -slackurl $slackChannelurl -msg "$target deploy failed"
    throw "MDT DEPLOY FAILED"
} 
3 {
    Write-Host "Process Completed" -ForegroundColor Green
    Send-XDslackmsg -slackurl $slackChannelurl -msg "$target deploy SUCCESS"
        do{
        write-host "Waiting for machine to power down"
        Start-Sleep -Seconds 15
        $vm = get-vm $target
        }
        Until($vm.PowerState -eq "PoweredOff")
        #take snap of VM
        New-Snapshot -vm $vm -Name "TOXD"

} 
Default {
    Write-Host "Unknown Status"} 
}

Disconnect-VIServer -Confirm:$false

#outputvars
$output = @{
"vm"=$VMNAME;
"slackurl"=$slackurl;
}

$object = New-Object –TypeName PSObject –Prop $output
#creates temp file for other jenkins stage on DDC
$object|Export-Csv "C:\temp\frombuild.csv" -Force -NoTypeInformation