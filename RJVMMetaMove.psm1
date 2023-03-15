# Todo:
# Create a 'Migrate' function
#   1. Export (Get-VMMetadata) tags/attributes
#   2. Move
#   3. Import (Set-VMMetadata) tags/attributes
#   4. Check and give update
# Give all the functions and 'RJ' prefix to make them unique.
# Encryption/disk policy (basically, if datastore is encrypted OR the specific VM is encrypted, its 'yes')
# This needs to be renamed to cover the generic purpose of the 3 modules here (get-vmmetadata, get-vmcoredata, set-vmmetadata).
# Create module manifest (.psd1)
# Learn how to keep function parameters private (or not) and whether to pass an object or text is the right thing to do.

function Get-RJVMMetaData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )
    
    # Get the virtual machine
    $VM = Get-VM -Name $VMName
    $CustomAttrList = Get-CustomAttribute -Server $VM.Uid.Split(":")[0].Split("@")[1]

    If ($VM) {
        $output = @()

        # Create an object to hold the custom attributes
        $CustomObject = New-Object -TypeName PSObject

        # Multiples
        # Loop through each custom attribute and add it to the object
        $CustomAttributes = $VM.ExtensionData.CustomValue
        foreach ($attribute in $CustomAttributes) {
            if ($attribute.Value){
                $CustomObject = New-Object -TypeName PSObject
                $CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name
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
            $CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name
            $CustomObject | Add-Member -Name "Tag" -MemberType NoteProperty -value $Tag.Tag.name
            $output += $CustomObject
        }
        return $output
    }
    else {
        Write-Error "Virtual machine not found."
    }
}

function Get-RJVMCoreData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )
    
    # Get the virtual machine
    $VM = Get-VM -Name $VMName

    if ($VM) {
        # Get all custom attributes for the virtual machine
        
        $output = @()

        # Create an object to hold the custom attributes
        $vcserver = $VM.Uid.Split(":")[0].Split("@")[1]
        $CustomObject = New-Object -TypeName PSObject

        # --singles
        $CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name # yes
        $CustomObject | Add-Member -Name "VMCreated" -MemberType NoteProperty -value $VM.extensiondata.config.createdate # yes
        $CustomObject | Add-Member -Name "VMVersion" -MemberType NoteProperty -value $VM.extensiondata.config.version # yes
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
            $CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name
            $CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $HardDisk.Name
            #$CustomObject | Add-Member -Name "DiskEncryptionStatus" -MemberType NoteProperty -value $null
            $CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value "S:$($HardDisk.StorageFormat) / P:$($HardDisk.Persistence) / T:$($HardDisk.DiskType)"
            $CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value ([math]::Round($HardDisk.CapacityGB,2))
            $CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $Datastore
            #$CustomObject | Add-Member -Name "DatastoreEncryptionStatus" -MemberType NoteProperty -value $null
            $output += $CustomObject
        }

        # Loop through each Network and add it to the object
        $NetworkAdapters = Get-NetworkAdapter -VM $VM
        foreach ($NetworkAdapter in $NetworkAdapters){
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name
            $CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value $NetworkAdapter.NetworkName
            $output += $CustomObject
        }

        return $output
    }
    else {
        Write-Error "Virtual machine not found."
    }
}

function Set-RJVMMetaData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject] $VMName,
        [Parameter(Mandatory = $true)]
        [psobject] $TargetVM,
        [Parameter(Mandatory = $true)]
        [object] $TargetVC,
        [Parameter(Mandatory = $true)]
        [object] $VMMetaDataItems
    )

    # This section below will become the 'put-VMMetaData' function.
    foreach ($VMMetaDataItem in $VMMetaDataItems){
        if ($VMMetaDataItem.AttributeName){
            $TargetVM | Set-Annotation -CustomAttribute $VMMetaDataItem.AttributeName -Value $VMMetaDataItem.AttributeValue
            }
        
        if ($VMMetaDataItem.Tag){
            New-TagAssignment -Tag $VMMetaDataItem.Tag -Entity $TargetVM -Server $TargetVC # $VMMetaDataItem.Tag
        }
    }
}

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

        $Datastores = get-datastore -vmhost $oVMHost | Sort-Object CapacityGB -Descending
        foreach ($Datastore in $Datastores) {
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Parameter" -MemberType NoteProperty -value "Datastore"
            $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value "$($Datastore.Name) / ($([int]$Datastore.CapacityGB)GB)"
            $output += $CustomObject
        }

        # #get-virtualportgroup -vmhost $oVMHost | format-table -autosize -property @{L='Virtual Port Group';E={$_.Name}}
        # $VirtualPortGroups = get-virtualportgroup -vmhost $oVMHost
        # foreach ($VirtualPortGroup in $VirtualPortGroups) {
        #     $CustomObject = New-Object -TypeName PSObject
        #     $CustomObject | Add-Member -Name "Parameter" -MemberType NoteProperty -value "VirtualPortGroup"
        #     $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value "$($VirtualPortGroup.Name)"
        #     $output += $CustomObject
        # }

        #get-vdswitch -VMHost $oVMHost | format-table -autosize -property @{L='vNetwork dSwitch';E={$_.Name}}
        $vdSwitches = get-vdswitch -VMHost $oVMHost
        foreach ($vdSwitch in $vdSwitches) {
            $CustomObject = New-Object -TypeName PSObject
            $CustomObject | Add-Member -Name "Parameter" -MemberType NoteProperty -value "vdSwitch"
            $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value "$($vdSwitch.Name)"
            $output += $CustomObject
            $vdPortGroups = Get-VDPortgroup -vdSwitch $vdSwitch | Sort-Object Name
            foreach ($vdPortGroup in $vdPortGroups) {
                $CustomObject = New-Object -TypeName PSObject
                $CustomObject | Add-Member -Name "Parameter" -MemberType NoteProperty -value "vdPortGroup"
                $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value "$($vdPortGroup.Name)"
                $output += $CustomObject
            }
        }
        return $output
    }
    else {
         Write-Error "VmHost not found."
    }
}
