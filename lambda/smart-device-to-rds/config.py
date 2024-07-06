import sqlalchemy

cols_for_rds = {
    "date": sqlalchemy.types.DATE(),
    "timestamp": sqlalchemy.types.DateTime(),
    "gateway_name": sqlalchemy.types.VARCHAR(length=255),
    "gateway_model": sqlalchemy.types.VARCHAR(length=255),
    "gateway_serial": sqlalchemy.types.VARCHAR(length=255),
    "device_name": sqlalchemy.types.VARCHAR(length=255),
    "device_serial": sqlalchemy.types.VARCHAR(length=255),
    "line_to_neutral_voltage_phase_a": sqlalchemy.types.Float(),
    "line_to_neutral_voltage_phase_b": sqlalchemy.types.Float(),
    "line_to_neutral_voltage_phase_c": sqlalchemy.types.Float(),
    "active_power_overall_total": sqlalchemy.types.Float(),
    "import_active_energy_overall_total": sqlalchemy.types.Float(),
    "analog_input_channel_1": sqlalchemy.types.Float(),
    "analog_input_channel_2": sqlalchemy.types.Float(),
    "power_factor_overall_phase_a": sqlalchemy.types.Float(),
    "power_factor_overall_phase_b": sqlalchemy.types.Float(),
    "power_factor_overall_phase_c": sqlalchemy.types.Float(),
    "active_power_overall_phase_a": sqlalchemy.types.Float(),
    "active_power_overall_phase_b": sqlalchemy.types.Float(),
    "active_power_overall_phase_c": sqlalchemy.types.Float(),
}
