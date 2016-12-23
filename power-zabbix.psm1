#Módulo para o powershell!
$ErrorActionPreference= "Stop";

#Verifica se um assembly já foi carregado!
Function CheckAssembly {
	param($Name)
	
	if($Global:PowerZabbix_Loaded){
		return $true;
	}
	
	if( [appdomain]::currentdomain.getassemblies() | ? {$_ -match $Name}){
		$Global:PowerZabbix_Loaded = $true
		return $true;
	} else {
		return $false
	}
}

Function LoadJsonEngine {

	$Engine = "System.Web.Extensions"

	if(!(CheckAssembly Engine)){
		try {
			Add-Type -Assembly  $Engine
			$Global:PowerZabbix_Loaded = $true;
		} catch {
			throw "ERROR_LOADIING_WEB_EXTENSIONS: $_";
		}
	}

}


#Troca caracteres não-unicode por um \u + codigo!
#Solucao adapatada da resposta do Douglas em: http://stackoverflow.com/a/25349901/4100116
Function EscapeNonUnicodeJson {
	param([string]$Json)
	
	$Replacer = {
		param($m)
		
		return [string]::format('\u{0:x4}', [int]$m.Value[0] )
	}
	
	$RegEx = [regex]'[^\x00-\x7F]';
	write-verbose "EscapeNonUnicodeJson: Original Json: $Json";
	$ReplacedJSon = $RegEx.replace( $Json, $Replacer)
	write-verbose "EscapeNonUnicodeJson: NonUnicode Json: $ReplacedJson";
	return $ReplacedJSon;
}


Function ConvertToJson($o) {
	LoadJsonEngine

	$jo=new-object system.web.script.serialization.javascriptSerializer
	$jo.maxJsonLength=[int32]::maxvalue;
    return EscapeNonUnicodeJson ($jo.Serialize($o))
}

Function ConvertFromJson([string]$json) {
	LoadJsonEngine
	$jo=new-object system.web.script.serialization.javascriptSerializer
	$jo.maxJsonLength=[int32]::maxvalue;
    return $jo.DeserializeObject($json)
}


#Faz uma chamada para a API do zabbix!
Function CallZabbixURL([object]$data = $null,$url = $null,$method = "POST", $contentType = "application/json-rpc"){
	$ErrorActionPreference="Stop";
	
	write-verbose "CallZabbixURL: URL param is: $Url";
	
	
	try {
		if($data -is [hashtable]){
			write-verbose "Converting input object to json string..."
			$data = ConvertToJson $data;
		}
		
		write-verbose "CalZabbixURL: json that will be send is: $data"
		
		#Checando cache...
		$Cache = $Global:PowerZabbix_AuthCache;
		if(!$URL){
			$URL = $Cache.LastURL;
		} else {
			$Cache.LastURL = $URL;
		}
		
		write-verbose "Usando URL: $URL"
		
		
		if($Global:PowerZabbix_ZabbixUrl -and !$url){
			$url = $Global:PowerZabbix_ZabbixUrl;
		}
		
		if($url -NotLike "*api_jsonrpc.php" ){
			if($url -NotLike "*/"){
				$url += "/"
			}
			
			$url += "api_jsonrpc.php"
		}
		
		
		

		write-verbose "CallZabbixURL: Creating WebRequest method... Url: $url. Method: $Method ContentType: $ContentType";
		$Web = [System.Net.WebRequest]::Create($url);
		$Web.Method = $method;
		$Web.ContentType = $contentType
		
		#Determina a quantidade de bytes...
		[Byte[]]$bytes = [byte[]][char[]]$data;
		
		#Escrevendo os dados
		$Web.ContentLength = $bytes.Length;
		write-verbose "CallZabbixURL: Bytes lengths: $($Web.ContentLength)"
		
		
		write-verbose "CallZabbixURL: Getting request stream...."
		$RequestStream = $Web.GetRequestStream();
		
		
		try {
			write-verbose "CallZabbixURL: Writing bytes to the request stream...";
			$RequestStream.Write($bytes, 0, $bytes.length);
		} finally {
			write-verbose "CallZabbixURL: Disposing the request stream!"
			$RequestStream.Dispose() #This must be called after writing!
		}
		
		
		
		write-verbose "CallZabbixURL: Making http request... Waiting for the response..."
		$HttpResp = $Web.GetResponse();
		
		
		
		$responseString  = $null;
		
		if($HttpResp){
			write-verbose "CallZabbixURL: charset: $($HttpResp.CharacterSet) encoding: $($HttpResp.ContentEncoding). ContentType: $($HttpResp.ContentType)"
			write-verbose "CallZabbixURL: Getting response stream..."
			$ResponseStream  = $HttpResp.GetResponseStream();
			
			write-verbose "CallZabbixURL: Response stream size: $($ResponseStream.Length) bytes"
			
			$IO = New-Object System.IO.StreamReader($ResponseStream);
			
			write-verbose "CallZabbixURL: Reading response stream...."
			$responseString = $IO.ReadToEnd();
			
			write-verbose "CalZabbixURL: response json is: $responseString"
		}
		
		
		write-verbose "CallZabbixURL: Response String size: $($responseString.length) characters! "
		return $responseString;
	} catch {
		throw "ERROR_CALLING_ZABBIX_URL: $_";
	} finally {
		if($IO){
			$IO.close()
		}
		
		if($ResponseStream){
			$ResponseStream.Close()
		}
		
		<#
		if($HttpResp){
			write-host "Finazling http request stream..."
			$HttpResp.finalize()
		}
		#>

	
		if($RequestStream){
			write-verbose "Finazling request stream..."
			$RequestStream.Close()
		}
	}
}

