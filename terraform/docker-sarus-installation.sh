#/bin/bash

apt-get update
apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo 'Installing Sarus...'
echo "You need to have configured a .env file with required parameters. If you haven't done so, use the env.template file"

# checking docker version
currentver="$(docker --version)"
requiredver="Docker version 19.03.6"
 if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
        echo "Greater than or equal to ${requiredver}"
 else
        echo "Your Docker version is less than ${requiredver}"
        exit 1
 fi

echo 'Authenticating to the container registry...'
docker login registry.gitlab.com/sarus-tech -u $SARUS_RELEASES_USERNAME $SARUS_RELEASES_PASSWORD

echo 'Pulling docker images...'
docker-compose pull

echo 'Launching Sarus'
docker-compose up -d
