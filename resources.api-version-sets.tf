# ----------------
# API VERSION SETS
# ----------------
locals {
  # Path where the API version set files are located
  api_version_sets_path = "${var.artifacts_path}/apiVersionSets"

  # Name of the file holding the information
  api_version_set_information_file = var.api_version_set_information_filename

  # List all version set information files names
  api_version_set_info_files_names = fileset(".", "${local.api_version_sets_path}/*/${local.api_version_set_information_file}")

  # Backend Map: "versionSet name" => { properties=<properties object, decoded from json file> }
  api_version_sets_map = {
    for info_file_name in local.api_version_set_info_files_names :
    basename(dirname(info_file_name)) => {
      # if the file content is incorrect, the error will be thrown here
      properties = jsondecode(templatefile(info_file_name, var.template_variables)).properties
    }
  }
}

resource "azurerm_api_management_api_version_set" "main" {
  for_each = local.api_version_sets_map

  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  name              = each.key
  display_name      = each.value.properties.displayName
  versioning_scheme = each.value.properties.versioningScheme

  description         = try(each.value.properties.description, null)
  version_header_name = try(each.value.properties.versionHeaderName, null)
  version_query_name  = try(each.value.properties.versionQueryName, null)

}