#Irá conter as credenciais em cache para as urls...
$Global:PowerZabbix_AuthCache = @{
		Credentials 	= @{}
		LastURL			= $null
		Named			= @{}
	}
	
#Guarda as informações de conexão com o Zabbix na memória da sessão para uso com os outros comandos!
#A url definida será marcada como last url...
Function Set-ZabbixConnection([string]$url, $user = $null, $password = $null, $Name = $null) {
	
	if($Name -and !$url){
		$url = GetNamedZabbixConnection $Name;
		if(!$url){
			throw 'NAME_NOT_FOUND: $Name';
		}
	}
	
	$Slot = Get-URLCache $url;
	SetLastURL $url;
	
	if($User){
		$Slot.user = $user;
	}
		
	if($Password -ne $null){
		$Slot.password = $password;
	}
	
	if($Name -and $url){
		SetNamedZabbixConnection -Name $Name -URL $url;
	}
}

#Cria ou muda o valor de um slot nomeado no cache...
Function SetNamedZabbixConnection([string]$Name, [string]$URL){
	$NameTable = $Global:PowerZabbix_AuthCache.Named;
	
	if($NameTable.Contains($Name)){
		$NameTable[$Name] = $URL;
	} else {
		$NameTable.add($Name,$URL);
	}
}

#Obtém o valor da url de uma conexão nomeada...
Function GetNamedZabbixConnection([string]$Name){
	if($Global:PowerZabbix_AuthCache.Named.Contains($Name)){
		return $Global:PowerZabbix_AuthCache.Named[$Name];
	}
}

#Cria e obtém uma referencia para o cache slot da url...
Function Get-URLCache([string]$URL) {
	$Cache = $Global:PowerZabbix_AuthCache.Credentials;
	if($Cache.Contains($URL)){
		return $Cache[$URL];
	} else {
		$CacheSlot = @{user=$null;password=$null;lastAuth=$null};
		$Cache.add($URL,$CacheSlot);
		return $CacheSlot;
	}
}

