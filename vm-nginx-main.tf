# Bootstrapping Template File
data "template_file" "nginx-vm-cloud-init" {
  template = file("install-nginx.sh")
}
# Create Network Security Group
resource "azurerm_network_security_group" "nginx-vm-nsg" {
  depends_on=[azurerm_resource_group.network-rg]
  name = "nginx-nsg"
  location = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  security_rule {
    name = "Allow-SSH"
    description = "Allow SSH"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name = "Allow-HTTP"
    description = "Allow HTTP"
    priority = 110
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "Internet"
    destination_address_prefix = "*"
  }
}
# Associate the web NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "nginx-vm-nsg-association" {
  depends_on=[azurerm_resource_group.network-rg]
  subnet_id = azurerm_subnet.vm-subnet.id
  network_security_group_id = azurerm_network_security_group.nginx-vm-nsg.id
}
# Get a Static Public IP
resource "azurerm_public_ip" "nginx-vm-ip" {
  depends_on=[azurerm_resource_group.network-rg]
  name = "nginx-ip"
  location = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  allocation_method = "Static"
}
# Create Network Card for the VM
resource "azurerm_network_interface" "nginx-nic" {
  depends_on=[azurerm_resource_group.network-rg]
  name = "nginx-nic"
  location = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  
  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.vm-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.nginx-vm-ip.id
  }
}
# Create Nginx VM
resource "azurerm_linux_virtual_machine" "nginx-vm" {
  depends_on=[azurerm_network_interface.nginx-nic]
  name = "nginx-vm"
  location = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  network_interface_ids = [azurerm_network_interface.nginx-nic.id]
  size = var.nginx_vm_size
  source_image_reference {
    publisher = var.ubuntu-publisher
    offer = var.ubuntu-offer
    sku = "18.04-LTS"
    version = "latest"
  }
  os_disk {
    name = "nginx-osdisk"
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  computer_name = "nginx-vm"
  admin_username = var.nginx_admin_username
  admin_password = random_password.nginx-vm-password.result
  disable_password_authentication = false
  custom_data = base64encode(data.template_file.nginx-vm-cloud-init.rendered)
}