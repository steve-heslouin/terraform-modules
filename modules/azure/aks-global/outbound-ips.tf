resource "azurerm_public_ip_prefix" "aks" {
  count               = var.public_ip_prefix_configuration.count
  name                = "pip-prefix-${var.environment}-${var.location_short}-${var.name}-aks-${count.index}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  prefix_length       = var.public_ip_prefix_configuration.prefix_length
  sku                 = "Standard"
}
