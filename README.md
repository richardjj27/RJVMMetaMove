# RJVMMetaMove

The project contains three scripts and one module containing four functions.

## *ExportHosts.ps1*
Create a report in Excel for all VM hosts from multiple vCenter servers as listed in VCList.csv.

- `$XLOutputFile` - Name and location of output file.
- `$VCenterList` - List of vCenter servers to be processed.

## *ExportVMs.ps1*
Create a report in Excel for all VM guests from multiple vCenter servers as listed in VCList.csv.

- `$XLOutputFile` - Name and location of output file.
- `$VCenterList` - List of vCenter servers to be processed.

## *MigrateVMs.ps1*
Migrate a list of VMs from one cluster to another (including cross vCenter) preserving tags and custom attributes.

- `$LogFile` - Output log file.
- `$VCenterList` - List of vCenter servers to be processed. (Servers)
- `$VMListFile` - CSV list of VMs to be moved. (SourceVM,TargetVMHost,TargetNetwork,TargetDatastore)

## *RJVMMetaDataMove.psm1*
### *Get-RJVMMetaData*
`VMName` The VM guest to be queried.<br>
Get multiple useful attributes and settings for the specified VM.
- An explanation for each attribute is included in the notes tab of the output of ExportVMs.ps1 - todo.

### *Get-RJVMHostData*
`VNHost` The VM host to be queried.<br>
Get multiple useful attributes and settings for the specified VM host.
- An explanation for each attribute is included in the notes tab of the output of ExportHosts.ps1 - todo.

### *Set-RJVMCustomAttributes*
`TargetVM` Write attributes to this VM.<br>
`TargetVC` ...and this VC (is this needed?)<br>
`VNNetadata` Write this metadata array to the above VM.<br>
- Set custom attributes for a specific VM derived from previous Get-RJVMMetaData.

### *Write-RJLog*
`LogFile`String (or is it an object) to write log entries to.<br>
`Severity`The severity of the log entry (0 = information, 1 = debug, 2 = warning, 3 = error)<br>
`LogText`The test to be written.<br>
- Write timed, formatted log text to the file specified in $LogFile.

## *Dependent Files*
### *ExcelFormat.csv*
- Defines the selection, order, formatting and notes for each exported field.
- Target 1 is for the VM hosts report.
- Target 2 is for the VM guests report.

### *VCList.csv*
- Defines the list of vCenter Servers (their FQDN) to be interrogated.
