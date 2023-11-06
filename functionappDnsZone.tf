provider "azurerm" {
  features {
    # resource_group {
    #   prevent_deletion_if_contains_resources = false
    # }
  }
#   client_id       = "4f166274-0b30-4099-bdc5-888ad48ed4b7"
#   client_secret   = "AjN8Q~6zmjtEwcShjYKB9UutS9w5JauA9okDcdlT"
  subscription_id = "4f166274-0b30-4099-bdc5-888ad48ed4b7" #"9baaa753-911f-4192-a73e-e9ed9fc6ef4b" 
  tenant_id       = "13b96fd0-9063-418d-8c91-8f106307639f" #"13b96fd0-9063-418d-8c91-8f106307639f"
}
resource "azurerm_resource_group" "example" {
  name     = var.RGname
  location = var.location
}

resource "azurerm_function_app" "example" {
  name                      = var.name
  location                  = var.location
  resource_group_name       = azurerm_resource_group.example.name
  app_service_plan_id       = azurerm_app_service_plan.example.id
  storage_account_name       = azurerm_storage_account.example.name
  storage_account_access_key = azurerm_storage_account.example.primary_access_key
  https_only                = true
  site_config {
    always_on = var.always_on
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }
    use_32_bit_worker_process = var.use_32_bit_worker_process
    ftps_state                = var.ftps_state
    dotnet_framework_version  = var.net_framework_version
  }
    depends_on = [
    azurerm_resource_group.example,
    azurerm_storage_account.example,
    azurerm_app_service_plan.example
 ]
  
}

resource "azurerm_app_service_plan" "example" {
  name                = "example-appserviceplan"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_storage_account" "example" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.example.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_application_insights" "example" {
  name                = "appinsights"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.example.name
  application_type    = "web"
}

resource "azurerm_virtual_network" "example" {
  name                = "DNSVnet"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = "funsubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_private_endpoint" "example" {
  name                = "pvtendpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                     = "pvtserviceconnection"
    private_connection_resource_id = azurerm_function_app.example.id
    is_manual_connection       = false
  }

  private_dns_zone_group {
    name                 = "example-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.example.id]
  }
  depends_on = [
    azurerm_private_dns_zone.example
 ]
}

resource "azurerm_private_dns_zone" "example" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_private_dns_a_record" "example" {
  name                = var.inbound_private_dns_zone_a_record_name
  zone_name           = azurerm_private_dns_zone.example.name
  resource_group_name = azurerm_resource_group.example.name
  ttl                 = 10

  records = [
    azurerm_private_endpoint.example.private_service_connection[0].private_connection_resource_id
  ]
    depends_on = [
    azurerm_private_dns_zone.example,
    azurerm_private_endpoint.example
 ]
}


# resource "azurerm_private_dns_zone" "example_scm" {
#   name                = "privatelink.azurewebsites.net/scm"
#   resource_group_name = "MA-RG"
# }

resource "azurerm_private_dns_a_record" "example_scm" {
  name                = var.inbound_private_dns_zone_a_record_name_scm
  zone_name           = azurerm_private_dns_zone.example.name
  resource_group_name = azurerm_resource_group.example.name
  ttl                 = 10
  records = [
    azurerm_private_endpoint.example.private_service_connection[0].private_connection_resource_id
  ]

}

resource "azurerm_network_interface" "example" {
  name                = "funpvtendpoint.nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "privateEndpointIpConfig"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "example_scm" {
  name                = "apimpvtendpoint.nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "privateEndpointIpConfig"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "example-link"
  resource_group_name   = azurerm_resource_group.example.name
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = azurerm_virtual_network.example.id
}

output "function_app_name" {
  value = azurerm_function_app.example.name
}

variable "name" {
  type    = string
  default = "your-function-app-name"
}

variable "location" {
  type    = string
  default = "East US"
}
variable "RGname" {
  type    = string
  default = "MA-RG"
}

variable "use_32_bit_worker_process" {
  type    = bool
  default = false
}

variable "ftps_state" {
  type    = string
  default = "FtpsOnly"
}

variable "storage_account_name" {
  type    = string
  default = "mahastorage2507"
}

variable "net_framework_version" {
  type    = string
  default = "v4.0"
}

variable "always_on" {
  type    = bool
  default = true
}

variable "inbound_private_dns_zone_a_record_name" {
  type    = string
  default = "inboundprivatednszonearecordname"
}

variable "inbound_private_dns_zone_a_record_name_scm" {
  type    = string
  default = "inboundprivatednszonearecordnamescm"
}




#API Management

# resource "azurerm_resource_group" "example" {
#   name     = "example-resources"
#   location = "West Europe"
# }

resource "azurerm_api_management" "example" {
  name                = "example-apim"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  publisher_name      = "My Company"
  publisher_email     = "company@terraform.io"

  sku_name = "Developer_1"
}
resource "azurerm_subnet" "example1" {
  name                 = "apisubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_api_management_api" "example" {
  name                = "example-api"
  resource_group_name = azurerm_resource_group.example.name
  api_management_name = azurerm_api_management.example.name
  revision            = "1"
  display_name        = "Example API"
  path                = "example"
  protocols           = ["https"]

  import {
    content_format = "swagger-link-json"
    content_value  = "http://conferenceapi.azurewebsites.net/?format=json"
  }
}

resource "azurerm_private_endpoint" "example1" {
  name                = "pvtendpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.example1.id

  private_service_connection {
    name                     = "pvtserviceconnection"
    private_connection_resource_id = azurerm_api_management_api.example.id
    is_manual_connection       = false
  }

  private_dns_zone_group {
    name                 = "example-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.example1.id]
  }
  depends_on = [
    azurerm_private_dns_zone.example1
 ]
}

resource "azurerm_private_dns_zone" "example1" {
  name                = "privatelink.azure-api.net."
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_private_dns_a_record" "example1" {
  name                = var.inbound_private_dns_zone_a_record_name
  zone_name           = azurerm_private_dns_zone.example1.name
  resource_group_name = azurerm_resource_group.example.name
  ttl                 = 10

  records = [
    azurerm_private_endpoint.example1.private_service_connection[0].private_connection_resource_id
  ]
    depends_on = [
    azurerm_private_dns_zone.example1,
    azurerm_private_endpoint.example1
 ]
}

resource "azurerm_private_dns_a_record" "example1_scm" {
  name                = var.inbound_private_dns_zone_a_record_name_scm
  zone_name           = azurerm_private_dns_zone.example1.name
  resource_group_name = azurerm_resource_group.example.name
  ttl                 = 10
  records = [
    azurerm_private_endpoint.example1.private_service_connection[0].private_connection_resource_id
  ]

}

resource "azurerm_network_interface" "example" {
  name                = "apipvtendpoint.nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "privateEndpointIpConfig"
    subnet_id                     = azurerm_subnet.example1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "example_scm" {
  name                = "apimpvtendpoint.nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "privateEndpointIpConfig"
    subnet_id                     = azurerm_subnet.example1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "example1" {
  name                  = "example-link"
  resource_group_name   = azurerm_resource_group.example.name
  private_dns_zone_name = azurerm_private_dns_zone.example1.name
  virtual_network_id    = azurerm_virtual_network.example.id
}

output "api_app_name" {
  value = azurerm_api_management_api.example.name
}

variable "inbound_private_dns_zone_a_record_name" {
  type    = string
  default = "inboundprivatednszonearecordname"
}

variable "inbound_private_dns_zone_a_record_name_scm" {
  type    = string
  default = "inboundprivatednszonearecordnamescm"
}
