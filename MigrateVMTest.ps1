# Script to test the migrate-xvc function.
# initially, do all the hard work here, later, put it all in a function with 3 parameters (VM, sourcevc, destvc)

import-Module -Name vmware.powercli
import-Module .\export-vmmetadata.psm1

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$credential = Get-Credential
$SourceVC = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$DestinationVC = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
$VMtoMove = "TestVM"

$VMMetaDataItems = get-VMMetaData -VMName $VMtoMove

# This section below will become the 'put-VMMetaData' function.
foreach ($VMMetaDataItem in $VMMetaDataItems){
    write-host $VMMetaDataItem |fl
}


Disconnect-VIServer -Server $SourceVC -Confirm:$false
Disconnect-VIServer -Server $DestinationVC -Confirm:$false
