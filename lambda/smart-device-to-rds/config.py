import sqlalchemy

cols_for_rds = {
    "date": sqlalchemy.types.DATE(),
    "timestamp": sqlalchemy.types.DateTime(),
    "month": sqlalchemy.types.INTEGER(),  # For the month column
    "year": sqlalchemy.types.INTEGER(),
    #"gateway_name": sqlalchemy.types.VARCHAR(length=255),
    #"gateway_model": sqlalchemy.types.VARCHAR(length=255),
    "gateway_serial": sqlalchemy.types.VARCHAR(length=255),
    "company_id": sqlalchemy.types.VARCHAR(length=255),
    "line_to_neutral_voltage_phase_a": sqlalchemy.types.Float(),
    "line_to_neutral_voltage_phase_b": sqlalchemy.types.Float(),
    "line_to_neutral_voltage_phase_c": sqlalchemy.types.Float(),
    "line_current_overall_phase_a": sqlalchemy.types.Float(),
    "line_current_overall_phase_b": sqlalchemy.types.Float(),
    "line_current_overall_phase_c": sqlalchemy.types.Float(),
    "line_current_overall_neutral": sqlalchemy.types.Float(),
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
   # "device_online":sqlalchemy.types.Boolean(),
    "voltage_unbalance_factor":sqlalchemy.types.Float(),  # Units: %
    "current_unbalance_factor":sqlalchemy.types.Float(),  # Units: %
    "frequency":sqlalchemy.types.Float(),
    "power_factor_overall": sqlalchemy.types.Float(), 
    "reactive_power_overall_total":sqlalchemy.types.Float(), 
    "reactive_power_overall":sqlalchemy.types.Float(),
    "reactive_power_overall_phase_a":sqlalchemy.types.Float(),
    "reactive_power_overall_phase_b":sqlalchemy.types.Float(),
    "reactive_power_overall_phase_c":sqlalchemy.types.Float(),
    "apparent_power_overall_total": sqlalchemy.types.Float(),
    "total_harmonic_distortion_current_phase_a":sqlalchemy.types.Float(),
    "total_harmonic_distortion_current_phase_b":sqlalchemy.types.Float(),
    "total_harmonic_distortion_current_phase_c":sqlalchemy.types.Float(),
    "3rd_harmonic_phase_a":sqlalchemy.types.Float(),
    "3rd_harmonic_phase_b":sqlalchemy.types.Float(),
    "3rd_harmonic_phase_c":sqlalchemy.types.Float(),
    "5th_harmonic_phase_a":sqlalchemy.types.Float(),
    "5th_harmonic_phase_b":sqlalchemy.types.Float(),
    "5th_harmonic_phase_c":sqlalchemy.types.Float(),
    "load":sqlalchemy.types.Float(),                        # Units: %
    "energy":sqlalchemy.types.Float(),                       # Units: %
   # "excess_load":sqlalchemy.types.Float(),                 # Units: %
   # "excess_current_unbalance":sqlalchemy.types.Float(),    # Units: %
   # "excess_voltage_unbalance":sqlalchemy.types.Float(),    # Units: %
   # "excess_power_factor":sqlalchemy.types.Float(),         # Units: %
  #  "transformer_uptime":sqlalchemy.types.Float(),          # Units: % 
   # "daily_maximum_load":sqlalchemy.types.Float(),
   # "daily_minimum_load":sqlalchemy.types.Float(),
    "Distributed_Electricity":sqlalchemy.types.Float(),
    "transformer_capacity":sqlalchemy.types.Float(),
    "transformer_load_percentage":sqlalchemy.types.Float()  # Units: %
}

