#Guacomater
##Automate the creation of Guacamole AD objects

Guacamole (the HTML5 remote desktop gateway) has the ability to use Microsoft's Active Directory as the store for where connection objects are held, instead of in a MariaDB instance. As AD is already my store for other types of objects, namely computers, users and groups, I preferred using it to store guacamole objects. It also opened up unique management opportunities

With this in mind, I wanted a way to automatically have any new computers I add to AD be populated in the Guacamole console. This way I didn't need to have a seperate process for ensuring new servers get added properly to Guacamole to be able to remotely connect to them.

##Guacomater was born

Guacomater is a PowerShell script I created that runs periodically on a server on my network. It scans designated OU's for computer objects and compares it against currently defined Guacamole objects. Once this comparison is done, the Guacamole objects are created or deleted as required.

##Parameters
A number of switches & parameters are avaialble to help tailor the operation of the script. Ideally, you would look through the script and evaluate its behaviour in the lab prior to turning loose in production. That said, below are the exposed script options.

####GuacObjectsOU
DN of OU that will hold our Guacamole configuration objects

####WorkstationGroup
AD security group allowed to connect to 'workstation' class systems.

####ServerGroup
AD security group allowed to connec to 'server' class systems

####Domain
NETBIOS domain name objects exist in

####Rebuild
Boolean value (true/false) used to control if all existing guac objects should be purged and started over from scratch. Use care with this if objects have been created outside of the script.

####CleanAny
Boolean value to manage objects not created by the script

####EVLog
Boolean value to determine if an event should be written to the local event log when the script runs

####Mail
Boolean value used to decide if an email should be sent

####SMTPServer
String value that identifies the SMTP server (e.g. mail.contoso.com)

####MailFrom
String value that identifies the email address the email will come from (e.g. scripts@contoso.com)

####MailTo
