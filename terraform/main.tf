### general stuff & resource group

provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

### network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "internal" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic1"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}


### the VM
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "${var.prefix}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_E2s_v3" # around $110/month
  admin_username                  = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.main.id,
    azurerm_network_interface.internal.id,
  ]

  admin_ssh_key {
    username = "adminuser"
    public_key = file("~/.ssh/sarus-azure-2_key.pub")
  }

  source_image_reference {
    version   = "latest"
    offer                 = "0001-com-ubuntu-server-focal"
    publisher             = "Canonical"
    sku                   = "20_04-lts-gen2"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_virtual_machine_extension" "main" {
  name                 = "hostname"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
  {
  "script": "YXB0LWdldCB1cGRhdGUKYXB0LWdldCBpbnN0YWxsIFwKICAgIGNhLWNlcnRpZmljYXRlcyBcCiAgICBjdXJsIFwKICAgIGdudXBnIFwKICAgIGxzYi1yZWxlYXNlCm1rZGlyIC1wIC9ldGMvYXB0L2tleXJpbmdzCmN1cmwgLWZzU0wgaHR0cHM6Ly9kb3dubG9hZC5kb2NrZXIuY29tL2xpbnV4L3VidW50dS9ncGcgfCBzdWRvIGdwZyAtLWRlYXJtb3IgLW8gL2V0Yy9hcHQva2V5cmluZ3MvZG9ja2VyLmdwZwplY2hvIFwKICAiZGViIFthcmNoPSQoZHBrZyAtLXByaW50LWFyY2hpdGVjdHVyZSkgc2lnbmVkLWJ5PS9ldGMvYXB0L2tleXJpbmdzL2RvY2tlci5ncGddIGh0dHBzOi8vZG93bmxvYWQuZG9ja2VyLmNvbS9saW51eC91YnVudHUgXAogICQobHNiX3JlbGVhc2UgLWNzKSBzdGFibGUiIHwgc3VkbyB0ZWUgL2V0Yy9hcHQvc291cmNlcy5saXN0LmQvZG9ja2VyLmxpc3QgPiAvZGV2L251bGwKYXB0LWdldCB1cGRhdGUKYXB0LWdldCBpbnN0YWxsIGRvY2tlci1jZSBkb2NrZXItY2UtY2xpIGNvbnRhaW5lcmQuaW8gZG9ja2VyLWNvbXBvc2UtcGx1Z2luCg=="
  }
SETTINGS

}

### now the DB
resource "azurerm_storage_account" "example" {
    name                     = "examplesa"
    resource_group_name      = azurerm_resource_group.main.name
    location                 = azurerm_resource_group.main.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_sql_server" "main" {
  name                         = "myexamplesqlserver"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "4dm1n157r470r"
  administrator_login_password = "4-v3ry-53cr37-p455w0rd"

  tags = {
    environment = "production"
  }
}

resource "azurerm_sql_firewall_rule" "allowAzureServices" {
  name                = "Allow_Azure_Services"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_sql_server.main.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}


resource "azurerm_sql_database" "appdb01" {
  depends_on                       = [azurerm_sql_firewall_rule.allowAzureServices]
  name                             = "AzSqlDbName"
  resource_group_name              = azurerm_sql_server.main.resource_group_name
  location                         = azurerm_sql_server.main.location
  server_name                      = azurerm_sql_server.main.name
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  requested_service_objective_name = "BC_Gen5_2"
  max_size_gb    = 4
  read_scale     = true
  zone_redundant = true


  create_mode = "Default"
  import {
    storage_uri                  = "https://examplesa.blob.core.windows.net/source/Source.bacpac"
    storage_key                  = "gSKjBfoK4toNAWXUdhe6U7YHqBgCBPsvoDKTlh2xlqUQeDcuCVKcU+uwhq61AkQaPIbNnqZbPmYwIRkXp3OzLQ=="
    storage_key_type             = "StorageAccessKey"
    administrator_login          = "4dm1n157r470r"
    administrator_login_password = "4-v3ry-53cr37-p455w0rd"
    authentication_type          = "SQL"
    operation_mode               = "Import"
  }


    tags = {
        foo = "bar"
    }
}
