#!/bin/bash

function install_snappy {
  sudo apt-get --force-yes -y install
  export JAVA_HOME=/usr/lib/jvm/java-6-sun 
  snappy_url="http://snappy.googlecode.com/files/snappy-1.0.5.tar.gz"
  #rm -rf snappy-read-only 
  #svn checkout http://snappy.googlecode.com/svn/trunk/ snappy-read-only
  rm -rf snappy-1.0.5
  curl $snappy_url | tar xvz 
  
  cd snappy-1.0.5
  #./autogen.sh
  ./configure && make && sudo make install
  sudo ln -s /usr/local/lib/libsnappy.{a,so} /usr/lib

  cd ..
  rm -rf hadoop-snappy-read-only

  sudo ln -s $JAVA_HOME/jre/lib/amd64/server/libjvm.so /usr/local/lib/libjvm.so

  #svn co http://hadoop-snappy.googlecode.com/svn/branches/mavenized hadoop-snappy-read-only
  svn co http://hadoop-snappy.googlecode.com/svn/trunk/ hadoop-snappy-read-only
  cd hadoop-snappy-read-only
  #wget 'http://hadoop-snappy.googlecode.com/issues/attachment?aid=60001000&name=hadoop-snappy-dlopen.patch&token=pXyznME9u36A4qVP3ikI_rQDHb4%3A1332318198755' -O hadoop-snappy.patch
  #patch -p1 -i hadoop-snappy.patch
  mvn package
  mkdir tar_extracted
  mv target/hadoop-snappy-0.0.1-SNAPSHOT.tar.gz tar_extracted
  cd tar_extracted
  tar xvzf hadoop-snappy-0.0.1-SNAPSHOT.tar.gz 
  sudo cp -R hadoop-snappy-0.0.1-SNAPSHOT/lib/* /opt/mapr/hadoop/hadoop-0.20.2/lib/
  #sudo cp /usr/local/lib/libsnappy.{la,a} /opt/mapr/hadoop/hadoop-0.20.2/lib/native/Linux-amd64-64/ 

  #sudo cp -R hadoop-snappy-0.0.1-SNAPSHOT/lib/* /opt/mapr/lib/
  #sudo rm -rf /opt/mapr/hadoop/hadoop-0.20.2/lib/native/Linux-i386-32/
  #sudo rm /opt/mapr/hadoop/hadoop-0.20.2/lib/hadoop-snappy-0.0.1-SNAPSHOT.jar
}

function set_in_mapred_site {
 key=$1
 value=$2
 file=$3
 echo "Setting $key = $value in $file"
 #cat $mapred_site_file | tr -d "\n" | sed "s/> *</></g" > $mapred_site_file
 tmp_file="$file.tmp"
 sudo ruby $HOME/set_in_mapred.rb $file $tmp_file $key $value
 sudo cp $tmp_file $file
 #sudo perl -p -i -e "s/<property><name>$key</name><\/property>/blublu/" /opt/mapr/hadoop/hadoop-0.20.2/conf/mapred-site.xml.backup
 #sudo sed  -i "s/<property><name>$key<\/name><value>(.*)<\/value><\/property>//g" $mapred_site_file
 #sudo sed  -i "s/<\/configuration>//g" $mapred_site_file
 #sudo echo "<property><name>$key</name><value>$value</value></property></configuration>" >> $mapred_site_file
}

function config_hadoop {
 #sudo rm -rf /opt/mapr/hadoop/hadoop-0.20.2/lib/snappy #debug, remove
 #mapred_site_file="/opt/mapr/hadoop/hadoop-0.20.2/conf/mapred-site.xml"
 file="/opt/mapr/hadoop/hadoop-0.20.2/conf/mapred-site.xml"
 file_backup="${file}.backup"
 if [ ! -f "$file_backup" ]; then
   sudo cp $file $file_backup
 else 
   sudo cp $file_backup $file
 fi  
#mapred_site_file="/opt/mapr/hadoop/hadoop-0.20.2/conf/mapred-site.xml"
 set_in_mapred_site "mapred.output.compression.type" "BLOCK" $file
 set_in_mapred_site "mapred.map.output.compression.type" "BLOCK" $file
 set_in_mapred_site "mapred.submit.replication" "3" $file
 set_in_mapred_site "mapred.child.java.opts" "-Xmx1024m" $file
 set_in_mapred_site "mapreduce.job.counters.limit" "500" $file
 set_in_mapred_site "mapred.tasktracker.map.tasks.maximum" "2" $file
 set_in_mapred_site "mapred.tasktracker.reduce.tasks.maximum" "2" $file
 set_in_mapred_site "mapred.output.compress" "true"  $file
 set_in_mapred_site "mapred.compress.output" "true"  $file
 set_in_mapred_site "mapred.output.compression.codec" "org.apache.hadoop.io.compress.SnappyCodec" $file
 set_in_mapred_site "mapred.reduce.tasks" "20" $file
 set_in_mapred_site "mapred.compress.map.output" "true" $file
 set_in_mapred_site "mapred.map.output.compression.codec" "org.apache.hadoop.io.compress.SnappyCodec" $file
 set_in_mapred_site "io.compression.codecs" "org.apache.hadoop.io.compress.GzipCodec,org.apache.hadoop.io.compress.DefaultCodec,org.apache.hadoop.io.compress.BZip2Codec,org.apache.hadoop.io.compress.SnappyCodec" $file

}

function install_thrift {
  cd
  sudo apt-get -y --force-yes install libboost-dev libevent-dev libtool flex bison g++ automake pkg-config libboost-test-dev libmono-dev ruby1.8-dev libcommons-lang-java php5-dev
  wget http://archive.apache.org/dist/thrift/0.6.1/thrift-0.6.1.tar.gz
  tar xvzf thrift-0.6.1.tar.gz
  cd thrift-0.6.1
  ./configure && make && sudo make install
}


function master_install {
        user=$1
        master_host=$2
        
        sudo apt-get -y --force-yes -f install mapr-cldb mapr-jobtracker mapr-webserver mapr-zookeeper
	#install_thrift
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
   sudo sh -c 'echo "deb http://package.mapr.com/releases/v1.2.3/ubuntu/ mapr optional" >> /etc/apt/sources.list'
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
    echo "args: [user] [master_host] [master|slave] [install|config-hadoop|config-snappy|stop|start|restart]"
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
elif [ $operation = "config-hadoop" ]; then
  config_hadoop
elif [ $operation = "config-snappy" ]; then
  install_snappy
elif [ $operation = "config-thrift" ]; then
  install_thrift
elif [ $operation = "stop" -o $operation = "start" -o $operation = "stop" -o $operation = "restart" ]; then
  services $master_or_slave $operation
else
  echo "Unknown operation $operation "
  exit -1
fi





