# devops-project
# To run this project we need an ansible master which has terraform installed.
# When the client server comes up, ansible master copy the ssh key into master
# And install apache server, copy httpd.conf, copy ssl certificate related stuff into the machine.
# ansible-playbook <<playbookname>> --extra-vars "ip_address=clientIpaddress"
