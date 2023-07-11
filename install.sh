#!/bin/bash
if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi
echo //==============================================================
echo "          Nessus 10.4.1 DOWNLOAD, INSTALL, and CRACK"
echo //==============================================================
echo " o Installing Prerequisites.."
apt update &>/dev/null
apt -y install curl dpkg expect &>/dev/null
echo " o Stopping old nessusd"
/bin/systemctl stop nessusd.service &>/dev/null
echo " o Downloading Nessus.."
curl -A Mozilla --request GET \
  --url 'https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-10.4.2-ubuntu1404_amd64.deb' \
  --output 'Nessus-10.4.2-ubuntu1404_amd64.deb' &>/dev/null
echo " o Installing Nessus.."
sudo dpkg -i Nessus-10.4.2-ubuntu1404_amd64.deb &>/dev/null
echo " o Starting service once FIRST TIME INITIALIZATION (we have to do this)"
/bin/systemctl start nessusd.service &>/dev/null
echo " o Let's allow Nessus time to initalize - we'll give it like 20 seconds..."
sleep 20
echo " o Stopping the nessus service.."
/bin/systemctl stop nessusd.service &>/dev/null
echo " o Changing nessus settings to Zen preferences (freedom fighter mode)"
echo "   Listen port: 11127"
/opt/nessus/sbin/nessuscli fix --set xmlrpc_listen_port=11127 &>/dev/null
echo "   Theme:       dark"
/opt/nessus/sbin/nessuscli fix --set ui_theme=dark &>/dev/null
echo "   Safe checks: off"
/opt/nessus/sbin/nessuscli fix --set safe_checks=false &>/dev/null
echo "   Logs:        performance"
/opt/nessus/sbin/nessuscli fix --set backend_log_level=performance &>/dev/null
echo "   Updates:     off"
/opt/nessus/sbin/nessuscli fix --set auto_update=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set auto_update_ui=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set disable_core_updates=true &>/dev/null
echo "   Telemetry:   off"
/opt/nessus/sbin/nessuscli fix --set report_crashes=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set send_telemetry=false &>/dev/null
echo " o Adding a user you can change this later (u:admin,p:admin)"
cat > expect.tmp<<'EOF'
spawn /opt/nessus/sbin/nessuscli adduser admin
expect "Login password:"
send "admin\r"
expect "Login password (again):"
send "admin\r"
expect "*(can upload plugins, etc.)? (y/n)*"
send "y\r"
expect "*(the user can have an empty rules set)"
send "\r"
expect "Is that ok*"
send "y\r"
expect eof
EOF
expect -f expect.tmp &>/dev/null
rm -rf expect.tmp &>/dev/null
echo " o Downloading new plugins."
curl -A Mozilla -o all-2.0.tar.gz \
  --url 'https://plugins.nessus.org/v2/nessus.php?f=all-2.0.tar.gz&u=4e2abfd83a40e2012ebf6537ade2f207&p=29a34e24fc12d3f5fdfbb1ae948972c6' &>/dev/null
echo " o Installing plugins."
/opt/nessus/sbin/nessuscli update all-2.0.tar.gz &>/dev/null
echo " o Fetching version number."
vernum=$(curl https://plugins.nessus.org/v2/plugins.php 2> /dev/null)
echo " o Building plugin feed."
cat > /opt/nessus/var/nessus/plugin_feed_info.inc <<EOF
PLUGIN_SET = "${vernum}";
PLUGIN_FEED = "ProfessionalFeed (Direct)";
PLUGIN_FEED_TRANSPORT = "Tenable Network Security Lightning";
EOF
echo " o Protecting files for persistent crack."
chattr -i /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
cp /opt/nessus/var/nessus/plugin_feed_info.inc /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
echo " o Set everything immutable."
chattr +i /opt/nessus/var/nessus/plugin_feed_info.inc &>/dev/null
chattr +i -R /opt/nessus/lib/nessus/plugins &>/dev/null
echo " o Unset key files."
chattr -i /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
chattr -i /opt/nessus/lib/nessus/plugins  &>/dev/null
echo " o Starting Nessus service."
/bin/systemctl start nessusd.service &>/dev/null
echo " o Sleep for 20 seconds to start server"
sleep 20
echo " o Monitoring Nessus progress. Following line updates every 10 seconds until 100%"
zen=0
while [ $zen -ne 100 ]
do
 statline=`curl -sL -k https://localhost:11127/server/status|awk -F"," -v k="engine_status" '{ gsub(/{|}/,""); for(i=1;i<=NF;i++) { if ( $i ~ k ){printf $i} } }'`
 if [[ $statline != *"engine_status"* ]]; then echo -ne "\n Problem: Nessus server unreachable? Trying again..\n"; fi
 echo -ne "\r $statline"
 if [[ $statline == *"100"* ]]; then zen=100; else sleep 10; fi
done
echo -ne '\n  o Done!\n'
echo
echo "        Access your Nessus:"
echo
echo "        https://localhost:11127/"
echo "        username: admin"
echo "        password: admin"
echo
