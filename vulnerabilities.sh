# For now, just CentOS and Redhat are supported.
# If you use Debian or Ubuntu, replace "yum" with "apt-get".
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm > /dev/null
yum -y install jq curl > /dev/null

# Initial state for the security scan.
success=false

# Create directory structure for pulsar
mkdir /opt/enginsight/
mkdir /opt/enginsight/pulsar

# Download latest version of pulsar
latest=$(curl -sS https://dls.enginsight.com/pulsar/latest)
downloadPath=https://dls.enginsight.com/pulsar/$latest/ngs-pulsar-amd64
curl -sS -o /opt/enginsight/pulsar/ngs-pulsar-amd64 $downloadPath
chmod a+x /opt/enginsight/pulsar/ngs-pulsar-amd64

# Create new host."
response=$(curl -sS -X POST $apiUrl/v1/hosts                 \
    -d '{"host":{"alias":"CI Security Scan","tags":["ci"]}}' \
    -H "Content-Type: application/json"                      \
    -H "x-ngs-access-key-id: $accessKeyId"                   \
    -H "x-ngs-access-key-secret: $accessKeySecret")

# Parse hostId out of json result.
hostId=$(echo $response | jq -r '.host._id')

# Create config file for pulsar.
cat >/opt/enginsight/pulsar/config.json <<EOL
{"host":{"_id":"$hostId"},
 "api": {"url":"$apiUrl",
  "accessKey":{
    "id":"$accessKeyId",
    "secret":"$accessKeySecret"
  }
}}
EOL

# Execute pulsar for max 15 seconds. (collect security information...)
timeout 15s /opt/enginsight/pulsar/ngs-pulsar-amd64 > /dev/null

echo "Scan for vulnerabilities..."

for i in {1..10}; do
    # Give us some time to detect security issues.
    sleep 2

    report=$(curl -sS -X GET $apiUrl/v1/hosts/$hostId/reports/hti/latest \
        -H "x-ngs-access-key-id: $accessKeyId"                           \
        -H "x-ngs-access-key-secret: $accessKeySecret")

    score=$(echo $report | jq -r '.report.hti.score')
     cves=$(echo $report | jq -r '.report.hti.vulnerabilities')
    count=$(echo $report | jq -r '.report.hti.vulnerabilities | length')

    if [ $count ]; then
        if [ "$count" -eq "0" ]; then
            success=true
        fi
        break
    fi
done

# Delete host to save ressources in your account.
curl -sS --output /dev/null -X DELETE $apiUrl/v1/hosts/$hostId \
    -H "x-ngs-access-key-id: $accessKeyId"                     \
    -H "x-ngs-access-key-secret: $accessKeySecret"

# If vulnerabilities were found, exit script with status 1.
if ! $success; then
  echo "Found $count CVE(s) => Worst CVE score is $score"
  echo "========================================================"
  echo $cves | jq '.'
  exit 1
else
  echo "No vulnerabilities found!"
fi
