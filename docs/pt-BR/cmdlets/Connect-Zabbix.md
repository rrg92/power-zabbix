---
external help file: PowerZabbix-help.xml
schema: 2.0.0
---

# Connect-Zabbix

## SYNOPSIS <!--!= @#Synop !-->
Conecta com um Zabbix e cria uma nova sessão para invocar os demais comandos

## DESCRIPTION <!--!= @#Desc !-->
Este é o ponto de partida para começar a usar o power zabbix.  
Este comando faz a autenticação com o servidor zabbix especificado e, se a autenticação for feita com sucesso, cria uma sessão.  
Uma sessão é um objeto na memória do power-zabbix que contém tudo o que é necessário para invocar as demais APIs.  É onde fica o token de autenticação.  
Você pode se autenticar usando uma API token, basta informar a mesma no campo "Password"

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
A URL do zabbix!
Pode ser servidor:porta (assume http por padrao)
pode ser https://servidor:porta 
Formato: [http[s]://]host[:porta][/path]

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
Nome do usuário (Criado no zabbix)

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
Senha do usuáro

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
Autentica usando uma API Token

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
Especifica a api token direto como parâmetro.
Especificar este, implicitamente, habilita -UseApiToken

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
Nome único que identifica esta conexão

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
Forçar recriar a conexão mesmo que já exista uma em aberto

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