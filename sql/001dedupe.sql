DELETE FROM smart_device_readings
WHERE id IN (
        SELECT id
        FROM (
                SELECT ROW_NUMBER() OVER (
                        PARTITION BY timestamp,
                        gateway_serial
                        ORDER BY id ASC
                    ) as row_num,
                    gateway_serial,
                    timestamp,
                    id
                from smart_device_readings
            ) t
        where row_num > 1
    )