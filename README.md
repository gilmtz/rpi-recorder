# RPi Recorder

Rpi recorder is a set of scripts to use a Raspberry Pi 4 as a USB audio device to simultaneously record audio and play it back via an external DAC.

The project aims to create setup scripts to create meeting notes without needing each platform to support recording and AI transcription.

## Setup Instructions

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/rpi-recorder.git
    cd rpi-recorder
    ```

2.  **Run the setup script:**
    ```bash
    sudo ./setup_usb_gadget.sh --no-ethernet
    ```

3.  **Add your user to the `audio` group:**
    ```bash
    sudo usermod -aG audio $USER
    ```

4.  **Reboot the Raspberry Pi:**
    ```bash
    sudo reboot
    ```

5.  **Start the web server:**
    ```bash
    python3 web_gui/app.py &
    ```

The web interface will be available at `http://<your-pi-ip-address>:5000`.

## Project Goals

- [X] A setup script for the USB audio device
- [X] A minimal web GUI to start and stop recording
- [ ] Local AI transcription using small whisper models