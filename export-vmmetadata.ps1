# Initial

function Get-VMMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )
    
    # Get the virtual machine
    $VM = Get-VM -Name $VMName
    $CustomAttrList = Get-CustomAttribute -Server $VM.Uid.Split(":")[0].Split("@")[1]

    if ($VM) {
        # Get all custom attributes for the virtual machine
        
        $output = @()
        $vcserver = $VM.Uid.Split(":")[0].Split("@")[1]

        # Create an object to hold the custom attributes
        $CustomObject = New-Object -TypeName PSObject
        $CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $VM.name # yes
        $CustomObject | Add-Member -Name "AttributeKey" -MemberType NoteProperty -value $null
        $CustomObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $null
        $CustomObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $null
        $CustomObject | Add-Member -Name "Tag" -MemberType NoteProperty -value $null
        $CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $null
        $CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value $null
        $CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $null
        #$CustomObject | Add-Member -Name "DiskDatastoreEncryptionStatus" -MemberType NoteProperty -value $null
        $CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value $null
        $CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value $null

        # --singles
        $CustomObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $vcserver # yes
        $CustomObject | Add-Member -Name "Host" -MemberType NoteProperty -value (get-vmhost -vm $vm).name # yes
        $CustomObject | Add-Member -Name "HostVersion" -MemberType NoteProperty -value (get-vmhost -vm $vm).version # yes
        $CustomObject | Add-Member -Name "HostBuild" -MemberType NoteProperty -value (get-vmhost -vm $vm).build # yes
        $CustomObject | Add-Member -Name "Datacenter" -MemberType NoteProperty -value (Get-Datacenter -Server $vcserver -vm $vm.name) # yes
        $CustomObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value (Get-Cluster -Server $vcserver -vm $vm.name) # yes
        $CustomObject | Add-Member -Name "ResourcePool" -MemberType NoteProperty -value (Get-ResourcePool -Server $vcserver -VM $VM) # yes
        $CustomObject | Add-Member -Name "MemoryGB" -MemberType NoteProperty -value $vm.memorygb # yes
        $CustomObject | Add-Member -Name "CPU" -MemberType NoteProperty -value $vm.NumCpu # yes
        $CustomObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $vm.extensiondata.guest.toolsversion # yes
        $CustomObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $vm.notes # check
        $CustomObject | Add-Member -Name "Powerstate" -MemberType NoteProperty -value $vm.powerstate # yes
        $CustomObject | Add-Member -Name "GuestOS" -MemberType NoteProperty -value $vm.extensiondata.guest.guestfullname # yes
        $CustomObject | Add-Member -Name "Snapshot" -MemberType NoteProperty -value ($vm | get-snapshot).created # yes
        $output += $CustomObject

        # -- multiples
        # Loop through each custom attribute and add it to the object
        $CustomAttributes = $VM.ExtensionData.CustomValue
        foreach ($Attribute in $CustomAttributes) {
            if ($attribute.Value){
                $CustomObject = New-Object -TypeName PSObject
                $CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $VM.name
                $CustomObject | Add-Member -Name "AttributeKey" -MemberType NoteProperty -value $attribute.key
                $CustomObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value ($CustomAttrList |where-object{ $_.Key -eq $Attribute.Key}).Name
                $CustomObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $attribute.value
                $output += $CustomObject
            }
        }

        # Loop through each tag and add it to the object
        $CustomTags = Get-TagAssignment -Entity $VM
        foreach ($Tag in $CustomTags) {
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $VM.name
            $CustomObject | Add-Member -Name "Tag" -MemberType NoteProperty -value $Tag.Tag
            $output += $CustomObject
        }

        # Loop through each disk and add it to the object.
        $HardDisks = get-HardDisk -VM $VM
        foreach ($HardDisk in $HardDisks) {
            $Datastore = ($HardDisk.Filename | select-string '(?<=\[)[^]]+(?=\])').matches.value 
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $VM.name
            $CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $HardDisk.Name
            $CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value "S:$($HardDisk.StorageFormat) / P:$($HardDisk.Persistence) / T:$($HardDisk.DiskType)"
            $CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $Datastore
            #$CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $HardDisk.Filename
            #$CustomObject | Add-Member -Name "DiskDatastoreEncryptionStatus" -MemberType NoteProperty -value $null
            $CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value $HardDisk.CapacityGB
            $output += $CustomObject
        }

        # Loop through each Network and add it to the object
        $NetworkAdapters = Get-NetworkAdapter -VM $VM
        foreach ($NetworkAdapter in $NetworkAdapters){
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $VM.name
            $CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value $NetworkAdapter.NetworkName
            $output += $CustomObject
        }

        return $output
    }
    else {
        Write-Error "Virtual machine not found."
    }
}

import-module -Name vmware.powercli
import-Module -Name ImportExcel
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$output = ".\output.xlsx"

# delete old file
remove-item $output -force -ErrorAction SilentlyContinue

# Connect to the vCenter Server
$credential = Get-Credential

$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
$VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential


$VirtualMachines = get-VM -server $VC1
$VirtualMachines += get-VM -server $VC2
$VirtualMachines += get-VM -server $VC3
# | where-object NumCpu -ge 18

$count = 0

foreach ($VirtualMachine in $VirtualMachines){
    $completed = [math]::Round((($count/$VirtualMachines.count) * 100), 2)

    get-VMMetadata -VMName $VirtualMachine | export-excel $output -append -freezetoprow -autofilter -autosize
    Write-Progress -Activity "Scan Progress" -Status "$completed% completed." -PercentComplete $completed
    $count += 1
}

Disconnect-VIServer -Server $VC1 -Confirm:$false
Disconnect-VIServer -Server $VC2 -Confirm:$false
Disconnect-VIServer -Server $VC3 -Confirm:$false