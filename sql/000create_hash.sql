with hash as (
    SELECT MD5(
            CONCAT_WS(
                '',
                CAST(date as varchar(255)),
                CAST(timestamp as varchar(255)),
                CAST(gateway_name as varchar(255)),
                CAST(gateway_model as varchar(255)),
                CAST(gateway_serial as varchar(255)),
                CAST(device_name as varchar(255)),
                CAST(device_serial as varchar(255)),
                CAST(
                    line_to_neutral_voltage_phase_a::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    line_to_neutral_voltage_phase_b::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    line_to_neutral_voltage_phase_c::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    active_power_overall_total::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    import_active_energy_overall_total::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    analog_input_channel_1::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    analog_input_channel_2::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    power_factor_overall_phase_a::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    power_factor_overall_phase_b::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    power_factor_overall_phase_c::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    active_power_overall_phase_a::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    active_power_overall_phase_b::decimal(10, 3) as varchar(255)
                ),
                CAST(
                    active_power_overall_phase_c::decimal(10, 3) as varchar(255)
                )
            )
        ) as hash_id
    from smart_device_readings
)
update smart_device_readings as sdr
SET hash_id = hash.hash_id
from hash
where hash.hash_id is null