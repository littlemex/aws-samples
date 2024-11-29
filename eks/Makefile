
.PHONY: all install clean

all: install

install:
	@echo "Updating package lists..."
	@sudo apt-get update
	@sudo apt-get install -y gnupg software-properties-common
	@echo "Installing HashiCorp GPG key..."
	@wget -O- https://apt.releases.hashicorp.com/gpg | \
	gpg --dearmor | \
	sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
	@echo "Verifying the GPG key's fingerprint..."
	@gpg --no-default-keyring \
	--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
	--fingerprint
	@echo "Adding the HashiCorp repository..."
	@echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(shell lsb_release -cs) main" | \
	sudo tee /etc/apt/sources.list.d/hashicorp.list
	@echo "Updating package lists from HashiCorp repository..."
	@sudo apt-get update
	@echo "Installing Terraform..."
	@sudo apt-get install -y terraform
	@terraform --version

clean:
	@echo "Removing HashiCorp repository and key..."
	@sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
	@sudo rm -f /etc/apt/sources.list.d/hashicorp.list
