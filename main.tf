terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}


provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "first-rg" {
  name     = "First-Resource-Grp"
  location = "West Europe"
  tags = {
    enviroment = "rafik"
  }
}

resource "azurerm_virtual_network" "first-vn" {
  name                = "First-Virtual-Network"
  resource_group_name = azurerm_resource_group.first-rg.name
  location            = azurerm_resource_group.first-rg.location
  address_space       = ["10.123.0.0/16"]

}


resource "azurerm_subnet" "first-sub" {
  name                 = "First-Subnet"
  resource_group_name  = azurerm_resource_group.first-rg.name
  virtual_network_name = azurerm_virtual_network.first-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "first-sec-grp" {
  name                = "Network-Security-Grp"
  resource_group_name = azurerm_resource_group.first-rg.name
  location            = azurerm_resource_group.first-rg.location
}

resource "azurerm_network_security_rule" "first-net-rule" {
  name                        = "Security-Rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.first-rg.name
  network_security_group_name = azurerm_network_security_group.first-sec-grp.name

}

resource "azurerm_subnet_network_security_group_association" "subnet-grp-association" {
  subnet_id                 = azurerm_subnet.first-sub.id
  network_security_group_id = azurerm_network_security_group.first-sec-grp.id
}

resource "azurerm_public_ip" "first-ip" {
  name                = "Public-IP"
  resource_group_name = azurerm_resource_group.first-rg.name
  location            = azurerm_resource_group.first-rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "first-nic" {
  name                = "First-Network-Interface"
  location            = azurerm_resource_group.first-rg.location
  resource_group_name = azurerm_resource_group.first-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.first-sub.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.first-ip.id
  }
}

resource "azurerm_linux_virtual_machine" "first-vm" {
  name                  = "Ubuntu-Vm-18.04"
  resource_group_name   = azurerm_resource_group.first-rg.name
  location              = azurerm_resource_group.first-rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.first-nic.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/azureKeySSH.pub")
  }


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/azureKeySSH"

    })
    interpreter = ["Powershell", "-command"]
  }
}

data "azurerm_public_ip" "first-data" {
  name                = azurerm_public_ip.first-ip.name 
  resource_group_name = azurerm_resource_group.first-rg.name 
}

output "Public-IP-Adress" {
  value = "${azurerm_linux_virtual_machine.first-vm.name}: ${data.azurerm_public_ip.first-data.ip_address}"


}













