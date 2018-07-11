# Author: Naz Snidanko naz.snidanko@airvm.com
# Date Created: Jun 7, 2018
# Date Modified: 
# Version: 1.0
# Description: Hyalto usage reporting api test for allocationVDC

################################################
# Configure the variables below for the Hyalto
################################################
$RESTAPIServer = "api.hyalto-qa2.com"
#time format yyyy-mm-ddThh%3Amm%3Ass Note: use %3A to fill in blank spaces in http request
$startTime = "2018-07-03T14%3A00%3A00"
$endTime = "2018-07-05T14%3A00%3A00"
# REST api key
$Login = @{
	"accessKey" = "85.1fae4315-f50a-4c76-8213-1b9d79e43599"
    "secretKey" = "a6e81199-5318-4c29-ae47-01190958356e"
} | ConvertTo-Json
################################################
# Nothing to configure below this line - Starting the main function of the script
################################################
# Adding certificate exception to prevent API errors
################################################
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
################################################
# Building Hyalto API string & invoking REST API
################################################

$BaseAuthURL = "https://" + $RESTAPIServer + "/accountManagement/auth/token/"
$Type = "application/json"
# Authenticating with API
Try 
{
$SessionResponse = Invoke-RestMethod -Uri $BaseAuthURL -Method POST -Body $Login -ContentType $Type
}
Catch 
{
$_.Exception.ToString()
$error[0] | Format-List -Force
}

$token = $SessionResponse.accessToken


$BaseUsersURL = "https://" + $RESTAPIServer + "/accountManagement/accounts/"
$users = Invoke-RestMethod -Uri $BaseUsersURL -Method GET -Headers @{ Authorization = "$token" } -ContentType $Type

	Foreach ($user in $users)
	{
    echo "=====RECORD START=============================="
	echo "Customer name: $($user.companyName)"
	echo "Customer id: $($user.id)"
	#echo "Company name:"
	#echo $users.companyName
	$BaseServicesURL = "https://" + $RESTAPIServer + "/serviceOfferings/accounts/" + $user.id + "/services/"
	$Myservices = Invoke-RestMethod -Uri $BaseServicesURL -Method GET -Headers @{ Authorization = "$token" } -ContentType $Type
	
		Foreach ($Myservice in $Myservices)
			{
				If ( $Myservice.metaData.type -eq "allocationVDC" )
					{
					echo "------------------"
					echo "VDC name: $($Myservice.name)"
					echo "VDC ID: $($Myservice.id)"
					$BaseUsageURL = "https://" + $RESTAPIServer + "/solutions/usage/account/" + $user.id + "/raw?filter[Services_id]=" + $Myservice.id + "&filter[startTime]=" + $startTime + "&filter[endTime]=" + $endTime
	                $Myusages = Invoke-RestMethod -Uri $BaseUsageURL -Method GET -Headers @{ Authorization = "$token" } -ContentType $Type
						#reset values
						$RAMResult = @()
						$CPUResult = @()
						# extract RAM
						Foreach ($MyRam in $Myusages.services.properties.ram.changes)
						{
						# load adata into object
						$RAMResult += New-Object psobject -Property @{
                        Time = $MyRAM.timestamp
						Value = $MyRAM.value
						Unit = $MyRAM.unit_size
                        }

						}
						# extract CPU
						Foreach ($MyCPU in $Myusages.services.properties.compute.changes)
						{
						# load adata into object
						$CPUResult += New-Object psobject -Property @{
                        Time = $MyCPU.timestamp
						Value = $MyCPU.value
						Unit = $MyCPU.unit_size
                        }
						}
						#display combined
						echo "RAM Report:"
						echo $RAMResult | Measure-Object -Property Value -Minimum -Maximum -Average
						echo "CPU Report:"
						echo $CPUResult | Measure-Object -Property Value -Minimum -Maximum -Average
					}			
			}
	
	"=====RECORD END=============================="
	}