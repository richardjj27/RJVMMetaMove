# Script to test the export-vmmmetadata function by exporting all VMs.

import-Module -Name vmware.powercli
import-Module -Name ImportExcel
import-Module .\RJVMMetaMove.psm1

#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$output = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\vmHostExport [F] $(get-date -Format "yyyy-MM-dd_HH.mm").xlsx"

# Silently delete old file
#remove-item $output -force -ErrorAction SilentlyContinue

# Connect to the vCenter Server
$credential = Get-Credential
$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
$VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential

$allVMHosts = get-VMHost -server $VC1
$allVMHosts += get-VMHost -server $VC2
$allVMHosts += get-VMHost -server $VC3

foreach ($allVMHost in $allVMHosts){
    Get-RJVMHostData -VMHost $allvmhost.Name | export-excel $output -append -freezetoprow -autofilter -autosize
}

Disconnect-VIServer -Server * -Confirm:$false