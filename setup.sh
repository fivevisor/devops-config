set -e

function require_input() {
    local prompt="$1"
    local var_name="$2"
    local input_value=""

    while [[ -z "$input_value" ]]; do
        echo -n "$prompt: "
        read input_value
        if [[ -z "$input_value" ]]; then
            echo "❌ Error: $var_name cannot be empty!"
        fi
    done

    echo "$input_value"
}

# General Update
sudo apt update && sudo apt upgrade -y

# Docker Setup
sudo apt install -y docker.io
sudo systemctl enable --now docker

# Docker Compose Setup
sudo apt install -y docker-compose

# Generating SSH Key
EMAIL_ADDRESS=$(require_input "Enter your e-mail address" "Email Address")
ssh-keygen -t ed25519 -C $EMAIL_ADDRESS -f ~/.ssh/id_ed25519 -N ""

# Adding SSH Key to GitHub
GITHUB_USER=$(require_input "Enter your GitHub username" "GitHub Username")
echo -n "Enter your GitHub personal access token: "
read -s GITHUB_TOKEN
echo ""

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ Error: GitHub Token cannot be empty!"
    exit 1
fi

SSH_KEY=$(cat ~/.ssh/id_ed25519.pub | tr -d '\n')
curl -X POST https://api.github.com/user/keys \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"title": "Ubuntu Server Key", "key": "'"$SSH_KEY"'"}'

# Trigger GitHub Workflows
GITHUB_ORG=$(require_input "Enter your GitHub organisation name" "GitHub Organisation")
echo "Enter repository names separated by a space:"
read -a REPOS

if [ ${#REPOS[@]} -eq 0 ]; then
    echo "Error: No repositories entered. Exiting..."
    exit 1
fi

for REPO in "${REPOS[@]}"; do
    echo "Triggering workflow for $REPO..."
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "https://api.github.com/repos/$GITHUB_ORG/$REPO/actions/workflows/main.yml/dispatches" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d '{"ref":"main"}')

    if [ "$RESPONSE" -eq 204 ]; then
        echo "✅ Successfully triggered workflow for $REPO"
    else
        echo "❌ Failed to trigger workflow for $REPO (HTTP $RESPONSE)"
    fi
done

echo "Setup completed."

# Use the following command to easily run.
# bash <(curl -sL https://raw.githubusercontent.com/fivevisor/devops-config/main/setup.sh)
