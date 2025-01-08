# --------
# policy_fragments
# --------
locals {
  # Path where the policy_fragment files are located
  policy_fragment_path = "${var.artifacts_path}/policyFragments"

  # Name of the file holding the information
  policy_fragment_information_file = var.policy_fragment_information_filename

  # List all policy_fragment information files names, e.g. ["./artifacts/policy_fragments/dt-api/policyFragmentInformation.json"]
  policy_fragment_info_files_names = fileset(".", "${local.policy_fragment_path}/*/${local.policy_fragment_information_file}")

  # policy_fragment Map: "policy_fragment name" => { info=<info object, decoded from json file>, content= XML file content }
  policy_fragments_map = {
    for info_file_name in local.policy_fragment_info_files_names :
    basename(dirname(info_file_name)) => {
      # if the file content is incorrect, the error will be thrown here
      properties = jsondecode(templatefile(info_file_name, var.template_variables)).properties
      content    = templatefile("${dirname(info_file_name)}/${var.policy_fragment_content_filename}", var.template_variables)

    }
  }
}

# Create policy_fragment
resource "azurerm_api_management_policy_fragment" "main" {
  for_each = local.policy_fragments_map

  api_management_id = data.azurerm_api_management.main.id
  name              = each.key
  description       = try(each.value.properties.description, "Policy fragment: ${each.key}")
  format            = "rawxml"
  value             = each.value.content

  # 'name' is just a convenience for easier code navigation, the directroy name is used as a resource name
  # make sure there are no accidental types and "name" in json (if present) matches the dir name
  lifecycle {
    precondition {
      condition     = each.key == try(each.value.properties.name, each.key)
      error_message = "Property 'name' (${each.value.properties.name}) does not match directory name (${each.key})"
    }
  }
}

