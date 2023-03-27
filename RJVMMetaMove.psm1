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
# Make the multivalue function values return an array. 
# Add allocated license key information to hosts
# Try to find a way of getting some kind of CPU compatibility information.
# Need to test snapshots output
# pluralise the multiline output values (where appropriate) - or not?
# Try to find a way to switch on wordwrap for the appropraite columns

function Get-RJVMMetaData {
    <#
    .SYNOPSIS
        A function to collect metadata from a spefified VM.

    .DESCRIPTION
        The function returns an array object containing the VM's Tags and attributes.

    .EXAMPLE
        $VMData = Get-RJVMMetaData -VMName "TheBigServer"
    #>

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

function Get-RJVMMetaData2 {
    <#
    .SYNOPSIS
        A function to collect metadata from a spefified VM.

    .DESCRIPTION
        The function returns an array object containing the VM's Tags and attributes.

    .EXAMPLE
        $VMData = Get-RJVMMetaData -VMName "TheBigServer"
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )
    
    # Get the virtual machine
    $VM = Get-VM -Name $VMName
    $CustomAttrList = Get-CustomAttribute -Server $VM.Uid.Split(":")[0].Split("@")[1]
    $CustomObject = New-Object -TypeName PSObject

    If ($VM) {
        #$output = @()

        # Create an object to hold the custom attributes
        $vcserver = $VM.Uid.Split(":")[0].Split("@")[1]

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
        $CustomObject | Add-Member -Name "CPUCores" -MemberType NoteProperty -value $vm.NumCpu # yes
        $CustomObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $vm.extensiondata.guest.toolsversion # yes
        $CustomObject | Add-Member -Name "Folder" -MemberType NoteProperty -value $vm.folder # yes
        $CustomObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $vm.notes # check
        $CustomObject | Add-Member -Name "Powerstate" -MemberType NoteProperty -value $vm.powerstate # yes
        $CustomObject | Add-Member -Name "GuestOS" -MemberType NoteProperty -value $vm.extensiondata.guest.guestfullname # yes
        $CustomObject | Add-Member -Name "Snapshots" -MemberType NoteProperty -value ($vm | get-snapshot).created # yes
        #$output += $CustomObject


        #### To do ####

        # -- multiples
        # Loop through each disk and add it to the object.
        
        #$outputDiskName = @()
        $outputDiskLayout = @()
        #$outputDiskSizeGB = @()
        $outputDiskDatastore = @()
        
        $HardDisks = get-HardDisk -VM $VM
        
        foreach ($HardDisk in $HardDisks) {
            # $Datastore = ($HardDisk.Filename | select-string '(?<=\[)[^]]+(?=\])').matches.value 
            # #$CustomObject = New-Object -TypeName PSObject
            # #$CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name
            # $CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $HardDisk.Name
            # #$CustomObject | Add-Member -Name "DiskEncryptionStatus" -MemberType NoteProperty -value $null
            # $CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value "S:$($HardDisk.StorageFormat) / P:$($HardDisk.Persistence) / T:$($HardDisk.DiskType)"
            # $CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value ([math]::Round($HardDisk.CapacityGB,2))
            # $CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $Datastore
            # #$CustomObject | Add-Member -Name "DatastoreEncryptionStatus" -MemberType NoteProperty -value $null
            # #$output += $CustomObject

            #$outputDiskName += $HardDisk.Name
            $outputDiskLayout += "S:$($HardDisk.StorageFormat) / P:$($HardDisk.Persistence) / T:$($HardDisk.DiskType)"
            #$outputDiskSizeGB += ([math]::Round($HardDisk.CapacityGB,2))
            $outputDiskDatastore += ($HardDisk.Filename | select-string '(?<=\[)[^]]+(?=\])').matches.value 
        }

        #$CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value $outputDiskName
        $CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value $outputDiskLayout
        #$CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value $outputDiskSizeGB
        $CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $outputDiskDatastore
        $CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value (get-HardDisk -VM $VM).Name
        #$CustomObject | Add-Member -Name "DiskLayout" -MemberType NoteProperty -value (get-HardDisk -VM $VM).Name
        $CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value (get-HardDisk -VM $VM).CapacityGB
        #$CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value (get-HardDisk -VM $VM).Name

        # # Loop through each Network and add it to the object
        
        # $outputNetworkAdapters = @()
        
        # $NetworkAdapters = Get-NetworkAdapter -VM $VM

        # foreach ($NetworkAdapter in $NetworkAdapters){
        # #     #$CustomObject = New-Object -TypeName PSObject
        # #     #$CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name
        # #     $CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value $NetworkAdapter.NetworkName
        # #     #$output += $CustomObject
        # $outputNetworkAdapters += $NetworkAdapter.NetworkName
        # }

        # $CustomObject | Add-Member -Name "NetworkAdapters" -MemberType NoteProperty -value $outputNetworkAdapters
        $CustomObject | Add-Member -Name "NetworkAdapters" -MemberType NoteProperty -value (Get-NetworkAdapter -VM $VM).NetworkName

        # #### To do ####

        # Create an object to hold the custom attributes
        #$CustomObject = New-Object -TypeName PSObject
        #$CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name



        # Multiples & attributes which sometimes don't line up.
        # Loop through each custom attribute and add it to the object
        
        $outputCustomAttrKey = @()
        $outputCustomAttrName = @()
        $outputCustomAttrValue = @()
        
        $CustomAttributes = $VM.ExtensionData.CustomValue

        foreach ($attribute in $CustomAttributes) {
            if ($attribute.Value){
                $outputCustomAttrKey += $attribute.key
                $outputCustomAttrName += ($CustomAttrList |where-object{ $_.Key -eq $Attribute.Key}).Name
                $outputCustomAttrValue += $attribute.value
            }
        }
        
        $CustomObject | Add-Member -Name "AttributeKey" -MemberType NoteProperty -value $outputCustomAttrKey 
        $CustomObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $outputCustomAttrName
        $CustomObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $outputCustomAttrValue

        #$outputCustomTag = @()

        # Loop through each tag and add it to the object
        #$CustomTags = Get-TagAssignment -Entity $VM
        #foreach ($Tag in $CustomTags) {
        #    $outputCustomTag += $Tag.Tag.name
        #}

        $CustomObject | Add-Member -Name "AttributeTag" -MemberType NoteProperty -value (Get-TagAssignment -Entity $VM).Tag.Name
        # $CustomObject | Add-Member -Name "AttributeTag" -MemberType NoteProperty -value $outputCustomTag

        return $CustomObject
    }

    else {
        #Write-Error "Virtual machine not found."
        return $null
    }


}

