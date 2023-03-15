function Get-RJVMHostData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject] $VMHost
    )

    $oVMHost = get-vmhost -name $VMHost

    if($oVMHost){

        $CustomObject = New-Object -TypeName PSObject
        $output = @()

        #get-datastore -vmhost $oVMHost | format-table -autosize -property @{L='Datastore Name';E={$_.Name}},CapacityGB

        $Datastores = get-datastore -vmhost $oVMHost
        foreach ($Datastore in $Datastores) {
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Parameter" -MemberType NoteProperty -value "Datastore"
            $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value "$($Datastore.Name) / ($([int]$Datastore.CapacityGB)GB)"
            $output += $CustomObject
        }

        #get-virtualportgroup -vmhost $oVMHost | format-table -autosize -property @{L='Virtual Port Group';E={$_.Name}}
        $VirtualPortGroups = get-virtualportgroup -vmhost $oVMHost
        foreach ($VirtualPortGroup in $VirtualPortGroups) {
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Parameter" -MemberType NoteProperty -value "VirtualPortGroup"
            $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value "$($VirtualPortGroup.Name)"
            $output += $CustomObject
        }

        #get-vdswitch -VMHost $oVMHost | format-table -autosize -property @{L='vNetwork dSwitch';E={$_.Name}}
        $vdSwitches = get-vdswitch -VMHost $oVMHost
        foreach ($vdSwitch in $vdSwitches) {
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Parameter" -MemberType NoteProperty -value "vdSwitch"
            $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value "$($vdSwitch.Name)"
            $output += $CustomObject
        }

        return $output
    }
    else {
         Write-Error "vmHost not found."
    }
}

# Add this to the function as Get-RJHostInfo

import-Module -Name vmware.powercli
#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
$credential = Get-Credential
Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential

$a = Get-RJVMHostData -VMHost "su-gbcp-vxrail01.emea.wdpr.disney.com"

Disconnect-VIServer -Server * -Confirm:$false