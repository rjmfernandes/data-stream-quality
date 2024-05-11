# Create a Flink compute pool to execute a Flink SQL statement.
resource "confluent_flink_compute_pool" "my_compute_pool" {
  display_name = "${var.use_prefix}-pool"
  cloud        = var.cc_cloud_provider
  region       = var.cc_cloud_region
  max_cfu      = 10

  environment {
    id = confluent_environment.cc_handson_env.id
  }

  depends_on = [
    confluent_environment.cc_handson_env,
    confluent_role_binding.clients_cluster_admin
  ]
}

# Create a Flink-specific API key that will be used to submit statements.
data "confluent_flink_region" "my_flink_region" {
  cloud  = var.cc_cloud_provider
  region = var.cc_cloud_region
}

// https://docs.confluent.io/cloud/current/access-management/access-control/rbac/predefined-rbac-roles.html#flinkadmin

resource "confluent_role_binding" "app-manager-flink-admin" {
  principal   = "User:${confluent_service_account.app_manager.id}"
  role_name   = "FlinkAdmin"
  crn_pattern = confluent_environment.cc_handson_env.resource_name
}

resource "confluent_role_binding" "app-manager-flink-developer" {
  principal   = "User:${confluent_service_account.app_manager.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.cc_handson_env.resource_name
}

resource "confluent_role_binding" "app-general-flink-admin" {
  principal   = "User:${confluent_service_account.clients.id}"
  role_name   = "FlinkAdmin"
  crn_pattern = confluent_environment.cc_handson_env.resource_name
}

resource "confluent_role_binding" "app-general-flink-developer" {
  principal   = "User:${confluent_service_account.clients.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.cc_handson_env.resource_name
}

resource "confluent_role_binding" "app-general-environment-admin" {
  principal   = "User:${confluent_service_account.clients.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.cc_handson_env.resource_name
}


resource "confluent_role_binding" "app-manager-assigner" {
  principal   = "User:${confluent_service_account.app_manager.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.main.resource_name}/service-account=${confluent_service_account.clients.id}"
}


resource "confluent_api_key" "my_flink_api_key" {
  display_name = "my_flink_api_key"

  owner {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.my_flink_region.id
    api_version = data.confluent_flink_region.my_flink_region.api_version
    kind        = data.confluent_flink_region.my_flink_region.kind

    environment {
      id = confluent_environment.cc_handson_env.id
    }
  }

  depends_on = [
    confluent_environment.cc_handson_env,
    confluent_role_binding.clients_cluster_admin
  ]
}