function Get-RJVMCoreData {
    <#
    .SYNOPSIS
        A function to collect core data from a specified VM.
    .DESCRIPTION
        The function returns an array object containing the following VM data.
            * Data Created
            * Hardware Version
            * List of disks
            * Disk Name
            * Disk Layout
            * Disk Size (GB)
            * Disk Datastore
            * List of Network Adapters
            * vCenter
            * Host
            * Host Version
            * Folder
            * Data Center
            * Cluster
            * Resource Pool
            * Memory (GB)
            * CPU Cores
            * Tools Version
            * Notes
            * Power State
            * Guest OS
            * Snapshot Date    
    
    .EXAMPLE
        $VMData = Get-RJVMCoreData -VMName "TheBigServer"
    #>

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
        $CustomObject | Add-Member -Name "CPUCores" -MemberType NoteProperty -value $vm.NumCpu # yes
        $CustomObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $vm.extensiondata.guest.toolsversion # yes
        $CustomObject | Add-Member -Name "Folder" -MemberType NoteProperty -value $VM.folder # yes
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

# what is the difference between and [object] and a [psobject].
# should I be passing objects or just the text?
function Set-RJVMMetaData {
    <#
    .SYNOPSIS
        A function to import the tags and custom attributes for a specified VM based on the export from a previous Get-RJVMMetaData call.

    .DESCRIPTION
        More of what it does.

    .EXAMPLE
        Set-RJVMMetaData -VMName $VMtoMove -TargetVM $TargetVM -TargetVC $TargetVC -VMMetaDataItems $VMMetaDataItems
    #>

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
    <#
    .SYNOPSIS
        A function to return the key network and datastore data necessary for a Cross vCenter VM Migration.

    .DESCRIPTION
        Returns an array containing a specific host's available Datastore, Port Groups and Switches.

    .EXAMPLE
        $TheHost = Get-RJVMHostData -VMHost "TheVMHost"
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [psobject] $VMHost
    )

    $oVMHost = get-vmhost -name $VMHost

    if($oVMHost){

        $CustomObject = New-Object -TypeName PSObject
        #$output = @()

        $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value $oVMHost.Name
        $CustomObject | Add-Member -Name "State" -MemberType NoteProperty -value $oVMHost.ConnectionState
        $CustomObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value ($oVMHost.Uid.Split(":")[0].Split("@")[1])

        $CustomObject | Add-Member -Name "ParentCluster" -MemberType NoteProperty -value $oVMHost.parent
        $CustomObject | Add-Member -Name "Vendor" -MemberType NoteProperty -value $oVMHost.extensiondata.hardware.systeminfo.Vendor
        $CustomObject | Add-Member -Name "Model" -MemberType NoteProperty -value $oVMHost.extensiondata.hardware.systeminfo.Model
        if($oVMHost.ConnectionState -ne "NotResponding"){        
            $CustomObject | Add-Member -Name "SerialNumber" -MemberType NoteProperty -value ($oVMHost|get-esxcli).hardware.platform.get.invoke().enclosureserialnumber
        }
        $CustomObject | Add-Member -Name "NumCpu" -MemberType NoteProperty -value $oVMHost.NumCpu
        $CustomObject | Add-Member -Name "CryptoState" -MemberType NoteProperty -value $oVMHost.CryptoState
        $CustomObject | Add-Member -Name "Version" -MemberType NoteProperty -value $oVMHost.Version
        $CustomObject | Add-Member -Name "Build" -MemberType NoteProperty -value $oVMHost.Build
        $CustomObject | Add-Member -Name "MemoryTotalGB" -MemberType NoteProperty -value ([math]::Round($oVMHost.MemoryTotalGB,0))
        $CustomObject | Add-Member -Name "MaxEVCMode" -MemberType NoteProperty -value $oVMHost.MaxEVCMode
        $CustomObject | Add-Member -Name "ProcessorType" -MemberType NoteProperty -value $oVMHost.ProcessorType

        #get-datastore -vmhost $oVMHost | format-table -autosize -property @{L='Datastore Name';E={$_.Name}},CapacityGB

        $Datastores = get-datastore -vmhost $oVMHost | Sort-Object CapacityGB -Descending
        $outputDatastoreName = @()
        $outputDatastoreType = @()
        $outputDatastoreCapacity = @()

        foreach ($Datastore in $Datastores) {
            $outputDatastoreName += $Datastore.Name
            $outputDatastoreName += $Datastore.Type
            $outputDatastoreCapacity += ([math]::Round($Datastore.CapacityGB,0))
        }

        $CustomObject | Add-Member -Name "DatastoreName" -MemberType NoteProperty -value $outputDatastoreName
        $CustomObject | Add-Member -Name "DatastoreType" -MemberType NoteProperty -value $outputDatastoreType
        $CustomObject | Add-Member -Name "DatastoreCapacityGB" -MemberType NoteProperty -value $outputDatastoreCapacity

        #get-vdswitch -VMHost $oVMHost | format-table -autosize -property @{L='vNetwork dSwitch';E={$_.Name}}
        $vdSwitches = get-vdswitch -VMHost $oVMHost
        $outputVDPortGroup = @()

        foreach ($vdSwitch in $vdSwitches) {
            $vdPortGroups = Get-VDPortgroup -vdSwitch $vdSwitch | Sort-Object Name
            foreach ($vdPortGroup in $vdPortGroups) {
                $outputVDportGroup += $vdPortGroup.Name
            }
        }

        $CustomObject | Add-Member -Name "vdPortGroup" -MemberType NoteProperty -value $outputVDPortGroup

        return $CustomObject
    }
    else {
         Write-Error "VmHost not found."
    }
}
