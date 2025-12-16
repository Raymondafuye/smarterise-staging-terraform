# Smart Device To RDS

This lambda function writes data from the parsed-kinesis-data-stream to the Aurora Serverless RDS Database.

## Notes

- The database contains a unique constrain on (gateway serial, timestamp). If there is a duplicate record, this will be ignored on insert.
- This is done by creating a temp table that the lambda writes to, and then an INSERT ... ON CONFLICT (timestamp, gateway_serial) DO NOTHING ingests it to the smart_device_readings table
