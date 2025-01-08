# ----
# DATA
# ----

data "azuread_client_config" "current" {
  count = can(local.apim_groups.aad_groups) ? 1 : 0 # only need this one if groups are defined
}

data "azurerm_api_management" "main" {
  name                = var.api_management_name
  resource_group_name = var.api_management_resource_group_name
}

data "azurerm_application_insights" "main" {
  count = local.application_insights_enabled ? 1 : 0

  name                = var.application_insights_name
  resource_group_name = var.application_insights_resource_group_name
}

# ------------------------------------------------
# Other resources are placed in seperated TF-files
# ------------------------------------------------
