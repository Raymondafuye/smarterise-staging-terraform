# Scripts

The scripts located in this directory are designed to easily scale down infrastructure and scale it back up, whilst also re-hydrating the database with new data as everything is scaled back up.

It is advised to not run terraform in between disable.py and enable.py (and not running the GitHub Actions Workflows which apply terraform)

## Installing AWS CLI
Note that you will need to have the AWS CLI installed on your system to use these scripts. You can find instructions on how to install the CLI for your specific OS here:

https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html


## Docker
To check that you have docker installed, run:
```bash
docker --version
```
if you have docker installed, this should return the version of docker that you have installed. E.g (Docker version 20.10.23)

If you do not have docker installed, please see https://docs.docker.com/get-docker/ and install docker
### Building or Pulling the image

To run docker container, you can either pull the image from ECR or build the docker image from the scripts directory.

#### Pulling from ECR

##### Retrieve an authentication token and authenticate your Docker client to your registry.
```bash
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 368563411071.dkr.ecr.eu-west-2.amazonaws.com
```

##### Pull the image
```bash
docker pull 368563411071.dkr.ecr.eu-west-2.amazonaws.com/enable_disable:latest
```

#### Tag the image with
```bash
docker tag 368563411071.dkr.ecr.eu-west-2.amazonaws.com/enable_disable:latest enable_disable
```


**OR** instead of Pulling from ECR, you can build the image.

#### Building the image
cd into the scripts directory and run the following:
```bash
docker build -t enable_disable .
```

### Creating environment variables

You will need to create a .env file containing the environment variables listed in the template: [.env.template](.env.template)

For more information on creating access keys, see: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey

### Running the container

To run the container, you will need to run the following after building or pulling the image:

```bash
docker run -it --env-file=.env enable_disable
```

where .env is the filepath to the .env file you created in the above step.

This will put you in a bash shell inside the container. From here, you can run the following:


#### Test Run
```bash
python test_run.py
```
test_run.py will test connectivity to AWS:
   1. secrets
   2. rds
   3. lambda
   4. ecs

#### Disable
```bash
python disable.py
```
disable.py will perform the following:
   1. query aurora database: select 100 latest timestamps, and take the earliest one - X
   2. Store X as JSON in S3 (RDS State bucket)
   3. Turn off event source mapping (lambda trigger) for lambda function that writes to Aurora RDS
   4. Change desired count of ECS service to 0 (effectively shutting it down)
   5. Wait until RDS scales down to 0 ACUs (effectively pausing it)


#### Enable
```bash
python enable.py
```
enable.py will perform:

   1. Retrieve JSON from S3 and read timestamp - X
   2. Turn on event source mapping with boto3, so that the lambda function that writes to Aurora is now invoked by new data
   3. Change desired count of ECS service to 1, resuming the django api
   4. Wait for RDS to scale up from 0 ACUs (effectively resuming it)
   5. Get current timestamp - Y
   6. Query Athena/S3 for records between X and Y
   7. Write a CSV containing the records to S3 (RDS State bucket)
   8. Writes to Aurora, deduplicating on INSERT

Note that step 8 happens in chunks of 10000 rows at a time.


#### Connect to Aurora Lambda
Note that there is a lambda function that exists in [infra/lambda/connect-to-aurora](../lambda/connect-to-aurora).

This lambda will ping the Aurora database every 6 days. This is to avoid a cold-start where the database shuts down and restores itself from a snapshot (which happens after it is at 0 ACUs for 7 days) as this can take hours/days to restore.