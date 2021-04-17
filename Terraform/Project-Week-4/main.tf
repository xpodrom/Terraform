# Provider
provider "azurerm" {
  version         = "2.56.0"
  subscription_id = var.subscriptionID
  features { }
}

# RG
resource "azurerm_resource_group" "TerraformRG" {
 name     = "TerraformRG"
 location = var.location
}

# VNet
resource "azurerm_virtual_network" "BaseVnet" {
 name                = "BaseVnet"
 address_space       = ["10.0.0.0/16"]
 location            = azurerm_resource_group.TerraformRG.location
 resource_group_name = azurerm_resource_group.TerraformRG.name
}

# Application Subnet
resource "azurerm_subnet" "PublicSubnet" {
 name                 = "PublicSubnet"
 resource_group_name  = azurerm_resource_group.TerraformRG.name
 virtual_network_name = azurerm_virtual_network.BaseVnet.name
 address_prefix       = "10.0.2.0/24"
}

# DataBase Subnet
resource "azurerm_subnet" "PrivateSubnet" {
 name                 = "PrivateSubnet"
 resource_group_name  = azurerm_resource_group.TerraformRG.name
 virtual_network_name = azurerm_virtual_network.BaseVnet.name
 address_prefix       = "10.0.1.0/24"
}

# Application Security Group
resource "azurerm_network_security_group" "AppSecurityGroup" { 
  name                = "AppSecurityGroup"
  location            = var.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
  # Application Rule
  security_rule { 
    name                       = "HTTPS"  
    priority                   = 1000  
    direction                  = "Inbound"  
    access                     = "Allow"  
    protocol                   = "Tcp"  
    source_port_range          = "*"  
    destination_port_range     = "443"  
    source_address_prefix      = "*"  
    destination_address_prefix = "*"  
  }
  # Application Rule
    security_rule { 
    name                       = "HTTP"  
    priority                   = 1001  
    direction                  = "Inbound"  
    access                     = "Allow"  
    protocol                   = "Tcp"  
    source_port_range          = "*"  
    destination_port_range     = "80"  
    source_address_prefix      = "*"  
    destination_address_prefix = "*"  
  }
  # Application Rule   
  security_rule {
    name                       = "RDP"  
    priority                   = 110  
    direction                  = "Inbound"  
    access                     = "Allow"  
    protocol                   = "Tcp"  
    source_port_range          = "*"  
    destination_port_range     = "3389"  
    source_address_prefix      = "*"  
    destination_address_prefix = "*"  
  } 
}

