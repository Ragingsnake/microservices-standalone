terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # This tells Terraform to store its memory (state) in Azure, 
  # so GitHub Actions can safely keep track of what it builds.
  backend "azurerm" {} 
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# 1. Create a Resource Group to hold everything
resource "azurerm_resource_group" "rg" {
  name     = "microservices-demo-rg"
  location = "southeastasia" # Feel free to change this to a region closer to you
}

# 2. Create the AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "microservices-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "microservicesaks"

  # The actual virtual machines that will run your containers
  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2s_v3" # Standard size, capable of running the demo
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
    Project     = "MicroservicesDemo"
  }
}
