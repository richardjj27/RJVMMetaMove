# RJVMMetaMove

The project contains three scripts and one module containing four functions.

## *ExportHosts.ps1*
Create a report in Excel for all VM hosts from multiple vCenter servers as listed in VCList.csv.

- `$WorkingFolder` - The path of where your export will go.
- `$XLOutputs` - A CSV list of fields to be exported, their order and formatting.
- `$XLOutputFile` - Name and location of output files.
- `$VCenterList` - List of vCenter servers to be processed.  The script will authenticate to all of these.

## *ExportVMs.ps1*
Create a report in Excel for all VM guests from multiple vCenter servers as listed in VCList.csv.

- `$WorkingFolder` - The path of where your export will go.
- `$XLOutputs` - A CSV list of fields to be exported, their order and formatting.
- `$XLOutputFile` - Name and location of output file.
- `$VCenterList` - List of vCenter servers to be processed.  The script will authenticate to all of these.

## *MigrateVMs.ps1*
Migrate a list of VMs from one cluster to another (including cross vCenter) preserving tags and custom attributes.

- `$WorkingFolder` - The path of where your output and logs will go, plus your list of servers to be migrated.
- `$LogFile` - Output log file.
- `$VCenterList` -   The script will authenticate to all of these.
- `$VMListFile` - CSV list of VMs to be moved. (SourceVM,TargetVMHost,TargetNetwork,TargetDatastore)

## *RJVMMetaDataMove.psm1*
### *Get-RJVMMetaData*
`VMName` The VM guest to be queried.<br>

Get multiple useful attributes and settings for the specified VM.

### *Get-RJVMHostData*
`VNHost` The VM host to be queried.<br>

Get multiple useful attributes and settings for the specified VM host.

### *Set-RJVMCustomAttributes*
`TargetVM` Write attributes to this VM.<br>
`TargetVC` ...and this VC (is this needed?)<br>
`VNNetadata` Write this metadata array to the above VM.<br>

- Set custom attributes for a specific VM derived from previous Get-RJVMMetaData.

### *Write-RJLog*
`LogFile`String (or is it an object) to write log entries to.<br>
`Severity`The severity of the log entry (0 = information, 1 = debug, 2 = warning, 3 = error)<br>
`LogText`The test to be written.<br>

- Write a formatted log text to the file specified in $LogFile with timings.

## *Dependent Files*
### *ExcelOutput.csv*
- Defines the selection, order, formatting and notes for each exported field.
- Target 1 is for the VM hosts report.
- Target 2 is for the VM guests report.

### *$VMListFile*
- Defines the list of VMs to be migrated.  This needs to provide the following.
- `SourceVM` - The machine name to be moved.
- `TargetVMHost` - The target VM Host - just pick any host from within the target cluster and let the destination DRS keep things balanced.
- `TargetNetwork` - The target network.
- `TargetDatastore` - The target datastore.

### *VCList.csv*
- Defines the list of vCenter Servers (their FQDN) to be interrogated.
