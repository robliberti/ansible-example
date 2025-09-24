.PHONY: setup lint generate validate clean all help

PYTHON ?= python3
ANSIBLE_VERSION ?= 5.9.0
CUSTOMER ?= all
PRODUCTS ?= all
VERBOSE ?= 

help:
	@echo "Tomcat Configuration Automation"
	@echo "Usage:"
	@echo "  make setup             Install required dependencies"
	@echo "  make lint              Run linting on Ansible playbooks"
	@echo "  make generate          Generate configuration files"
	@echo "                         CUSTOMER=<id> PRODUCTS=<product list>"
	@echo "  make validate          Validate generated configuration files"
	@echo "                         CUSTOMER=<id> PRODUCTS=<product list> VERBOSE=1"
	@echo "  make clean             Remove generated files"
	@echo "  make all               Generate and validate all configurations"
	@echo
	@echo "Examples:"
	@echo "  make generate CUSTOMER=fdr PRODUCTS=dakota,selectprime"
	@echo "  make validate CUSTOMER=gsf PRODUCTS=api VERBOSE=1"
	@echo "  make all"

setup:
	@echo "Installing dependencies..."
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install ansible==$(ANSIBLE_VERSION) jinja2 PyYAML lxml
	@echo "Installing system dependencies..."
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y libxml2-utils; \
	elif command -v brew >/dev/null 2>&1; then \
		brew install libxml2; \
	else \
		echo "Warning: Could not install libxml2-utils automatically."; \
		echo "Please install manually for xmllint support."; \
	fi
	@echo "Setup complete."

lint:
	@echo "Linting Ansible playbooks..."
	ansible-lint ansible/playbooks/*.yml

generate:
	@echo "Generating configuration files for customer: $(CUSTOMER), products: $(PRODUCTS)"
	./scripts/generate.sh -c $(CUSTOMER) -p $(PRODUCTS)

validate:
	@echo "Validating configuration files for customer: $(CUSTOMER), products: $(PRODUCTS)"
	./scripts/validate.sh -c $(CUSTOMER) -p $(PRODUCTS) $(if $(VERBOSE),-v,)

clean:
	@echo "Cleaning generated files..."
	rm -rf output/

all: generate validate
	@echo "All configurations generated and validated successfully."
