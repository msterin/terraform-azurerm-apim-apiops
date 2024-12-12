# Azure API Management (APIM) APIOps Terraform module
APIM APIOps enables you to publish and manage your APIs via Azure API Management (APIM) using a GitOps approach. This involves conducting all publishing and configuration of the APIs via a git repository. Such operations are facilitated through configuration in JSON files, alongside the OpenAPI specification available in either JSON or YAML format.

API developers are not required to possess any knowledge about Terraform, as all configurations are executed through JSON files.

Based on Robert Brandsø work: [robertbrandso/terraform-azurerm-apim-apiops](https://github.com/robertbrandso/terraform-azurerm-apim-apiops). Adds support for API Operations, template expansion for XML policies, and more.

## Resources

* [Wiki](https://github.com/msterin/terraform-azurerm-apim-apiops/wiki)
* [Example configuration](https://github.com/msterin/terraform-azurerm-apim-apiops/tree/main/examples)
* [Terraform registry](https://registry.terraform.io/modules/msterin/apim-apiops)

## Flow

The diagram below illustrates the flow of APIM APIOps.

[![APIM APIOps flow](https://github.com/robertbrandso/terraform-azurerm-apim-apiops/wiki/images/apiops-flow.drawio.png)](https://github.com/robertbrandso/terraform-azurerm-apim-apiops/wiki/images/apiops-flow.drawio.png)
