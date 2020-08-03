#!/bin/bash
#
# echo -e "\e[1;36m \e[0m"
#
# Copyright (c) 2020 Anmol Nayyar. Released under the MIT License.
# Find me @ https://www.linkedin.com/in/anmol-nayyar/

echo " "
echo "This script assumes that you are trying to host a basic static website on a remote server"
echo " "
echo -e "\e[1;33mThis script is tuned specifically for Debian 10 Buster \e[0m"
echo " "
echo -e "\e[1;33mStatic files [HTML, CSS, JS etc.] should be existing /var/www directory \e[0m"
echo " "
echo "Performing some basic checks...."

if readlink /proc/$$/exe | grep -q "dash"; then
	echo -e "\e[1;31mThis script needs to be run with bash, not sh \e[0m"
	exit
fi

if [[ "$EUID" -ne 0 ]]; then
echo -e "\e[1;31mSorry, you need to run this scrip with root privileges \e[0m"
exit
fi

#Detect running Operating System
if [[ -e /etc/debian_version ]]; then
getOS=`cat /etc/debian_version | cut -d "." -f1`;
if [[ $getOS -eq 10 ]]; then
:
else
echo -e "\e[1;33mThe Operating System is not Debian 10, there might be some issues with the Installation \e[0m"
fi
else
echo -e "\e[1;33mThe Operating System is not Debian / Ubuntu \e[0m"
exit
fi

echo " "
echo "Everything looks fine"
echo " "

#Getting inputs from the user
echo "We need a few inputs from your side before we begin"
echo -e "\e[1;36mEnter the domain name of your website [Eg. example.com]: \e[0m"
read DomainName
echo -e "\e[1;36mEnter the public IP address of your server [xxx.xxx.xxx.xxx]: \e[0m"
read IpAddress
echo -e "\e[1;36mEnter the name of root directory where your wesbite files are located in /var/www/ folder [Eg. exampleDirectory]: \e[0m"
read OrgSiteDirectory
echo -e "\e[1;36mDo you have a custom 404 html page in the directory ? (Y/n) \e[0m"
read custom_html
if [[ "$custom_html" = 'y' || "$custom_html" = 'Y' ]]; then
echo -e "\e[1;36mEnter the name of the custom error page [Eg. 404.html]:  \e[0m"
read errorPageName
errorPage="/var/www/$DomainName/$errorPageName"
else
echo "The website will be directed to HOME by default"
errorPage="/var/www/$DomainName/index.html"
fi
echo -e "\e[1;36mEnter an Email address to be used for SSL certificate related communication\e[0m"
read email
echo -e "\e[1;36mChoose the key size for SSL Configuration\e[0m"
echo -e "\e[1;36m  1) 4096 [takes a lot of time, more secure]\e[0m"
echo -e "\e[1;36m  2) 2048 [Comparatively Quicker, less secure]\e[0m"
read -p "Select an option: " key_option
until [[ "$key_option" =~ ^[1-2]$ ]]; do
			echo "$option: invalid selection."
			read -p "Select an option: " key_option
		done
echo	
case "$key_option" in
	1)
	key_size="4096"
	;;
	2)
	key_size="2048"
	;;
esac

#confirmation from the user
echo "Please confirm if the information is correct:"
echo -e "Domain name of your site is \e[1;32m$DomainName\e[0m"
echo -e "IP address of Server is \e[1;32m $IpAddress \e[0m"
echo -e "path to root directory of your site is: \e[1;32m/var/www/$OrgSiteDirectory\e[0m"
echo -e "Error Page will be configured as \e[1;32m$errorPage\e[0m"
echo -e "Email address for SSL communication is \e[1;32m$email\e[0m"
echo -e "Key size for SSL certificates will be \e[1;32m$key_size\e[0m"
echo -e "\e[1;36mKindly confirm if the data is correct (Y/n)\e[0m"
read dataConfirm

if [[ "$dataConfirm" = 'y' || "$dataConfirm" = 'Y' ]]; then
mv /var/www/$OrgSiteDirectory /var/www/$DomainName
else
echo " "
echo -e "\e[1;31mKindly execute the script again an re-enter the data\e[0m"
echo " "
exit
fi

