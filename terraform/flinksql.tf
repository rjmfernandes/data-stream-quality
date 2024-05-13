# --------------------------------------------------------
# Flink SQL: CREATE TABLE shoe_customers_keyed
# --------------------------------------------------------
resource "confluent_flink_statement" "create_shoe_customers_keyed" {
  depends_on = [
        resource.confluent_environment.cc_handson_env,
        resource.confluent_schema_registry_cluster.cc_sr_cluster,
        resource.confluent_kafka_cluster.cc_kafka_cluster,
        resource.confluent_connector.datagen_products,
        resource.confluent_connector.datagen_customers,
        resource.confluent_connector.datagen_orders,
        resource.confluent_flink_compute_pool.my_compute_pool,
        resource.confluent_role_binding.app-general-environment-admin
  ]   

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
   properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  statement  = "CREATE TABLE shoe_customers_keyed(customer_id STRING,first_name STRING,last_name STRING,email STRING,PRIMARY KEY (customer_id) NOT ENFORCED) WITH ('kafka.partitions' = '1');"
 
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}


# --------------------------------------------------------
# Flink SQL: CREATE TABLE shoe_products_keyed
# --------------------------------------------------------
resource "confluent_flink_statement" "create_shoe_products_keyed" {
  depends_on = [
    resource.confluent_environment.cc_handson_env,
    resource.confluent_schema_registry_cluster.cc_sr_cluster,
    resource.confluent_kafka_cluster.cc_kafka_cluster,
    resource.confluent_connector.datagen_products,
    resource.confluent_connector.datagen_customers,
    resource.confluent_connector.datagen_orders,
    resource.confluent_flink_compute_pool.my_compute_pool,
    resource.confluent_role_binding.app-general-environment-admin
  ]   

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "CREATE TABLE shoe_products_keyed(product_id STRING,brand STRING,`model` STRING,sale_price INT,rating DOUBLE,PRIMARY KEY (product_id) NOT ENFORCED) WITH ('kafka.partitions' = '1');"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: INSERT INTO shoe_customers_keyed
# --------------------------------------------------------
resource "confluent_flink_statement" "insert_shoe_customers_keyed" {
  depends_on = [
    resource.confluent_flink_statement.create_shoe_customers_keyed
  ]  

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "INSERT INTO shoe_customers_keyed SELECT id, first_name, last_name, email FROM shoe_customers;"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: INSERT INTO shoe_products_keyed 
# --------------------------------------------------------
resource "confluent_flink_statement" "insert_shoe_products_keyed" {
  depends_on = [
    resource.confluent_flink_statement.create_shoe_products_keyed
  ]    

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "INSERT INTO shoe_products_keyed SELECT id, brand, name, sale_price, rating FROM shoe_products;"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: CREATE TABLE shoe_order_customer
# --------------------------------------------------------
resource "confluent_flink_statement" "create_shoe_order_customer" {
  depends_on = [
    resource.confluent_environment.cc_handson_env,
    resource.confluent_schema_registry_cluster.cc_sr_cluster,
    resource.confluent_kafka_cluster.cc_kafka_cluster,
    resource.confluent_connector.datagen_products,
    resource.confluent_connector.datagen_customers,
    resource.confluent_connector.datagen_orders,
    resource.confluent_flink_compute_pool.my_compute_pool,
    resource.confluent_role_binding.app-general-environment-admin,
    resource.confluent_flink_statement.create_shoe_products_keyed,
    resource.confluent_flink_statement.create_shoe_customers_keyed
  ]   

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "CREATE TABLE shoe_order_customer(order_id INT,product_id STRING,customer_id STRING,first_name STRING,last_name STRING,email STRING,ts TIMESTAMP(3) WITH LOCAL TIME ZONE NOT NULL,WATERMARK FOR ts AS ts - INTERVAL '5' SECOND) WITH ('changelog.mode' = 'append','kafka.partitions' = '1');"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: INSERT INTO shoe_order_customer
# --------------------------------------------------------
resource "confluent_flink_statement" "insert_shoe_order_customer" {
  depends_on = [
    resource.confluent_flink_statement.create_shoe_order_customer
  ]  

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "INSERT INTO shoe_order_customer SELECT order_id,product_id,shoe_orders.customer_id,first_name,last_name,email,shoe_orders.`$rowtime` FROM shoe_orders INNER JOIN shoe_customers_keyed FOR SYSTEM_TIME AS OF shoe_orders.`$rowtime` ON shoe_orders.customer_id = shoe_customers_keyed.customer_id;"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: CREATE TABLE shoe_order_customer_product
# --------------------------------------------------------
resource "confluent_flink_statement" "create_shoe_order_customer_product" {
  depends_on = [
    resource.confluent_environment.cc_handson_env,
    resource.confluent_schema_registry_cluster.cc_sr_cluster,
    resource.confluent_kafka_cluster.cc_kafka_cluster,
    resource.confluent_connector.datagen_products,
    resource.confluent_connector.datagen_customers,
    resource.confluent_connector.datagen_orders,
    resource.confluent_flink_compute_pool.my_compute_pool,
    resource.confluent_role_binding.app-general-environment-admin,
    resource.confluent_flink_statement.create_shoe_products_keyed,
    resource.confluent_flink_statement.create_shoe_customers_keyed,
    resource.confluent_flink_statement.create_shoe_order_customer
  ]   

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "CREATE TABLE shoe_order_customer_product(order_id INT,product_id STRING,customer_id STRING,first_name STRING,last_name STRING,email STRING,brand STRING,`model` STRING,sale_price INT,rating DOUBLE,ts TIMESTAMP(3),WATERMARK FOR ts AS ts - INTERVAL '5' SECOND) WITH ('changelog.mode' = 'append', 'kafka.partitions' = '1');"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: INSERT INTO shoe_order_customer_product
# --------------------------------------------------------
resource "confluent_flink_statement" "insert_shoe_order_customer_product" {
  depends_on = [
    resource.confluent_flink_statement.create_shoe_order_customer_product
  ]  

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "INSERT INTO shoe_order_customer_product SELECT order_id,shoe_order_customer.product_id,shoe_order_customer.customer_id,first_name,last_name,email,brand,`model`,sale_price,rating,ts FROM shoe_order_customer INNER JOIN shoe_products_keyed FOR SYSTEM_TIME AS OF shoe_order_customer.ts ON shoe_order_customer.product_id = shoe_products_keyed.product_id;"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: CREATE TABLE shoe_loyalty_levels
# --------------------------------------------------------
resource "confluent_flink_statement" "create_shoe_loyalty_levels" {
  depends_on = [
    resource.confluent_environment.cc_handson_env,
    resource.confluent_schema_registry_cluster.cc_sr_cluster,
    resource.confluent_kafka_cluster.cc_kafka_cluster,
    resource.confluent_connector.datagen_products,
    resource.confluent_connector.datagen_customers,
    resource.confluent_connector.datagen_orders,
    resource.confluent_flink_compute_pool.my_compute_pool,
    resource.confluent_role_binding.app-general-environment-admin,
    resource.confluent_flink_statement.create_shoe_products_keyed,
    resource.confluent_flink_statement.create_shoe_customers_keyed,
    resource.confluent_flink_statement.create_shoe_order_customer,
    resource.confluent_flink_statement.create_shoe_order_customer_product
  ]    

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "CREATE TABLE shoe_loyalty_levels(customer_id STRING,total BIGINT,rewards_level STRING,ts TIMESTAMP(3) WITH LOCAL TIME ZONE NOT NULL,WATERMARK FOR ts AS ts - INTERVAL '5' SECOND) WITH ('changelog.mode' = 'append','kafka.partitions' = '1');"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: INSERT INTO shoe_loyalty_levels
# --------------------------------------------------------
resource "confluent_flink_statement" "insert_shoe_loyalty_levels" {
  depends_on = [
    resource.confluent_flink_statement.create_shoe_loyalty_levels
  ]   

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "INSERT INTO shoe_loyalty_levels SELECT customer_id, total, CASE WHEN total > 80000000 THEN 'GOLD' WHEN total > 7000000 THEN 'SILVER' WHEN total > 600000 THEN 'BRONZE' ELSE 'CLIMBING' END AS rewards_level,ts FROM(SELECT customer_id,SUM(sale_price) OVER (PARTITION BY customer_id ORDER BY ts RANGE BETWEEN INTERVAL '1' DAY PRECEDING AND CURRENT ROW) AS total, ts FROM shoe_order_customer_product);"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: CREATE TABLE shoe_promotions
# --------------------------------------------------------
resource "confluent_flink_statement" "create_shoe_promotions" {
  depends_on = [
   resource.confluent_environment.cc_handson_env,
    resource.confluent_schema_registry_cluster.cc_sr_cluster,
    resource.confluent_kafka_cluster.cc_kafka_cluster,
    resource.confluent_connector.datagen_products,
    resource.confluent_connector.datagen_customers,
    resource.confluent_connector.datagen_orders,
    resource.confluent_flink_compute_pool.my_compute_pool,
    resource.confluent_role_binding.app-general-environment-admin,
    resource.confluent_flink_statement.create_shoe_products_keyed,
    resource.confluent_flink_statement.create_shoe_customers_keyed,
    resource.confluent_flink_statement.create_shoe_order_customer,
    resource.confluent_flink_statement.create_shoe_order_customer_product,
    resource.confluent_flink_statement.create_shoe_loyalty_levels
  ] 

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "CREATE TABLE shoe_promotions(email STRING,promotion_name STRING,PRIMARY KEY (email) NOT ENFORCED) WITH ('kafka.partitions' = '1');"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Flink SQL: Insert into shoe_promotions
# --------------------------------------------------------
resource "confluent_flink_statement" "insert_shoe_promotion" {
  depends_on = [
    resource.confluent_flink_statement.create_shoe_promotions
  ]   

  organization {
    id = data.confluent_organization.main.id
  }

   environment {
    id = confluent_environment.cc_handson_env.id
  } 
  compute_pool {
    id = confluent_flink_compute_pool.my_compute_pool.id
  }
  principal {
    id = confluent_service_account.clients.id
  }
  statement  = "EXECUTE STATEMENT SET BEGIN INSERT INTO shoe_promotions SELECT email, 'next_free' AS promotion_name FROM shoe_order_customer_product WHERE brand = 'Jones-Stokes' GROUP BY email HAVING COUNT(*) % 10 = 0; INSERT INTO shoe_promotions SELECT  email, 'bundle_offer' AS promotion_name FROM shoe_order_customer_product WHERE brand IN ('Braun-Bruen', 'Will Inc') GROUP BY email HAVING COUNT(DISTINCT brand) = 2 AND COUNT(brand) > 10; END;"
  properties = {
    "sql.current-catalog"  : confluent_environment.cc_handson_env.display_name
    "sql.current-database" : confluent_kafka_cluster.cc_kafka_cluster.display_name
  }
  rest_endpoint   =  data.confluent_flink_region.my_flink_region.rest_endpoint
  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
