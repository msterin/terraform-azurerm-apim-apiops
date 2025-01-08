# --------
# GATEWAYS
# --------
locals {
  # Path where the gateway files are located
  gateway_path = "${var.artifacts_path}/gateways"

  # Name of the file holding the information
  gateway_information_file = var.gateway_information_filename

  # List all gateway information files names, e.g. ["./artifacts/gateways/dt-api/gatewayInformation.json"]
  gateway_info_files_names = fileset(".", "${local.gateway_path}/*/${local.gateway_information_file}")

  # gateway Map: "gateway name" => { info=<info object, decoded from json file> }
  gateways_map = {
    for info_file_name in local.gateway_info_files_names :
    basename(dirname(info_file_name)) => {
      # if the file content is incorrect, the error will be thrown here
      properties = jsondecode(templatefile(info_file_name, var.template_variables)).properties
    }
  }

  # Build a map of "gateway.API" => { gateway_name, api_name }.

  flattened_gateway_api_pairs = flatten([
    for gateway, gateway_info in local.gateways_map : [
      for api in gateway_info.properties.apis : {
        gateway = gateway
        api     = api
      }
    ]
  ])

  gateway_to_api_map = {
    for pair in local.flattened_gateway_api_pairs :
    "${pair.gateway}.${pair.api}" => pair
  }
}

resource "azurerm_api_management_gateway" "main" {
  for_each = local.gateways_map

  api_management_id = data.azurerm_api_management.main.id
  name              = each.value.properties.name
  description       = try(each.value.properties.description, each.value.properties.name)

  location_data {
    name     = each.value.properties.location.name
    city     = try(each.value.properties.location.city, null)
    district = try(each.value.properties.location.district, null)
    region   = try(each.value.properties.location.region, null)
  }

}

resource "azurerm_api_management_gateway_api" "main" {
  for_each = local.gateway_to_api_map

  gateway_id = azurerm_api_management_gateway.main[each.value.gateway].id

  # We need to strip ';rev=x' from the API ID, otherwise this will never match and will always be reapplied
  # There is a bug in azurerm provider that strips ';rev=x' from API ID on storing in the object, but not on input
  # the id format is '<id>;rev=x' so we just need to pick up the first part before ';'
  api_id = split(";", azurerm_api_management_api.main[each.value.api].id)[0]
}
