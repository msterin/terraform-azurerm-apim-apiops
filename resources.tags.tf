# --------
# API TAGS
# --------
locals {
  # Path where the tags information file are located
  tags_path = "${var.artifacts_path}/tags"

  # Name of the file holding the information
  tags_information_file = var.tags_information_filename

  # Tags information file full path
  apim_tags = "${local.tags_path}/${local.tags_information_file}"

  # tags map as presented in the file (after template processing) or an empty map
  tags_map = try(jsondecode(file(local.apim_tags)).tags, {})
}

# Create tag on API Management scope
resource "azurerm_api_management_tag" "main" {
  for_each = local.tags_map

  api_management_id = data.azurerm_api_management.main.id
  name              = each.key
  display_name      = each.value
}
