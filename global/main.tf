

data "azurerm_client_config" "current" {}


## Resource Group development default resources
resource "azapi_resource" "AppInsights" {
  body = {
    etag = "\"6f0192e9-0000-1500-0000-692efc1f0000\""
    kind = "web"
    properties = {
      Application_Type                = "web"
      Flow_Type                       = "Redfield"
      IngestionMode                   = "LogAnalytics"
      Request_Source                  = "IbizaWebAppExtensionCreate"
      SamplingPercentage              = null
      WorkspaceResourceId             = azapi_resource.logAnalyticsWorkspace.id
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
    }
  }
  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  location                  = var.location
  name                      = "${var.environment}_client_insights"
  parent_id                 = var.rg_id
  schema_validation_enabled = true
  type                      = "microsoft.insights/components@2020-02-02-preview"
}

resource "azapi_resource" "logAnalyticsWorkspace" {
  body = {
    etag = "\"1e02a6cc-0000-1500-0000-692efc110000\""
    properties = {
      features = {
        enableLogAccessUsingOnlyResourcePermissions = true
        legacy                                      = 0
        searchVersion                               = 1
      }
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
      retentionInDays                 = 30
      sku = {
        name = "PerGB2018"
      }
      workspaceCapping = {
        dailyQuotaGb = -1
      }
    }
  }
  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  location                  = var.location
  name                      = "DefaultWorkspace-3454637f"
  parent_id                 = var.rg_id
  schema_validation_enabled = true
  type                      = "Microsoft.OperationalInsights/workspaces@2025-02-01"
}

resource "azurerm_virtual_network" "rg_vnet" {
  name                = "${var.prefix}-network"
  resource_group_name = var.environment
  location            = var.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "receipt-zone" {
  name                 = "frontend"
  virtual_network_name = azurerm_virtual_network.rg_vnet.name
  resource_group_name  = var.environment
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "distro-zone" {
  name                              = "backend"
  virtual_network_name              = azurerm_virtual_network.rg_vnet.name
  resource_group_name               = var.environment
  address_prefixes                  = ["10.0.2.0/24"]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "support-zone" {
  name                 = "database"
  virtual_network_name = azurerm_virtual_network.rg_vnet.name
  resource_group_name  = var.environment
  address_prefixes     = ["10.0.3.0/24"]
}
resource "azurerm_public_ip" "vnet_public_ip" {
  name                = "${var.prefix}-pip"
  location            = var.location
  resource_group_name = var.environment
  allocation_method   = "Static"
}


# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "myPublicIP"
  location            = var.location
  resource_group_name = var.environment
  allocation_method   = "Static"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "rg_nsg" {
  name                = "${var.environment}NetworkSecurityGroup"
  location            = var.location
  resource_group_name = var.environment

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "rg_nic" {
  name                = "${var.environment}NIC"
  location            = var.location
  resource_group_name = var.environment

  ip_configuration {
    name                          = "${var.environment}_nic_configuration"
    subnet_id                     = azurerm_subnet.receipt-zone.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.rg_nic.id
  network_security_group_id = azurerm_network_security_group.rg_nsg.id
}


resource "random_string" "acr_name" {
  length  = 5
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_container_registry" "app_registry" {
  name                = "${random_string.acr_name.result}registry"
  resource_group_name = var.environment
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true

}

resource "random_string" "azurerm_key_vault_name" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false
}

locals {
  current_user_id = coalesce(var.msi_id, data.azurerm_client_config.current.object_id)
}

resource "azurerm_key_vault" "vault" {
  name                       = coalesce(var.vault_name, "vault-${random_string.azurerm_key_vault_name.result}")
  location                   = var.location
  resource_group_name        = var.environment
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = local.current_user_id

    key_permissions    = var.key_permissions
    secret_permissions = var.secret_permissions
  }
}

resource "random_string" "azurerm_key_vault_key_name" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_key_vault_key" "key" {
  name = coalesce(var.key_name, "key-${random_string.azurerm_key_vault_key_name.result}")

  key_vault_id = azurerm_key_vault.vault.id
  key_type     = var.key_type
  key_size     = var.key_size
  key_opts     = var.key_ops

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
}

output "AppInsightsWorkspace" {
  value = azapi_resource.AppInsights.id
}

