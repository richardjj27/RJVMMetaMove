# Add this to the function as Get-RJHostInfo

import-Module -Name vmware.powercli
#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$credential = Get-Credential

#### Migrate the VM

# code to find datastore, portgroup and cSwitch
Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$myvmhost = get-vmhost -name "su-gbcp-vxrail01.emea.wdpr.disney.com"
get-datastore -vmhost $myvmhost | format-table -autosize -property @{L='Datastore Name';E={$_.Name}},CapacityGB
get-virtualportgroup -vmhost $myvmhost | format-table -autosize -property @{L='Virtual Port Group';E={$_.Name}}
get-vdswitch -VMHost $myvmhost | format-table -autosize -property @{L='vNetwork dSwitch';E={$_.Name}}

Disconnect-VIServer -Server * -Confirm:$false