#Trata a resposta enviada pela API do zabbix.
#Em caso de erros, uma expcetion será tratada. Caso contrário, um objeto contendo a resposta será retornado.
Function TranslateZabbixJson {
	param($ZabbixResponse)
	
	#Cria um objeto contendo os campos da resposta!
	$ZabbixResponseO = ConvertFromJson $ZabbixResponse;
	
	#Se o campo "error" estiver presente, significa que houve um erro!
	#https://www.zabbix.com/documentation/3.0/manual/api
	if($ZabbixResponseO.error){
		$ZabbixError = $ZabbixResponseO.error;
		$MessageException = "[$($ZabbixError.code)]: $($ZabbixError.data). Details: $($ZabbixError.data)";
		$Exception = New-Object System.Exception($MessageException)
		$Exception.Source = "ZabbixAPI"
		throw $Exception;
		return;
	}
	
	
	#Caso contrário, o resultado será enviado
	return $ZabbixResponseO.result;
}

#Gera um id para as requisições da api DO ZABBIX
Function  GetNewZabbixApiId {
	return [System.Guid]::NewGuid().Guid.ToString()
}

#Autentica no Zabbix. As informações de autenticação serão guardadas na sessao para autenticação posterior!
Function Auth-Zabbix {
	[CmdLetBinding()]
	param(
			 $User 		= $null
			,$Password	= $null
			,$URL 		= $null
			,[switch]$Save = $null
		)

	#Obtém uma referencial local para o cache de autenticação...
	$Cache = $Global:PowerZabbix_AuthCache;
		
	#Se não foi informada um URL, tenta obter a última utilizada...
	if(!$URL){
		write-verbose "Auth-Zabbix: Nenhuma URL fornecida... Tentando usar a última..."
		$URL = GetLastURL;
	}
	
	write-verbose "Auth-Zabbix: URL is: $URL";
	$URLCache = Get-URLCache $URL;
	
	
	#Se não foi informada um usuário, tenta consultar o cache...
	
	#Se o usuário não foi informado, então tenta obter do cache!
	if(!$User){
		write-verbose "Auth-Zabbix: Nenhum usuário informado, tentando obter do cache..."
		
		#Se o usuário existe no cache...
		if($URLCache.user){
			write-verbose "Auth-Zabbix: Usuário encontrado no cache para $URL!"
			$User 		= $URLCache.User;
			$Password 	= $URLCache.Password;
		}
		
		#Se ainda não houver usuário, solicita um...
		if(!$User){
			write-verbose "Auth-Zabbix: Usuário não encontrado no cache... Solicitando credenciais..."
			$Creds = Get-Credential
			$NC = $Creds.GetNetworkCredential();
			$User = $NC.UserName
			$Password = $NC.Password;
		}
	}
	
	
	write-verbose "Auth-Zabbix: USerName: $User | Password: $($Password[0])******$($Password[$Password.Length-1])";
	write-debug "Auth-Zabbix: Password: $PAssword";
	
	#Salva o usuário...
	if($Save){
		write-verbose "Auth-Zabbix: Guardando informações no cache..."
		$URLCache.User = $User;
		$URLCache.Password = $Password;
	}
		
		
	#Monta o objeto de autenticação
	[string]$NewId = GetNewZabbixApiId;
	$AuthString = ConvertToJson @{
							jsonrpc = "2.0"
							method	= "user.login"
							params =  @{
										user 		= [string]$User
										password	= [string]$Password
									}
							id = $NewId
							auth = $null
						}
						
	#Chama a Url
	$resp = CallZabbixURL -data $AuthString -url $URL;
	$resultado = TranslateZabbixJson $resp;
	

	if($resultado){
		$URLCache.lastAuth = $resultado;
		return;
	}
}

