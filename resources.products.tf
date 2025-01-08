# --------
# PRODUCTS
# --------
locals {
  # Path where the product files are located
  products_path = "${var.artifacts_path}/products"

  # Name of the files holding the information and policy
  product_information_file = var.product_information_filename
  product_policy_file      = var.product_policy_filename

  # Produce an array of existing file names, e.g. ["apis/SDL_apiops/operations/DigitalTwins_Update/policy.xml"]
  all_product_info_files_names   = fileset(".", "${local.products_path}/*/${local.product_information_file}")
  all_product_policy_files_names = fileset(".", "${local.products_path}/*/${local.product_policy_file}")

  # A map of product_name => { properties=<info object, decoded from json file> }
  products_map = {
    for path in local.all_product_info_files_names :
    basename(dirname(path)) => {
      product_name = basename(dirname(path))
      properties   = jsondecode(templatefile(path, var.template_variables)).properties
    }
  }

  # A map of product_name => { xml_content=<policy content after tempalate processing> }
  product_policies_map = {
    for path in local.all_product_policy_files_names :
    basename(dirname(path)) => {
      product_name = basename(dirname(path))
      xml_content  = templatefile(path, var.template_variables)
    }
  }

  # helpers to help build api, tag and group maps
  # ---------------------------------------------
  #   lists of {product, api ,  {product, tag} and {product, group} pairs.
  product_api_pairs = flatten([for product, product_info in local.products_map : [
    for api in try(product_info.properties.apis, []) : {
      product = product
      api     = api
    }
  ]])

  product_tag_pairs = flatten([for product, product_info in local.products_map : [
    for tag in try(product_info.properties.tags, []) : {
      product = product
      tag     = tag
    }
  ]])

  product_group_pairs = flatten([for product, product_info in local.products_map : [
    for group in try(product_info.properties.groups, []) : {
      product = product
      group   = group
    }
  ]])



  # maps to be used in nested resources (i.e groups/tags/apis) creation
  #-------------------------------------------------------------------

  # A map of productName.ApiName => { product_name, api_name}
  product_apis_map = { for pair in local.product_api_pairs :
    "${pair.product}.${pair.api}" => {
      product_name = pair.product
      api_name     = pair.api
    }
  }

  # A map of productName.TagName => { product_name, tag_name}
  product_tags_map = { for pair in local.product_tag_pairs :
    "${pair.product}.${pair.tag}" => {
      product_name = pair.product
      tag_name     = pair.tag
    }
  }

  # A map of productName.GroupName => { product_name, group_name}
  product_groups_map = { for pair in local.product_group_pairs :
    "${pair.product}.${pair.group}" => {
      product_name = pair.product
      group_name   = pair.group
    }
  }

}

# Create product
resource "azurerm_api_management_product" "main" {
  for_each = local.products_map

  product_id          = each.key
  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  display_name = each.value.properties.displayName
  description  = try(each.value.properties.description, null)
  published    = each.value.properties.published
  terms        = try(each.value.properties.terms, null)

  subscription_required = each.value.properties.subscriptionRequired
  approval_required     = each.value.properties.approvalRequired
  subscriptions_limit   = try(each.value.properties.subscriptionsLimit, null)
}

# Add API(s) to product
resource "azurerm_api_management_product_api" "main" {
  for_each = local.product_apis_map

  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  product_id = azurerm_api_management_product.main[each.value.product_name].product_id # get id and force dependency on product resource
  api_name   = azurerm_api_management_api.main[each.value.api_name].name               # instead of using api_name directly, force dependency on api resource
}

# Add group(s) to product
resource "azurerm_api_management_product_group" "main" {
  # Create set with "<product name>/<api name>". In this way we can then itterate over all groups for each product
  for_each = local.product_groups_map

  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  product_id = azurerm_api_management_product.main[each.value.product_name].product_id # get id and force dependency on product resource

  # A group may be both an Azure AD group, a local group and an already existing built-in group in APIM so we just pass the name, and not fetching it from an existing resource.
  # Also, we need to run the same lower and replace as done in azurerm_api_management_group.aad and azurerm_api_management_group.local, since group names may only contain alphanumeric characters, underscores and dashes up to 80 characters in length.
  group_name = lower(replace(regex("[^/]+$", each.value.group_name), "/[ .]/", "-"))

  # Groups needs to be created at APIM scope before assigned to product
  depends_on = [
    azurerm_api_management_group.aad,
    azurerm_api_management_group.local
  ]
}

# Assign tag(s) to Product
resource "azurerm_api_management_product_tag" "main" {
  # Create set with "<product name>/<tag name>". In this way we can then iterate over all tags for each product
  for_each = local.product_tags_map

  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  api_management_product_id = azurerm_api_management_product.main[each.value.product_name].product_id # get id and force dependency on product resource
  name                      = azurerm_api_management_tag.main[each.value.tag_name].name
}

# Create Product policy
resource "azurerm_api_management_product_policy" "main" {
  # Only create if policy file and product information file exists.
  for_each = local.product_policies_map

  api_management_name = data.azurerm_api_management.main.name
  resource_group_name = data.azurerm_api_management.main.resource_group_name

  product_id  = azurerm_api_management_product.main[each.key].product_id
  xml_content = each.value.xml_content
}
