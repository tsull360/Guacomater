<#
.SYNOPSIS
    Automate the creation of Guacamole configuration objects.

.DESCRIPTION
    Guacomator automates the creation and deletion of Guacamole, a clientless RDP tool,
     configuration objects in Active Directory using AD OU data as the authoritative source
    of configuration.

    For more info on Guacamole: https://guacamole.apache.org/

.PARAMETER GuacObjectsOU
    Location where the script will create new Guac objects at and manage existing ones.

.PARAMETER WorkstationGroup
    AD security group used for permissions Guac objects sourced from a Workstattions OU

.PARAMETER ServerGroup
    AD security group used for permissionsing Guac objects sourced for the servers OU

.PARAMETER Domain
    AD domain scrip is operating in

.PARAMETER Rebuild
    Instructs script to ignore existing state and recreate all objects

.PARAMETER CleanAny
    The script tags any objects it creates (vs manual ones). This switch
    instructs script to reconcile any objects whether created by the script or not.

.PARAMETER EVLog
    Boolean switch for writing to the event log.

.PARAMETER Mail
    Boolean switch for sending a stats email.

.PARAMETER SMTPServer
    FQDN of mail server to relay mail off of.

.PARAMETER MailFrom
    SMTP address of sending user

.PARAMETER MailTo
    SMTP address of recipient(s)

.INFO
    Author: Tim Sullivan
    Contact: tsull360@live.com
    Version: v1.0 - Initial Release

#>

[CmdletBinding(SupportsShouldProcess=$true)]
Param
(
    
    [Parameter(Mandatory=$false)]
    [String]$GuacObjectsOU,
    
    [Parameter(Mandatory=$false)]
    [String]$WorkStationGroup,
    
    [Parameter(Mandatory=$false)]
    [String]$ServerGroup,

    [Parameter(Mandatory=$false)]
    [String]$Domain,

    [Parameter(Mandatory=$false)]
    [Boolean]$Rebuild=$false,

    [Parameter(Mandatory=$false)]
    [Boolean]$CleanAny=$false,
    
    [Parameter(Mandatory=$false)]
    [Boolean]$EVLog=$true,
    
    [Parameter(Mandatory=$false)]
    [Boolean]$Mail=$true,

    [Parameter(Mandatory=$false)]
    [String]$SMTPServer,

    [Parameter(Mandatory=$false)]
    [String]$MailFrom,

    [Parameter(Mandatory=$false)]
    [String]$MailTo

)

$ADOUTable = @{
    "Servers" = "OU=Devices,OU=Org,DC=contoso,DC=com";
    "Workstations" = "OU=Computers,OU=Enterprise Management,DC=contoso,DC=com";
    "DC" = "OU=Domain Controllers,DC=contoso,DC=com"
}

$GuacUserTable = @{
    "Servers" = "CN=ServerAdmins,OU=Groups,OU=Org,DC=contoso,DC=com";
    "Workstations" = "CN=WorkstationAdmins,OU=Groups,OU=Org,DC=contoso,DC=com"
}

