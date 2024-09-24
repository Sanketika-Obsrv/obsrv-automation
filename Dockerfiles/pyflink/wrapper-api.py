from flask import Flask, request, jsonify
import os
import zipfile
import subprocess

app = Flask(__name__)

@app.route('/submit-flink-job', methods=['POST'])
def submit_flink_job():
    try:
        uploaded_file = request.files['file']
        main_file_name = request.args.get('main_file', '')
        temp_dir = '/tmp/'
        os.makedirs(temp_dir, exist_ok=True)
        print(temp_dir, main_file_name)
        zip_file_path = os.path.join(temp_dir, 'job.zip')
        uploaded_file.save(zip_file_path)

        with zipfile.ZipFile(zip_file_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)

        flink_command = f'/opt/flink/bin/flink run --jobmanager flink-jobmanager.pyflink.svc.cluster.local:8081 -pyclientexec python3 -pyexec python3 -py {os.path.join(temp_dir, main_file_name)} --jarfile /opt/flink/lib/flink-sql-connector-kafka-3.0.1-1.18.jar'
        subprocess.run(flink_command, shell=True, check=True)

        return jsonify({'message': 'Flink job submitted successfully'})

    except Exception as e:
        print(e)
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5000)

