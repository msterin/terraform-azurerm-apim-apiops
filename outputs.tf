output "api" {
  value = {
    api_paths       = { for k, v in azurerm_api_management_api.main : k => v.path }
    apim_url        = data.azurerm_api_management.main.gateway_url
    apim_id         = data.azurerm_api_management.main.id
    apim_portal_url = data.azurerm_api_management.main.portal_url
  }
}

