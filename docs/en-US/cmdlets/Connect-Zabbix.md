---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Connect-Zabbix

## SYNOPSIS <!--!= @#Synop !-->
Connects to a Zabbix server and creates a new session to invoke other commands

## DESCRIPTION <!--!= @#Desc !-->
This is the starting point for using power zabbix.  
This command authenticates with the specified zabbix server and, if authentication is successful, creates a session.  
A session is an object in power-zabbix memory that contains everything needed to invoke other APIs.  It's where the authentication token is stored.  
You can authenticate using an API token, just provide it in the "Password" field

## SYNTAX <!--!= @#Syntax !-->

### UserPass
```
Connect-Zabbix [[-URL] <Object>] [-User <Object>] [-Password <Object>] [-Frontend] [-Name <Object>] [-Force] [<CommonParameters>]
```

### Apitoken
```
Connect-Zabbix [[-URL] <Object>] [-UseApiToken] [-ApiToken <Object>] [-Frontend] [-Name <Object>] [-Force] [<CommonParameters>]
```

## PARAMETERS <!--!= @#Params !-->

### -URL
The Zabbix URL!
Can be server:port (assumes http by default)
can be https://server:port 
Format: [http[s]://]host[:port][/path]

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: 1
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -User
User name (Created in zabbix)

```yml
Parameter Set: UserPass
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Password
User password

```yml
Parameter Set: UserPass
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -UseApiToken
Authenticates using an API Token

```yml
Parameter Set: Apitoken
Type: SwitchParameter
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: False
Accept pipeline input: false
Accept wildcard characters: false
```

### -ApiToken
Specifies the API token directly as a parameter.
Specifying this implicitly enables -UseApiToken

```yml
Parameter Set: Apitoken
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Frontend

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: False
Accept pipeline input: false
Accept wildcard characters: false
```

### -Name
Unique name that identifies this connection

```yml
Parameter Set: (All)
Type: Object
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: 
Accept pipeline input: false
Accept wildcard characters: false
```

### -Force
Force recreate the connection even if one is already open

```yml
Parameter Set: (All)
Type: SwitchParameter
Aliases: 
Accepted Values: 
Required: false
Position: named
Default Value: False
Accept pipeline input: false
Accept wildcard characters: false
```



<!--**AiDocBlockStart**-->
_Automatically translated using PowershAI and AI. 
_
<!--**AiDocBlockEnd**-->
