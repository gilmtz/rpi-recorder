
import os
import signal
import subprocess
from datetime import datetime
from flask import Flask, render_template, jsonify, request, send_from_directory
import whisper

app = Flask(__name__)

RECORDING_DIR = "/home/gilbertomartinez/recordings"
# A variable to hold the recording process
recording_process = None

# --- Whisper Model Management ---
# We will load models on demand and cache them in memory.
# This is a trade-off: it uses more RAM if multiple models are used,
# but avoids the slow model loading process on each request.
loaded_models = {}
# Sticking to .en models as they are smaller and faster.
AVAILABLE_MODELS = ["tiny.en", "base.en", "small.en"]


@app.route('/')
def index():
    """Serves the main HTML page."""
    recordings_data = []
    if os.path.exists(RECORDING_DIR):
        wav_files = sorted(
            [f for f in os.listdir(RECORDING_DIR) if f.endswith('.wav')],
            reverse=True
        )
        # For each wav file, find all available transcriptions
        for wav_file in wav_files:
            transcriptions = []
            for model_name in AVAILABLE_MODELS:
                transcription_file = f"{wav_file}.{model_name}.txt"
                if os.path.exists(os.path.join(RECORDING_DIR, transcription_file)):
                    transcriptions.append(model_name)
            
            recordings_data.append({
                "filename": wav_file,
                "transcriptions": transcriptions
            })

    return render_template(
        'index.html',
        recordings=recordings_data,
        is_recording=is_recording(),
        available_models=AVAILABLE_MODELS
    )

@app.route('/start_recording', methods=['POST'])
def start_recording():
    """Starts the arecord process."""
    global recording_process
    if recording_process and recording_process.poll() is None:
        return jsonify({"status": "error", "message": "Already recording."}), 400

    if not os.path.exists(RECORDING_DIR):
        os.makedirs(RECORDING_DIR)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    filename = os.path.join(RECORDING_DIR, f"manual_recording_{timestamp}.wav")
    
    command = ["arecord", "-D", "multicapture", "-f", "S32_LE", "-r", "48000", "-c", "2", filename]
    
    recording_process = subprocess.Popen(command)
    return jsonify({"status": "success", "message": "Recording started."})

@app.route('/stop_recording', methods=['POST'])
def stop_recording():
    """Stops the arecord process."""
    global recording_process
    if recording_process and recording_process.poll() is None:
        recording_process.send_signal(signal.SIGINT)
        try:
            recording_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
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

@app.route('/transcribe', methods=['POST'])
def transcribe_recording():
    """Transcribes a given audio file using a specified model."""
    data = request.get_json()
    filename = data.get('filename')
    model_name = data.get('model_name')

    if not all([filename, model_name]):
        return jsonify({"status": "error", "message": "Filename and model name are required."}), 400
    
    if model_name not in AVAILABLE_MODELS:
        return jsonify({"status": "error", "message": "Invalid model name."}), 400

    audio_path = os.path.join(RECORDING_DIR, filename)
    transcription_path = f"{audio_path}.{model_name}.txt"

    if not os.path.exists(audio_path):
        return jsonify({"status": "error", "message": "Audio file not found."}), 404
    
    if os.path.exists(transcription_path):
        return jsonify({"status": "error", "message": "Transcription for this model already exists."}), 400

    try:
        # Load model if not already cached
        if model_name not in loaded_models:
            print(f"Loading Whisper model: {model_name}...")
            loaded_models[model_name] = whisper.load_model(model_name)
            print("Model loaded.")

        model = loaded_models[model_name]
        
        # Run the transcription
        result = model.transcribe(audio_path, fp16=False) # fp16=False is recommended for ARM CPUs
        
        # Save the transcription to a file
        with open(transcription_path, "w") as f:
            f.write(result["text"])
            
        return jsonify({"status": "success", "message": "Transcription complete.", "transcription": result["text"]})

    except Exception as e:
        app.logger.error(f"Transcription failed for {filename} with model {model_name}: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/get_transcription/<filename>')
def get_transcription(filename):
    """Serves the content of a transcription file."""
    # The filename now includes the model, e.g., "recording.wav.tiny.en.txt"
    transcription_path = os.path.join(RECORDING_DIR, filename)
    if os.path.exists(transcription_path):
        return send_from_directory(RECORDING_DIR, filename)
    return jsonify({"status": "error", "message": "Transcription not found."}), 404


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
