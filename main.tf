terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.31.1"
    }
  }
}

provider "azurerm" {
  features{}
}

resource "azurerm_resource_group" "int3" {
    location = "eastus"
    name     = "int3"
    tags     = {
        "CreationDateTime" = "2021-09-02T09:27:18.1361281Z"
        "Environment"      = "Dev"
        "created_by"       = "none"
    }

    timeouts {}
}

resource "azurerm_virtual_network" "Pub" {
  name                = "Pub"
  resource_group_name =  azurerm_resource_group.int3.name
  location = azurerm_resource_group.int3.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "Priv" {
  name                = "Priv"
  resource_group_name =  azurerm_resource_group.int3.name
  location = azurerm_resource_group.int3.location
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_availability_set" "DemoAset" {
  name                = "Aset"
  location            = azurerm_resource_group.int3.location
  resource_group_name = azurerm_resource_group.int3.name
}

resource "azurerm_public_ip" "testip" {
  name                = "testip"
  resource_group_name = azurerm_resource_group.int3.name
  location            = azurerm_resource_group.int3.location
  allocation_method   = "Static"

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_subnet" "external" {
  name                 = "external"
  resource_group_name  = azurerm_resource_group.int3.name
  virtual_network_name = azurerm_virtual_network.Pub.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.int3.name
  virtual_network_name = azurerm_virtual_network.Priv.name
  address_prefixes     = ["10.1.4.0/24"]
}

resource "azurerm_network_interface" "internalnic" {
  name                = "internalnic"
  location            = azurerm_resource_group.int3.location
  resource_group_name = azurerm_resource_group.int3.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "externalnic" {
  name                = "externalnic"
  location            = azurerm_resource_group.int3.location
  resource_group_name = azurerm_resource_group.int3.name
  ip_configuration {
    name                          = "external"
    subnet_id                     = azurerm_subnet.external.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.testip.id
  }
}

resource "tls_private_key" "sshkey" {
    algorithm = "RSA"
    rsa_bits = 4096
}

output "tls_private_key" { 
    value = tls_private_key.sshkey.private_key_pem 
    sensitive = true
}

resource "azurerm_windows_virtual_machine" "Public" {
  name                = "PublicVM"
  resource_group_name = azurerm_resource_group.int3.name
  location            = azurerm_resource_group.int3.location
  size                = "Standard_F2"
  admin_username      = "T0mmer"
  admin_password      = "L3tsgooo0"
  availability_set_id = azurerm_availability_set.DemoAset.id
  network_interface_ids = [
    azurerm_network_interface.externalnic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "Private" {
  name                = "PrivVM"
  resource_group_name = azurerm_resource_group.int3.name
  location            = azurerm_resource_group.int3.location
  size                = "Standard_F2"
  admin_username      = "tommer"
  computer_name  = "PrivVM"
  admin_password      = "Bruh10!"
  network_interface_ids = [
    azurerm_network_interface.internalnic.id,
  ]

  admin_ssh_key {
    username   = "tommer"
    public_key = tls_private_key.sshkey.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_virtual_network_peering" "Peering" {
  name                      = "PubToPriv"
  resource_group_name       = azurerm_resource_group.int3.name
  virtual_network_name      = azurerm_virtual_network.Pub.name
  remote_virtual_network_id = azurerm_virtual_network.Priv.id
}

resource "azurerm_virtual_network_peering" "Peering2" {
  name                      = "PrivToPub"
  resource_group_name       = azurerm_resource_group.int3.name
  virtual_network_name      = azurerm_virtual_network.Priv.name
  remote_virtual_network_id = azurerm_virtual_network.Pub.id
}