# DataBase Security Group
resource "azurerm_network_security_group" "DbSecurityGroup" {
  name                = "DbSecurityGroup"
  location            = var.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
  # DataBase Rule
  security_rule { 
    name                       = "HTTP"  
    priority                   = 1050  
    direction                  = "Inbound"  
    access                     = "Allow"  
    protocol                   = "Tcp"  
    source_port_range          = "*"  
    destination_port_range     = "5432"  
    source_address_prefix      = "*"  
    destination_address_prefix = "*"  
  }
  # DataBase Rule
  security_rule {
    name                       = "SSH"
    priority                   = 109
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

# Application Load Balancer Public IP
resource "azurerm_public_ip" "PublicIPForAppLB" {
 name                         = "PublicIPForLB"
 location                     = azurerm_resource_group.TerraformRG.location
 resource_group_name          = azurerm_resource_group.TerraformRG.name
 allocation_method            = "Static"
}

# Application VM Public IP
resource "azurerm_public_ip" "AppVmPublicIP" {
 count                        = 3
 name                         = "AppVmPublicIP_${count.index}"
 location                     = azurerm_resource_group.TerraformRG.location
 resource_group_name          = azurerm_resource_group.TerraformRG.name
 allocation_method            = "Static"
}

# Application Load Balancer
resource "azurerm_lb" "AppLoadBalancer" {
 name                = "AppLoadBalancer"
 location            = azurerm_resource_group.TerraformRG.location
 resource_group_name = azurerm_resource_group.TerraformRG.name

 frontend_ip_configuration {
   name                 = "PublicIPAddress"
   public_ip_address_id = azurerm_public_ip.PublicIPForAppLB.id
 }
}

# Application Load Balancer Rule
resource "azurerm_lb_rule" "AppLbRule" {
  resource_group_name            = azurerm_resource_group.TerraformRG.name
  loadbalancer_id                = azurerm_lb.AppLoadBalancer.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "PublicIPAddress"
}

# DataBase Load Balancer Public IP
resource "azurerm_public_ip" "PublicIpForDBLB" {
  name                = "PublicIpForDBLB"
  location            = var.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
  allocation_method   = "Static"
}

# DataBase Load Balancer
resource "azurerm_lb" "DBLoadBalancer" {
  name                = "DBLoadBalancer"
  location            = var.location
  resource_group_name = azurerm_resource_group.TerraformRG.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.PublicIpForDBLB.id
  }
}

# DataBase Load Balancer Rule
resource "azurerm_lb_rule" "DbLbRule" {
  resource_group_name            = azurerm_resource_group.TerraformRG.name
  loadbalancer_id                = azurerm_lb.DBLoadBalancer.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 5437
  backend_port                   = 5437
  frontend_ip_configuration_name = "PublicIPAddress"
}

# DataBase Backend Address Pool
resource "azurerm_lb_backend_address_pool" "BackEndAddressPoolDb" {
 resource_group_name = azurerm_resource_group.TerraformRG.name
 loadbalancer_id     = azurerm_lb.DBLoadBalancer.id
 name                = "BackEndAddressPoolDb"
}

# Application Backend Address Pool
resource "azurerm_lb_backend_address_pool" "BackEndAddressPoolApp" {
 resource_group_name = azurerm_resource_group.TerraformRG.name
 loadbalancer_id     = azurerm_lb.AppLoadBalancer.id
 name                = "BackEndAddressPoolApp"
}

# DataBase Load Balancer NAT Rule
resource "azurerm_lb_nat_rule" "DbNatRuleLb" {
  count                          = 3
  resource_group_name            = azurerm_resource_group.TerraformRG.name
  loadbalancer_id                = azurerm_lb.DBLoadBalancer.id
  name                           = "PostgressAccess${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = 5000+count.index
  backend_port                   = 5432
  frontend_ip_configuration_name = "PublicIPAddress"
}

# DataBase Network Interface NAT Rule Association
resource "azurerm_network_interface_nat_rule_association" "DbNatRuleLb" {
  count                 = 3
  network_interface_id  = element(azurerm_network_interface.DbNetworkInterface.*.id,count.index+4)
  ip_configuration_name = "DbIPConfiguration"
  nat_rule_id           = element(azurerm_lb_nat_rule.DbNatRuleLb.*.id,count.index)
  
}

# Application Load Balancer NAT Rule
resource "azurerm_lb_nat_rule" "AppNatRuleLb" {
  count                          = 3
  resource_group_name            = azurerm_resource_group.TerraformRG.name
  loadbalancer_id                = azurerm_lb.AppLoadBalancer.id
  name                           = "ApplicationAccess${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = 5000+count.index
  backend_port                   = 8080
  frontend_ip_configuration_name = "PublicIPAddress"
}

# Application Network Interface NAT Rule Association
resource "azurerm_network_interface_nat_rule_association" "AppNatRuleLb" {
  count                 = 3
  network_interface_id  = element(azurerm_network_interface.AppNetworkInterface.*.id,count.index+4)
  ip_configuration_name = "AppIPConfiguration"
  nat_rule_id           = element(azurerm_lb_nat_rule.AppNatRuleLb.*.id,count.index)
}

# Application Network Interface
resource "azurerm_network_interface" "AppNetworkInterface" {
 count               = 3
 name                = "AppNetworkInterface${count.index}"
 location            = azurerm_resource_group.TerraformRG.location
 resource_group_name = azurerm_resource_group.TerraformRG.name
 ip_configuration {
   name                          = "AppIPConfiguration"
   subnet_id                     = azurerm_subnet.PublicSubnet.id
   private_ip_address_allocation = "Static"
   private_ip_address            = "10.0.2.${count.index+4}"
   public_ip_address_id          = element(azurerm_public_ip.AppVmPublicIP.*.id,count.index)

 }
}

# DataBase Network Interface
resource "azurerm_network_interface" "DbNetworkInterface" {
 count               = 3
 name                = "DbNetworkInterface${count.index}"
 location            = azurerm_resource_group.TerraformRG.location
 resource_group_name = azurerm_resource_group.TerraformRG.name
 ip_configuration {
   name                          = "DbIPConfiguration"
   subnet_id                     = azurerm_subnet.PrivateSubnet.id
   private_ip_address_allocation = "Static"
   private_ip_address            = "10.0.1.${count.index+4}"

 }
}

# Application Managed Disk
resource "azurerm_managed_disk" "AppDisk" {
 count                = 3
 name                 = "AppDisk_${count.index}"
 location             = azurerm_resource_group.TerraformRG.location
 resource_group_name  = azurerm_resource_group.TerraformRG.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

# DataBase Managed Disk
resource "azurerm_managed_disk" "DBDisk" {
 count                = 3
 name                 = "DBDisk${count.index}"
 location             = azurerm_resource_group.TerraformRG.location
 resource_group_name  = azurerm_resource_group.TerraformRG.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

# Application Availability Set
resource "azurerm_availability_set" "AppAvailabilitySet" {
 name                         = "AppAvailabilitySet"
 location                     = azurerm_resource_group.TerraformRG.location
 resource_group_name          = azurerm_resource_group.TerraformRG.name
 managed                      = true
}

# DataBase Availability Set
resource "azurerm_availability_set" "DbAvailabilitySet" {
 name                         = "DbAvailabilitySet"
 location                     = azurerm_resource_group.TerraformRG.location
 resource_group_name          = azurerm_resource_group.TerraformRG.name
 managed                      = true
}

# DataBase VM
resource "azurerm_virtual_machine" "DBVM" {
 count                 = 3
 name                  = "DBVM_${count.index}"
 location              = azurerm_resource_group.TerraformRG.location
 availability_set_id   = azurerm_availability_set.DbAvailabilitySet.id
 resource_group_name   = azurerm_resource_group.TerraformRG.name
 network_interface_ids = [element(azurerm_network_interface.DbNetworkInterface.*.id, count.index)]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "DBOsDisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 storage_data_disk {
   name            = element(azurerm_managed_disk.DBDisk.*.name, count.index)
   managed_disk_id = element(azurerm_managed_disk.DBDisk.*.id, count.index)
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = element(azurerm_managed_disk.DBDisk.*.disk_size_gb, count.index)
 }

 os_profile {
   computer_name  = "DbVm${count.index}"
   admin_username = var.login
   admin_password = var.password
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags = {
   environment = "development"
 }
}

# Application VM
resource "azurerm_virtual_machine" "AppVM" {
 count                 = 3
 name                  = "AppVM_${count.index}"
 location              = azurerm_resource_group.TerraformRG.location
 availability_set_id   = azurerm_availability_set.AppAvailabilitySet.id
 resource_group_name   = azurerm_resource_group.TerraformRG.name
 network_interface_ids = [element(azurerm_network_interface.AppNetworkInterface.*.id, count.index)]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2012-R2-Datacenter"
    version   = "latest"
 }

 storage_os_disk {
   name              = "AppOsDisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 storage_data_disk {
   name            = element(azurerm_managed_disk.AppDisk.*.name, count.index)
   managed_disk_id = element(azurerm_managed_disk.AppDisk.*.id, count.index)
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = element(azurerm_managed_disk.AppDisk.*.disk_size_gb, count.index)
 }

 os_profile {
   computer_name  = "AppVm${count.index}"
   admin_username = var.login
   admin_password = var.password
 }

 os_profile_windows_config{
   
 }

 tags = {
   environment = "development"
 }
}

# Application Network Interface Backend Address Pool Association
resource "azurerm_network_interface_backend_address_pool_association" "BackEndAddressPoolApp" {
  count                   = 3
  network_interface_id    = element(azurerm_network_interface.AppNetworkInterface.*.id, count.index+4)
  ip_configuration_name   = "AppIPConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.BackEndAddressPoolApp.id

    depends_on = [
    azurerm_lb_backend_address_pool.BackEndAddressPoolApp,
  ]
}

# DataBase Network Interface Backend Address Pool Association
resource "azurerm_network_interface_backend_address_pool_association" "BackEndAddressPoolDb" {
  count                   = 3
  network_interface_id    = element(azurerm_network_interface.DbNetworkInterface.*.id, count.index+4)
  ip_configuration_name   = "DbIPConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.BackEndAddressPoolDb.id

    depends_on = [
    azurerm_lb_backend_address_pool.BackEndAddressPoolDb,
  ]
}