# Infra

### Architecture

![Architecture diagram](/docs/images/architecture.png)

1. Data is streamed from the IoT device to AWS IoT Core.
2. An AWS IoT Topic writes data from IoT to Kinesis (`device-data-stream`)
3. New data in kinesis triggers a Lambda Function `smart-device-to-s3-raw`. This does the following:
   1. Parses the data.
   2. Writes the data to S3 and Athena.
   3. Puts the parsed data into a new kinesis data stream called `parsed-device-data-stream`.
4. New data in `parsed-device-data-stream` triggers a Lambda Function `smart-device-to-rds`. This does the following:
   1. Writes the data into the postgresql Aurora Serverless V1 database and deduplicates based on `gateway_serial` and `timestamp`.
5. New data in `parsed-device-data-stream` triggers a Lambda Function `invoke-ml-mode`. This does the following:
   1. TBC
6. The django app is hosted in ECS Fargate.
7. The web app is hosted in S3, Distributed in CloudFront and Routed in Route53. 

### Configuring an IoT Device

To add a device to IoT you will need to do the following:

1. In [terraform/variables.tf](terraform/variables.tf#L35) add the device to the smart_device_names default variable
2. Run terraform apply (or push to main, which will trigger the GHA workflow)
3. This will generate a certificate, private key and public key and push them to the S3 bucket smarterise-accuenergy-mqtt-certificates
4. Download the certificate from s3 and upload it to the device's web ui in certificates manager
5. In MQTT on the ui, enable MQTT, SSL
6. Go MQTT Topic and Parameter Selection in the ui, set Topic to `accuenergy/<device_name>` and select all of the parameters that you want to stream