echo " "
echo -e "Before going ahead, set up a DNS A Record to point \e[1;33m$IpAddress to $DomainName\e[0m by logging in to your domain registrar console"
echo " "
echo -e "\e[1;36mHave you set the DNS record ? (Y/n)\e[0m"
read selection

if [[ "$selection" = 'y' || "$selection" = 'Y' ]]; then
:
else
echo " "
echo "Kindly Execute the Script after setting up the DNS record"
exit
fi

echo
echo "Following files will be installed"
echo "1. Nginx"
echo "2. Certbot and nginx plugin" 
echo
echo "Installing the required files..."
sudo apt-get install nginx -y
sudo apt-get install certbot python-certbot-nginx -y
echo
echo "Configuring Nginx"

#Basic Sanitization
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.save
rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default

#Temporary File for certificate
echo "server {" > /etc/nginx/sites-available/$DomainName
echo -e "\tlisten 80 default_server;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tlisten [::]:80 default_server;" >> /etc/nginx/sites-available/$DomainName
echo -e "\troot /var/www/$DomainName;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tindex index.html;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tserver_name $DomainName;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tlocation / {" >> /etc/nginx/sites-available/$DomainName
echo -e "\t\ttry_files $uri $uri/ =404;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t}" >> /etc/nginx/sites-available/$DomainName
echo -e "}" >> /etc/nginx/sites-available/$DomainName

ln -s /etc/nginx/sites-available/$DomainName /etc/nginx/sites-enabled/$DomainName
sudo systemctl restart nginx

echo
echo -e "\e[1;36mBasic Setup Complete\e[0m"

echo
echo -e "\e[1;36mObtaining an SSL Certificate\e[0m"

sudo certbot certonly -m $email --agree-tos --domain $DomainName --nginx -n

if [[ -e "/etc/letsencrypt/live/$DomainName" ]]; then
:
else
echo -e "\e[1;31mThere is some issue with certificate generation, Kindly ensure that an A record has been established properly and Try again.\e[0m"
echo -e "If the issue persists, please follow manual installation \e[1;36mhttps://blog.fruxlabs.com/securely-set-up-a-website-with-nginx/\e[0m"
exit
fi

echo
echo "Building configuration for $DomainName"

