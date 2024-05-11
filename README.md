For details check: https://github.com/rjmfernandes/flink

Automated for deploying the compute pool and all long running Flink SQL jobs.

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

# Costs of this Confluent Cloud

The lab execution does not consume much money. We calculated an amount of less than 10$ for a couple of hours of testing. If you create the cluster one day before, we recommend to pause all connectors.

# Destroy the hands.on infrastructure

```bash
cd terraform
terraform destroy -auto-approve
cd ..
```

There could be a conflict destroying everything with our Tags. In this case destroy again via terraform.