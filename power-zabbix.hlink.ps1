#Módulo para o powershell!
$ErrorActionPreference= "Stop";

#Auxiliar functions!
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

		if(!(CheckAssembly $Engine)){
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

	#Converts objets to JSON and vice versa,
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


#Make calls to a zabbix server url api.
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

#This is the global cache. Here we store used credentials...
#The global cache is place where the module will store connections.
#It store connections based on URL suplied,
	if(!$Global:PowerZabbix_AuthCache){
		write-verbose "Creating the Auth Cache variable!"
		$Global:PowerZabbix_AuthCache = @{
				#The credentials slot is used to store credentials. This is also called as URLCache.
				#Each key of the hashtable is a URL. This allow our module store just a credential per URL.
				#Check the GetURLCache function for more info about each pair stored on this hashtable.
				Credentials 	= @{}
				
				#This is URL of last used URL.
				#Some cmdlets like Auth-Zabbix or Set-ZabbixConnection sets the URL as last used URL.
				#Last used url is used by authentication functions. If no url is passed, it will used last used, if there are one.
				LastURL			= $null
				
				#This store a user frindly name for a URL (Set-ZabbixConnection)
				Named			= @{}
			}
	}
	
	#Binds a user friendly name to a URL in authentication cache.
	Function SetNamedZabbixConnection([string]$Name, [string]$URL){
		$NameTable = $Global:PowerZabbix_AuthCache.Named;
		
		if($NameTable.Contains($Name)){
			$NameTable[$Name] = $URL;
		} else {
			$NameTable.add($Name,$URL);
		}
	}

	#Gets the value of a named URL.
	Function GetNamedZabbixConnection([string]$Name){
		if($Global:PowerZabbix_AuthCache.Named.Contains($Name)){
			return $Global:PowerZabbix_AuthCache.Named[$Name];
		}
	}
	
	#Gets a reference to a cache slot of a specific URL in Auth Cache.
	#If a slot does not exist for the URL, a new one is created.
	Function GetURLCache([string]$URL) {
		$Cache = $Global:PowerZabbix_AuthCache.Credentials;
		if($Cache.Contains($URL)){
			return $Cache[$URL];
		} else {
			$CacheSlot = @{
				#Contains the username used.
				user=$null
				#Contains the user password.
				password=$null
				
				#Contains the last authentication result from zabbix api login method.
				lastAuth=$null
				
				#Contains the last authentication result from fronend login.
				lastFrontendAuth =$null
			};
			$Cache.add($URL,$CacheSlot);
			return $CacheSlot;
		}
	}

	#Get last used URL
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
		
	#Sets the last used URL.
	Function SetLastURL {
		param([string]$url)
		$Cache = $Global:PowerZabbix_AuthCache;
		$Cache.LastURL = $url;
	}
		
	#Handle the zabbix server answers.
	#If the repsonse represents a error, a exception will be thrown. Otherwise, a object containing the response will be returned.
	Function TranslateZabbixJson {
		param($ZabbixResponse)
		
		#Converts the response to a object.
		$ZabbixResponseO = ConvertFromJson $ZabbixResponse;
		
		#If the "error" property is set, then a error is build.
		#https://www.zabbix.com/documentation/3.0/manual/api
		if($ZabbixResponseO.error){
			$ZabbixError = $ZabbixResponseO.error;
			$MessageException = "[$($ZabbixError.code)]: $($ZabbixError.data). Details: $($ZabbixError.data)";
			$Exception = New-Object System.Exception($MessageException)
			$Exception.Source = "ZabbixAPI"
			throw $Exception;
			return;
		}
		
		
		#If not error, then return response result.
		return $ZabbixResponseO.result;
	}

	#Generate a id for be used in each request to the API.
	Function  GetNewZabbixApiId {
		return [System.Guid]::NewGuid().Guid.ToString()
	}

	
	#Gets a authentication token to be used in calls to API.
	#Cmdlets that implements api methods must calls this in order to get a valid token.
	#this functions handles a logic to obtain a token.
	#If there are a token in cache, then it will be return it.
	#If dont, then it will calls all necessary functions to obtain a new token.
	Function GetZabbixApiAuthToken {
		param([switch]$FrontEnd = $false)
		
		write-verbose "GetZabbixApiAuthToken: Getting last used url..."
		$LastURL 	= GetLastURL
		$URLCache 	= GetURLCache $LastURL;

		if($URLCache.lastAuth){
			write-verbose "GetZabbixApiAuthToken: last auth found  = $($URLCache.lastAuth)"
			
			if($FrontEnd){
				return $URLCache.lastFrontendAuth;
			} else {
				return $URLCache.lastAuth;
			}
		} else {
			write-verbose "GetZabbixApiAuthToken: Requesting auth..."
			Auth-Zabbix;
			
			if(!$URLCache.lastAuth){
				throw 'INVALID_AUTH_TOKEN'
				return;
			}
			
			write-verbose "GetZabbixApiAuthToken: Auth = $($URLCache.lastAuth)"
			if($FrontEnd){
				return $URLCache.lastFrontendAuth;
			} else {
				return $URLCache.lastAuth;
			}
		}
	}

	
	#This is a generic API builder. This builds a hashtable with all common information to call api methods.
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
	
	
	#This functions builds all commons *.get API methods parameters.
	#You can use this to generate some basic structure for a get operation of any object type.
	Function ZabbixAPI_Get {
		param(
			[hashtable]$Options
			,$APIParams = @{}
		)
		
		$Options.params.add("filter",@{});
		
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
			$Options.params.filter["name"] = $APIParams.props.name
		}
		
		return;
	}

	
	#Convert a datetime object to a unix time representation.
	Function Datetime2Unix {
		param([datetime]$Datetime)
		
		return $Datetime.toUniversalTime().Subtract([datetime]'1970-01-01').totalSeconds;
	}

	#Converts a unixtime representation to a datetime in local time.
	Function UnixTime2LocalTime {
		param([uint32]$unixts)
		
		return ([datetime]'1970-01-01').toUniversalTime().addSeconds($unixts).toLocalTime();
	}
		
		
	#Get a list of names and converts it to ids.
	#This is a auxliary function that contains common steps to convert a name of some object (hosts, hostgroups, etc.) to the respective id.
	#It handles names not founds, etc.
	#You must supply the original names and a scriptblock used to cast the name to the id.
	Function ZabbixAPI_List2Ids {
		param(
			#This is the names list!
			$SourceList
			
			,[scriptblock]$NamesToId
			
			,[switch]$NoValidate = $false	
		)

		$Ids = @();
		$Names = @();
		
		$SourceList | %{
			if($_ -as [int]){
				$Ids += @{id=$_;name=$null};
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
			
			$Ids += $Founded;
			
			
		}
		
		return $Ids;
	}

	
	#Converts a hashtable to a URLENCODED format to be send over HTTP requests.
	Function BuildURLEncoded {
		param($DATA)
		
		$FinalString = @();
		$DATA.GetEnumerator() | %{
			$FinalString += "$($_.Key)=$($_.Value)";
		}

		Return ($FinalString -Join "&");
	}
	
	#Copies bytes from a stream to another!
	Function CopyToStream {
		param($From,$To)
		
		[Byte[]]$Buffer = New-Object Byte[](4096);
		$BytesRead = 0;
		while( ($BytesRead = $From.read($Buffer, 0,$Buffer.length)) -gt 0  ){
			$To.Write($buffer, 0, $BytesRead);
		}
	}

	#Makes a POST HTTP call and return cmdlet with the results.
	#This will return a object containing following:
	#	raw 		- The raw bytes of response content.
	#	html		- The html respponse, if contentType is text/html
	#	httpResponse - The original http response object!
	#	session	- The session data, to be used as the parameter "session" to simulate sessions!
	Function InvokeHttp {
		[CmdLetBinding()]
		param($URL, [hashtable]$data = @{}, $Session = $null, $method = 'POST', [switch]$AllowRedirect = $false)
		
		
		$Result = New-Object PsObject @{
			raw = $null
			html = $null
			httpResponse = $null
			session = @{cookies=$null}
		}
		
		$CookieContainer = New-Object Net.CookieContainer;
		
		if($Session){
			write-verbose "InvokeHttp: Session was informed. Importing cookies!"
			$Session.Cookies | ?{$_} | %{
					write-verbose "InvokeHttp: Cookie $($_.Name) imported!"
					$CookieContainer.add($_);
			}
		}
		
		try {
			$HttpRequest 					= [Net.WebRequest]::Create($URL);
			$HttpRequest.CookieContainer 	= $CookieContainer;
			$HttpRequest.Method 			= $method;
			$HttpRequest.AllowAutoRedirect 	= $AllowRedirect
			
			if($HttpRequest.method -eq 'POST'){
				write-verbose "InvokeHttp: Setiing up the POST headers!"
				$PostData 	= BuildURLEncoded $data
				write-verbose "InvokeHttp: Post data encoded is: $PostData"
				$PostBytes 	= [System.Text.Encoding]::UTF8.GetBytes($PostData)
				$HttpRequest.ContentType = 'application/x-www-form-urlencoded';
				$HttpRequest.ContentLength 	= $PostBytes.length;
				write-verbose "InvokeHttp: Post data length is: $($PostBytes.Length)"
				
				write-verbose "InvokeHttp: getting request stream to write post data..."
				$RequestStream					= $HttpRequest.GetRequestStream();
				try {
					write-verbose "InvokeHttp: writing the post data to request stream..."
					$RequestStream.Write($PostBytes, 0, $PostBytes.Length);
				} finally {
					write-verbose "InvokeHttp: disposing the request stream..."
					$RequestStream.Dispose();
				}
			}
			
			write-verbose "InvokeHttp: Calling the page..."
			$HttpResponse = $HttpRequest.getResponse();
			
			if($HttpResponse){
				write-verbose "InvokeHttp: Http response received. $($HttpResponse.ContentLength) bytes of $($HttpResponse.ContentType)"
				$Result.httpResponse = $HttpResponse;
				
				if($HttpResponse.Cookies){
					write-verbose "InvokeHttp: Generating response session!";
					$HttpResponse.Cookies | %{
						write-verbose "InvokeHttp: Updating path of cookie $($_.Name)";
						$_.Path = '/';
					}
					
					$Result.session = @{cookies=$HttpResponse.Cookies};
				}
				
				
				write-verbose "InvokeHttp: Getting response stream and read it..."
				$ResponseStream = $HttpResponse.GetResponseStream();
				
				write-verbose "InvokeHttp: Creating memory stream and storing bytes...";
				$MemoryStream = New-Object IO.MemoryStream;
				CopyToStream -From $ResponseStream -To $MemoryStream
				$ResponseStream.Dispose();
				$ResponseStream = $null;


				#If content type is text/html, then parse it!
				if($HttpResponse.contentType -like 'text/html;*'){
					write-verbose "InvokeHttp: Creating streamreader to parse html response..."
					$MemoryStream.Position = 0;
					$StreamReader = New-Object System.IO.StreamReader($MemoryStream);
					write-verbose "InvokeHttp: Reading the response stream!"
					$ResponseContent =  $StreamReader.ReadToEnd();
					write-verbose "InvokeHttp: Using HAP to load HTML..."
					$HAPHtml = New-Object HtmlAgilityPack.HtmlDocument
					$HAPHtml.LoadHtml($ResponseContent);
					$Result.html = $HAPHtml;
				}
				
				write-verbose "InvokeHttp: Copying bytes of result to raw content!";
				$MemoryStream.Position = 0;
				$Result.raw = $MemoryStream.toArray();
				$MemoryStream.Dispose();
				$MemoryStream = $null;
				
				 
			}
			
			return $Result;
		} catch {
			throw "INVOKE_HTTP_ERROR: $_"
		} finnaly {
			if($MemoryStream){
				$MemoryStream.Dispose();
			}
			
			if($StreamReader){
				$StreamReader.Dispose();
			}
			
			
			if($ResponseStream){
				$ResponseStream.close();
			}
		
			if($HttpResponse){
				$HttpResponse.close();
			}
			

		}
		
	}
	
	
	
		
############# DEBUGGING CMDLETS.
##### This cmdlets are provided to allows externals calls debug of the module. To be used by module developers only.
#Debugging purposes
	Function Get-NewZabbixParams {
		param($method)
		
		return ZabbixAPI_NewParams $method
	}

	Function Invoke-ZabbixURL {
		param($APIParams, [switch]$Translate)
		
		
		write-host "Converting APIParams to JSON..."
		$APIString = ConvertToJson $APIParams;
		write-host "JSON:`r`n" $APIString
		
		$resp = CallZabbixURL -data $APIString;
		
		if($Translate){
			$resultado = TranslateZabbixJson $resp;
			$ResultsObjects = @();
			if($resultado){
				$resultado | %{
					$ResultsObjects += NEw-Object PSObject -Prop $_;	
				}
			}
		}
		
		return @{RawResponse=$resp;RawTranslate=$Resultado;ResultObjects=$ResultsObjects};
	}
	
	
	
############# NON-API Cmdlets
######This cmdlets are provided to allwos use supply or get information that module needs to talk with api, like usernames, urls, etc.

	#Store a URL connection information on cache.
	#This URL is marked as last url and will be used in calls to api.
	Function Set-ZabbixConnection([string]$url, $user = $null, $password = $null, $Name = $null) {
		
		if($Name -and !$url){
			$url = GetNamedZabbixConnection $Name;
			if(!$url){
				throw 'NAME_NOT_FOUND: $Name';
			}
		}
		
		$Slot = GetURLCache $url;
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


	#Auths a user on the zabbix server.
	#The authentication information (like auth token generated by the server) is saved on credential cache and marked as last used URL.
	#THus, every call that needs a authentication token, will be get from cache.
	Function Auth-Zabbix {
		[CmdLetBinding()]
		param(
				 $User 		= $null
				,$Password	= $null
				,$URL 		= $null
				,[switch]$Save = $null
				,[switch]$Frontend = $false
			)

		#Obtém uma referencial local para o cache de autenticação...
		$Cache = $Global:PowerZabbix_AuthCache;
			
		#Se não foi informada um URL, tenta obter a última utilizada...
		if(!$URL){
			write-verbose "Auth-Zabbix: Nenhuma URL fornecida... Tentando usar a última..."
			$URL = GetLastURL;
		}
		
		write-verbose "Auth-Zabbix: URL is: $URL";
		$URLCache = GetURLCache $URL;
		
		
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
			write-verbose "Auth-Zabbix: Saving user and password on cache..."
			$URLCache.User = $User;
			$URLCache.Password = $Password;
		}
			
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
		}
		
		#If users wants login in frontend, then do this.
		#This is useful for invoking some method that api dont support, like graphics.
		if($Frontend){
			$AuthPage = $URL;
			
			if($AuthPage -NotLike '*/'){
				$AuthPage = $AuthPage + '/'
			}
			
			write-verbose "Auth-Zabbix: Login into frontend. Ivoking the the page $AuthPage...";
			$LoginPage = InvokeHttp -URL $AuthPage;
			
			#At this point, we can setup all information need to send to zabbix login page.
			$LoginData = @{
				name = $User
				password = $Password
				enter = 'Sign in'
				autologin = 1
			}
			
			#Just call using our function to invoke http request...
			$LoginResult = InvokeHttp -URL $AuthPage -data $LoginData
			
			#If the login result was a 302, means sucessfully login.
			#This is because when login is sucessfully, zabbix frontend redirects the user to another page.
			#HTTP CODE 302 means redirections.
			if($LoginResult.httpResponse.statusCode -eq 302){
				$URLCache.lastFrontendAuth = $LoginResult.session;
			} else {
				
				#If return code was another thant 302, then somehting wrong occured.
				#We must try find in html response possible error messages expected...
				
				$AllErrorMsgs = @();
				
				if($LoginResult.html){
					$AllErrorMsgs += $LoginResult.html.DocumentNode.SelectNodes('//div[@class="article"]//div[@class="red"]/text()') | %{$_.InnerText};
				}
				
				
				if($AllErrorMsgs){
					throw "AUTH_FRONTEND_ERROR: $($AllErrorMsgs -Join '`r`n')"
					return;
				}

				throw "AUTH_FRONTEND_UNKOWN! StatusCode: $([int]$LoginResult.httpResponse.statusCode)"
			}
			
		}

		return;

	}


	#Returns a hashtable with a host interface to be used with cmdlet Create-Zabbixhost
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/hostinterface/object
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

	
	#Converts a lot of host names to respectiv ids!
	#The returned object is a array of hashtable containing the hostid key.
	Function ConvertHostNames2Ids {
		param($Names, [switch]$ReturnNames = $false)
		
		write-verbose "ConvertHostNames2Ids: Castings groups to groups ids..."
		$HostIds = ZabbixAPI_List2Ids $Names { 
													param($HostNames) 
													
													$Found = @();
													
													$Found = Get-ZabbixHost -Name $HostNames -Output @('hostid','name') | %{
														New-Object PSObject -Prop @{id=$_.hostid;name=$_.name};
													}
													
													return $Found;
												};			
		
		$NewGroups = @();
		if($HostIds){
			 $HostIds | %{
				$NewId = @{hostid = [int]$_.id};
				
				if($ReturnNames){
					$NewId['name'] = $_.name;
				}
				
				$NewGroups += $NewId;
			 }
		} else {
			throw "GROUPS_NOT_FOUND: $Names";
		}	
		
		write-verbose "ConvertHostNames2Ids: Hosts add casted sucessfully!";
		return $NewGroups;
	}
	
	
	#Converts a lot of groups names to respectiv ids!
	#The returned object is a array of hashtable containing the groupid key.
	Function ConvertGroupNames2Ids {
		param($Names, [switch]$ReturnNames = $false)
		
		write-verbose "ConvertGroupNames2Ids: Castings groups to groups ids..."
		$GroupIds = ZabbixAPI_List2Ids $Names { 
													param($GroupNames) 
													
													$Found = @();
													
													$Found = Get-ZabbixHostGroup -Name $GroupNames -Output @('groupid','name') | %{
														New-Object PSObject -Prop @{id=$_.groupid;name=$_.name};
													}
													
													return $Found;
												};			
		
		$NewGroups = @();
		if($GroupIDs){
			 $GroupIDs | %{
				$NewId = @{groupid = [int]$_.id};
				
				if($ReturnNames){
					$NewId['name'] = $_.name;
				}
				
				$NewGroups += $NewId;
			 }
		} else {
			throw "GROUPS_NOT_FOUND: $Names";
		}	
		
		write-verbose "ConvertGroupNames2Ids: Groups add casted sucessfully!";
		return $NewGroups;
	}
	
	#Converts a lot of map names to respective ids!
	#The returned object is a array of hashtable containing the groupid key.
	Function ConvertMapNames2Ids {
		param($Names, [switch]$ReturnNames = $false)
		
		write-verbose "ConvertMapNames2Ids: Castings maps to groups ids..."
		$MapIds = ZabbixAPI_List2Ids $Names { 
													param($MapNames) 
													
													$Found = @();
													
													$Found = Get-ZabbixMap -Name $MapNames -output @('sysmapid','name') | %{
														New-Object PSObject -Prop @{id=$_.sysmapid;name=$_.name};
													}
													
													return $Found;
												};			
		
		$NewMaps = @();
		if($MapIds){
			 $MapIds | %{
				$NewID = @{sysmapid = [int]$_.id};
				if($ReturnNames){
					$NewID['name'] = $_.name;
				}
				$NewMaps += $NewID;
			 }
		} else {
			throw "MAPS_NOT_FOUND: $Names";
		}	
		
		write-verbose "ConvertGroupNames2Ids: Groups add casted sucessfully!";
		return $NewMaps;
	}
	

