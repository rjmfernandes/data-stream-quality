The initial terraform is based on: https://github.com/rjmfernandes/flink-cc-automated

# Intro 

Data Stream Quality here is understood as the quality of our Data Stream Processing. Different but can also be considered as going beyond just the Data Quality of our Steam Data (check https://github.com/tomasalmeida/confluent-data-contract for Data Quality discussion). 

Here we will validate the quality or health of our stream processing through specific dimensions data objects (topics/tables containing aggregates) associated with the original sources and by-products or results of our Stream Processing jobs. Typically through comparison between dimensions/aggregateds sitting before and after each corresponding stream processing. 

Our stream processing jobs here as an example are also implemented with Flink SQL (deployed automatically with our terraform) but keep in mind that they could just as well have been implemented using any other technology, including Kafka Streams for example. The basic idea in this example project is that the data objects being validated as source and results of our stream processing are both Kafka topics and that the validation would sit external to the process itself. In the example here we have implemented these validations with Confluent Cloud Flink SQL but again they could have used another data streaming technology using same philosophy.

# Setup

- User account on [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree)
- Local install of [Terraform](https://www.terraform.io) (details below)
- Local install of [jq](https://jqlang.github.io/jq/download) (details below)
- Local install Confluent CLI, [install the cli](https://docs.confluent.io/confluent-cli/current/install.html) 

```shell
echo "Enter a prefix value as 'rfernandes_':"
read prefix_value
confluent login
CC_API_KEY_SECRET=`confluent api-key create --resource cloud --description "API for terraform"`
CC_API_KEY=`echo "$CC_API_KEY_SECRET"| grep 'API Key'|sed s/'.*| '//g|sed s/' .*'//g`
CC_API_SECRET=`echo "$CC_API_KEY_SECRET"| grep 'API Secret'|sed s/'.*| '//g|sed s/' .*'//g`
cat > $PWD/terraform/terraform.tfvars <<EOF
confluent_cloud_api_key = "$CC_API_KEY"
confluent_cloud_api_secret = "$CC_API_SECRET"
use_prefix = "$prefix_value"
EOF
cd ./terraform
 terraform init -upgrade
terraform plan
terraform apply -auto-approve
cc_hands_env=`terraform output -json | jq -r .cc_hands_env.value`
cc_kafka_cluster=`terraform output -json | jq -r .cc_kafka_cluster.value`
cc_flink_pool=`terraform output -json | jq -r .FlinkComputePool.value`
cd ..
confluent environment use $cc_hands_env
confluent flink compute-pool use $cc_flink_pool
```

Please check whether the terraform execution went without errors.

# Flink SQL

Now you can check in Confluent Cloud UI all connectors have been deployed as well the Flink Compute Pool and the long running Flink SQL jobs. You can also execute the Flink Shell:

```shell
confluent flink shell --database $cc_kafka_cluster
```

You can list the tables;

```
SHOW TABLES;
```

And query the shoe_loyalty_levels for example:

```
SELECT * from shoe_loyalty_levels;
```

The shoe_promotions table will take a bit longer to get populated as enough orders are processed to some customers.

How many flink jobs are running?

```shell
confluent flink statement list --cloud aws --region eu-central-1 --status running
```

Check CFUs in use:

```shell
confluent flink compute-pool describe
```

# Data Stream Quality with Flink SQL

## Orders to Order_Customer

Now we start really implementing our Stream Data Quality validations.

Let's start by creating a table associated with the aggregates of our source topic `shoe_orders` (populated by a source connector):

```sql
CREATE TABLE dimensions_orders(
  order_window_start TIMESTAMP,
  order_window_end TIMESTAMP,
  customer_events BIGINT,
  product_events BIGINT,
  order_events BIGINT,
  PRIMARY KEY (order_window_start) NOT ENFORCED
  );
```

And after populating our dimensions table columns with our aggregateds from the source topic:

```sql
INSERT INTO dimensions_orders
    SELECT
    window_start,
    window_end,
    COUNT(distinct customer_id) AS customer_events,
    COUNT(distinct product_id) AS product_events,
    COUNT( order_id) as order_events
    FROM TABLE(
    TUMBLE(TABLE shoe_orders, DESCRIPTOR(`$rowtime`), INTERVAL '1' MINUTES))
    GROUP BY window_start,window_end;
```

We are creating aggregates per time windows so that when validating we can have information about the time periods things can be going wrong.

Next we create another dimension data point after the first join of orders with customers topic:

```sql
CREATE TABLE dimensions_order_customer(
  order_window_start TIMESTAMP,
  order_window_end TIMESTAMP,
  customer_events BIGINT,
  product_events BIGINT,
  order_events BIGINT,
  PRIMARY KEY (order_window_start) NOT ENFORCED
  );
```

And again as before, populate from the sink topic of our first stream job process:

```sql
INSERT INTO dimensions_order_customer
    SELECT
    window_start,
    window_end,
    COUNT(distinct customer_id) AS customer_events,
    COUNT(distinct product_id) AS product_events,
    COUNT( order_id) as order_events
    FROM TABLE(
    TUMBLE(TABLE shoe_order_customer, DESCRIPTOR(ts), INTERVAL '1' MINUTES))
    GROUP BY window_start,window_end;
```

We can start checking for any discrepancies by executing:

```sql
select dimensions_orders.order_window_start,dimensions_orders.order_window_end, 
dimensions_orders.customer_events as o_customers,dimensions_order_customer.customer_events as oc_customers,
dimensions_orders.product_events as o_products,dimensions_order_customer.product_events as oc_products,
dimensions_orders.order_events as o_orders,dimensions_order_customer.order_events as oc_orders
from dimensions_orders INNER JOIN dimensions_order_customer ON dimensions_orders.order_window_start = dimensions_order_customer.order_window_start
WHERE dimensions_orders.customer_events <> dimensions_order_customer.customer_events
OR dimensions_orders.product_events <> dimensions_order_customer.product_events
OR dimensions_orders.order_events <> dimensions_order_customer.order_events;
````

- We are comparing here each dimension between both dimension tables and checking if any are not exactly equal. 
- You could also be populating another topic with those results and maybe have notification alerts associated with new entries corresponding to detected discrepancies. 
- In some cases any discrepancy will have meaning (as here) and will require investigation, while in other use cases you may just be interested in big discrepancies maybe filtered with percentages, etc.

## Order_Customer to Order_Customer_Product

Again we create another dimension after the second join streaming process:

```sql
CREATE TABLE dimensions_order_customer_product(
  order_window_start TIMESTAMP,
  order_window_end TIMESTAMP,
  customer_events BIGINT,
  product_events BIGINT,
  order_events BIGINT,
  PRIMARY KEY (order_window_start) NOT ENFORCED
  );
```

And populate:

```sql
INSERT INTO dimensions_order_customer_product
    SELECT
    window_start,
    window_end,
    COUNT(distinct customer_id) AS customer_events,
    COUNT(distinct product_id) AS product_events,
    COUNT( order_id) as order_events
    FROM TABLE(
    TUMBLE(TABLE shoe_order_customer_product, DESCRIPTOR(ts), INTERVAL '1' MINUTES))
    GROUP BY window_start,window_end;
```

We can now again check for discrepancies with dimensions topic/table before:

```sql
select dimensions_order_customer.order_window_start,dimensions_order_customer.order_window_end, 
dimensions_order_customer.customer_events as oc_customers,dimensions_order_customer_product.customer_events as ocp_customers,
dimensions_order_customer.product_events as oc_products,dimensions_order_customer_product.product_events as ocp_products,
dimensions_order_customer.order_events as oc_orders,dimensions_order_customer_product.order_events as ocp_orders
from dimensions_order_customer INNER JOIN dimensions_order_customer_product ON dimensions_order_customer.order_window_start = dimensions_order_customer_product.order_window_start
WHERE dimensions_order_customer.customer_events <> dimensions_order_customer_product.customer_events
OR dimensions_order_customer.product_events <> dimensions_order_customer_product.product_events
OR dimensions_order_customer.order_events <> dimensions_order_customer_product.order_events;
```

- It's pretty much the same as before and you may have noticed that we are comparing so far always consecutive points but technically there is no reason why you could not compare with further apart points in the streaming process chain. 
- As long as the dimension points share really comparable aggregateds. You need to know something about what your streaming jobs do to data to understand what aggregates you can build and to which extent they are comparable with other dimensions aggregated elsewhere in your streaming processes jobs chain.
- It's in general a good practice though, to have the comparison between points as consecutive as possible, in order that if a problem is found we can understand where most likely is happening and with which streaming processes is associated.

## Order_Customer_Product and Loyalty_Level

Our final dimension table:

```sql
CREATE TABLE dimensions_loyalty_level(
  order_window_start TIMESTAMP,
  order_window_end TIMESTAMP,
  customer_events BIGINT,
  PRIMARY KEY (order_window_start) NOT ENFORCED
  );
```

Populated by:

```sql
INSERT INTO dimensions_loyalty_level
    SELECT
    window_start,
    window_end,
    COUNT(distinct customer_id) AS customer_events
    FROM TABLE(
    TUMBLE(TABLE shoe_loyalty_levels, DESCRIPTOR(ts), INTERVAL '1' MINUTES))
    GROUP BY window_start,window_end;
```

- This query is simpler than the previous dimension tables populating queries cause in `shoe_loyalty_levels` topic we miss part of the extra information (products and orders) by the definition of the data in that topic is only associated with customers.

Now for comparing with point immediately before:

```sql

select dimensions_order_customer_product.order_window_start,dimensions_order_customer_product.order_window_end, 
dimensions_order_customer_product.customer_events as ocp_customers,dimensions_loyalty_level.customer_events as ll_customers
from dimensions_order_customer_product INNER JOIN dimensions_loyalty_level ON dimensions_order_customer_product.order_window_start = dimensions_loyalty_level.order_window_start
WHERE dimensions_order_customer_product.customer_events <> dimensions_loyalty_level.customer_events;
```

## Note on Promotions Topic

There is another final topic resulting from the terraform deployed Flink SQL jobs which is `shoe_promotions`. This topic is the result of a rather obscuring streaming logic (from the point of view of its result not sharing many common points with the entry data). For reference we share here:

```sql
EXECUTE STATEMENT 
SET 
  BEGIN INSERT INTO shoe_promotions 
SELECT 
  email, 
  'next_free' AS promotion_name 
FROM 
  shoe_order_customer_product 
WHERE 
  brand = 'Jones-Stokes' 
GROUP BY 
  email 
HAVING 
  COUNT(*) % 10 = 0;
INSERT INTO shoe_promotions 
SELECT 
  email, 
  'bundle_offer' AS promotion_name 
FROM 
  shoe_order_customer_product 
WHERE 
  brand IN ('Braun-Bruen', 'Will Inc') 
GROUP BY 
  email 
HAVING 
  COUNT(DISTINCT brand) = 2 
  AND COUNT(brand) > 10;
END;
```

- In such cases it becomes pratically impossible to validate against other dimension points the result of the streaming job, and whatever validation needed has most likely to be part of the streaming job implementation itself.

## Create Problems

Generate some issues to show up on your check discrepancies query... 
- A good way is just by stopping some of the insert Flink SQL queries and restarting them. 
- And/or stopping your connectors and restarting after. 
- You may even try to delete a topic completely and after creating it again, with corresponding restart of process for populating the topic, just as any other processes that were reading from that topic and would have been affected.

# Important Notes about the Terraform Flink SQL Jobs Changes

In here we have changed (in some cases quite considerably) the original Flink SQL jobs deployed by the original project. The reason is that for the validating a streaming job we need to know what our stream job is doing to data at each time. The original project relied (maybe too much?) on primary key based tables that would make impossible to know what the streaming job is doing to data at each point in time.

This is an important point to remember: *If you want to be able to validate what you do, do it in a way that allows the validation after.*

It's also good to remember the original project purpose was an introduction to Flink SQL and intentionally tried to keep some things simpler. What basically doesnt work that well for us when we want to have streaming processes possible to be validated as here.

Here we list those changes considering their relevance. Also from the point of view of reference of building streaming jobs in Flink SQL that allows us to keep data events history and later validation.

## Order_Customer Table

The original creation of the `shoe_order_customer` table was the following:

```sql
CREATE TABLE shoe_order_customer(
  order_id INT, product_id STRING, first_name STRING, 
  last_name STRING, email STRING
) WITH (
  'changelog.mode' = 'retract', 'kafka.partitions' = '1'
);
```

We have changed to:

```sql
CREATE TABLE shoe_order_customer(
  order_id INT, 
  product_id STRING, 
  customer_id STRING, 
  first_name STRING, 
  last_name STRING, 
  email STRING, 
  ts TIMESTAMP(3) WITH LOCAL TIME ZONE NOT NULL, 
  WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
  'changelog.mode' = 'append', 'kafka.partitions' = '1'
);
```

There are some relevant changes:
-  We store the customer_id cause we want to be able to have this as aggregated dimension for later comparison between points (remember the customer data itself mauy change but not its id...).
- We use as watermark a table field (in general this strategy corresponds to use an event time for watermark although not exactly here as we will see)
- We don't use retract as changelog.mode. We want the events of our streaming jobs not to overwrite each other so we can always have them available for building our aggregates to compare with same periods of time in other parts of our streaming job chain. We are adding here a 5 second as example for the time allowed to wait for late out of order events. 

The original populating query of the table was:

```sql
INSERT INTO shoe_order_customer (
  order_id, product_id, first_name, 
  last_name, email
) 
SELECT 
  order_id, 
  product_id, 
  first_name, 
  last_name, 
  email 
FROM 
  shoe_orders 
  INNER JOIN shoe_customers_keyed ON shoe_orders.customer_id = shoe_customers_keyed.customer_id;
```

We changed to:

```sql
INSERT INTO shoe_order_customer 
SELECT 
  order_id, 
  product_id, 
  shoe_orders.customer_id, 
  first_name, 
  last_name, 
  email, 
  shoe_orders.`$rowtime` 
FROM 
  shoe_orders 
  INNER JOIN shoe_customers_keyed 
    FOR SYSTEM_TIME AS OF shoe_orders.`$rowtime` 
    ON shoe_orders.customer_id = shoe_customers_keyed.customer_id;
```

As you see the major changes are:
- We are in fact using the `$rowtime`for the "event time" ts field. The reason for not using the original order's `ts` field is that those come with an uncontextualized long past date (2021) that would make very hard for us to understand what is going on in a demo as here (also in general real time streaming is about events happening now and not 3 years ago). But is also true that this way we are maybe bypassing in these tests some issues that may be related with out of order late events. In any case we setup our tables to allow in general 5 seconds for that.
- We are also using temporary joins (the `FOR SYSTEM_TIME AS OF` part) considering we dont use any longer a retracted table.

## Order_Customer_Product table

The original creation of the `shoe_order_customer_product` table was the following:

```sql
CREATE TABLE shoe_order_customer_product(
  order_id INT, first_name STRING, last_name STRING, 
  email STRING, brand STRING, `model` STRING, 
  sale_price INT, rating DOUBLE
) WITH (
  'changelog.mode' = 'retract', 'kafka.partitions' = '1'
);
```

We changed to:

```sql
CREATE TABLE shoe_order_customer_product(
  order_id INT, 
  product_id STRING, 
  customer_id STRING, 
  first_name STRING, 
  last_name STRING, 
  email STRING, 
  brand STRING, 
  `model` STRING, 
  sale_price INT, 
  rating DOUBLE, 
  ts TIMESTAMP(3), 
  WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
  'changelog.mode' = 'append', 'kafka.partitions' = '1'
);
```

- Again we keep product_id (as we did for customer_id) considering dimension keys to be used for validation purposes later.
- And as before we are defining a table field timestamp for watermark (it will basically inherit the value from table before as event time).
- And again we are using `append` for `changelog.mode` for the same reasons as before.

The query to populate the table before:

```sql
INSERT INTO shoe_order_customer_product (
  order_id, first_name, last_name, email, 
  brand, `model`, sale_price, rating
) 
SELECT 
  order_id, 
  first_name, 
  last_name, 
  email, 
  brand, 
  `model`, 
  sale_price, 
  rating 
FROM 
  shoe_order_customer 
  INNER JOIN shoe_products_keyed ON shoe_order_customer.product_id = shoe_products_keyed.product_id;
```

Has been changed to:

```sql
INSERT INTO shoe_order_customer_product 
SELECT 
  order_id, 
  shoe_order_customer.product_id, 
  shoe_order_customer.customer_id, 
  first_name, 
  last_name, 
  email, 
  brand, 
  `model`, 
  sale_price, 
  rating, 
  ts 
FROM 
  shoe_order_customer 
  INNER JOIN shoe_products_keyed FOR SYSTEM_TIME AS OF shoe_order_customer.ts 
  ON shoe_order_customer.product_id = shoe_products_keyed.product_id;
```

Again for the same reasons as before.

## Loyalty_Levels Table

Before we had:

```sql
CREATE TABLE shoe_loyalty_levels(
  email STRING, 
  total BIGINT, 
  rewards_level STRING, 
  PRIMARY KEY (email) NOT ENFORCED
) WITH ('kafka.partitions' = '1');
```

And now we have:

```sql
CREATE TABLE shoe_loyalty_levels(
  customer_id STRING, 
  total BIGINT, 
  rewards_level STRING, 
  ts TIMESTAMP(3) WITH LOCAL TIME ZONE NOT NULL, 
  WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
  'changelog.mode' = 'append', 'kafka.partitions' = '1'
);

```

- Although we loose the products and order information by the nature of this stream process and resulting data, we want to keep at least the customer_id for the validation purposes. We don't consider the email relevant since the customer may change its email (and for the sake of the loyalty level calculation in fact we should probably ignore it).
- Again we want to have the historical information so we keep the "event time" as field again to be able to validate.
- Same reason as usual on why we change to append changelog.mode.
- And of course no primary keys since we want the historical information in fact for being able to validate. (Having the history of events is by the way one of the nice reasons to use a streaming process in place of just standard databases.)

Finally the population query in this case was originally:

```sql
INSERT INTO shoe_loyalty_levels(email, total, rewards_level) 
SELECT 
  email, 
  SUM(sale_price) AS total, 
  CASE WHEN SUM(sale_price) > 80000000 THEN 'GOLD' WHEN SUM(sale_price) > 7000000 
  THEN 'SILVER' WHEN SUM(sale_price) > 600000 THEN 'BRONZE' ELSE 'CLIMBING' END AS rewards_level 
FROM 
  shoe_order_customer_product 
GROUP BY 
  email;
```

Changed now to:

```sql
INSERT INTO shoe_loyalty_levels 
SELECT 
  customer_id, 
  total, 
  CASE WHEN total > 80000000 THEN 'GOLD' WHEN total > 7000000 
  THEN 'SILVER' WHEN total > 600000 THEN 'BRONZE' ELSE 'CLIMBING' END AS rewards_level, 
  ts 
FROM 
  (
    SELECT 
      customer_id, 
      SUM(sale_price) OVER (
        PARTITION BY customer_id 
        ORDER BY 
          ts RANGE BETWEEN INTERVAL '1' DAY PRECEDING 
          AND CURRENT ROW
      ) AS total, 
      ts 
    FROM 
      shoe_order_customer_product
  );
```

- Cause we want to have the partial aggregations history for every new incoming event we use the `OVER ... RANGE` part. We use 1 day as aggregation period here cause first "this is a demo", second (and for the same reason) for keeping everything simple and small we are using the default retention period of 7 days only, also Flink in CC does not allow (yet) for time units longer than `DAY`. We could have used something 365 days though and probably would have been more reallistic or not... These longer periods of times based aggregations may make sense to be first consolidated externally to Kafka.
- We have made it into an overlapped query just for clarity reasons. So that total is calculated once and then after translated also into a `rewards_level`. Its not clear if doing this way could also have some performance benefits for the query itself. Our guess is that Flink would be anyway smart enough to understand it had calculated the sum already but doing this way also has the benefit of potentially making the query more readable... Although that is most certainly debatable.

# Costs of this Confluent Cloud

The lab execution does not consume much money but you should count to be more than the one for the original project due to the new validations queries associated with the new dimension tables/topics and the comparison queries between points. If you create the cluster one day before, we recommend to pause all connectors.

# Destroy the infrastructure

```bash
cd terraform
terraform destroy -auto-approve
cd ..
```

There could be a conflict destroying everything with our Tags. In this case destroy again via terraform.