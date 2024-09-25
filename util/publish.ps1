<#
	Publica na PSGalery!
#>
[CmdletBinding()]
param(
	$ApiKey = $Env:PSGALERY_KEY
	,[switch]$CompileDoc
	,[switch]$BasicTest
	,[switch]$Publish
	,[switch]$CheckVersion
)

$ErrorActionPreference = "Stop";
. (Join-Path "$PsScriptRoot" UtilLib.ps1)
$Info = GetProjectVars

$ModuleRoot = Resolve-Path $Info.ModuleDir

if(!$Global:PUBLISH_DATA){
	$Global:PUBLISH_DATA = @{}
}

if(!$PUBLISH_DATA.TempDir){
	$TempFile =  [Io.Path]::GetTempFileName()
	$TempDir  = $TempFile+"-powershai";
	$PUBLISH_DATA.TempDir = New-Item -Force -ItemType Directory -Path $TempDir;
}

$TempDir = $PUBLISH_DATA.TempDir;

if($CompileDoc){
	$PlatyDir = Join-Path $TempDir "platy"
	$null = New-Item -Force -ItemType Directory -Path $PlatyDir
	write-host "DocCompileWorkDir: $PlatyDir";
	$DocsScript = Join-Path $PsScriptRoot doc.ps1
	& $DocsScript $PlatyDir -SupportedLangs * -MaxAboutWidth 150
	write-host " Done!"
}



# Module version!
if($CheckVersion){
	# Current version!
	$LastTaggedVersion = git describe --tags --match "v*" --abbrev=0;
	
	if($LastTaggedVersion){
		$TaggedVersion = [Version]($LastTaggedVersion.replace("v",""))
	}


	$Mod = import-module $ModuleRoot -force -PassThru;

	if($TaggedVersion -ne $Mod.Version){
		throw "PUBLISH_INCORRECT_VERSION: Module = $($Mod.Version) Git = $TaggedVersion";
	}
}

if($Publish){
	$PublishParams = @{
		Path 		= $ModuleRoot
		NuGetApiKey = $ApiKey
		Force 		= $true
		Verbose 	= $true;
	}
	Publish-Module -Path $ModuleRoot -NuGetApiKey $ApiKey -Force -Verbose
}