############# API cmdlets ###############
#######API implementations. Starting at this point, API implementation################

######### HOST
	
	#Get a host object, that represent a host!
	#Based on: https://www.zabbix.com/documentation/3.4/manual/api/reference/host/object#host
	Function Get-ZabbixHostObject {
		[CmdLetBinding()]
		param()
		
		return New-Object PsObject -Prop @{
			hostid = [string]$null
			host = [string]$null
			name = [string]$null
			status = [int]$null
		}
		
	}

	#Equivalente ao método da API host.get
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/host/get
	Function Get-ZabbixHost {
		[CmdLetBinding()]
		param(
			 [int[]]$Id = @()
			,[string[]]$Name = @()
			,[string[]]$Groups 		= @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$output				= $null
			,$SelectGroups 			= $false
			,$SelectInterfaces		= $false
			,$HostStatus			= $null
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "host.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							output		= $output
							"filter"	= $filter
						}
						
					props = @{
						name = $Name 
					}
				}

		if($Id){
			$APIParams.params.add("hostids", $Id)
		}
				
		if($SelectGroups){
			$APIParams.params.add("selectGroups", $SelectGroups)
		}
		
		if($SelectInterfaces){
			$APIParams.params.add("selectInterfaces", $SelectInterfaces)
		}
		
		if($HostStatus -ne $null){
			$APIParams.params.filter.add("status", ([int]$HostStatus) )
		}
		
		#If groups was specified, convert it to group names...
		if($Groups){
			write-verbose "Get-ZabbixHost: About to convert group names to ids"
			[hashtable[]]$GroupsID = ConvertGroupNames2Ids $Groups;
			[int[]]$groupsids = @($GroupsID | %{$_.groupid});
			$APIParams.params.add("groupids", $groupsids )
		}
				
		#Builds the JSON string!
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


	#Equivalent to the method host.update.
	#In addition, added the option "Append". This option not exist in original API and is just a facility provided by this module.
	#https://www.zabbix.com/documentation/3.4/manual/api/reference/host/update
	#You must pipe this from result of Get-ZabbixHost in order to use them.
	Function Update-ZabbixHost {
		[CmdLetBinding(SupportsShouldProcess=$True)]
		param(
			$Groups = $null
			
			,#If specified, the cmdlet will get existent groups and add to the list informed!
				[switch]$Append = $false
				
			,#If piped with Get-Zabibx host, get the returned object from it!
			 #Note that this cmdlet expects a object returned by Get-Zabbixhost cmdlet!
				[Parameter(ValueFromPipeline=$true, Mandatory=$true)]
				$ZabbixHost
		)

		begin {
			$AllHosts = @{};
			[int[]]$NewGroups = @();
			
			#If groups was specified, convert it to group names...
			if($Groups){
				write-verbose "Update-ZabbixHost: About to convert group names to ids"
				[hashtable[]]$NewsGroup = ConvertGroupNames2Ids $Groups;
			}
		
		
		}
		
		process {
			if($ZabbixHost){
				#Converts the object to a hashtable in order to avoid circular reference problem...
				$ObjectHashTable = @{};
				$ZabbixHost.psobject.properties | %{ $ObjectHashTable.add($_.Name,$ZabbixHost.psobject.properties[$_.Name].Value)  };
				
				#Add the groupids property if exists...
				if($NewsGroup){
					$ObjectHashTable.add("groups",$NewsGroup)
				}
				
				$AllHosts.add($ZabbixHost.hostid, $ObjectHashTable);
			} else {
				throw "INVALID_ZABBIX_HOST"
			}
		}
		
		end {
		
			#If appends specified, gets the groups for the hosts...
			if($Append){
				#Gets the groups for each host id!
				$Ids = $AllHosts.Values | %{$_.hostid};
				$HostInfo = Get-ZabbixHost -SelectGroups @("groupid") -Id $Ids -Output @("hostid");
				
				#Adds groups for each host!
				$HostInfo | %{
					$CurrentHost = $AllHosts[$_.hostid];
					$CurrentGroups = $_.groups;
					
					$CurrentHost.groups += @( $CurrentGroups | %{ @{groupid=$_.groupid}  }  )
				}
				
			}
		
		
			$APIParams = ZabbixAPI_NewParams "host.update";
			$APIParams.params = @($AllHosts.Values);
			
			write-verbose "Update-ZabbixHost: APIParams, before convert $APIParams"
			$APIString = ConvertToJson $APIParams;
			write-verbose "Update-ZabbixHost: APIString, before convert $APISTring"
			
			#Chama a Url
			$ConfirmMsg = @(
				"Hosts to be updated: $($AllHosts.count)"
				"JSON: "+(ConvertToJson @($AllHosts.Values))
			) -Join "`r`n"

			
			
			
			if($PSCmdLet.ShouldProcess($ConfirmMsg)){
				$resp = CallZabbixURL -data $APIString;
				$resultado = TranslateZabbixJson $resp;
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
			,[string[]]$Hosts 	= @()		
			,[string[]]$Groups  	= @()
			,[string[]]$ObjectId	= @()	
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
			
			,#Try gets correlated event with this one.
			 #A correlated event is the event the OK or PROBLEM event associated with this.
			 #If passed object is a PROBLEM, the correlated is a OK.
			 #If passed object is a OK, the correlated is a PROBLEM. This always must exists (if not deleted by zabbix internal)
			 #YOu must pass a object or array of objects returned by this cmdlet.
			 #The cmdlet will add the property "correlated" to each object.
			 #This parameter is not provided by Zabbix API, and just it a enchament provided by this cmdlet.
			 #Note that for each object passed in this parameter, the cmdlet will make a call to zabbix. The number of calls to zabbix will be equals to number of objects.
			 #This can be slow.
				$Correlate = $null
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
				
		if($Correlate){
			
			$Correlate  | %{
				if($_.value -eq 1) {
					#finds the OK. It must be a clock after this clock.
					$C = Get-ZabbixEvent -ObjectId $_.objectid -TimeFrom ([int]$_.clock + 1) -Value 0 -Limit 1
				} else {
					#finds the PROBLEM, It must be a clock current.
					$C = Get-ZabbixEvent -ObjectId $_.objectid -TimeTill ([int]$_.clock - 1) -Value 1 -Limit 1
				}
				
				$_ | Add-Member -Type Noteproperty -Name "correlated" -Value $C -force;
			
			}
			
			return;
		}
		else {
			
		
			if($Id){
				$APIParams.params.add("eventids", $Id ); 
			}
			
			if($ObjectId){
				$APIParams.params.add('objectids', $ObjectId);
			}
					
			if($TimeFrom){
				[string]$TimeFromFilter = "";
				if($TimeFrom -is [int]){
					$TimeFromFilter = $TimeFrom;
				} else {
					$TimeFromFilter = Datetime2Unix $TimeFrom;
				}
			
				$APIParams.params.add("time_from", $TimeFromFilter); 
			}
			
			if($TimeTill){
				[string]$TimeTillFilter = "";
				if($TimeTill -is [int]){
					$TimeTillFilter = $TimeTill;
				} else {
					$TimeTillFilter = Datetime2Unix $TimeTill;
				}
				
				$APIParams.params.add("time_till", $TimeTillFilter ); 
			}
			
			if($Value){
				$APIParams.params.add('value', $Value);
			}
			
			if($Hosts){
				write-verbose "Get-ZabbixEvent: Castings hosts to groups ids..."
				[hashtable[]]$HostsIds = ConvertHostNames2Ids $Hosts;
				[int[]]$hostids = @($HostsIds | %{$_.hostid});
				$APIParams.params.add("hostids", $hostids )
				write-verbose "Get-ZabbixEvent: Groups add casted sucessfully!"
			}
			
			if($Groups){
				write-verbose "Get-ZabbixEvent: Castings groups to groups ids..."
				[hashtable[]]$GroupsID = ConvertGroupNames2Ids $Groups;
				[int[]]$groupsids = @($GroupsID | %{$_.groupid});
				$APIParams.params.add("groupids", $groupsids )
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
	
######### MAP

	#Implementation of method map.get
	Function Get-ZabbixMap {
		param(
			 [int[]]$Id		 = @()
			,[string[]]$Name = @()
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$Output			   = $null
		)

				
		#Determinando searchByAny
		$APIParams = ZabbixAPI_NewParams "map.get"
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
				
		if($Id){
			$APIParams.params.add('sysmapids', $Id);
		}
		
		write-verbose "Get-ZabbixMap: APIParams, before convert $APIParams"
		$APIString = ConvertToJson $APIParams;
		write-verbose "Get-ZabbixMap: APIString, before convert $APISTring"
							
		#Chama a Url
		write-verbose "Get-ZabbixMap:  calling zabbix url function..."
		$resp = CallZabbixURL -data $APIString;
		write-verbose "Get-ZabbixMap:  response received! Calling translate..."
		$resultado = TranslateZabbixJson $resp;
		write-verbose "Get-ZabbixMap:  Translated!"
		
		write-verbose "Get-ZabbixMap: Building result objexts..."
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$ResultsObjects += NEw-Object PSObject -Prop $_;	
			}
		}

		write-verbose "Get-ZabbixMap: Objects generated = $ResultsObjects.count"
		
		return $ResultsObjects;
	}

######### ITEM	

	#Equivalente ao método da API item.get
	#https://www.zabbix.com/documentation/2.0/manual/appendix/api/item/get
	Function Get-ZabbixItem {
		[CmdLetBinding()]
		param(
			 $name = $null
			,[int[]]$Id				= @()
			,$Hosts 				= @()		
			,$Groups  				= @()
			,$selectHosts 			= $null
			,$selectTriggers		= $null
			,$limit					= $null
			,[switch]$Search 	   = $false
			,[switch]$SearchByAny  = $false
			,[switch]$StartSearch  = $false
			,$output				= $null
		)

		
	
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "item.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $Search 
							searchByAny = $SearchByAny
							startSearch = $StartSearch
							limit		= $limit
							output		= $output
						}
						
						
					props = @{
						name = $Name 
					}
				}

			
		
		if($Id){
			$APIParams.params.add("itemids", $Id ); 
		}
		
		if($Hosts){
			$NamesToConvert = @();
			[int[]]$hostids =  $Hosts | %{
				if($_.hostid){
					return $_.hostid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				write-verbose "Get-ZabbixItem: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $NamesToConvert;
				$hostids += @($ConvertedHosts | %{$_.hostid});
			}
		
			$APIParams.params.add("hostids", $hostids )
			write-verbose "Get-ZabbixItem: Groups add casted sucessfully!"
		}
		
		if($Groups){
			$NamesToConvert = @();
			[int[]]$groupsids =  $Groups | %{
				if($_.groupid){
					return $_.groupid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				write-verbose "Get-ZabbixItem: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedGroups = ConvertGroupNames2Ids $NamesToConvert;
				$groupsids += @($ConvertedGroups | %{$_.groupid});
			}
		
			$APIParams.params.add("groupids", $groupsids )
			write-verbose "Get-ZabbixItem: Groups add casted sucessfully!"
		}

		
		if($selectHosts){
			$APIParams.params.add("selectHosts", $selectHosts);
		}
		
		if($selectTriggers){
			$APIParams.params.add("selectTriggers", $selectTriggers);
		}
				

			
		write-verbose "Get-ZabbixItem: About to generate json from apiparams!"
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
				
				$ResultsObjects += $r;
			}
		}

		return $ResultsObjects;
	}
	
######### HISTORY	
	#Equivalente ao método da API history.get
	#https://www.zabbix.com/documentation/2.0/manual/appendix/api/history/get
	Function Get-ZabbixHistory {
		[CmdLetBinding()]
		param(
			 [int]$history 	= $null
			,$Hosts 	= @()		
			,$Items		= @()
			,$TimeFrom 	= $null
			,$TimeTill	= $null
			,$limit		= $null
		)

		
		#Determinando searchByAny
		[hashtable]$APIParams = ZabbixAPI_NewParams "history.get"
		ZabbixAPI_Get $APIParams -APIParams @{
					common = @{
							search 		= $false 
							searchByAny = $false
							startSearch = $false
							limit		= $limit
						}
				}
					
		if($TimeFrom){
			[string]$TimeFromFilter = "";
			if($TimeFrom -is [int]){
				$TimeFromFilter = $TimeFrom;
			} else {
				$TimeFromFilter = Datetime2Unix $TimeFrom;
			}
		
			$APIParams.params.add("time_from", $TimeFromFilter); 
		}
		
		if($TimeTill){
			[string]$TimeTillFilter = "";
			if($TimeTill -is [int]){
				$TimeTillFilter = $TimeTill;
			} else {
				$TimeTillFilter = Datetime2Unix $TimeTill;
			}
			
			$APIParams.params.add("time_till", $TimeTillFilter ); 
		}

		if($Hosts){
			$NamesToConvert = @();
			[int[]]$hostids =  $Hosts | %{
				if($_.hostid){
					return $_.hostid;
				} else {
					if ($_ -is [string]){
						$NamesToConvert += $_;
					} else {
						return [int]$_;
					}
				}
			}
			
			if($NamesToConvert){
				write-verbose "Get-ZabbixHistory: Castings hosts to groups ids..."
				[hashtable[]]$ConvertedHosts = ConvertHostNames2Ids $NamesToConvert;
				$hostids += @($ConvertedHosts | %{$_.hostid});
			}
		
			$APIParams.params.add("hostids", $hostids )
			write-verbose "Get-ZabbixHistory: Groups add casted sucessfully!"
		}
		
		if($Items){
			[int[]]$itemids = @();
			
			$Items | %{
				if($_.itemid){
					$itemids += $_.itemid
				} else {	
					$itemids += [int]$_;
				}
			}
			
			$APIParams.params.add("itemids", $itemids )
		}
		
		if($history){
			$APIParams.params.add("history", $history )
		}

		write-verbose "Get-ZabbixHistory: About to generate json from apiparams!"
		$APIString = ConvertToJson $APIParams;
		write-verbose "JSON is: $APIString";
		
		#Chama a Url
		$resp = CallZabbixURL -data $APIString;
		$resultado = TranslateZabbixJson $resp;
		
		
		$ResultsObjects = @();
		if($resultado){
			$resultado | %{
				$r = New-Object PSObject -Prop $_;
				
				#Adiciona o datetime local...
				if($r | gm "clock"){
					$r | Add-Member -Type Noteproperty -Name "datetime" -Value (UnixTime2LocalTime $r.clock)
				}

				$ResultsObjects += $r;
			}
		}

		return $ResultsObjects;
	}

	
############# FRONTEND cmdlets ###############
#######Starting at this point, some calls to frontend to workaround some functionality that API dont support.################

######### MAP

	#This allows get a map.
	#The cmdlet must be used in conjuction with the Get-ZabbixMap cmdlet.
	#It will add the property 'mapImage' to the object returned from this cmdlet.
	#This property will contains the following properties:
	#
	#	bytes (the bytes of map. Just write to a file)
	#	errro (possible errors ocurred when getting map from zabbix)
	Function Add-ZabbixMapImage {
		[CmdLetBinding()]
		param(
		
			#Must return this object with Get-ZabbixMap cmdlet
			#The return objects must include at least sysmapid propertie.
			[parameter(Mandatory=$true,ValueFromPipeline=$true)]
			[object]$Map
			
			,$MinSeverity 	= 5
		)
		
		begin {
			#Get last authentication of frontned!
			$FrontendSession = GetZabbixApiAuthToken -Frontend;
			#Get last used URL!
			$LastURL = GetLastURL;
			#Full URL to the map!
			$AccessURL = "$LastURL/map.php?sysmapid={0}&severity_min=$MinSeverity";
		}
		
		process  {
			if(!$Map){
				return;
			}
		
			$MapURL = $AccessURL -f $_.sysmapid;
			$MapImage = New-Object PSObject;
			$MapImage | Add-Member -Name bytes -Type Noteproperty -Value $null
			$MapImage | Add-Member -Name error -Type Noteproperty -Value $null
			$Map | Add-Member -Name mapImage -Type Noteproperty -Value $MapImage;
			
			if(!$Map.sysmapid){
				$MapImage.error = 'sysmapid property not found!';
				return;
			}
		
			
			write-verbose "Accessing the map $($_.name) on url $MapURL";
			$HttpResp = InvokeHttp -URL $MapURL -Session $FrontendSession;
			
			try {
				if($HttpResp.httpResponse.statusCode -eq 200){
					$MapImage.bytes = $HttpResp.raw;
				} else {
					$MapImage.error = "HTTP ERROR: StatusCode:$($HttpResp.httpResponse.statusCode)";
				}
			} catch {
				$MapImage.error = $_;
			}
		}
		
		end {
			write-verbose "Done";
		}
	}


