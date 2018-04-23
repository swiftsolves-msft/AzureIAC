# Configure the Azure Provider
provider "azurerm" { }

# Create/refer a resource group
resource "azurerm_resource_group" "rgNetworking" {
  name     = "rgNRSNetworking"
  location = "Canada Central"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "WUS-VNET" {
  name                = "WUS-VNET"
  address_space       = ["192.170.0.0/16"]
  location            = "${azurerm_resource_group.rgNetworking.location}"
  resource_group_name = "${azurerm_resource_group.rgNetworking.name}"

  subnet {
    name           = "GatewaySubnet"
    address_prefix = "192.170.0.0/24"
  }

  subnet {
    name           = "AAA"
    address_prefix = "192.170.1.0/24"
  }

  subnet {
    name           = "DATA"
    address_prefix = "192.170.2.0/24"
  }
  subnet {
    name           = "APP"
    address_prefix = "192.170.3.0/24"
  }

  subnet {
    name           = "WEB"
    address_prefix = "192.170.4.0/24"
  }
  subnet {
    name           = "DMZ"
    address_prefix = "192.170.5.0/24"
  }

}
