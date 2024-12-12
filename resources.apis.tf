# ----
# APIS
# ----

# If information file does not exist, we assume the user just wants to manage policies
# for an existing API and we don't need to create the API itself (thus we also ignore specs/swagger file if any)

# Оtherwise we create the API and (optionally) the policy. Note that in this case both information and specification files are mandatory and must exist.

#
locals {
  # Path where the API files are located
  apis_path = "${var.artifacts_path}/apis"

  # Name of the files holding the information, specification and policy
  api_information_file   = var.api_information_filename
  api_specification_file = var.api_specification_filename
  api_policy_file        = var.api_policy_filename

  # Lists all files in apis folder
  all_api_files = fileset(local.apis_path, "**")

  # Extracts directory names and removes duplicates. Each directory holds information about one API.
  apis = distinct([for key in local.all_api_files : dirname(key)])

  # Array of existing file names, e.g. ["./artifacts/apis/myApi/policy.xml"]
  all_apis_info_files_names   = fileset(".", "${local.apis_path}/*/${local.api_information_file}")
  all_apis_policy_files_names = fileset(".", "${local.apis_path}/*/${local.api_policy_file}")

  # Form maps for resource creation - each map element will be used to create a resource (API or policy)
  # if map is empty, the correspondent resources will not be created

  # API Map: "api name" => { info=<info object, decoded from json file>, spec=<spec file content> }
  apis_map = {
    for info_file_name in local.all_apis_info_files_names :
    basename(dirname(info_file_name)) => {
      info           = jsondecode(templatefile(info_file_name, {})) # todo: pass a map with variables
      spec_file_name = "${dirname(info_file_name)}/${local.api_specification_file}"
    }
  }

  # API Policy Map: "api name" => { file_name = <policy file_name>, content = <policy file content> }
  api_policies_map = {
    for policy_file_name in local.all_apis_policy_files_names :
    basename(dirname(policy_file_name)) => {
      content = file(policy_file_name)
    }
  }

  # a helper - all a list of {api_name, tag_name} pairs
  api_tag_pairs = flatten([
    for api_name, value in local.apis_map : [
      for tag in try(value.info.properties.tags, []) : {
        tag_name = tag
        api_name = api_name
    }]
  ])

  # API Tag Map: "apiname.tagname" => { api_id = <api id>, tag_name = <tag name> }
  api_tag_map = {
    for pair in local.api_tag_pairs : "${pair.api_name}.${pair.tag_name}" => {
      api_id   = azurerm_api_management_api.main[pair.api_name].id
      tag_name = pair.tag_name
    }
  }

  # Per-API diagnostic log settings
  api_diagnostic_logs_map = {
    for api_name, value in local.apis_map : api_name => {
      diagnosticLogs = value.info.properties.diagnosticLogs
      info           = value.info
    } if can(value.info.properties.diagnosticLogs)
  }

}

# Create API
resource "azurerm_api_management_api" "main" {
  for_each = local.apis_map

  name                = lower(replace(each.key, " ", "-"))
  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name
  api_type            = "http"

  display_name = each.value.info.properties.displayName
  description  = try(each.value.info.properties.description, null)

  revision              = try(each.value.info.properties.apiRevision, 1)
  subscription_required = try(each.value.info.properties.subscriptionRequired, true)
  protocols             = try(each.value.info.properties.protocols, ["https"])

  service_url          = try(each.value.info.properties.serviceUrl, null)
  terms_of_service_url = try(each.value.info.properties.termsOfService, null)

  # Set var.allow_api_without_path to false or true to choose between if the path property should be mandatory or not.
  # This is controlled and checked in the postcondition block.
  path = try(each.value.info.properties.path, null)

  # If version is set, version_set_id also need to be set.
  # version_set_id depends on azurerm_api_management_api_version_set.main
  version        = try(each.value.info.properties.version, null)
  version_set_id = try(azurerm_api_management_api_version_set.main[each.value.info.properties.apiVersionSet.versionSetName].id, null)

  # Subscription key parameter names
  dynamic "subscription_key_parameter_names" {
    # Only create if subscriptionKeyParameterNames is defined in API information file
    for_each = can(each.value.info.properties.subscriptionKeyParameterNames) ? ["true"] : []
    content {
      header = each.value.info.properties.subscriptionKeyParameterNames.header
      query  = each.value.info.properties.subscriptionKeyParameterNames.query
    }
  }

  # License
  dynamic "license" {
    # Only create if license is defined in API information file
    for_each = can(each.value.info.properties.license) ? ["true"] : []
    content {
      # Only create each property if value exists in specification file
      name = try(each.value.info.properties.license.name, null)
      url  = try(each.value.info.properties.license.url, null)
    }
  }

  # Contact
  dynamic "contact" {
    # Only create if contact is defined in API information file
    for_each = can(each.value.info.properties.contact) ? ["true"] : []
    content {
      # Only create each property if value exists in specification file
      name  = try(each.value.info.properties.contact.name, null)
      email = try(each.value.info.properties.contact.email, null)
      url   = try(each.value.info.properties.contact.url, null)
    }
  }

  # Import specification file
  import {
    content_format = endswith(local.api_specification_file, ".json") ? "openapi+json" : "openapi"
    content_value  = file(each.value.spec_file_name)
  }

  lifecycle {
    # Checking if no path is set to be allowed, and the actual value of the path property.
    # Set var.allow_api_without_path to false or true to choose between if the path property should be mandatory or not.
    postcondition {
      condition     = (self.path == "" || self.path == null) && var.allow_api_without_path == false ? false : true
      error_message = "API without path is not allowed. Set 'allow_api_without_path' to 'true' to allow this."
    }
  }

  depends_on = [azurerm_api_management_tag.main]
}

