#!/bin/bash

# Function to print error and exit
function error_exit {
    echo "$1" >&2
    exit 1
}

# Check if the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    error_exit "This script must be run as root. Use sudo or log in as root."
fi

# Get the username from input
read -p "Enter the username to grant Docker permissions: " USERNAME

# Check if the user exists
if ! id -u "$USERNAME" > /dev/null 2>&1; then
    error_exit "User $USERNAME does not exist."
fi

# Update the package database
echo "Updating package database..."
apt-get update -y || error_exit "Failed to update package database."

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release || error_exit "Failed to install required packages."

# Add Docker’s official GPG key
echo "Adding Docker GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error_exit "Failed to add Docker GPG key."

# Set up the Docker repository
echo "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Failed to set up Docker repository."

# Update the package database again
echo "Updating package database with Docker packages..."
apt-get update -y || error_exit "Failed to update package database."

# Install Docker Engine, CLI, and Docker Compose plugin
echo "Installing Docker and Docker Compose..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error_exit "Failed to install Docker."

# Start and enable Docker service
echo "Starting Docker service..."
systemctl start docker || error_exit "Failed to start Docker service."
systemctl enable docker || error_exit "Failed to enable Docker service."

# Add the user to the Docker group
echo "Adding user $USERNAME to the docker group..."
usermod -aG docker "$USERNAME" || error_exit "Failed to add user $USERNAME to the docker group."

# Print success message
echo "Docker and Docker Compose have been successfully installed."
echo "User $USERNAME has been added to the Docker group."
echo "You will need to log out and back in for the changes to take effect."

exit 0
