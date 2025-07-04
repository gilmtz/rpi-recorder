

import os
import signal
import subprocess
from datetime import datetime
from flask import Flask, render_template, jsonify, request, send_from_directory

app = Flask(__name__)

RECORDING_DIR = "/home/gilbertomartinez/recordings"
# A variable to hold the recording process
recording_process = None



@app.route('/')
def index():
    """Serves the main HTML page."""
    recordings = []
    if os.path.exists(RECORDING_DIR):
        recordings = sorted(
            [f for f in os.listdir(RECORDING_DIR) if f.endswith('.wav')],
            reverse=True
        )
    return render_template('index.html', recordings=recordings, is_recording=is_recording())

@app.route('/start_recording', methods=['POST'])
def start_recording():
    """Starts the arecord process."""
    global recording_process
    if recording_process and recording_process.poll() is None:
        return jsonify({"status": "error", "message": "Already recording."}), 400

    if not os.path.exists(RECORDING_DIR):
        os.makedirs(RECORDING_DIR)

    # Generate a unique filename with a timestamp
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    filename = os.path.join(RECORDING_DIR, f"manual_recording_{timestamp}.wav")
    
    command = [
        "arecord",
        "-D", "multicapture",
        "-f", "S32_LE",
        "-r", "48000",
        "-c", "2",
        filename
    ]
    
    # Start the recording process
    recording_process = subprocess.Popen(command)
    return jsonify({"status": "success", "message": "Recording started."})

@app.route('/stop_recording', methods=['POST'])
def stop_recording():
    """Stops the arecord process."""
    global recording_process
    if recording_process and recording_process.poll() is None:
        # Send SIGINT to the process for a graceful shutdown
        recording_process.send_signal(signal.SIGINT)
        try:
            # Wait for the process to terminate
            recording_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            # If it doesn't terminate, kill it
            recording_process.kill()
    
    recording_process = None
    return jsonify({"status": "success", "message": "Recording stopped."})

@app.route('/status')
def get_status():
    """Returns the current recording status."""
    return jsonify({"is_recording": is_recording()})

def is_recording():
    """Checks if the recording process is active."""
    return recording_process is not None and recording_process.poll() is None

@app.route('/recordings/<filename>')
def get_recording(filename):
    """Serves a specific recording file."""
    return send_from_directory(RECORDING_DIR, filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

