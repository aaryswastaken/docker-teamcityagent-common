#!/bin/sh
echo "Updating property file..."

sed -i "s|^serverUrl=.*$|serverUrl=$TEAMCITY_SERVER_URL|" /srv/teamcity-agent/conf/buildAgent.properties
sed -i "s|^ownPort=.*$|ownPort=$AGENT_PORT|" /srv/teamcity-agent/conf/buildAgent.properties
sed -i "s|^name=.*$|name=$AGENT_NAME|" /srv/teamcity-agent/conf/buildAgent.properties

echo "UPDATED:"
cat /srv/teamcity-agent/conf/buildAgent.properties

echo "============================================"

/srv/teamcity-agent/bin/agent.sh run