#Obtém o token de autenticação se existe. Caso contrário, chama a função de auth!
Function GetZabbixApiAuthToken {
	write-verbose "GetZabbixApiAuthToken: Getting last used url..."
	$LastURL 	= GetLastURL
	$URLCache 	= Get-URLCache $LastURL;

	if($URLCache.lastAuth){
		write-verbose "GetZabbixApiAuthToken: last auth found  = $($URLCache.lastAuth)"
		return $URLCache.lastAuth;
	} else {
		write-verbose "GetZabbixApiAuthToken: Requesting auth..."
		Auth-Zabbix;
		
		if(!$URLCache.lastAuth){
			throw 'INVALID_AUTH_TOKEN'
			return;
		}
		
		write-verbose "GetZabbixApiAuthToken: Auth = $($URLCache.lastAuth)"
		return $URLCache.lastAuth;
	}
}

#Retorna uma hashtable para ser usada na comunicação com a apu
Function ZabbixAPI_NewParams {
	param($method)
	
	[string]$token = GetZabbixApiAuthToken;
	[string]$NewId = GetNewZabbixApiId;
	
	
	$APIParams =  @{
					jsonrpc = "2.0"
					auth 	= $token
					id 		= $NewId
					method	= $method
					params 	=  @{}
				}
				
	return $APIParams
}

#Ontém a última URL usada...
Function GetLastURL {
	$Cache = $Global:PowerZabbix_AuthCache;
	
	if($Cache.LastURL){
		return $Cache.LastURL;
	} else {
		write-verbose "GetLastURL: NO last url, requesting new..."
		$URL = Read-Host "Forneça a URL para o zabbix"
		$Cache.LastURL = $URL;
		return $Cache.LastURL;
	}
}

Function SetLastURL {
	param([string]$url)
	$Cache = $Global:PowerZabbix_AuthCache;
	$Cache.LastURL = $url;
}

#Função genérica usada para chamar o método get de diversos elementos!
#Retorna uma hashtable contendo as informações baseadas no filtro!
#Assim, os usuários da mesma podem fazer alterações se necessário!!!
#APIParams @{common=@{};props=@{}}
Function ZabbixAPI_Get {
	param(
		[hashtable]$Options
		,$APIParams = @{}
	)
	
	#Determinando searchByAny
	if($APIParams.common.searchByAny){
		$Options.params.add("searchByAny", $true);
	}
	
	if($APIParams.common.startSearch){
		$Options.params.add("startSearch", $true);
	}
	
	
	if($APIParams.common.limit){
		$Options.params.add("limit", $APIParams.common.limit);
	}
	
	
	if($APIParams.common.output){
		$Options.params.add("output", $APIParams.common.output);
	}
	
				
	#Determinando se iremos usar search ou filter pra buscar...
	if($APIParams.common.search){
		$Options.params.add("searchWildcardsEnabled",$true);
		$Options.params.add("search",@{
									name = $APIParams.props.name
							});
	} 
	elseif($APIParams.props.name) {
		$Options.params.add("filter",@{
									name = $APIParams.props.name
							});
	}
	
	return;
}

#Converte uma lista de valores para ids!
Function ZabbixAPI_List2Ids {
	param($SourceList, [scriptblock]$NamesToId, [switch]$NoValidate = $false)

	$Ids = @();
	$Names = @();
	
	$SourceList | %{
		if($_ -as [int]){
			$Ids += [int]$_;
		} else {
			$Names += $_.toString()
		}
	}
	
	if($Names){
		#NameToId must return a array of objects, where each object contains id of entity and the associated name in name property.
		$Founded += & $NamesToId $Names;
		
		if(!$NoValidate){
			#Gera um array com a lista de nomes encontrados...
			$NamesFound = @($Founded | %{$_.name});
			
			#Obtém os nomes que não foram encontrados...
			$NamesNotFound  = @();
			$NamesNotFound = $SourceList | ? {  $NamesFound  -NotContains $_  } | %{$_};
			
			if($NamesNotFound){
				throw "NAMES_NOT_FOUND: $NamesNotFound"
			}
		}
		
		$Ids += $Founded | %{$_.id}
		
		
	}
	
	return $Ids;
}

