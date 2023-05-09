$excelpkg = open-excelpackage -path "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\RJVMMetaMove\Exports\vmHostExport 2023-05-09_14.35.xlsx"
set-excelcolumn -worksheet $excelpkg.workbook.worksheets['vmHostExport'] -column 14 -numberformat 'Number'
close-excelpackage -excelpackage $excelpkg