#Function for creating new guacConfig objects.
Function New-GuacObject($CreateObject)
{
    try
    {
        Write-Verbose "Creating guacConfig object for $CreateObject"

        # Need to go backwards, taking the objectDN and using that to lookup the 'class' of system
        $CreateObjectDN = $CreateObject.DistinguishedName

        Write-Verbose "Object DN: $CreateObjectDN"
        
        $MemberVal = ("CN=Tim,OU=Users,OU=Org,DC=contoso,DC=com")

        $ConfigTable = @{
            "guacConfigProtocol"="rdp";
            "member"="$MemberVal"
            "pHostname"="hostname=$CreateObject.$Domain";
            "pUsername"="username=`${GUAC_USERNAME}";
            "pPassword"="password=`${GUAC_PASSWORD}";
            "pCert"="ignore-cert=true";
            "pSecurity"="security=any";
            "pClient"="client-name=`${GUAC_CLIENT_HOSTNAME}";
            "Description"="Created by Guac Config script."
        }
        
        New-ADObject -Type "guacConfigGroup" -Name $CreateObject -Path "$GuacObjectsOU" -OtherAttributes @{guacConfigProtocol="rdp"; `
                                                                                                           guacConfigParameter= `
                                                                                                           $($ConfigTable.Get_Item("pHostName")), `
                                                                                                           $($ConfigTable.Get_Item("pUserName")), `
                                                                                                           $($ConfigTable.Get_Item("pPassword")), `
                                                                                                           $($ConfigTable.Get_Item("pCert")), `
                                                                                                           $($ConfigTable.Get_Item("pSecurity")), `
                                                                                                           $($ConfigTable.Get_Item("pClient")); `
                                                                                                           member="$MemberVal"; `
                                                                                                           description=$($ConfigTable.Get_Item("Description"))}
        Write-Verbose "Object Created!"
    }
    catch
    {
        Write-Verbose "Error creating guacConfig object. Error. $($_.Exception.Message)"
    }
}

#Function for deleting no longer needed guacConfig objects.
Function Remove-GuacObject($RemoveObject)
{
    Write-Verbose "In Remove-GuacObject function..."
    try 
    {
        Write-Verbose "Removing object $RemoveObject"
        Remove-ADObject -Identity $RemoveObject -confirm:$false
        Write-Verbose "Object deleted!"
    }
    catch 
    {
        Write-Verbose "Error deleting object. Error: $($_.Exception.Messge)"
    }
    Write-Verbose "Remove-GuacObject function work done."
}

#Function for getting all relevent AD computer objects
Function Get-ADObjects
{
    Write-Verbose "In Get-ADObjects function..."
    $ADOUTable.GetEnumerator() | Foreach-Object 
    {
        Foreach ($OU in $ADObjectsOU)
        {
            Write-Verbose "Getting ADObjects from $($_.Value)..."
            $Script:ADObjects += Get-ADComputer -Filter * -SearchBase $_.Value -Properties *
        }
    Write-Verbose "AD Objects: $($ADObjects.Name)"

    Write-Verbose "Get-ADObjects function work complete."
    }
}

#Function for getting all current guacamole configuration objects
Function Get-GuacObjects
{
    Write-Verbose "In Get-GuacObjects function..."
    Write-Verbose "Getting GuacObjects from $GuacObjectsOU"

    If ($CleanAny -eq $true)
    {
        Write-Verbose "Cleanany set to true. Will evaluate all objects."
        $Script:GuacObjects = Get-ADObject -LDAPFilter "(objectClass=guacConfigGroup)" -SearchBase $GuacObjectsOU -Properties *
    }
    Else
    {
        Write-Verbose "Cleanany set to false. Will only operate on script created objects."
        $Script:GuacObjects = Get-ADObject -LDAPFilter "(objectClass=guacConfigGroup)" -SearchBase $GuacObjectsOU -Properties * | Where-Object {$_.Description -notlike "Created by Guac Config script"}
        Write-Verbose "Guac Objects: $($GuacObjects.Name)"  
    }
  

    Write-Verbose "Get-GuacObjects function complete."
}

#Retrieve AD objects, call Get-ADObjects function.
Get-ADObjects

#Retrieve current Guacamole objects.
Get-GuacObjects

#Build action lists.
If ($ADObjects -like "*")
{
    #Call function to compare objects, build task lists.
    Write-Verbose "In Compare-Objects function..."

    If ($Rebuild -eq $true)
    {

        Write-Verbose "Rebuild flag passed. Will recreate all Guac config objects."
        $Script:MissingGuac = $ADObjects

        $Script:MissingAD = $GuacObjects

        Write-Verbose "Rebuild. Will remove: $($MissingAD.Name)"
        Write-Verbose "Rebuild. Will recreate: $($MissingGuac.Name)"

    }
    Else
    {

        Write-Verbose "Rebuild flag not passed. Comparing Guac config to AD."
        #AD Objects, no corresponding Guac Object
        $Script:MissingGuac = Compare-Object -ReferenceObject $ADObjects -DifferenceObject $GuacObjects -Property Name| Where-Object {$_.SideIndicator -eq '<='}
    
        # Guac objects, no corresponding AD object
        $Script:MissingAD = Compare-Object -ReferenceObject $ADObjects -DifferenceObject $GuacObjects -Property Name | Where-Object {$_.SideIndicator -eq '=>'}

        Write-Verbose "No rebuild. Will delete: $($MissingAD.Name)"
        Write-Verbose "No rebuild. Will create: $($MissingGuac.Name)"

    }
    

    Write-Verbose "Compare-Objects function work complete."
}
Else
{
    Write-Verbose "No AD object results were returned. Exiting out."
}

#Begin deletion of no longer needed guac objects.
If ($MissingAD.Name -like "*")
{
    Write-Verbose "Found no longer needed Guac objects to delete."
    #Begin deletion of unneeded guac objects.
    ForEach ($AD in $MissingAD.Name)
    {
        Write-Verbose "Will delete guac config: $AD"
        $RemoveObject = "CN=$AD,$GuacObjectsOU"
        Remove-GuacObject $RemoveObject
        Write-Verbose "Task complete for $AD"
    }
}
Else
{
    Write-Verbose "No extra guacamole objects to clean up."
}

#Begin creation of needed guac objects.
If ($MissingGuac.Name -like "*")
{
    Write-Verbose "Found missing Guacamole config items."
    Foreach ($Guac in $MissingGuac.Name)
    {
        Write-Verbose "Will create guac config: $Guac"
        $CreateObject = $Guac
        New-GuacObject $CreateObject
        Write-Verbose "Task Complete for $Guac"
    }
}
Else 
{
    Write-Verbose "No missing guacamole items to create."
}


$LogMessage = @"
Guacamole Object Creation Script

Supplied Variables
Guac Objects OU: $GuacObjectsOU
Workstation Management Group: $WorkStationGroup
Server Management Group: $ServerGroup
Device Domain: $Domain
Generate Event Log Entry: $EVLog
Send Email: $Mail
SMTP Server: $SMTPServer
Mail Sender: $MailFrom
Mail Recipient: $MailTo
Should Rebuild: $Rebuild
Should Cleanup All: $CleanAny

Work Status
Will Delete:
$($MissingAD.Name)

Will Create:
$($MissingGuac.Name)

Script Actions Complete
"@


If ($EVLog -eq $true)
{
    Write-Verbose "Writing event log entry..."
    #Create event log source, if it does not already exist.
    if ([System.Diagnostics.EventLog]::SourceExists("Guacomator") -eq $false) 
    {
        [System.Diagnostics.EventLog]::CreateEventSource("Guacomator","Application")
    }
    Write-EventLog -LogName "Application" -EntryType Information -EventId 0330 -Source Guacomator -Message $LogMessage
    Write-Verbose "Event log entry recorded."
}

            
If ($email -eq $true)
{
    Write-Verbose "Sending mail message..."
    try
    {
        Write-Verbose "Sending status email..."
        Send-MailMessage -To $MailTo -Subject "Guacamole Object Creator" -Body $LogMessage -SmtpServer $SMTPServer -From $MailFrom
        Write-Verbose "Mail sent."
    }
    catch
    {
        Write-Verbose "Error sending mail message. Error: $_.Exception.Message"
    }
    Write-Verbose "Mail actions complete."
}