#requires -Version 1
$script:WriteLOGlogFile
$script:WriteLOGlogComp
$script:WriteLOGlogThread
$script:WriteLOGlogOutput
FUNCTION Write-LOG
{
	<#
		.SYNOPSIS
		Writes LOG messages into a CMTrace/Trace32 compatible LOG file.
		.DESCRIPTION
		a given Parameter on Function call will override those settings
		.PARAMETER MSG
		The LOG message
		.PARAMETER Comp
		Defines the LOG-Component
		.PARAMETER Thread
		Defines the Thread-ID
		.PARAMETER Path
		Defines the Path and / or LOG File Name.
		You can use a full path, only a file name or sub-paths with a filename.
                
		Direct execution:
		* If no Path is given the file will be created in the current directory.
		* If not defined the LOG file "logfile.log" will be created in the current directory.
        
		Execution from a script:
		* If no Path is given the file will be created in the Script directory.
		* If not defined the LOG file "logfile.log" will be created in the Script directory.
		.Output
		If Parameter ist given the LOG Message is returned as Write-Output.
		When Enabling -Output it is possible to Pipe the Log Messages to another Command
		.Split
		If Parameter ist given the existing LOG File will be backuped and a new LOG File is created.
		.EXAMPLE
		Write-Log TestMSG TestComponent 0
		.EXAMPLE
		Write-Log TestMSG
		.NOTES
		File Name                  : Write-LOG.psm1
		Author                     : OgrueAT
		Requires                   : PowerShell V1
	#>
	PARAM(
		[Parameter(Mandatory = $True,Position = 1,ValueFromPipeline = $True)]
		$MSG
		,[Parameter(Position = 2)]
		[string]$Comp
		,[Parameter(Position = 3)]
		[int]$Thread
		,[Parameter(Position = 4)]
		[string]$Path
		,[switch]$Output
		,[switch]$Split
	)
	BEGIN {
		[int]$MSGCount = 0
		#Check for present Values and set defaults if nothing there
		IF(!$Comp)
		{
			IF($WriteLOGlogComp)
			{
				$Comp = $WriteLOGlogComp
			}
			ELSE
			{
				$Comp = ' '
			}
		}
		IF(!$Thread)
		{
			IF($WriteLOGlogThread)
			{
				$Thread = $WriteLOGlogThread
			}
			ELSE
			{
				$Thread = 0
			}
		}
		IF($WriteLOGlogPath -and !$Path)
		{
			$Path = $WriteLOGlogPath
		}
		IF($WriteLOGlogOutput)
		{
			$Output = $WriteLOGlogOutput
		}

		#Check if Function is called from Script and set Variables
		try 
		{
			$null = Split-Path -Parent -Path $MyInvocation.ScriptName
			$basePath = Split-Path -Parent -Path $MyInvocation.ScriptName
			$logName = (($MyInvocation.ScriptName).Split('\')[-1]).Split('.')[0]
			$fromScript = $True
		}
		catch 
		{
			$basePath = (Get-Item -Path '.\' -Verbose).FullName
			$logName = 'logfile'
			$fromScript = $False
		}

		#Set FileName if nothing is specified
		IF(!$Path)
		{
			$Path = $basePath+'\'+$logName+'.log'
		}
		#Check $Path
		IF($Path)
		{
			#If last charackter is '\' remove it
			$Path = $Path.TrimEnd('\')
			#if, whyever, there are more than 2 trailing '\' replace with 2 '\\'
			$Path = $Path -Replace '\\{3,}', '\\'
			$chekFile = ($Path.Split('\'))[-1]
			#if File is Directory add logName
			IF($chekFile -notmatch '\.')
			{
				$Path = $Path+'\'+$logName+'.log'
			}
		}
		#if File is set without FullPath
		IF($Path -notlike '[A-Z]:\*' -and $Path -notlike '\\*')
		{
			$Path = $basePath+'\'+$Path
			#safeRun - replace multible \
			$Path = $Path -Replace '\\{2,}', '\'
		}
		##Check if path exists and create it if not
		IF(!(Test-Path -Path (Split-Path -Parent -Path $Path)))
		{
			$null = New-Item -ItemType directory -Path (Split-Path -Parent -Path $Path) -Force
		}

		#if Split $True or file size <10MB move to backup-log
		IF((Test-Path -Path $Path) -and ($Split -or (Get-Item $Path).Length/1MB -gt 1))
		{
			$PathBKP = (Split-Path -Parent -Path (Get-Item $Path).FullName)+'\'+(Get-Item $Path).Basename+'_'+(Get-Date -Format MM-dd-yy)+'_'+(Get-Date -Format hh-mm-ss)+'.log'
			Move-Item $Path -Destination $PathBKP -Force
			[string]("--- LOG exceeded file size, moved old LOG to $PathBKP"+"$"+"$"+'<LOG-Process><'+(Get-Date -Format MM-dd-yyyy)+' '+(Get-Date -Format hh:mm:ss)+'.'+((Get-Date).millisecond)+'><thread=0>') | Out-File -Encoding utf8 -Append -FilePath "$Path"
		}

		#Verbose-Output
		Write-Verbose -Message "run from Script:    $fromScript"
		IF($WriteLOGlogPath -or $WriteLOGlogComp -or $WriteLOGlogThread -or $WriteLOGlogOutput)
		{
			Write-Verbose -Message ''
			Write-Verbose -Message '--- Settings from Set-LOG ---'
			IF($WriteLOGlogPath)
			{
				Write-Verbose -Message "Set-LOG File:       $WriteLOGlogPath"
			}
			IF($WriteLOGlogComp)
			{
				Write-Verbose -Message "Set-LOG-Component:  $WriteLOGlogComp"
			}
			IF($WriteLOGlogThread)
			{
				Write-Verbose -Message "Set-LOG Thread:     $WriteLOGlogThread"
			}
			IF($WriteLOGlogOutput)
			{
				Write-Verbose -Message "Set-LOG Output:     $WriteLOGlogOutput"
			}
		}
		Write-Verbose -Message ''
		Write-Verbose -Message '--- Applied Settings ---'
		Write-Verbose -Message "LOG-File:           $Path"
		Write-Verbose -Message "LOG-Output          $Output"
		Write-Verbose -Message "LOG-Split           $Split"
		Write-Verbose -Message "LOG-Component:      $Comp"
		Write-Verbose -Message "LOG-Thread:         $Thread"
		Write-Verbose -Message 'LOG-Lines:'
	}
	PROCESS {
		#whatever $MSG is, make it a String
		#if $MSG is a Object, output first Entry with Headers - Works only for the First object found in pipe!
		IF(($MSG.GetType().FullName -match 'Object') -and ($MSGCount -eq 0))
		{
			$MSGstr = $MSG | Format-Table
			$MSGCount++
		}
		ELSE
		{
			$MSGstr = $MSG | Format-Table -HideTableHeaders
		}
		$MSGstr = Out-String -InputObject $MSGstr -Stream

		#finaly, write the LOG
		foreach($MSGline in $MSGstr)
		{
			#get rid of emtpy lines
			IF($MSGline)
			{
				#Rreplace NULL Characters (CMTrace dosnt like them)
				[string]$MSGline = $MSGline.Replace([char]0x00,' ')
				Write-Verbose -Message "$MSGline"
				[string]($MSGline+'  '+'$$'+'<'+$Comp+'><'+(Get-Date -Format MM-dd-yyyy)+' '+(Get-Date -Format hh:mm:ss)+'.'+((Get-Date).millisecond)+'><thread='+$Thread+'>') | Out-File -Encoding utf8 -Append -FilePath "$Path"
				IF($Output)
				{
					Write-Output -InputObject "$MSGline"
				}
			}
		}

	}
	END{
		Return
	}
}
FUNCTION Set-LOG
{
	<#
		.SYNOPSIS

		.DESCRIPTION

		.PARAMETER Comp
		Defines the LOG-Component
		.PARAMETER Thread
		Defines the Thread-ID
		.PARAMETER File
		Defines the LOG File.

		.NOTES
		File Name  : Write-LOG.psm1
		Author     : OgrueAT
		Requires   : PowerShell V1
	#>
	PARAM(
		[string]$Comp
		,[int]$Thread
		,[switch]$Output
		,[string]$Path
	)
	IF(!$Comp -and !$Thread -and !$Path -and !$Output)
	{
		IF(Test-Path -Path variable:\WriteLOGlogComp)
		{
			Clear-Variable -Name WriteLOGlogComp -Scope Script
		}
		IF(Test-Path -Path variable:\WriteLOGlogThread)
		{
			Clear-Variable -Name WriteLOGlogThread -Scope Script
		}
		IF(Test-Path -Path variable:\WriteLOGlogOutput)
		{
			Clear-Variable -Name WriteLOGlogOutput -Scope Script
		}
		IF(Test-Path -Path variable:\WriteLOGlogPath)
		{
			Clear-Variable -Name WriteLOGlogPath -Scope Script
		}
	}
	IF($Comp)
	{
		$script:WriteLOGlogComp = $Comp
	}
	IF($Thread)
	{
		$script:WriteLOGlogThread = $Thread
	}
	IF($Path)
	{
		$script:WriteLOGlogPath = $Path
	}
	IF($Output)
	{
		$script:WriteLOGlogOutput = $True
	}
	ELSE
	{
		$script:WriteLOGlogOutput = $False
	}
}
