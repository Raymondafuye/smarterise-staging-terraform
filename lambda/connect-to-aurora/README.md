# Connect To Aurora

This lambda will ping the Aurora database every 6 days. This is to avoid a cold-start where the database shuts down and restores itself from a snapshot (which happens after it is at 0 ACUs for 7 days)