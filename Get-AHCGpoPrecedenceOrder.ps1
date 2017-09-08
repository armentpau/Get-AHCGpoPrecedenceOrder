<#
	.SYNOPSIS
		Gets the inheritance Precedence order of GPOs
	
	.DESCRIPTION
		Gets the inheritance precedence order of GPOs.  This returns the real order of the Precedence instead of the order returned by get-GPInheritance
	
	.PARAMETER Target
		Specifies the domain or the OU for which to retrieve the Group Policy inheritance information by its LDAP distinguished name. For example, the "MyOU" organizational unit in the contoso.com domain is specified as "ou=MyOU,dc=contoso,dc=com".
	
	.PARAMETER Server
		Specifies the name of the domain controller that this cmdlet contacts to complete the operation. You can specify either the fully qualified domain name (FQDN) or the host name. For example:
		
		FQDN: DomainController1.sales.contoso.com
		Host Name: DomainController1
		
		If you do not specify the name by using the Server parameter, a random server is selected
	
	.PARAMETER Domain
		Specifies the domain for this cmdlet. You must specify the fully qualified domain name (FQDN) of the domain (for example: sales.contoso.com).

For the Get-GPInheritance cmdlet, this is typically the domain of the container (domain or OU) for which you want to retrieve inheritance information. If the specified domain is different than the domain of the container, a trust must exist between the two domains.
	
	.EXAMPLE
		PS C:\> Get-AHCGpoPrecedenceOrder -Target 'Value1'
	
	.NOTES
		Additional information about the function.
#>
function Get-AHCGpoPrecedenceOrder
{
	[CmdletBinding(PositionalBinding = $false,
				   SupportsPaging = $false,
				   SupportsShouldProcess = $false)]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $false,
				   Position = 0)]
		[ValidateNotNullOrEmpty()]
		[Alias('Path')]
		[string[]]$Target,
		[Parameter(ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $false,
				   Position = 1)]
		[Alias('dc')]
		[string]$Server,
		[Parameter(ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $false,
				   Position = 2)]
		[string]$Domain
	)
	
	BEGIN
	{
		if (([string]::IsNullOrEmpty($Server)))
		{
			if ([string]::IsNullOrEmpty($Domain))
			{
				$Domain = (get-addomain).dnsroot
			}
			$Server = (Get-ADDomainController -DomainName $Domain -Discover).hostname
		}
		$returnData = @()
	}
	PROCESS
	{
		$returnData += foreach ($ouTarget in $Target)
		{
			Write-Verbose $ouTarget
			$TargetSplitArray = $ouTarget.tostring().tolower() -split ","
			$domainName = "dc=$((Get-ADDomain -Server $Server).name.tostring().tolower())"
			$domainIndex = [array]::IndexOf($TargetSplitArray, $domainName)
			$OUArray = @()
			$counter = 0
			do
			{
				Write-Verbose "Working with ou $($($TargetSplitArray[$counter .. $(($TargetSplitArray | measure-object).count - 1)] -join ","))"
				$OUArray += New-Object -TypeName System.Management.Automation.PSObject -Property @{
					"Order"	       = $counter + 1
					"OUData"	   = Get-ADobject -Identity $($TargetSplitArray[$counter .. $(($TargetSplitArray | measure-object).count - 1)] -join ",") -Server $Server
					"Links"	       = Get-GPInheritance -Target $($TargetSplitArray[$counter .. $(($TargetSplitArray | measure-object).count - 1)] -join ",") -Server $Server
				}
				$counter++
			}
			while ($counter -le $domainIndex)
			$gpoOrderArray = @()
			$gpoCounter = 1
			foreach ($item in ($OUArray | Sort-Object -Property order -Descending))
			{
				$item.links.gpolinks | where-object{ $_.enforced -eq $true } | Where-Object{ $_.enabled -eq $true } | Sort-Object -Property order | ForEach-Object{
					$gpoOrderArray += New-Object -TypeName System.Management.Automation.PSObject -Property @{
						"GPOID"		    = $_.gpoid
						"DisplayName"   = $_.displayname
						"Enabled"	    = $_.enabled
						"Enforced"	    = $_.enforced
						"Target"	    = $_.target
						"Order"		    = $gpoCounter
					}
					$gpoCounter++
				}
			}
			
			foreach ($item in ($OUArray | Sort-Object -Property order))
			{
				$item.links.gpolinks | where-object{ $_.enforced -eq $false } | Where-Object{ $_.enabled -eq $true } | Sort-Object -Property order | ForEach-Object{
					$gpoOrderArray += New-Object -TypeName System.Management.Automation.PSObject -Property @{
						"GPOID"	      = $_.gpoid
						"DisplayName" = $_.displayname
						"Enabled"	  = $_.enabled
						"Enforced"    = $_.enforced
						"Target"	  = $_.target
						"Order"	      = $gpoCounter
					}
					$gpoCounter++
				}
			}
			New-Object -TypeName System.Management.Automation.PSObject -Property @{
				"OU"   = $($ouTarget.ToString())
				"GPOData" = $gpoOrderArray
			}
			
		}
	}
	END
	{
		return $returnData
	}
}