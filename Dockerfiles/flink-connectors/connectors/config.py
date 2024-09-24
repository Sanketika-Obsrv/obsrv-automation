import operator
import os
from functools import reduce

import yaml


class Config:
    def __init__(self):
        config_path = os.getenv("CONFIG_PATH", "/data/flink/connectors/connectors-init/")
        conf_file = os.getenv("CONFIG_FILE", "connector-conf.yaml")
        with open(os.path.join(config_path, conf_file)) as config_file:
            self.config = yaml.safe_load(config_file)

    def find(self, path):
        element_value = reduce(operator.getitem, path.split("."), self.config)
        return element_value
