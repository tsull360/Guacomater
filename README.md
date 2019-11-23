# Guacomater
## Automate the creation of Guacamole AD objects

Guacamole (the HTML5 remote desktop gateway) has the ability to use Microsoft's Active Directory as the store for where connection objects are held, instead of in a MariaDB instance. As AD is already my store for other types of objects, namely computers, users and groups, I preferred using it to store guacamole objects. It also opened up unique management opportunities

With this in mind, I wanted a way to automatically have any new computers I add to AD be populated in the Guacamole console. This way I didn't need to have a seperate process for ensuring new servers get added properly to Guacamole to be able to remotely connect to them.

Some more info can be found here: https://tsull360.wordpress.com/2019/11/23/automating-guacamole-object-creation-2/

## Guacomater was born

Guacomater is a PowerShell script I created that runs periodically on a server on my network. It scans designated OU's for computer objects and compares it against currently defined Guacamole objects. Once this comparison is done, the Guacamole objects are created or deleted as required.

## Parameters

A number of switches & parameters are avaialble to help tailor the operation of the script. Please open up the script and take a look at the parameters available. These need to be customized as appropriate.

# Thats It!
I hope this helps out in your environment to get more from Guacamole. Please feel free to open issues or make changes.