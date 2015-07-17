#!/bin/bash

if [ -z "$1" ];
then
	echo "Please specify domain name as an argument."
	exit 1
fi

email2sub="jakub.pazdyga@ft.com"
maintainer="Jakub Pazdyga <$email2sub>"
domainname2sub="$1"
wwwpath2sub='/var/www'
vhosttmpldir="ops/httpd/httpd/conf.d"

cleanup() {
	rm -fr {dev,ops}
	cat /dev/null > Dockerfile
}

dockerbake() {
	sudo docker build -t apache_$shortname2sub-img .
	sudo docker run --name apache_$shortname2sub -d -p 80:80 apache_$shortname2sub-img
	cleanup
	cd ..
}

dockeros() {

	cd docker
	cleanup
	echo -e "FROM centos\nMAINTAINER $maintainer\nRUN yum -y install epel-release\nRUN yum -y update ; yum -y install python-setuptools python-pip" > Dockerfile
        for package in `ls ../ops/`;
	do
		echo -e "RUN yum -y install $package" >> Dockerfile
	done
	echo -e "RUN rm -rf /var/cache/yum/* && yum clean all\nRUN pip install supervisor\nRUN mkdir -p /etc/supervisor.d/\nCOPY supervisord.conf /etc/supervisor.d/supervisord.conf\n" >> Dockerfile

}

dockerdirs() {

	for directory in `find ./ops/ -mindepth 2 -type d | cut -d/ -f4-`;
	do
		echo "RUN mkdir -p /etc/$directory" >> Dockerfile
	done
	for configfile in `find ./ops/ -mindepth 2 -type f`;
	do
		target=`echo $configfile | cut -d/ -f4- | sed 's|^|/etc\/|g'`
		echo "ADD $configfile $target" >> Dockerfile
	done
	echo -e "VOLUME /var/log $wwwpath2sub/\nENV DATE_TIMEZONE UTC\nEXPOSE 80 443\nUSER root\nCMD [\"/usr/bin/supervisord\", \"-n\", \"-c/etc/supervisor.d/supervisord.conf\"]" >> Dockerfile

}

dockervhost() {
	echo -e "RUN mkdir -p $wwwpath2sub/$shortname2sub.$domainname2sub\nCOPY ./root_$shortname2sub/ $wwwpath2sub/$shortname2sub.$domainname2sub/\n" >> Dockerfile
}

vhostcreate() {
	sed -e 's/email2sub/'$email2sub'/g' -e 's/shortname2sub/'$shortname2sub'/g' -e 's/domainname2sub/'$domainname2sub'/g' -e "s|wwwpath2sub|$wwwpath2sub|g" $vhosttmpldir/vhosts.conf > $vhosttmpldir/$shortname2sub-vhost.conf
}

imageprep() {

	cp -rp ../ops/ ./
	for shortname2sub in `ls -d ../dev/* | grep root | awk -F '_' '{print $2}'`;
	do
		cp -rp ../dev/root_$shortname2sub ./
		vhostcreate
		dockervhost
	done
	rm -f $vhosttmpldir/vhosts.conf

}

dockeros
imageprep
dockerdirs
dockerbake
