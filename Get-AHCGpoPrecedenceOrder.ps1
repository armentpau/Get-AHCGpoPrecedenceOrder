function Get-AHCGpoPrecedenceOrder
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]$Target
	)
	
	$TargetSplitArray = $target.tostring().tolower() -split ","
	$domainName = "dc=$((Get-ADDomain).name.tostring().tolower())"
	$domainIndex = [array]::IndexOf($TargetSplitArray, $domainName)
	$OUArray = @()
	$counter = 0
	do
	{
		$OUArray += New-Object -TypeName System.Management.Automation.PSObject -Property @{
			"Order"   = $counter + 1
			"OUData"  = Get-ADobject -Identity $($TargetSplitArray[$counter .. $(($TargetSplitArray | measure-object).count - 1)] -join ",")
			"Links"   = Get-GPInheritance -Target $($TargetSplitArray[$counter .. $(($TargetSplitArray | measure-object).count - 1)] -join ",")
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
				"GPOID"    = $_.gpoid
				"DisplayName" = $_.displayname
				"Enabled"  = $_.enabled
				"Enforced" = $_.enforced
				"Target"   = $_.target
				"Order"    = $gpoCounter
			}
			$gpoCounter++
		}
	}
	
	foreach ($item in ($OUArray | Sort-Object -Property order))
	{
		$item.links.gpolinks | where-object{ $_.enforced -eq $false } | Where-Object{ $_.enabled -eq $true } | Sort-Object -Property order | ForEach-Object{
			$gpoOrderArray += New-Object -TypeName System.Management.Automation.PSObject -Property @{
				"GPOID"	    = $_.gpoid
				"DisplayName" = $_.displayname
				"Enabled"   = $_.enabled
				"Enforced"  = $_.enforced
				"Target"    = $_.target
				"Order"	    = $gpoCounter
			}
			$gpoCounter++
		}
	}
	return $gpoOrderArray
}