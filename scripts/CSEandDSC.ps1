Add-AzureRmAccount -identity

# Call Azure Resource Manager to get the service principal ID for the VM's MSI. 
$vmInfoPs = Get-AzureRMVM -ResourceGroupName "rgIAC" -Name "IaCLab"
$spID = $vmInfoPs.Identity.PrincipalId
echo "The MSI service principal ID is $spID"

# Install IIS on VM1 via CSE
$PublicSettings = '{"commandToExecute":"powershell Add-WindowsFeature Web-Server"}'

Set-AzureRmVMExtension -ExtensionName "IIS" -ResourceGroupName $rgName -VMName $vm1.Name `
  -Publisher "Microsoft.Compute" -ExtensionType "CustomScriptExtension" -TypeHandlerVersion 1.4 `
  -SettingString $PublicSettings -Location $location

# Install IIS on VM2 via DSC Push
$PublicSettings = '{"ModulesURL":"https://github.com/Azure/azure-quickstart-templates/raw/master/dsc-extension-iis-server-windows-vm/ContosoWebsite.ps1.zip", "configurationFunction": "ContosoWebsite.ps1\\ContosoWebsite", "Properties": {"MachineName": "WEB02"} }'

Set-AzureRmVMExtension -ExtensionName "DSC" -ResourceGroupName $rgName -VMName $vm2.Name `
  -Publisher "Microsoft.Powershell" -ExtensionType "DSC" -TypeHandlerVersion 2.19 `
  -SettingString $PublicSettings -Location $location
