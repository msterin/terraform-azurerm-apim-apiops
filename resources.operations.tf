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
    format("%s.%s",                                                                # Unique key for easy reference
      element(split("/", path), length(split("/", path)) - 4),                     # API name
      element(split("/", path), length(split("/", path)) - 2)                      # Op name
      ) => {                                                                       # node content:
      api_name           = element(split("/", path), length(split("/", path)) - 4) # API name
      op_name            = element(split("/", path), length(split("/", path)) - 2) # Op name
      policy_file_name   = path                                                    # Full path to file
      policy_xml_content = file(path)
    }
  }

  required_fields = ["method", "url_template"]

  operation_info_map = {
    for path in local.all_operations_info_files_names :
    format("%s.%s",                                                            # Unique key for easy reference
      element(split("/", path), length(split("/", path)) - 4),                 # API name
      element(split("/", path), length(split("/", path)) - 2)                  # Op name
      ) => {                                                                   # node content:
      api_name       = element(split("/", path), length(split("/", path)) - 4) # API name
      op_name        = element(split("/", path), length(split("/", path)) - 2) # Op name
      info_file_name = path                                                    # Full path to file
      op_info        = jsondecode(file(path))
    }
  }
}

resource "azurerm_api_management_api_operation_policy" "main" {
  for_each = local.operation_policies_map

  api_name            = each.value.api_name
  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name
  operation_id        = each.value.op_name
  xml_content         = file("${each.value.policy_file_name}")

  depends_on = [azurerm_api_management_api_operation.main]
}

resource "azurerm_api_management_api_operation" "main" {
  for_each = local.operation_info_map

  operation_id        = each.value.op_name
  api_name            = each.value.api_name
  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name
  url_template        = each.value.op_info.url_template
  method              = each.value.op_info.method
  display_name        = can(each.value.op_info.display_name) ? each.value.op_info.display_name : each.value.op_name
  description         = can(each.value.op_info.description) ? each.value.op_info.description : each.value.op_info.display_name

  dynamic "template_parameter" {
    # Only create if template_parameter is defined in API operation information file
    for_each = can(each.value.op_info.parameters) ? each.value.op_info.parameters : []

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
    precondition {
      condition     = alltrue([for f in local.required_fields : contains(keys(each.value.op_info), f)])
      error_message = "A mandatory field (one of '${join(", ", local.required_fields)}') is missing in ${each.value.info_file_name}"
    }
  }
  # lifecycle {
  #   precondition {
  #     # alltrue[for op in local.operation_info_map:
  #     condition = length(setsubtract(toset(local.required_fields), toset(keys(each.value.op_info)))) == 0
  #     # error_message = "Json file for operatiosetsubtractn ${each.value.op_name} is missing required fields ${setsubtract(local.required_fields, keys(each.value.op_info))} : ${each.value.info_file_name}"
  #     error_message = " bad"
  #   }
  # }

  depends_on = [
    azurerm_api_management_api.main,
    azurerm_api_management_backend.main,
    azurerm_api_management_named_value.main,
    azurerm_api_management_certificate.main
  ]
}