#Converte um datetime para um unixtimestamp!
Function Datetime2Unix {
	param([datetime]$Datetime)
	
	return $Datetime.toUniversalTime().Subtract([datetime]'1970-01-01').totalSeconds;
}

Function UnixTime2LocalTime {
	param([uint32]$unixts)
	
	return ([datetime]'1970-01-01').toUniversalTime().addSeconds($unixts).toLocalTime();
}

############# Aux cmdlets ###############
#######Cmdlets auxiliares que podem ser usados para facilitar a interação com a API, mas que não são implementações da mesma!################
	
	#Retorna uma hashtable com as configurações para a interface a ser usada com o cmdlet Create-ZabbixHost
	#Para mais informações verifique o link https://www.zabbix.com/documentation/3.4/manual/api/reference/hostinterface/object
	Function Get-InterfaceConfig {
		param(
			#Pode ser um nome DNS ou IP. O que vai determinar o tipo é a presença ou não do parâmetro -IsIP
			$Address = $null
			
			,#Porta da interface. 
				[int]$Port = 10050
				
			,#Indica que a interface não é a padrão!
			 #Neste caso, a propriedade main será marcada como 0.
				[switch]$NoMain 	= $false

			,#Indica se o valor em Address é um IP. Se sim, a interface será configurada como IP.
				[switch]$IsIP		= $False
			
			
			,#Tipo da interface. Pode se usar o nome ou id. Verifique o link para os ids!
				[ValidateSet("Agent","SNMP","IPMI","JMX",1,2,3,4)]
				$Type = "Agent"
		)
		
		$Config = @{dns="";ip="";main=1;port=$Port;type=[int]$null;useip=1};
		
		#Transforma o tipo em número!
		if($Type -is [string]){
			$i = 1;
			$Type = @("Agent","SNMP","IPMI","JMX") |  ? { if($Type -eq $_){return $true} else {$i++;return $false} } | %{$i};
		}
		
		$Config.type = $Type;
		
		
		if($IsIP){
			$Config.ip = [string]$Address;
		} else {
			$Config.dns = [string]$Address;
			$Config.useip = 0;
		}
		
		if($NoMain){
			$Config.main = 0;
		}
		
		
		return $Config;
		
	}

	
	
############# API cmdlets ###############
#######API implementations. A partir daqui, segue as implementações da API################

######### HOST
	#Equivalente ao método da API host.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/host/get
	Function Get-ZabbixHost {
		[CmdLetBinding()]
		param(
			$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$output				= $null
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "host.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							output		= $output
						}
						
					props = @{
						name = $Name 
					}
				}		
		$APIString = ConvertToJson $APIParams;
							
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		return $ResultsObjects;
	}


	#Equivalente ao método da API host.create
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/create
	Function Create-ZabbixHost {
		[CmdLetBinding()]
		param(
			$HostName
			,$VisibleName = $null
			,$Interfaces
			,$Groups = $null
			,$Templates = $null
		)

		
		$APIPArams = ZabbixAPI_NewParams "host.create";
		
		$APIPArams.params.add("host",$HostName);
		
		if($VisibleName){
			$APIPArams.params.add("name",$VisibleName);
		}
		
		$APIParams.params.add("interfaces",$interfaces);
		
		$AllGroups = @();
		if($Groups)	{
			$Groups | %{
				$AllGroups += @{groupid=$_.groupid};
			}
			$APIParams.params.add("groups", $AllGroups );
		}

		
		$AllTemplates = @();
		if($Templates){
			$Templates | %{
				$AllTemplates += @{templateid=$_.templateid};
			}
			$APIParams.params.add("templates", $AllTemplates );
		}
		
		
		$APIString = ConvertToJson $APIParams;
							
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		return $ResultsObjects;
	}


