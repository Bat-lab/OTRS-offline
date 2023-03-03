
#!/bin/bash


tar -xvf ./otrs6-0-38-offline.tar.gz -C /opt/


yum -y localinstall /opt/otrs6-0-38-offline/rpm-packages/*.rpm


mkdir -p /tmp/perl-modules/perl

#=========================================================================================
for file in /opt/otrs6-0-38-offline/perl-compile-modules/*.tar.gz
do 

tar -zxf "$file" -C /tmp/perl-modules/perl 

done
#========================================================================================
#mv /tmp/mytar/perl/DateTime-TimeZone-2.57 /tmp/mytar/perl/zDateTime-TimeZone-2.57
#ls -l /tmp/mytar/perl | awk '{print $9}' > /tmp/output.txt

#========================================================================================
while IFS= read -r line
do 

cd /tmp/perl-modules/perl/"$line" ; echo -e "n" | perl Makefile.PL;make;make install

done < ./perl-6.0-depend.txt


#========================================================================================



#############phpMyAdmin####################

sed -E -i -e 's/Require local/Require all granted/g'  /etc/httpd/conf.d/phpMyAdmin.conf

echo "date.timezone = Asia/Kolkata" >> /etc/php.ini


#################apache configuration#######################

sed -E -i -e 's/DirectoryIndex (.*)$/DirectoryIndex index.php \1/g' /etc/httpd/conf/httpd.conf

sed -E -i -e '/ServerName www.example.com:80/s/^#//g' -i /etc/httpd/conf/httpd.conf

systemctl restart httpd
systemctl status httpd
systemctl enable httpd

###########################mysql configuration and DB creation########################

systemctl start mysqld
systemctl status mysqld
systemctl enable mysqld

cp /etc/my.cnf /etc/my.cnf_orig

echo -e "character_set_server=utf8\nmax_allowed_packet   = 512M\n\ninnodb_redo_log_capacity = 1024M\ninnodb_log_file_size = 1024M\nauthentication_policy=mysql_native_password" >> /etc/my.cnf


#rm -rf /var/lib/mysql/ib_logfile0 /var/lib/mysql/ib_logfile1

systemctl restart mysqld

pass=$(cat /var/log/mysqld.log | grep -i 'temporary password' | awk '{print $13}')

SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect \"Enter password for user root:\"
send -- \"$pass\r\"

expect \"New password:\"
send \"Welcome@2023\r\"

expect \"Re-enter new password:\"
send \"Welcome@2023\r\"

expect \"Change the password for root ? ((Press y|Y for Yes, any other key for No) :\"
send \"yes\r\"

expect \"New password:\"
send \"Welcome@2023\r\"

expect \"Re-enter new password:\"
send \"Welcome@2023\r\"

expect \"Do you wish to continue with the password provided?(Press y|Y for Yes, any other key for No) :\"
send \"yes\r\"

expect \"Remove anonymous users? (Press y|Y for Yes, any other key for No) :\"
send \"yes\r\"

expect \"Disallow root login remotely? (Press y|Y for Yes, any other key for No) :\"
send \"yes\r\"

expect \"Remove test database and access to it? (Press y|Y for Yes, any other key for No) :\"
send \"yes\r\"

expect \"Reload privilege tables now? (Press y|Y for Yes, any other key for No) :\"
send \"yes\r\"

expect eof
")

echo "$SECURE_MYSQL"

sleep 7

mysql -u root -pWelcome@2023 -e "CREATE USER 'otrs'@'%' IDENTIFIED WITH mysql_native_password BY 'Otrs@123';"

mysql -u root -pWelcome@2023 -e "GRANT USAGE ON *.* TO 'otrs'@'%';"

mysql -u root -pWelcome@2023 -e "ALTER USER 'otrs'@'%' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;"

mysql -u root -pWelcome@2023 -e 'CREATE DATABASE IF NOT EXISTS `otrs`;'

mysql -u root -pWelcome@2023 -e 'GRANT ALL PRIVILEGES ON `otrs`.* TO "otrs"@"%";'


#CREATE USER 'otrs'@'%' IDENTIFIED WITH mysql_native_password BY 'Otrs@123';GRANT USAGE ON *.* TO 'otrs'@'%';ALTER USER 'otrs'@'%' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;CREATE DATABASE IF NOT EXISTS `otrs`;GRANT ALL PRIVILEGES ON `otrs`.* TO 'otrs'@'%';


################################otrs-setup##########################################

tar -jxvf /opt/otrs6-0-38-offline/otrs-community-edition-6.0.38.tar.bz2 -C /opt/

mv /opt/otrs-community-edition-6.0.38 /opt/otrs

/opt/otrs/bin/otrs.CheckModules.pl

perl -cw /opt/otrs/bin/cgi-bin/index.pl
perl -cw /opt/otrs/bin/cgi-bin/customer.pl
perl -cw /opt/otrs/bin/otrs.Console.pl

useradd -d /opt/otrs -c 'OTRS user' otrs
usermod -G apache otrs
cp /opt/otrs/Kernel/Config.pm.dist /opt/otrs/Kernel/Config.pm
perl -cw /opt/otrs/bin/cgi-bin/index.pl   # NEED SYNTAX  OK

cp /opt/otrs/scripts/apache2-httpd.include.conf /etc/httpd/conf.d/otrs.conf

/opt/otrs/bin/otrs.SetPermissions.pl --web-group=apache --otrs-user=otrs

systemctl restart httpd






