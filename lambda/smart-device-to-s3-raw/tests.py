import unittest

import lambda_function
import pandas as pd


class TestStreamer(unittest.TestCase):
    def __init__(self, *args, **kwargs):
        super(TestStreamer, self).__init__(*args, **kwargs)

        self.test_record_format_1 = {
            "timestamp_extracted": "1662135190",
            "groceries_to_buy": 2,
            "veg_eggplant": 3,
            "fruit_apple": 1,
        }
        self.test_record_format_2 = {"timestamp_extracted": "1662135191", "veg_aubergine": 2, "fruit_apple": 4}
        self.test_config = {
            "table_a": {
                "partition_cols": ["not_used"],
                "table_schema": {
                    "date_extracted": {"type": "date", "comment": "Date of when the ETL ran"},
                    "timestamp": {"type": "timestamp", "comment": "Timestamp of when the ETL ran", "unit": "s"},
                    "num_aubergine": {"comment": "Units: aubergines", "type": "integer"},
                    "num_apples": {"comment": "Units: apples", "type": "float"},
                },
                "format_types": {
                    "format_1": {
                        "unique_features": {"num_columns": 4, "has_columns": ["groceries_to_buy"]},
                        "map": {
                            "timestamp_extracted": {"target_column": "timestamp"},
                            "veg_eggplant": {"target_column": "num_aubergine"},
                            "fruit_apple": {"target_column": "num_apples"},
                        },
                    },
                    "format_2": {
                        "unique_features": {"num_columns": 4, "has_columns": ["deviceId", "metrics_1_value"]},
                        "map": {
                            "veg_aubergine": {"target_column": "num_aubergine"},
                            "fruit_apple": {"target_column": "num_apples"},
                        },
                    },
                },
            },
        }

    def test_set_default(self):
        record = {"a": "apples", "c": "carrots"}
        defaults = {"b": "bananas"}

        test_output = lambda_function.set_defaults(record=record, defaults=defaults)

        self.assertIn("b", test_output.keys())
        self.assertEqual("bananas", test_output["b"])

    def test_reorder_columns(self):
        df = pd.DataFrame(columns=["c", "a", "b"])
        column_order = ["a", "b"]

        test_output = lambda_function.reorder_columns(df=df, first_columns=column_order)

        self.assertEqual(test_output.columns[0], "a")
        self.assertEqual(test_output.columns[1], "b")
        self.assertEqual(test_output.columns[2], "c")

    def test_find_format_and_table(self):
        _format, table = lambda_function.find_format_and_table(
            record=self.test_record_format_1, _config=self.test_config
        )

        self.assertEqual("format_1", _format)
        self.assertEqual("table_a", table)

    def test_map_to_schema(self):
        output = lambda_function.map_to_schema(
            record=self.test_record_format_1, table="table_a", _format="format_1", _config=self.test_config
        )

        self.assertEqual(3, output["num_aubergine"])

    def test_cast_datatypes(self):
        data = lambda_function.map_to_schema(
            record=self.test_record_format_1, table="table_a", _format="format_1", _config=self.test_config
        )
        schema = self.test_config["table_a"]["table_schema"]
        units = {}
        df = pd.DataFrame(data, index=[0])

        cast_data = lambda_function.cast_datatypes(df, schema, units)

        self.assertEqual(cast_data["timestamp"].dtype, object)