######### HOSTGROUP	
	#Equivalente ao método da API hostgroup.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/get
	Function Get-ZabbixHostGroup {
		[CmdLetBinding()]
		param(
			[string[]]$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$Output			   = $null
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "hostgroup.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							output		= $output
						}
						
					props = @{
						name = $Name 
					}
				}
		
		write-verbose "Get-ZabbixHostGroup: APIParams, before convert $APIParams"
		$APIString = ConvertToJson $APIParams;
		write-verbose "Get-ZabbixHostGroup: APIString, before convert $APISTring"
							
		#Chama a Url
		write-verbose "Get-ZabbixHostGroup:  calling zabbix url function..."
		$resp = CallZabbixURL -data $APIString;
		write-verbose "Get-ZabbixHostGroup:  response received! Calling translate..."
		$resultado = TranslateZabbixJson $resp;
		write-verbose "Get-ZabbixHostGroup:  Translated!"
		
		write-verbose "Get-ZabbixHostGroup: Building result objexts..."
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		write-verbose "Get-ZabbixHostGroup: Objects generated = $ResultsObjects.count"
		
		return $ResultsObjects;
	}

	#Equivalente ao método da API hosgroup.create
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/create
	Function Create-ZabbixHostGroup {
		[CmdLetBinding()]
		param(
			[string[]]$Name
		)

		
		$APIPArams = ZabbixAPI_NewParams "hostgroup.create";
		
		$AllHostGroups = @();
		
		$Name | %{
			$AllHostGroups += @{name = [string]$_};
		}
		
		$APIParams.params = $AllHostGroups;
		
		
		$APIString = ConvertToJson $APIParams;
		write-verbose "Create-ZabbixHostGroup: APIString: $APIString"
							
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		return $ResultsObjects;
	}

	
######### TEMPLATE
	#Equivalente ao método da API template.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/template/get
	Function Get-ZabbixTemplate {
		[CmdLetBinding()]
		param(
			$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "template.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
						}
						
					props = @{
						name = $Name 
					}
				}		
		$APIString = ConvertToJson $APIParams;
							
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		return $ResultsObjects;
	}


