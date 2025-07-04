# RPi Recorder - Web GUI

This directory contains a simple Flask-based web server to control the audio recording on the Raspberry Pi.

## Features

- Start and stop recording manually.
- View a list of all recordings.
- Play back recordings directly in the browser.
- Visual status indicator for recording.

## Setup and Installation

1.  **Create a Virtual Environment:**

    To avoid conflicts with system packages, it's best to use a Python virtual environment.

    ```bash
    sudo apt-get update
    sudo apt-get install python3-venv
    python3 -m venv web_gui/venv
    ```

2.  **Install Dependencies:**

    Install Flask and its dependencies into the virtual environment.

    ```bash
    web_gui/venv/bin/pip install Flask
    ```

3.  **Run the Web Server:**

    To start the web server, run the following command from the `rpi-recorder` directory using the Python interpreter from the virtual environment:

    ```bash
    web_gui/venv/bin/python web_gui/app.py
    ```

4.  **Access the GUI:**

    Open a web browser and navigate to `http://<your-pi-ip>:5000`. If you are using the USB network gadget, this will be `http://10.0.0.1:5000`.

## How It Works

-   **`app.py`**: This is the main Flask application. It handles the web routes for starting/stopping the recording, checking the status, and serving the web page and audio files.
-   **`templates/index.html`**: This is the main HTML file for the user interface. It includes basic CSS for styling and JavaScript to communicate with the Flask backend.
-   **Recording Directory**: The application serves audio files from the `/home/gilbertomartinez/recordings` directory, which is configured in the `setup_usb_gadget.sh` script.
