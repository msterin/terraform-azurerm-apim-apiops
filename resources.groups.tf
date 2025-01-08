# ------
# GROUPS
# ------
locals {
  # Path where the groups information file are located
  groups_path = "${var.artifacts_path}/groups"

  # Name of the file holding the information
  groups_information_file = var.groups_information_filename

  # Group information file full path
  apim_groups_file_name = "${local.groups_path}/${local.groups_information_file}"

  apim_groups = fileexists(local.apim_groups_file_name) ? jsondecode(file(local.apim_groups_file_name)) : {}
}

# Get data about Azure AD groups to use the object ID
data "azuread_group" "apim_groups" {
  for_each = can(local.apim_groups.aad_groups) ? toset(local.apim_groups.aad_groups) : []

  display_name = each.key
}

# Create groups
## Before assigning a group on a product the group needs to be created on the API Management scope first.

## Azure AD groups
resource "azurerm_api_management_group" "aad" {
  for_each = can(local.apim_groups.aad_groups) ? toset(local.apim_groups.aad_groups) : []

  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  name         = lower(replace(each.key, "/[ .]/", "-")) # Replace both space " " and dots "." from name. "name" may only contain alphanumeric characters, underscores and dashes up to 80 characters in length
  display_name = each.key

  # if we don't need the current azurerm_api_management_group resource, we can skip client config fetch but we need to provide a dummy value - thus 'try' below
  external_id = "aad://${try(data.azuread_client_config.current[0].tenant_id, "null")}/groups/${data.azuread_group.apim_groups[each.key].object_id}"
  type        = "external"
}

## Local groups on APIM
resource "azurerm_api_management_group" "local" {
  for_each = can(local.apim_groups.local_groups) ? toset(local.apim_groups.local_groups) : []

  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  name         = lower(replace(each.key, "/[ .]/", "-")) # Replace both space " " and dots "." from name. "name" may only contain alphanumeric characters, underscores and dashes up to 80 characters in length
  display_name = each.key

  type = "custom"
}