######### EVENT
	#Equivalente ao método da API event.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/event/get
	Function Get-ZabbixEvent {
		[CmdLetBinding()]
		param(
			 [int[]]$Id	= @()
			,$Hosts 	= @()		
			,$Groups  = @()
			,$TimeFrom 	= $null
			,$TimeTill	= $null
			
			,
				[ValidateSet("trigger","discovered host","discovered service","auto-registered host","item","LLD rule",0,1,2,3,4,5)]
				$Object				= $null
				
			,$Value					= '1' #PROBLEM
			,$selectHosts 			= $null
			,$selectRelatedObject	= $null
			,	
				[Alias("selectAcks")]
				$selectAcknowledges	= $null
				
			,$limit					= $null
			,$acknowledged			= $null
		)

				
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "event.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $false 
							searchByAny = $false
							startSearch = $false
							limit		= $limit
						}
				}
				
		if($Id){
			$APIParams.params.add("eventids", $Id ); 
		}
				
		if($TimeFrom){
			$APIParams.params.add("time_from", [string](Datetime2Unix $TimeFrom) ); 
		}
		
		if($TimeTill){
			$APIParams.params.add("time_till", [string](Datetime2Unix $TimeTill) ); 
		}
		
		if($Hosts){
			write-verbose "Get-ZabbixEvent: Castings groups to hosts ids..."
			[int[]]$HostIds = ZabbixAPI_List2Ids $Hosts { 
													param($HostNames) 
													
													$Found = @();
													Get-ZabbixHost -Name $HostNames -output @('hostid','name') | %{
														New-Object PSObject -Prop @{id=$_.hostid;name=$_.name};
													}
													
													return $Found;
													
												};
			$APIParams.params.add("hostids", $HostsIds);
			write-verbose "Get-ZabbixEvent: Hosts add casted sucessfully!"
		}
		
		if($Groups){
			write-verbose "Get-ZabbixEvent: Castings groups to groups ids..."
			[int[]]$GroupIds = ZabbixAPI_List2Ids $Groups { 
														param($GroupNames) 
														
														$Found = @();
														
														$Found = Get-ZabbixHostGroup -Name $GroupNames -Output @('groupid','name') | %{
															New-Object PSObject -Prop @{id=$_.groupid;name=$_.name};
														}
														
														return $FOund;
													};			
			
			if($GroupIDs){
				$APIParams.params.add("groupids", $GroupIds);
			} else {
				throw "GROUPS_NOT_FOUND: $Groups";
			}	
			
			write-verbose "Get-ZabbixEvent: Groups add casted sucessfully!"
		}
		
		if($selectAcknowledges){
			$APIParams.params.add("select_acknowledges", $selectAcknowledges);
		}
		
		if($acknowledged -ne $null){
			$APIParams.params.add("acknowledged", [bool]$acknowledged);
		}
		
		if($Object){
			if($Object -is [string]){
				$i = 0;
				
				$Object = 'trigger','discovered host','discovered service','auto-registered host','item','LLD rule' | ?{
					if($_ -eq $Object){
						return $true;
					} else {
						$i++;return $false;
					}
				} | %{$i}
			}
		
			$APIParams.params.add("object", $object )
		}
		
		if($selectHosts){
			$APIParams.params.add("selectHosts", $selectHosts);
		}
		
		if($selectRelatedObject){
			$APIParams.params.add("selectRelatedObject", $selectRelatedObject);
		}
				
		write-verbose "Get-ZabbixEvent: About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		write-verbose "JSON is: $APIString";
		
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$r = NEw-Object PSObject -Prop $_;
				
				#Adiciona o datetime local...
				if($r | gm "clock"){
					$r | Add-Member -Type Noteproperty -Name "datetime" -Value (UnixTime2LocalTime $r.clock)
				}
				
				#Adiciona as informações da trigger...
				if($r.object -eq 0 -and $r.relatedObject.description){
					$r | Add-Member -Type Noteproperty -Name "TriggerName" -Value $r.relatedObject.description
				}
				
				#Adiciona as informações da trigger...
				if($r.object -eq 0 -and $r.relatedObject.priority){
					$r | Add-Member -Type Noteproperty -Name "TriggerSeverity" -Value $r.relatedObject.priority
				}
				
				#Adiciona as informações do host...
				if($r.object -eq 0 -and $r.hosts.count -ge 1){
					if($r.hosts[0].name){
						$r | Add-Member -Type Noteproperty -Name "HostName" -Value $r.hosts[0].name
					}
					
				}
				
				$ResultsObjects += $r;
			}
		}

		return $ResultsObjects;
	}

	#Equivalente ao método da API event.acknowledge
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/event/get
	Function Ack-ZabbixEvent {
		[CmdLetBinding(SupportsShouldProcess=$True)]
		param(
			[parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
			[int]$EventId
			,[string]$Message
		)
		
		begin  {
			[int[]]$EventsIds = @();
		}
		
		process {
			$EventsIds += $EventId;
		}
		
		end {
			[hashtable]$AckParams = @{eventids=$EventsIds;message=$Message};
			[hashtable]$APIParams = ZabbixAPI_NewParams "event.acknowledge"
			$APIParams.params = $AckParams;
			$APIString = ConvertToJson $APIParams;
			write-verbose "Ack-ZabbixEvent: APIString: $APIString";
			
			
			#Chama a Url
			
			if($PSCmdLet.ShouldProcess("Events[$($EventsIds.count)]:$EventsIds")){
				write-verbose 'Ack-ZabbixEvent: Calling url...'
				$resp = CallZabbixURL -data $APIString;
				$resultado = TranslateZabbixJson $resp;
				write-verbose 'Ack-ZabbixEvent: Translatio finished...'
			}

			
			$ResultsObjects = @();
			if($resultado){
				$resultado | %{
					$ResultsObjects += NEw-Object PSObject -Prop $_;	
				}
			}

			return $ResultsObjects;
		}
		
	}
	
	