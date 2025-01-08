# ------------
# OPERATION POLICIES
# ------------

locals {

  api_operation_filename = var.api_operation_filename

  # Produce an array of existing file names, e.g. ["apis/SDL_apiops/operations/DigitalTwins_Update/policy.xml"]
  all_operations_policy_files_names = fileset(".", "${local.apis_path}/*/operations/*/${local.api_policy_file}")
  all_operations_info_files_names   = fileset(".", "${local.apis_path}/*/operations/*/${local.api_operation_filename}")

  # Generate a map of "api.operation" => { api_name, op_name, full_policy_file_path}
  # {
  #     "SDL_apiops.Health_startup" = {
  #        "api_name" = "SDL_apiops"
  #        "op_name" = "Health_startup"
  #        "policy_file_name" = "artifacts/apis/SDL_apiops/operations/Health_startup/policy.xml"
  #        "policy_xml_content" = "<xml content>"
  #     },
  #     ....
  # }
  operation_policies_map = {
    for path in local.all_operations_policy_files_names :
    format("%s.%s",                                                  # Unique key for easy reference
      basename(dirname(dirname(dirname(path)))),                     # API name, 3 levels up
      basename(dirname(path))                                        # Op name
      ) => {                                                         # node content:
      api_name           = basename(dirname(dirname(dirname(path)))) # API name, 3 levels up
      op_name            = basename(dirname(path))                   # Op name
      policy_file_name   = path                                      # Full path to file
      policy_xml_content = templatefile(path, var.template_variables)
    }
  }

  required_fields = ["method", "url_template"]

  operation_info_map = {
    for path in local.all_operations_info_files_names :
    format("%s.%s",                                              # Unique key for easy reference
      basename(dirname(dirname(dirname(path)))),                 # API name, 3 levels up
      basename(dirname(path))                                    # Op name
      ) => {                                                     # node content:
      api_name       = basename(dirname(dirname(dirname(path)))) # API name, 3 levels up
      op_name        = basename(dirname(path))                   # Op name
      info_file_name = path                                      # Full path to file
      properties     = jsondecode(templatefile(path, var.template_variables)).properties
    }
  }
}

resource "azurerm_api_management_api_operation_policy" "main" {
  for_each = local.operation_policies_map

  api_name            = each.value.api_name
  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name
  operation_id        = each.value.op_name
  xml_content         = each.value.policy_xml_content

  depends_on = [azurerm_api_management_api_operation.main]
}

resource "azurerm_api_management_api_operation" "main" {
  for_each = local.operation_info_map

  operation_id        = each.value.op_name
  api_name            = each.value.api_name
  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name
  url_template        = each.value.properties.url_template
  method              = each.value.properties.method
  display_name        = can(each.value.properties.display_name) ? each.value.properties.display_name : each.value.op_name
  description         = can(each.value.properties.description) ? each.value.properties.description : each.value.properties.display_name

  dynamic "template_parameter" {
    # Only create if template_parameter is defined in API operation information file
    for_each = can(each.value.properties.parameters) ? each.value.properties.parameters : []

    content {
      name        = template_parameter.value["name"]
      type        = template_parameter.value["type"]
      required    = template_parameter.value["required"]
      description = can(template_parameter.value["description"]) ? template_parameter.value["description"] : template_parameter.value["name"]
    }
  }

  response {
    status_code = 200
  }

  lifecycle {
    # 'name' is just a convenience for easier code navigation, the directroy name is used as a resource name
    # make sure there are no accidental mismatches between "name" in json (if present) and directory name
    precondition {
      condition     = each.value.op_name == try(each.value.properties.name, each.value.op_name)
      error_message = "Property 'name' (${try(each.value.properties.name, null)}) does not match directory name (${each.value.op_name})"
    }

    # check for mandatory fields in the operation information file
    precondition {
      condition     = alltrue([for f in local.required_fields : contains(keys(each.value.properties), f)])
      error_message = "A mandatory field (one of '${join(", ", local.required_fields)}') is missing in ${each.value.info_file_name}"
    }
  }

  depends_on = [
    azurerm_api_management_api.main,
    azurerm_api_management_backend.main,
    azurerm_api_management_named_value.main
  ]
}

output "map" {
  value = local.operation_policies_map
}
