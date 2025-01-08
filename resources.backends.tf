# --------
# BACKENDS
# --------
locals {
  # Path where the backend files are located
  backend_path = "${var.artifacts_path}/backends"

  # Name of the file holding the information
  backend_information_file = var.backend_information_filename

  # List all backend information files names, e.g. ["./artifacts/backends/dt-api/backendInformation.json"]
  backend_info_files_names = fileset(".", "${local.backend_path}/*/${local.backend_information_file}")

  # Backend Map: "backend name" => { info=<info object, decoded from json file> }
  backends_map = {
    for info_file_name in local.backend_info_files_names :
    basename(dirname(info_file_name)) => {
      # if the file content is incorrect, the error will be thrown here
      properties = jsondecode(templatefile(info_file_name, var.template_variables)).properties
    }
  }
}

# Create backend
resource "azurerm_api_management_backend" "main" {
  for_each = local.backends_map

  name                = each.key
  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  description = try(each.value.properties.description, null)
  protocol    = "http"
  url         = each.value.properties.url
  resource_id = try(each.value.properties.azureResourceManagerId, null)

  dynamic "tls" {
    # Only create if validateCertificateChain and/or validateCertificateName is defined
    for_each = can(each.value.properties.validateCertificateChain) || can(each.value.properties.validateCertificateName) ? ["true"] : []
    content {
      validate_certificate_chain = try(each.value.properties.validateCertificateChain, null)
      validate_certificate_name  = try(each.value.properties.validateCertificateName, null)
    }
  }

  dynamic "credentials" {
    for_each = can(each.value.properties.credentials) ? ["true"] : []
    content {
      # Reference to a named value in "header" need to be referenced as "{{named-value-name}}". Source: https://github.com/hashicorp/terraform-provider-azurerm/issues/14548
      header = try(each.value.credentials.properties.headers, null)
      query  = try(each.value.credentials.properties.query, null)

      # If the certificate property in backend information file is present, add the certificate(s).
      # For loop creates new list with thumbprints which is retrived from azurerm_api_management_certificate.main.
      # Value in certificate property in backend information file need to be the same value as in certificate information file.
      certificate = can(each.value.properties.credentials.certificates) ? [
        for certificate in each.value.properties.credentials.certificates
        : azurerm_api_management_certificate.main[certificate].thumbprint
      ] : null

      dynamic "authorization" {
        for_each = can(each.value.properties.credentials.authorization) ? ["true"] : []
        content {
          scheme    = each.value.properties.credentials.authorization.scheme
          parameter = each.value.properties.credentials.authorization.parameter
        }
      }
    }
  }

  # If referenced, named value and certificate must exist before backend is created
  depends_on = [
    azurerm_api_management_named_value.main,
    azurerm_api_management_policy_fragment.main,
    azurerm_api_management_certificate.main
  ]


  # 'name' is just a convenience for easier code navigation, the directroy name is used as a resource name
  # make sure there are no accidental mismatches between "name" in json (if present) and directory name
  lifecycle {
    precondition {
      condition     = each.key == try(each.value.properties.name, each.key)
      error_message = "Property 'name' (${each.value.properties.name}) does not match directory name (${each.key})"
    }
  }
}