# Assign tag(s) on API
resource "azurerm_api_management_api_tag" "main" {
  for_each = local.api_tag_map

  api_id = each.value.api_id
  name   = each.value.tag_name
}

# Create API policy
resource "azurerm_api_management_api_policy" "main" {
  # Only create if policy file exists. API files must also exists - if not the policy will not be created.
  for_each = local.api_policies_map

  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  api_name    = azurerm_api_management_api.main[each.key].name
  xml_content = each.value.content
}

# Diagnostic log settings for API
resource "azurerm_api_management_api_diagnostic" "main" {
  for_each = local.api_diagnostic_logs_map

  api_management_name      = data.azurerm_api_management.main.name
  resource_group_name      = data.azurerm_api_management.main.resource_group_name
  api_management_logger_id = "${data.azurerm_api_management.main.id}/loggers/${data.azurerm_application_insights.main[0].name}"

  api_name   = azurerm_api_management_api.main[each.key].name # forces dependency
  identifier = "applicationinsights"

  sampling_percentage       = try(each.value.info.properties.diagnosticLogs.samplingPercentage, 100)
  always_log_errors         = try(each.value.info.properties.diagnosticLogs.alwaysLogErrors, false)
  log_client_ip             = try(each.value.info.properties.diagnosticLogs.logClientIp, true)
  verbosity                 = try(each.value.info.properties.diagnosticLogs.verbosity, "information")
  http_correlation_protocol = try(each.value.info.properties.diagnosticLogs.correlationProtocol, "Legacy")
  operation_name_format     = try(each.value.info.properties.diagnosticLogs.operationNameFormat, "Name")

  # Advanced options
  ## Frontend request
  dynamic "frontend_request" {
    for_each = can(each.value.info.properties.diagnosticLogs.frontendRequests) ? ["true"] : []
    content {
      headers_to_log = each.value.info.properties.diagnosticLogs.frontendRequests.headersToLog
      body_bytes     = each.value.info.properties.diagnosticLogs.frontendRequests.bodyBytes
      dynamic "data_masking" {
        for_each = can(each.value.info.properties.diagnosticLogs.frontendRequests.dataMasking) ? ["true"] : []
        content {
          dynamic "headers" {
            for_each = can(each.value.info.properties.diagnosticLogs.frontendRequests.dataMasking.headers) ? ["true"] : []
            content {
              mode  = each.value.info.properties.diagnosticLogs.frontendRequests.dataMasking.headers.mode
              value = each.value.info.properties.diagnosticLogs.frontendRequests.dataMasking.headers.value
            }
          }
          dynamic "query_params" {
            for_each = can(each.value.info.properties.diagnosticLogs.frontendRequests.dataMasking.queryParams) ? ["true"] : []
            content {
              mode  = each.value.info.properties.diagnosticLogs.frontendRequests.dataMasking.queryParams.mode
              value = each.value.info.properties.diagnosticLogs.frontendRequests.dataMasking.queryParams.value
            }
          }
        }
      }
    }
  }

  ### If removed from JSON, set values to null
  dynamic "frontend_request" {
    for_each = can(each.value.info.properties.diagnosticLogs.frontendRequests) ? [] : ["false"]
    content {
      headers_to_log = null
      body_bytes     = null
    }
  }

  ## Frontend response
  dynamic "frontend_response" {
    for_each = can(each.value.info.properties.diagnosticLogs.frontendResponse) ? ["true"] : []
    content {
      headers_to_log = each.value.info.properties.diagnosticLogs.frontendResponse.headersToLog
      body_bytes     = each.value.info.properties.diagnosticLogs.frontendResponse.bodyBytes
      dynamic "data_masking" {
        for_each = can(each.value.info.properties.diagnosticLogs.frontendResponse.dataMasking) ? ["true"] : []
        content {
          dynamic "headers" {
            for_each = can(each.value.info.properties.diagnosticLogs.frontendResponse.dataMasking.headers) ? ["true"] : []
            content {
              mode  = each.value.info.properties.diagnosticLogs.frontendResponse.dataMasking.headers.mode
              value = each.value.info.properties.diagnosticLogs.frontendResponse.dataMasking.headers.value
            }
          }
          dynamic "query_params" {
            for_each = can(each.value.info.properties.diagnosticLogs.frontendResponse.dataMasking.queryParams) ? ["true"] : []
            content {
              mode  = each.value.info.properties.diagnosticLogs.frontendResponse.dataMasking.queryParams.mode
              value = each.value.info.properties.diagnosticLogs.frontendResponse.dataMasking.queryParams.value
            }
          }
        }
      }
    }
  }

  ### If removed from JSON, set values to null
  dynamic "frontend_response" {
    for_each = can(each.value.info.properties.diagnosticLogs.frontendResponse) ? [] : ["false"]
    content {
      headers_to_log = null
      body_bytes     = null
    }
  }

  ## Backend request
  dynamic "backend_request" {
    for_each = can(each.value.info.properties.diagnosticLogs.backendRequest) ? ["true"] : []
    content {
      headers_to_log = each.value.info.properties.diagnosticLogs.backendRequest.headersToLog
      body_bytes     = each.value.info.properties.diagnosticLogs.backendRequest.bodyBytes
      dynamic "data_masking" {
        for_each = can(each.value.info.properties.diagnosticLogs.backendRequest.dataMasking) ? ["true"] : []
        content {
          dynamic "headers" {
            for_each = can(each.value.info.properties.diagnosticLogs.backendRequest.dataMasking.headers) ? ["true"] : []
            content {
              mode  = each.value.info.properties.diagnosticLogs.backendRequest.dataMasking.headers.mode
              value = each.value.info.properties.diagnosticLogs.backendRequest.dataMasking.headers.value
            }
          }
          dynamic "query_params" {
            for_each = can(each.value.info.properties.diagnosticLogs.backendRequest.dataMasking.queryParams) ? ["true"] : []
            content {
              mode  = each.value.info.properties.diagnosticLogs.backendRequest.dataMasking.queryParams.mode
              value = each.value.info.properties.diagnosticLogs.backendRequest.dataMasking.queryParams.value
            }
          }
        }
      }
    }
  }

  ### If removed from JSON, set values to null
  dynamic "backend_request" {
    for_each = can(each.value.info.properties.diagnosticLogs.backendRequest) ? [] : ["false"]
    content {
      headers_to_log = null
      body_bytes     = null
    }
  }

  ## Backend response
  dynamic "backend_response" {
    for_each = can(each.value.info.properties.diagnosticLogs.backendResponse) ? ["true"] : []
    content {
      headers_to_log = each.value.info.properties.diagnosticLogs.backendResponse.headersToLog
      body_bytes     = each.value.info.properties.diagnosticLogs.backendResponse.bodyBytes
      dynamic "data_masking" {
        for_each = can(each.value.info.properties.diagnosticLogs.backendResponse.dataMasking) ? ["true"] : []
        content {
          dynamic "headers" {
            for_each = can(each.value.info.properties.diagnosticLogs.backendResponse.dataMasking.headers) ? ["true"] : []
            content {
              mode  = each.value.info.properties.diagnosticLogs.backendResponse.dataMasking.headers.mode
              value = each.value.info.properties.diagnosticLogs.backendResponse.dataMasking.headers.value
            }
          }
          dynamic "query_params" {
            for_each = can(each.value.info.properties.diagnosticLogs.backendResponse.dataMasking.queryParams) ? ["true"] : []
            content {
              mode  = each.value.info.properties.diagnosticLogs.backendResponse.dataMasking.queryParams.mode
              value = each.value.info.properties.diagnosticLogs.backendResponse.dataMasking.queryParams.value
            }
          }
        }
      }
    }
  }

  ### If removed from JSON, set values to null
  dynamic "backend_request" {
    for_each = can(each.value.info.properties.diagnosticLogs.backendResponse) ? [] : ["false"]
    content {
      headers_to_log = null
      body_bytes     = null
    }
  }
}
