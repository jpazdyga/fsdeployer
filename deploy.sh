#!/bin/bash

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

bootstrap() {
	bootstrap=`find ../ops/ -mindepth 2 -type f | grep $helper | grep bootstrap.sh`
        echo "Bootstrap: $bootstrap"
        docker exec -i $helper-$shortname2sub bash < $bootstrap
}

dockerbake() {
	if [ -z "$hlist" ];
        then
                hlist=`find ../ops/ -mindepth 1 -type d | grep $availhlp | awk -F '/' '{print $NF}'`
        fi
	for helper in $hlist;
	do
		#TODO: listen port as variable from somewhere:
		sudo docker run --name $helper-$shortname2sub -d -p 3306:3306 jpazdyga/$helper
		bootstrap
	done
	sudo docker build --no-cache=true -t apache-$shortname2sub-img .
	sudo docker run --name apache-$shortname2sub -d -p 80:80 --add-host dbhost:$hostip apache-$shortname2sub-img
}

getappcode() {
	subdir=`echo \"$giturl\" | awk -F'/' '{print \$NF}' | cut -d. -f1 | sed 's/\"//g'`
	gitproto=`ncat -i0.2 -w1 --send-only github.com 9418 2>&1 | grep "timed out"`
	if [ ! -z "$gitproto" ];
	then
		giturl=`echo "$giturl" | sed -e 's/github.com:/github.com\//g' -e 's/git@/https:\/\//g'`
	else
		gitcheck=`git clone $giturl 2>1 > /dev/null ; echo $?`
		echo "Git protocol test result: $gitcheck"
		if [ "$gitcheck" -ne "0" ];
		then
			giturl=`echo "$giturl" | sed -e 's/github.com:/github.com\//g' -e 's/git@/https:\/\//g'`
		fi
	fi
	echo "Giturl: $giturl"
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
	echo -e "FROM jpazdyga/centos7-base\nMAINTAINER $maintainer\n" > Dockerfile
	echo -e "ENV container docker\n" >> Dockerfile
	echo -e "RUN yum clean all\n" >> Dockerfile
        for package in `ls ../ops/`;
	do
		echo -e "RUN yum -y install $package; yum clean all\n" >> Dockerfile
	done
	hostip=`ip addr show eth0 | grep -w inet | awk '{print $2}' | cut -d'/' -f1`
	echo -e "COPY supervisord.conf /etc/supervisor.d/supervisord.conf\n" >> Dockerfile
}

dockerdirs() {
	for directory in `find ./ops/ -mindepth 2 -type d | cut -d/ -f4-`;
	do
		if [ ! -d /etc/$directory ];
		then
			echo "RUN mkdir -p /etc/$directory\n" >> Dockerfile
		fi
	done
	echo -e "RUN mkdir -p /var/log/httpd\n" >> Dockerfile
	for configfile in `find ./ops/ -mindepth 2 -type f | egrep -v 'bootstrap|\.sql'`;
	do
		target=`echo $configfile | cut -d/ -f4- | sed 's|^|/etc\/|g'`
		echo "ADD $configfile $target" >> Dockerfile
	done
	echo -e "ENV container docker\nENV DATE_TIMEZONE UTC\nEXPOSE 80\nVOLUME $wwwpath2sub /etc\nUSER root\nCMD [\"/usr/bin/supervisord\", \"-n\", \"-c/etc/supervisor.d/supervisord.conf\"]" >> Dockerfile
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

helpers() {
	echo "We need to deploy $hlist server as well!"
}

helperslist() {
	echo -e "$availhlp\n"
	echo -e "Please declare if you want to deploy the helper of your choice by:\n$0 git@github.com:jpazdyga/testapp.git pazdyga.pl --helpers=mariadb\n"
	exit 0
}

helpmsg() {
	echo -e "\nPlease specify git url to clone as first argument, domain name as a second and (optionally) helper name:\n$0 git@github.com:jpazdyga/testapp.git pazdyga.pl\nList of available helpers is available by: $0 --helpers list.\n"
}

### List of helpers available. MariaDB is sufficent for the standard and taxonomy development ###
availhlp="mariadb"

if [ -z "$1" ] || [ -z "$2" ];
then
	helpmsg
	exit 1
else
	if [ ! -z "$3" ]
	then 
		if [ `echo $3 | grep "\-\-helpers"` ];
		then
			hlist=`echo $3 | cut -d'=' -f2`
			helpers
		else
			helpmsg
		fi
	fi
fi

case $1 in
	--helpers)
		echo -e "\nList of helper you can use to get your app running:\n"
		helperslist
	;;
	*)
		echo "Proceed"
	;;
esac
	
getappcode
dockeros
imageprep
dockerdirs
dockerbake
