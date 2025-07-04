# RPi Recorder

RPi Recorder is a project that turns a Raspberry Pi into a USB audio device capable of recording, playback, and local transcription. It's designed to capture audio from a host computer (e.g., a meeting on your laptop) and provide a simple web interface to manage recordings and transcribe them without relying on cloud services.

## Features

- **USB Audio Gadget:** Appears as a standard USB microphone to the host computer.
- **Live Monitoring:** Forwards the incoming audio to an external DAC connected to the Pi for real-time playback.
- **Web Interface:** A simple GUI to start/stop recordings, view past recordings, and initiate transcriptions.
- **Local Transcription:** Uses OpenAI's Whisper model to transcribe recordings directly on the Pi.

## Setup Instructions

These instructions assume you are running a fresh Raspberry Pi OS (Debian Bookworm).

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/rpi-recorder.git
    cd rpi-recorder
    ```

2.  **Install System Dependencies:**
    The script requires `ffmpeg` for audio processing.
    ```bash
    sudo apt-get update
    sudo apt-get install -y ffmpeg
    ```

3.  **Run the USB Gadget Setup Script:**
    This script configures the Pi to act as a USB audio device.
    ```bash
    sudo ./setup_usb_gadget.sh
    ```
    *Note: The `--with-ethernet` flag can be added to also create a USB network interface.*

4.  **Add User to Audio Group:**
    Allow your user to access the audio hardware.
    ```bash
    sudo usermod -aG audio $USER
    ```
    You will need to **reboot** after this for the change to take effect.

5.  **Install Python Dependencies:**
    Set up a virtual environment and install the required Python libraries for the web GUI and transcription.
    ```bash
    python3 -m venv web_gui/venv
    source web_gui/venv/bin/activate
    pip install -r web_gui/requirements.txt 
    ```
    *(Note: A `requirements.txt` will be added in a future step)*

6.  **Start the Web Server:**
    ```bash
    web_gui/venv/bin/python web_gui/app.py &
    ```

The web interface will be available at `http://<your-pi-ip-address>:5000`.

## Making it Persistent (Optional)

To make the USB gadget and web server start automatically on every boot, follow these steps.

### 1. Configure Modules to Load on Boot

First, you need to ensure the `dwc2` overlay and `libcomposite` module are loaded.

1.  **Enable the `dwc2` overlay:**
    Add `dtoverlay=dwc2` to the end of your `/boot/firmware/config.txt` file.
    ```bash
    echo "dtoverlay=dwc2" | sudo tee -a /boot/firmware/config.txt
    ```

2.  **Load `libcomposite` at boot:**
    Create a file to tell the system to load the module.
    ```bash
    echo "libcomposite" | sudo tee /etc/modules-load.d/libcomposite.conf
    ```

### 2. Create a `systemd` Service for the Setup Script

This service will run the `setup_usb_gadget.sh` script when the system starts.

1.  **Create the service file:**
    ```bash
    sudo nano /etc/systemd/system/rpi-recorder.service
    ```

2.  **Paste the following content** into the file. Make sure to replace `/home/gilbertomartinez/rpi-recorder` with the actual path to your project directory if it's different.
    ```ini
    [Unit]
    Description=RPi Recorder Setup Service
    After=network.target

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    WorkingDirectory=/home/gilbertomartinez/rpi-recorder
    ExecStart=/home/gilbertomartinez/rpi-recorder/setup_usb_gadget.sh
    ExecStart=/bin/bash -c 'source web_gui/venv/bin/activate && python web_gui/app.py &'

    [Install]
    WantedBy=multi-user.target
    ```

3.  **Enable and start the service:**
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable rpi-recorder.service
    sudo systemctl start rpi-recorder.service
    ```

After a reboot, both the USB gadget and the web server should start automatically. You can check the status at any time with `systemctl status rpi-recorder.service`.

## Project Goals

- [X] A setup script for the USB audio device
- [X] A minimal web GUI to start and stop recording
- [X] Local AI transcription using small whisper models
