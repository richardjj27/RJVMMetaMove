# RJVMMetaMove

The project contains three wrapper scripts for the module containing four functions.

## *ExportHosts.ps1*
Create a report in Excel for all VM hosts from multiple vCenter servers as listed in VCList.csv.

- `$WorkingFolder` - The path of where your export will go.<br>
- `$XLOutputs` - A CSV list of fields to be exported, their order and formatting.<br>
- `$XLOutputFile` - Name and location of output files.<br>
- `$VCenterList` - List of vCenter servers to be processed.  The script will authenticate to all of these.<br>

## *ExportVMs.ps1*
Create a report in Excel for all VM guests from multiple vCenter servers as listed in VCList.csv.

- `$WorkingFolder` - The path of where your export will go.<br>
- `$XLOutputs` - A CSV list of fields to be exported, their order and formatting.<br>
- `$XLOutputFile` - Name and location of output file.<br>
- `$VCenterList` - List of vCenter servers to be processed.  The script will authenticate to all of these.<br>

## *MigrateVMs.ps1*
Migrate a list of VMs from one cluster to another (including cross vCenter) preserving tags and custom attributes.

- `$WorkingFolder` - The path of where your output and logs will go, plus your list of servers to be migrated.<br>
- `$LogFile` - Migration log file.<br>
- `$VCenterList` -   The script will authenticate to all of these.<br>
- `$VMListFile` - CSV list of VMs to be moved. (SourceVM,TargetVMHost,TargetNetwork,TargetDatastore)<br>

## *RJVMMetaDataMove.psm1*
### *Get-RJVMMetaData*
Get multiple useful attributes and settings for the specified VM.

`VMName` The VM guest to be queried.<br>

### *Get-RJVMHostData*
Get multiple useful attributes and settings for the specified VM host.

`VNHost` The VM host to be queried.<br>

### *Set-RJVMCustomAttributes*
Set custom attributes for a specific VM derived from previous Get-RJVMMetaData.

`TargetVM` Write attributes to this VM.<br>
`VNMetadata` Write this metadata array to the above VM.<br>

### *Write-RJLog*
Write a formatted log text to the file specified in $LogFile with timings.

`LogFile` Target for migration log files.<br>
`Severity` The severity of the log entry (0 = information, 1 = debug, 2 = warning, 3 = error)<br>
`LogText` The test to be written.<br>

## *Dependent Files*
### *ExcelOutput.csv*
- Defines the selection, order, formatting and notes for each exported field.<br>
- Target 1 is for the VM hosts report.<br>
- Target 2 is for the VM guests report.<br>

### *VCList.csv*
- Defines the list of vCenter Servers (their FQDN) to be interrogated.

### *$VMListFile* (specified in code)
- Defines the list of VMs to be migrated.  This needs to provide the following.
- `SourceVM` - The machine name to be moved.<br>
- `TargetVMHost` - The target VM Host - just pick any host from within the target cluster and let the destination DRS keep things balanced.<br>
- `TargetNetwork` - The target network.<br>
- `TargetDatastore` - The target datastore.<br>
