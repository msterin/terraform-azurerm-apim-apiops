# ---------
# VARIABLES
# ---------

# Basics
variable "artifacts_path" {
  description = "(Required) Artifacts folder path. Path should be relative to your root module path."
  type        = string
  default     = "artifacts"
}

variable "allow_api_without_path" {
  description = "(Optional) Set to 'true' if you want it to be possible to publish API without path / API URL suffix."
  type        = bool
  default     = false
}

# API Management
variable "api_management_name" {
  description = "(Required) The name of the API Management Service."
  type        = string
}

variable "api_management_resource_group_name" {
  description = "(Required) The name of the Resource Group in which the API Management Service exists."
  type        = string
}

# Application Insights
## Only needed if diagnostic logs are configured on an API
variable "application_insights_name" {
  description = "(Optional) The name of the Application Insights component used for diagnostic logs."
  type        = string
  default     = null
}

variable "application_insights_resource_group_name" {
  description = "(Optional) The name of the Resource Group in which the Application Insights component exists."
  type        = string
  default     = null
}

variable "application_insights_logger_name" {
  description = "(Optional) The logger name to use for diagnostic logs. Needs to be unique per module call. If not passed, a random hash will be used."
  type        = string
  default     = null
}

# Filenames

## apiVersionSets
variable "api_version_set_information_filename" {
  description = "(Optional) Filename for the API Version Set configuration file."
  type        = string
  default     = "apiVersionSetInformation.json"
}

## apis
variable "api_information_filename" {
  description = "(Optional) Filename for the API configuration file."
  type        = string
  default     = "apiInformation.json"
}

variable "api_specification_filename" {
  description = "(Optional) Filename for the API specification JSON or YAML file."
  type        = string
  default     = "specification.json"

  validation {
    condition     = endswith(var.api_specification_filename, ".json") || endswith(var.api_specification_filename, ".yaml")
    error_message = "The api_specification_filename must end with either .json or .yaml"
  }
}

variable "api_policy_filename" {
  description = "(Optional) Filename for the API policy XML file."
  type        = string
  default     = "policy.xml"
}

## api operations
## note - we reuse API policy file name for operation policy file name
variable "api_operation_filename" {
  description = "(Optional) Filename for the API operation configuration file."
  type        = string
  default     = "operationInformation.json"
}


## backends
variable "backend_information_filename" {
  description = "(Optional) Filename for the backend configuration file."
  type        = string
  default     = "backendInformation.json"
}

## certificates
variable "certificates_information_filename" {
  description = "(Optional) Filename for the certificates configuration file."
  type        = string
  default     = "certificatesInformation.json"
}

## gateways
variable "gateway_information_filename" {
  description = "(Optional) Filename for the gateway configuration file."
  type        = string
  default     = "gatewayInformation.json"
}

## groups
variable "groups_information_filename" {
  description = "(Optional) Filename for the groups configuration file."
  type        = string
  default     = "groupsInformation.json"
}

## named-values
variable "named_value_information_filename" {
  description = "(Optional) Filename for the named value configuration file."
  type        = string
  default     = "namedValueInformation.json"
}

## policy fragments
variable "policy_fragment_information_filename" {
  description = "(Optional) Filename for the policy fragment configuration file."
  type        = string
  default     = "policyFragmentInformation.json"
}
variable "policy_fragment_content_filename" {
  description = "(Optional) Filename for the policy fragment XML content file."
  type        = string
  default     = "policy-fragment.xml"
}


## products
variable "product_information_filename" {
  description = "(Optional) Filename for the product configuration file."
  type        = string
  default     = "productInformation.json"
}

variable "product_policy_filename" {
  description = "(Optional) Filename for the product policy file."
  type        = string
  default     = "policy.xml"
}

## tags
variable "tags_information_filename" {
  description = "(Optional) Filename for the tags configuration file."
  type        = string
  default     = "tagsInformation.json"
}

## template expansion.
# Note: only those files that we use at the moment are handled as tempates. The rest is TBD to replace file() with templatefile() when needed.
variable "template_variables" {
  description = "(Optional) A Map of variables to be passed to template expansion. All XML and JSON files are templates. See terraform 'templatefile' for details."
  type        = map(any)
  default     = {}
}

