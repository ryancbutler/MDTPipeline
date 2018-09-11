Add-PSSnapin "Citrix*" -Verbose

#Machines Catalog
$MachineCatalog = "Win 10 Test"

function Send-XDslackmsg {
<#
.SYNOPSIS
   Sends message to Slack incoming webhook URL
.DESCRIPTION
   Sends message to Slack incoming webhook URL
.PARAMETER slackurl
   Slack web incoming hook url
.PARAMETER msg
   Message to send to URL
.PARAMETER emoji
    Emoji to use as avatar to send message
.EXAMPLE
   send-xdslackmsg -slackurl "https://myurl.com" -msg "Send this" -emoji ":joy:"
#>
[cmdletbinding()]
param(
[Parameter(Mandatory=$true)][string]$slackurl, 
[Parameter(Mandatory=$true)][string]$msg, 
$emoji=":building_construction:")
begin{
    Write-Verbose "BEGIN: $($MyInvocation.MyCommand)"
    $slackmsg = @{text=$msg;icon_emoji=$emoji}|ConvertTo-Json
}
process {
    Invoke-RestMethod -Uri $slackurl -Body $slackmsg -Method Post|Write-Verbose
}
end{Write-Verbose "END: $($MyInvocation.MyCommand)"}
}

try{
$imports = Import-Csv "\\mdt01\c$\temp\frombuild.csv"
}
catch
{
    throw "CAN'T IMPORT CSV"
}

#Sends Status
send-xdslackmsg -slackurl $env:slackChannelurl -msg "Upgrading $MachineCatalog!" -emoji ":joy:"

#Starts MC upgrade process
$ProvScheme = Set-ProvSchemeMetadata -Name 'ImageManagementPrep_DoImagePreparation' -ProvisioningSchemeName $MachineCatalog  -Value 'True' -Verbose
$pub = Publish-ProvMasterVMImage -ProvisioningSchemeName $MachineCatalog -MasterImageVM "XDHyp:\HostingUnits\VLAN2\$($imports.vm).vm\TOXD.snapshot" -Verbose

#Reboots MC
Start-BrokerRebootCycle -InputObject $MachineCatalog -RebootDuration 0 -WarningRepeatInterval 0 -Verbose

#Sends slack message
send-xdslackmsg -slackurl $env:slackChannelurl -msg "$MachineCatalog Upgrade $($pub.TaskState)" -emoji ":joy:"
