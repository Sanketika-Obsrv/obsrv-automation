import tarfile
import zipfile
import os
import requests
import uuid
import shutil
import json

from config import Config
from db_service import DatabaseService

config = Config()
db_service = DatabaseService()


def main():
    query = f"""
            SELECT datasource_ref, datasource
            FROM datasources
        """

    datasourcs = db_service.execute_select_all(query)
    druid_host = config.find("druid.host")

    for datasource in datasourcs:
        response = requests.delete(f"{druid_host}/druid/coordinator/v1/datasources/{datasource}",
                                   headers={"Content-Type": "application/json"})

        if response.status_code == 200:
            print(f"Druid Datasource Deletion | Successfully Deleted the Unused or Expired MasterDatasource ${datasource}")
        else:
            print(f"Druid Datasource Deletion | Error occurred while deleting datasource ${datasource}")

if __name__ == "__main__":
    main()
