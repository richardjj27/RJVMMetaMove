# Todo:
# Create a 'Set-VMMetadata' function
# Create a 'Migrate' function
#   1. Export (Get-VMMetadata) tags/attributes
#   2. Move
#   3. Import (Set-VMMetadata) tags/attributes
#   4. Check and give update
# Encryption/disk policy (basically, if datastore is encrypted OR the specific VM is encrypted, its 'yes')

function Get-VMMetaData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )
    
    # Get the virtual machine
    $VM = Get-VM -Name $VMName
    $CustomAttrList = Get-CustomAttribute -Server $VM.Uid.Split(":")[0].Split("@")[1]

    If ($VM) {
        # Get all custom attributes for the virtual machine

        $output = @()
        #$vcserver = $VM.Uid.Split(":")[0].Split("@")[1]

        # Create an object to hold the custom attributes
        $CustomObject = New-Object -TypeName PSObject
        #$CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $VM.name # yes
        #$CustomObject | Add-Member -Name "AttributeKey" -MemberType NoteProperty -value $null
        #$CustomObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $null
        #$CustomObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $null
        #$CustomObject | Add-Member -Name "Tag" -MemberType NoteProperty -value $null
        #$output += $CustomObject

        # Multiples
        # Loop through each custom attribute and add it to the object
        $CustomAttributes = $VM.ExtensionData.CustomValue
        foreach ($attribute in $CustomAttributes) {
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
        return $output
    }
    else {
        Write-Error "Virtual machine not found."
    }
}

function Get-VMCoreData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )
    
    # Get the virtual machine
    $VM = Get-VM -Name $VMName
    #$CustomAttrList = Get-CustomAttribute -Server $VM.Uid.Split(":")[0].Split("@")[1]

    if ($VM) {
        # Get all custom attributes for the virtual machine
        
        $output = @()
        $vcserver = $VM.Uid.Split(":")[0].Split("@")[1]

        # Create an object to hold the custom attributes
        $CustomObject = New-Object -TypeName PSObject

        #$CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $null
        #$CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value $null
        #$CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $null
        ##$CustomObject | Add-Member -Name "DiskDatastoreEncryptionStatus" -MemberType NoteProperty -value $null
        #$CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value $null
        #$CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value $null

        # --singles
        $CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $VM.name # yes
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
        # Loop through each disk and add it to the object.
        $HardDisks = get-HardDisk -VM $VM
        foreach ($HardDisk in $HardDisks) {
            $Datastore = ($HardDisk.Filename | select-string '(?<=\[)[^]]+(?=\])').matches.value 
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $VM.name
            $CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $HardDisk.Name
            #$CustomObject | Add-Member -Name "DiskEncryptionStatus" -MemberType NoteProperty -value $null
            $CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value "S:$($HardDisk.StorageFormat) / P:$($HardDisk.Persistence) / T:$($HardDisk.DiskType)"
            $CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value $HardDisk.CapacityGB
            $CustomObject | Add-Member -Name "Datastore" -MemberType NoteProperty -value $Datastore
            #$CustomObject | Add-Member -Name "DatastoreEncryptionStatus" -MemberType NoteProperty -value $null
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

$output = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\vCenterExport\vCenterExport.xlsx"

# delete old file
remove-item $output -force -ErrorAction SilentlyContinue

# Connect to the vCenter Server
$credential = Get-Credential

$VC1 = Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $credential
$VC2 = Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $credential
$VC3 = Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $credential

$VirtualMachines = get-VM -server $VC1 # | where-object NumCpu -ge 18
$VirtualMachines += get-VM -server $VC2
$VirtualMachines += get-VM -server $VC3

# create an empty XLSX doc with all the headings
$CustomObject = New-Object -TypeName PSObject
$CustomObject | Add-Member -Name "Server" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "AttributeKey" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Tag" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $null
#$CustomObject | Add-Member -Name "DiskEncryptionStatus" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $null
#$CustomObject | Add-Member -Name "DiskDatastoreEncryptionStatus" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Host" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "HostVersion" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "HostBuild" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Datacenter" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "ResourcePool" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "MemoryGB" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "CPU" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Powerstate" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "GuestOS" -MemberType NoteProperty -value $null
$CustomObject | Add-Member -Name "Snapshot" -MemberType NoteProperty -value $null
$CustomObject | export-excel $output -append -freezetoprow -autofilter -autosize

$count = 0
foreach ($VirtualMachine in $VirtualMachines){
    $completed = [math]::Round((($count/$VirtualMachines.count) * 100), 2)
    get-VMMetaData -VMName $VirtualMachine.Name | export-excel $output -append -freezetoprow -autofilter -autosize
    get-VMCoreData -VMName $VirtualMachine.Name | export-excel $output -append -freezetoprow -autofilter -autosize
    Write-Progress -Activity "Scan Progress" -Status "$completed% completed." -PercentComplete $completed
    $count++
}

Disconnect-VIServer -Server $VC1 -Confirm:$false
Disconnect-VIServer -Server $VC2 -Confirm:$false
Disconnect-VIServer -Server $VC3 -Confirm:$false