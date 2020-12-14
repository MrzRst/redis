#!/bin/bash
#Setup Redis For High Availability with Sentinel in CentOS
#Version: Redis-6.0.9-1

CONF_FILE='/etc/redis.conf'
LOG_FILE="/var/log/reportSetupRedis.log"

read -p "Please Enter IP Master Server:" IP
read -p "Number of Slaves Server: " NUM_SLAVE
Config_General()
{
echo -e "\*****Step1: Config_General\*****" >> $LOG_FILE
cp $CONF_FILE $CONF_FILE.org 1>>$LOG_FILE 2>>$LOG_FILE
rm -rf $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
cp $CONF_FILE.org $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/bind 127.0.0.1/bind 0.0.0.0/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/protected-mode yes/protected-mode no/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE 
sed -i 's/# requirepass foobared/requirepass Isc_Redis/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/supervised no/supervised systemd/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/appendonly no/appendonly yes/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE

sed -i 's/# maxmemory <bytes>/maxmemory 1gb/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/# maxmemory-policy noeviction/maxmemory-policy volatile-lru/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/# maxmemory-samples 5/maxmemory-samples 3/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/# maxclients 10000/maxclients 100000/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/timeout 0/timeout 300/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/tcp-keepalive 300/tcp-keepalive 0/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
sed -i 's/slowlog-log-slower-than 10000/slowlog-log-slower-than 50000/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE

}

Run_Redis()
{
echo -e " \****Step2.Run Service:.\****" >> $LOG_FILE
systemctl enable --now redis 1>>$LOG_FILE 2>>$LOG_FILE

ss -ltpn | grep redis-serve 1>>$LOG_FILE 2>>$LOG_FILE


firewall-cmd --add-port=6379/tcp --permanent 1>>$LOG_FILE 2>>$LOG_FILE

firewall-cmd --reload 1>>$LOG_FILE 2>>$LOG_FILE
}

sentinel()
{
echo -e "\*****Step3: Config_Sentinel\*****" >> $LOG_FILE
mv /etc/redis-sentinel.conf /etc/redis-sentinel.conf.org
cat <<EO >/etc/redis-sentinel.conf
port 26379
sentinel monitor isc-redis $IP 6379 2
sentinel down-after-milliseconds isc-redis 4000
sentinel failover-timeout isc-redis 6000
sentinel parallel-syncs isc-redis $NUM_SLAVE
bind 0.0.0.0
sentinel auth-pass isc-redis Isc_Redis
EO

echo "Done."  >> $LOG_FILE

 chown redis /etc/redi*
}


Run_Sentinel()
{
sentinel
echo -e "\*****Step4: Run_Sentinel\*****" >> $LOG_FILE
firewall-cmd --zone=public --permanent --add-port=26379/tcp  1>>$LOG_FILE 2>>$LOG_FILE
firewall-cmd --reload  1>>$LOG_FILE 2>>$LOG_FILE
systemctl enable --now redis-sentinel  1>>$LOG_FILE 2>>$LOG_FILE
ss -ltpn | grep redis-sentinel 1>>$LOG_FILE 2>>$LOG_FILE

redis-cli -p 26379 sentinel master isc-redis 1>>$LOG_FILE 2>>$LOG_FILE
redis-cli -p 26379 sentinel slaves isc-redis 1>>$LOG_FILE 2>>$LOG_FILE
redis-cli -p 26379 sentinel get-master-addr-by-name isc-redis 1>>$LOG_FILE 2>>$LOG_FILE

}



Master()
{
echo "master selected." > $LOG_FILE
Config_General
grep -v '^#' /etc/redis.conf | grep -v "^$" >> $LOG_FILE
Run_Redis 
Run_Sentinel
ss -ltpn | grep redis
echo "Setup For Master Server done."
}


Salve()
{
echo -e " \****slave selected.\****" > $LOG_FILE
Config_General
sed -i 's/# masterauth <master-password>/masterauth Isc_Redis/g' $CONF_FILE 1>>$LOG_FILE 2>>$LOG_FILE
echo "replicaof $IP 6379" >> $CONF_FILE && echo "replicaof $IP 6379" 1>>$LOG_FILE 2>>$LOG_FILE
grep -v '^#' /etc/redis.conf | grep -v "^$" >> $LOG_FILE
Run_Redis 
Run_Sentinel
ss -ltpn | grep redis
echo "Setup For Slave Server done."
}



echo "Which Server do you want to setup:"
select server in Master Slave
do
 case $server in
    "Master")
        echo "master selected."
        Master
        break
    ;;
    "Slave")
         echo "slave selected."
 	 Salve
         break
    ;;
    *)
    echo "Invalid entry."
    break
    ;;
 esac
done

