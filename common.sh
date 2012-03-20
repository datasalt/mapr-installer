#!/bin/bash

function install_snappy {
  sudo apt-get --force-yes -y install 
  snappy_url="http://snappy.googlecode.com/files/snappy-1.0.5.tar.gz"
  rm -rf snappy-1.0.5
  curl $snappy_url | tar xvz 
  cd snappy-1.0.5
  ./configure
  make
  sudo make install
  cd ..
  rm -rf hadoop-snappy-read-only

  sudo ln -s $JAVA_HOME/jre/lib/amd64/server/libjvm.so /usr/local/lib/libjvm.so

  #svn co http://hadoop-snappy.googlecode.com/svn/branches/mavenized hadoop-snappy-read-only
  svn co http://hadoop-snappy.googlecode.com/svn/trunk/ hadoop-snappy-read-only
  cd hadoop-snappy-read-only
  mvn package -DskipTests
  mkdir tar_extracted
  mv target/hadoop-snappy-0.0.1-SNAPSHOT.tar.gz tar_extracted
  cd tar_extracted
  tar xvzf hadoop-snappy-0.0.1-SNAPSHOT.tar.gz 
  sudo cp -R hadoop-snappy-0.0.1-SNAPSHOT/lib/* /opt/mapr/hadoop/hadoop-0.20.2/lib/

}

function set_in_mapred_site {
 key=$1
 value=$2
 echo "Setting $key = $value in mapred-site.xml"
 #cat $mapred_site_file | tr -d "\n" | sed "s/> *</></g" > $mapred_site_file
 tmp_mapred_site="$mapred_site_file.tmp"
 sudo ruby $HOME/set_in_mapred.rb $mapred_site_file $tmp_mapred_site $key $value
 sudo cp $tmp_mapred_site $mapred_site_file
 #sudo perl -p -i -e "s/<property><name>$key</name><\/property>/blublu/" /opt/mapr/hadoop/hadoop-0.20.2/conf/mapred-site.xml.backup
 #sudo sed  -i "s/<property><name>$key<\/name><value>(.*)<\/value><\/property>//g" $mapred_site_file
 #sudo sed  -i "s/<\/configuration>//g" $mapred_site_file
 #sudo echo "<property><name>$key</name><value>$value</value></property></configuration>" >> $mapred_site_file
}

function config_hadoop {

 mapred_site_file="/opt/mapr/hadoop/hadoop-0.20.2/conf/mapred-site.xml"
 mapred_backup="${mapred_site_file}.backup"
 if [ ! -f "$mapred_backup" ]; then
   sudo cp $mapred_site_file $mapred_backup
 else 
   sudo cp $mapred_backup $mapred_site_file
 fi  
#mapred_site_file="/opt/mapr/hadoop/hadoop-0.20.2/conf/mapred-site.xml"
 set_in_mapred_site "mapred.child.java.opts" "-Xmx1024m"
 set_in_mapred_site "mapreduce.job.counters.limit" "500"
 set_in_mapred_site "mapred.tasktracker.map.tasks.maximum" "2"
 set_in_mapred_site "mapred.tasktracker.reduce.tasks.maximum" "2"
 set_in_mapred_site "io.compression.codecs" "org.apache.hadoop.io.compress.GzipCodec,org.apache.hadoop.io.compress.DefaultCodec,org.apache.hadoop.io.compress.BZip2Codec,org.apache.hadoop.io.compress.SnappyCodec"

}




function master_install {
        user=$1
        master_host=$2
        
        sudo apt-get -y --force-yes -f install mapr-cldb mapr-jobtracker mapr-webserver mapr-zookeeper

        install_snappy
	sudo /etc/init.d/mapr-cldb stop
	sudo /opt/mapr/server/configure.sh -C $master_host:7222 -Z $master_host:5181 -N MyCluster
        config_hadoop
	sudo umount /dev/sdb
	echo "/dev/sdb" > /tmp/disks.txt
	sudo /opt/mapr/server/disksetup -F /tmp/disks.txt
	sudo /etc/init.d/mapr-zookeeper restart
	sudo /etc/init.d/mapr-warden restart
	sudo /etc/init.d/mapr-cldb restart
	N_SECONDS=40
	echo "Waiting $N_SECONDS seconds"
	sleep $N_SECONDS
	echo "Configuring access to Mapr Control System (webapp)"
	sudo /opt/mapr/bin/maprcli acl edit -type cluster -user $user:fc
	echo "Configured!"
	echo "Then you can enter using proxy to Mapr Control System: https://localhost:8443 and manage licenses"

}

function slave_install {
    master_host=$1
    sudo apt-get -y --force-yes -f install mapr-tasktracker mapr-fileserver
    sudo /etc/init.d/mapr-warden stop
    install_snappy
    sudo /opt/mapr/server/configure.sh -C $master_host:7222 -Z $master_host:5181 -N MyCluster
    config_hadoop
    #restart tasktracker
    sudo umount /dev/sdb
    echo "/dev/sdb" > /tmp/disks.txt
    sudo /opt/mapr/server/disksetup -F /tmp/disks.txt
    sudo /etc/init.d/mapr-warden restart
}



function install_all {
   user=$1
   master_host=$2
   master_or_slave=$3

   echo -e "blabla\nblabla" | sudo passwd $user
   sudo add-apt-repository ppa:sun-java-community-team/sun-java6
   sudo sh -c 'echo "deb http://package.mapr.com/releases/v1.2.2/ubuntu/ mapr optional" >> /etc/apt/sources.list'
   sudo dpkg --configure -a

   sudo apt-get update
   sudo dpkg --configure -a
   #Install SUN-JAVA6-JDK
   echo "y" | sudo apt-get -f -y --force-yes install perl ruby rubygems git-core openjdk-6-jre build-essential autotools-dev autoconf ant libtool maven2 subversion sun-java6-jdk
    
   #curl http://package.mapr.com/scripts/whirr/sun/java/install | sudo bash
   #echo "y" | sudo apt-get -y --force-yes install sun-java6-jdk
   sudo apt-get -f -y --force-yes install
   #sudo perl -MCPAN -e 'install XML::Simple'
   sudo gem install xml-simple
   sudo update-java-alternatives -s java-6-sun
   export JAVA_HOME=/usr/lib/jvm/java-6-sun

   if [ $master_or_slave = "master" ]; then
     master_install $user $master_host 
   elif [ $master_or_slave = "slave" ]; then
     slave_install $master_host
   else 
     echo "Unknown host_type $master_or_slave"
     exit -1
   fi
}

function services {
    master_or_slave=$1
    operation=$2
    if [ $master_or_slave = "master" ]; then
      sudo /etc/init.d/mapr-zookeeper $operation
      sudo /etc/init.d/mapr-warden $operation
      #sudo /etc/init.d/mapr-cldb $operation
    elif [ $master_or_slave = "slave" ]; then
      sudo /etc/init.d/mapr-warden $operation
    else 
     echo "Unknown host_type $master_or_slave"
     exit -1
    fi
}


if [ -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
    echo "args: [user] [master_host] [master|slave] [install|stop|start|restart]"
    exit 1
fi

user=$1
master_host=$2
master_or_slave=$3
operation=$4

echo "user $user"
echo "master $master_host"
echo "mode $master_or_slave"
echo "operation $operation"

if [ $operation = "install" ]; then
  install_all $user $master_host $master_or_slave
elif [ $operation = "stop" -o $operation = "start" -o $operation = "stop" -o $operation = "restart" ]; then
  services $master_or_slave $operation
else
  echo "Unknown operation $operation "
  exit -1
fi





