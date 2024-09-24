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
    runtime = os.getenv("RUNTIME", get_runtime())
    connector_id = os.getenv("CONNECTOR_ID", None)
    download_path = config.find("connectors.extraction_path")
    storage_path = config.find("connectors.storage_path")

    if not os.path.exists(download_path):
        os.makedirs(download_path)

    if not os.path.exists(storage_path):
        os.makedirs(storage_path)

    query = f"""
            SELECT cr.source_url, cr.source
            FROM connector_registry cr
            LEFT JOIN connector_instances ci on ci.connector_id = cr.id
            WHERE (cr.status = 'Live' or ci.status = 'Live') AND cr.runtime = '{runtime}'
        """

    if connector_id:
        query += f"AND cr.id = '{connector_id}' "

    # query += "GROUP BY cr.source_url;"

    connectors = db_service.execute_select_all(query)

    for connector in connectors:
        source_url, source = connector
        main_jar = source["main_program"]
        source = source["source"]

        print(f"Processing file with URL: {source_url} and Source: {source}")

        if os.path.exists(f"{storage_path}/{source}"):
            print(f"Connector Registry | Connector {source} already exists")
            with open(f"{storage_path}/{source}/metadata.json") as f:
                metadata = json.load(f)
                install_python_requirements(metadata, storage_path, source)
            continue

        if os.path.exists(f"{download_path}/{source_url}"):
            print(f"Connector Registry | Connector {source_url} already downloaded")
        else:
            download_status = download_file(source_url, f"{download_path}/{source_url}")
            if not download_status:
                print(f"Connector Registry | Error occurred while downloading {source}")
                exit(1)

        # ext_path = f"{download_path}/{uuid.uuid4()}"
        # ext_path = f"{storage_path}/{source}"

        ExtractionUtil.extract(f"{download_path}/{source_url}", storage_path, source.split('.')[-1])
        print(f"Connector Registry | Connector made available in storage path {storage_path}/{source}")

        # shutil.copy(f"{storage_path}/{source}/{main_jar}", f"/opt/flink/lib/{main_jar}")
        # print(f"Connector Registry | Jar copied to flink classpath /opt/flink/lib/")

        # load metadata and install python packages
        with open(f"{storage_path}/{source}/metadata.json") as f:
            metadata = json.load(f)
            install_python_requirements(metadata, storage_path, source)

def install_python_requirements(metadata, storage_path, source):
    if metadata.get("metadata", {}).get("technology", "") == "python":
        print(f"installing Python requirements for {storage_path}/{source}")
        os.system(f"pip install -r {storage_path}/{source}/requirements.txt")

def get_runtime():
    if os.path.exists("/opt/bitnami/spark"):
        return "spark"

    if os.path.exists("/opt/flink"):
        return "flink"


# Method to download the file from blob store
def download_file(rel_path, destination) -> bool:
    try:
        # get pre-signed URL from dataset-api
        dataset_api_host = config.find("dataset_api.host").strip("/")
        pre_signed_endpoint = config.find("dataset_api.pre_signed_url").strip("/")

        dataset_api_request = json.dumps({"request": {"files": [rel_path], "access": "read", "type": "connector"}})
        dataset_api_response = requests.post(f"{dataset_api_host}/{pre_signed_endpoint}", data=dataset_api_request, headers={"Content-Type": "application/json"})

        if dataset_api_response.status_code != 200:
            print(f"Connector Registry | Error occurred while fetching pre-signed URL for {rel_path}: {dataset_api_response.text}")
            return False

        dataset_api_response_json = dataset_api_response.json()

        url = dataset_api_response_json.get("result", [{}])[0].get(
            "preSignedUrl", None
        )

        if not url:
            print(f"Connector Registry | Pre-signed URL not found for {rel_path}")
            return False

        response = requests.get(url, stream=True)
        response.raise_for_status()

        with open(destination, 'wb') as file:
            for chunk in response.iter_content(chunk_size=8192):
                file.write(chunk)

        print(f"Connector Registry | Download completed successfully. URL:{rel_path} Destination: {destination}")
        return True
    except requests.exceptions.HTTPError as http_err:
        print(f"Connector Registry | HTTP error occurred during the file download:  {http_err}")
        return False
    except Exception as e:
        print(f"Connector Registry | An unexpected error occurred during the file download:  {e}")
        return False


class ExtractionUtil:
    def extract_gz(tar_path, extract_path):
        with tarfile.open(tar_path, "r:*") as tar:
            tar.extractall(path=extract_path)

    def extract_zip(tar_path, extract_path):
        with zipfile.ZipFile(tar_path, "r") as zip_ref:
            zip_ref.extractall(path=extract_path)

    # Method to extract the compressed files
    def extract(file, extract_out_path, ext) -> bool:
        extraction_function = ExtractionUtil.extract_gz

        compression_types = {
            "zip": ExtractionUtil.extract_zip,
        }

        try:
            print(
                f"Connector Registry | Extracting {file} to {extract_out_path} of {ext} file type"
            )

            if ext in compression_types:
                extraction_function = compression_types.get(ext)

            extraction_function(file, extract_out_path)
            print(f"Connector Registry | Extraction complete for {file}")
            return True
        except (tarfile.TarError, zipfile.BadZipFile, OSError) as e:
            print(
                f"Connector Registry | An error occurred while extracting the file: {e}"
            )
            return False
        except Exception as e:
            print(f"Connector Registry | An unexpected error occurred: {e}")
            return False


if __name__ == "__main__":
    main()