#Final Configuration
echo "server {" > /etc/nginx/sites-available/$DomainName
echo -e "\tlisten 443 http2 default_server;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tlisten [::]:443 default_server;" >> /etc/nginx/sites-available/$DomainName
echo -e "\troot /var/www/$DomainName;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tindex index.html;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tserver_name $DomainName;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t" >> /etc/nginx/sites-available/$DomainName
echo -e "\tssl on;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tssl_certificate /etc/letsencrypt/live/$DomainName/fullchain.pem;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tssl_certificate_key /etc/letsencrypt/live/$DomainName/privkey.pem;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t" >> /etc/nginx/sites-available/$DomainName
echo -e "\tgzip on;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tgzip_types application/javascript image/* text/css;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tgunzip on;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t" >> /etc/nginx/sites-available/$DomainName
echo -e "\terror_page 404 $errorPage;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tlocation = $errorPage {" >> /etc/nginx/sites-available/$DomainName
echo -e "\t\troot /var/www/$DomainName;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t\tinternal;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t}" >> /etc/nginx/sites-available/$DomainName
echo -e "\t" >> /etc/nginx/sites-available/$DomainName
echo -e "\tif (\$host != \"$DomainName\") {" >> /etc/nginx/sites-available/$DomainName
echo -e "\t\treturn 404;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t}" >> /etc/nginx/sites-available/$DomainName
echo -e "\t" >> /etc/nginx/sites-available/$DomainName
echo -e "\tlocation / {" >> /etc/nginx/sites-available/$DomainName
echo -e "\t\ttry_files \$uri \$uri/ =404;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t}" >> /etc/nginx/sites-available/$DomainName
echo -e "\t" >> /etc/nginx/sites-available/$DomainName
echo -e "\tlocation ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2)$ {" >> /etc/nginx/sites-available/$DomainName
echo -e "\t\texpires 10d;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t}" >> /etc/nginx/sites-available/$DomainName
echo -e '\t' >> /etc/nginx/sites-available/$DomainName
echo -e '\tadd_header "Referrer-Policy" "strict-origin";' >> /etc/nginx/sites-available/$DomainName
echo -e '\tadd_header Feature-Policy "geolocation none;";' >> /etc/nginx/sites-available/$DomainName
echo -e '\tadd_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;' >> /etc/nginx/sites-available/$DomainName
echo -e '\tadd_header "X-XSS-Protection" "1; mode=block";' >> /etc/nginx/sites-available/$DomainName
echo -e '\tadd_header "X-Content-Type-Options" "nosniff" always;' >> /etc/nginx/sites-available/$DomainName
echo -e '\tadd_header "X-Frame-Options" "DENY" always;' >> /etc/nginx/sites-available/$DomainName
echo -e '\tadd_header "X-Permitted-Cross-Domain-Policies" "master-only";' >> /etc/nginx/sites-available/$DomainName
echo -e "}" >> /etc/nginx/sites-available/$DomainName
echo -e "\t" >> /etc/nginx/sites-available/$DomainName
echo -e "server {" >> /etc/nginx/sites-available/$DomainName
echo -e "\tlisten 0.0.0.0:80;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tserver_name $DomainName;" >> /etc/nginx/sites-available/$DomainName
echo -e "\treturn 301 https://$DomainName\$request_uri;" >> /etc/nginx/sites-available/$DomainName
echo -e "\t}" >> /etc/nginx/sites-available/$DomainName
echo -e "\t" >> /etc/nginx/sites-available/$DomainName
echo -e "server {" >> /etc/nginx/sites-available/$DomainName
echo -e "\tlisten 80 default_server;" >> /etc/nginx/sites-available/$DomainName
echo -e "\tserver_name _;" >> /etc/nginx/sites-available/$DomainName
echo -e "\treturn 404;" >> /etc/nginx/sites-available/$DomainName
echo -e "}" >> /etc/nginx/sites-available/$DomainName

echo
echo "Hardening SSL. This step will take some time. DO NOT CANCEL"

openssl dhparam -out /etc/ssl/dhparams.pem $key_size
awk '/ssl_prefer_server_ciphers/ { print; print "\tssl_ciphers \"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA HIGH !RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS\";"; next }1' /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
awk '/ssl_ciphers/ { print; print "\tssl_dhparam /etc/ssl/dhparams.pem;"; next }1' /etc/nginx/nginx.conf.tmp > /etc/nginx/nginx.conf.tmp2
rm  /etc/nginx/nginx.conf
mv /etc/nginx/nginx.conf.tmp2 /etc/nginx/nginx.conf
rm /etc/nginx/nginx.conf.tmp
sed -i 's/ssl_protocols .*/ssl_protocols 'TLSv1.2\;'/' /etc/nginx/nginx.conf
sed -i 's/# server_tokens .*/server_tokens 'off\;'/' /etc/nginx/nginx.conf

echo
echo -e "\e[1;36mSetup Complete\e[0m"
echo
echo -e "\e[1;36mVerifying the configurations\e[0m"

sudo nginx -t 2> test

if grep -q ok test; then
    rm test
	sudo systemctl restart nginx
	chown -R www-data:www-data /var/www/$DomainName
	echo
	echo "One Last step to be performed by you."
	echo "Kindly add this line to your crontab for auto renewal of SSL certificate"
	echo -e "\e[1;33m17 7 * * * certbot renew --post-hook \"systemctl reload nginx\"\e[0m"
	echo
	echo "For additional security you can add CSP header to your website configuration as follows"
	echo -e "\e[1;33madd_header Content-Security-Policy \"default-src 'self';\";\e[0m"
	echo -e "\e[1;32mSetup Complete. You can visit your website at https://$DomainName\e[0m"
	echo 
	echo "Reach me out on https://github.com/anmolnayyar"
	exit
else
    echo
	rm test
	echo -e "\e[1;31mThere is some issue with the installation, please follow manual installation \e[1;36mhttps://blog.fruxlabs.com/securely-set-up-a-website-with-nginx/\e[0m"
	exit
fi
