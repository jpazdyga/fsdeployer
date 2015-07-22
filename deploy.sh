#!/bin/bash

if [ -z "$1" ];
then
	echo "Please specify git url to clone as first argument and a domain name as a second:"
	echo "$0 git@github.com:jpazdyga/testapp.git pazdyga.pl"
	exit 1
fi

email2sub="jakub.pazdyga@ft.com"
maintainer="Jakub Pazdyga <$email2sub>"
giturl="$1"
domainname2sub="$2"
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

getappcode() {
	subdir=`echo \"$giturl\" | awk -F'/' '{print \$NF}' | cut -d. -f1`
	gitproto=`ncat -i0.2 -w1 --send-only github.com 9418 2>&1 | grep "timed out"`
	if [ ! -z "$gitproto" ];
	then
		giturl=`echo "$giturl" | sed -e 's/github.com:/github.com\//g' -e 's/git@/https:\/\//g'`
	fi
	if [ ! -z ./ops ] || [ ! -z ./dev ] || [ ! -z ./$subdir ];
	then
		rm -fr $subdir
		git clone $giturl
		ln -s $subdir/ops ./
		ln -s $subdir/dev ./
		return 0
	else
		rm -fr subdir ops dev
		getappcode
	fi
}

dockeros() {
	cd docker
	cleanup
	test="test5"
	echo -e "FROM jpazdyga/centos7-base\nMAINTAINER $maintainer\n" > Dockerfile
	echo -e "RUN yum clean all #$test" >> Dockerfile
	for package in `ls ../ops/`;
	do
		echo -e "RUN yum -y install $package; yum clean all #$test" >> Dockerfile
	done
	echo -e "COPY supervisord.conf /etc/supervisor.d/supervisord.conf\n" >> Dockerfile
}

dockerdirs() {
	for directory in `find ./ops/ -mindepth 2 -type d | cut -d/ -f4-`;
	do
		if [ ! -d /etc/$directory ];
		then
			echo "RUN mkdir -p /etc/$directory" >> Dockerfile
		fi
	done
	for configfile in `find ./ops/ -mindepth 2 -type f`;
	do
		target=`echo $configfile | cut -d/ -f4- | sed 's|^|/etc\/|g'`
		echo "ADD $configfile $target" >> Dockerfile
	done
	echo -e "VOLUME $wwwpath2sub /var/log\nENV DATE_TIMEZONE UTC\nEXPOSE 80 443\nUSER root\nCMD [\"/usr/bin/supervisord\", \"-n\", \"-c/etc/supervisor.d/supervisord.conf\"]" >> Dockerfile
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

getappcode
dockeros
imageprep
dockerdirs
dockerbake
