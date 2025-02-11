# provider "azurerm" {
#   subscription_id = "REPLACE-WITH-YOUR-SUBSCRIPTION-ID"
#   client_id       = "REPLACE-WITH-YOUR-CLIENT-ID"
#   client_secret   = "REPLACE-WITH-YOUR-CLIENT-SECRET"
#   tenant_id       = "REPLACE-WITH-YOUR-TENANT-ID"
# }

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group}"
  location = "${var.location}"
}

resource "azurerm_storage_account" "stor" {
  name                     = "${var.dns_name}stor"
  location                 = "${var.location}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_replication_type}"
}

resource "azurerm_availability_set" "avset" {
  name                         = "${var.dns_name}avset"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_public_ip" "lbpip" {
  name                         = "terravm-pip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label            = "${var.lb_ip_dns_name}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "UKSOU-VNET"
  location            = "uksouth"
  address_space       = ["172.16.0.0/16"]
  resource_group_name = "rgNRSNetworking"
}

resource "azurerm_subnet" "subnet0" {
  name                 = "GatewaySubnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "rgNRSNetworking"
  address_prefix       = "172.16.0.0/24"
}

resource "azurerm_subnet" "subnet1" {
  name                 = "AAA"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "rgNRSNetworking"
  address_prefix       = "172.16.1.0/24"
}

resource "azurerm_subnet" "subnet2" {
  name                 = "DATA"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "rgNRSNetworking"
  address_prefix       = "172.16.2.0/24"
}

resource "azurerm_subnet" "subnet3" {
  name                 = "APP"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "rgNRSNetworking"
  address_prefix       = "172.16.3.0/24"
}

resource "azurerm_subnet" "subnet" {
  name                 = "WEB"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "rgNRSNetworking"
  address_prefix       = "172.16.4.0/24"
}


resource "azurerm_subnet" "subnet5" {
  name                 = "DMZ"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "rgNRSNetworking"
  address_prefix       = "172.16.5.0/24"
}

resource "azurerm_lb" "lb" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  name                = "terravmweb-lb"
  location            = "${var.location}"

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.lbpip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
  name                = "BackendPool1"
}

resource "azurerm_lb_nat_rule" "tcp" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  name                           = "RDP-VM-${count.index}"
  protocol                       = "tcp"
  frontend_port                  = "5000${count.index + 1}"
  backend_port                   = 3389
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  count                          = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  name                           = "LBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backend_pool.id}"
  idle_timeout_in_minutes        = 5
  probe_id                       = "${azurerm_lb_probe.lb_probe.id}"
  depends_on                     = ["azurerm_lb_probe.lb_probe"]
}

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_network_interface" "nic" {
  name                = "nic${count.index}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  count               = 2

  ip_configuration {
    name                                    = "ipconfig${count.index}"
    subnet_id                               = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation           = "Dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.backend_pool.id}"]
    load_balancer_inbound_nat_rules_ids     = ["${element(azurerm_lb_nat_rule.tcp.*.id, count.index)}"]
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "vm${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                 = 2

  storage_image_reference {
    publisher = "${var.image_publisher}"
    offer     = "${var.image_offer}"
    sku       = "${var.image_sku}"
    version   = "${var.image_version}"
  }

  storage_os_disk {
    name          = "osdisk${count.index}"
    create_option = "FromImage"
  }

  os_profile_windows_config {}

  os_profile {
    computer_name  = "${var.hostname}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }
}