# Raspberry Pi USB Audio Gadget Setup Guide

This guide will walk you through configuring a Raspberry Pi as a USB audio gadget on a fresh Raspberry Pi OS image. When complete, the Raspberry Pi will appear as a USB audio device to a host computer. Audio played on the host will be forwarded to an external USB DAC connected to the Pi.

## Prerequisites

*   A Raspberry Pi (4B, 5, or Zero 2 W recommended).
*   An SD card with a fresh installation of Raspberry Pi OS.
*   A USB-C cable to connect the Pi to a host computer.
*   An external USB DAC or sound card.
*   An internet connection on the Raspberry Pi for initial setup.

## Step 1: Enable the USB Gadget Hardware

First, you need to enable the `dwc2` USB gadget overlay.

1.  Open the boot configuration file:
    ```bash
    sudo nano /boot/firmware/config.txt
    ```

2.  Add the following line to the end of the file:
    ```
    dtoverlay=dwc2
    ```

3.  Save the file (`Ctrl+X`, then `Y`, then `Enter`) and reboot the Raspberry Pi:
    ```bash
    sudo reboot
    ```

## Step 2: Load the `g_audio` Module on Boot

Next, configure the system to automatically load the `g_audio` module with the correct parameters on startup.

1.  Create a new file to load the `g_audio` module at boot:
    ```bash
    sudo nano /etc/modules-load.d/g_audio.conf
    ```

2.  Add the following line to the file:
    ```
    g_audio
    ```

3.  Save and close the file.

4.  Now, create a file to configure the `g_audio` module's parameters:
    ```bash
    sudo nano /etc/modprobe.d/g_audio.conf
    ```

5.  Add the following line to set the audio parameters. This configures the gadget for 48kHz, 32-bit audio.
    ```
    options g_audio c_srate=48000 p_srate=48000 c_ssize=4 p_ssize=4
    ```

6.  Save and close the file.

## Step 3: Create the Audio Forwarding Script

This script will find the USB audio devices and start the `alsaloop` process to forward the audio.

1.  Create the script file:
    ```bash
    sudo nano /usr/local/bin/start-usb-audio.sh
    ```

2.  Copy and paste the following code into the file:
    ```bash
    #!/bin/bash

    # Configuration
    PI_AUDIO_DEVICE_IDENTIFIER="USB Audio"
    GADGET_AUDIO_DEVICE_NAME="UAC2"

    # Wait for devices to settle
    sleep 5

    # Find the ALSA device names
    USB_AUDIO_CARD=$(arecord -l | grep "$GADGET_AUDIO_DEVICE_NAME" | sed -n 's/card \([0-9]\+\):.*/\1/p' | head -n 1)
    PI_AUDIO_CARD=$(aplay -l | grep "$PI_AUDIO_DEVICE_IDENTIFIER" | sed -n 's/card \([0-9]\+\):.*/\1/p' | head -n 1)

    # Check if devices were found
    if [ -z "$USB_AUDIO_CARD" ] || [ -z "$PI_AUDIO_CARD" ]; then
        echo "ERROR: Could not find audio devices. Exiting."
        exit 1
    fi

    # Stop any previous audio processes
    killall alsaloop || true
    sleep 1

    # Start audio forwarding
    alsaloop -C plughw:"$USB_AUDIO_CARD",0 -P plughw:"$PI_AUDIO_CARD",0 -f S32_LE -r 48000 -c 2 --daemon
    ```

3.  Save the file and make it executable:
    ```bash
    sudo chmod +x /usr/local/bin/start-usb-audio.sh
    ```

## Step 4: Create a `systemd` Service

To run the script automatically at boot, we'll create a `systemd` service.

1.  Create the service file:
    ```bash
    sudo nano /etc/systemd/system/usb-audio.service
    ```

2.  Copy and paste the following configuration into the file:
    ```
    [Unit]
    Description=USB Audio Gadget Forwarding
    After=sound.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/start-usb-audio.sh
    RemainAfterExit=true
    Restart=always

    [Install]
    WantedBy=multi-user.target
    ```

3.  Save and close the file.

## Step 5: Enable the Service

Now, enable the new service so it starts on boot.

1.  Reload the `systemd` daemon to recognize the new service:
    ```bash
    sudo systemctl daemon-reload
    ```

2.  Enable the service to start at boot:
    ```bash
    sudo systemctl enable usb-audio.service
    ```

3.  You can either reboot now or start the service manually for the first time:
    ```bash
    sudo systemctl start usb-audio.service
    ```

## Step 6: Verification

After a reboot, the Raspberry Pi should be operating as a USB audio gadget.

1.  Connect the Raspberry Pi to your host computer using the USB-C port used for power/gadget mode.
2.  The host computer should recognize a new audio device named "UAC2 Gadget".
3.  You can verify that the ALSA devices are present on the Pi by running:
    ```bash
    arecord -l
    aplay -l
    ```
    You should see the "UAC2" device in the capture list and your external DAC in the playback list.

4.  Check the status of the `systemd` service to ensure it ran without errors:
    ```bash
    systemctl status usb-audio.service
    ```

You're all set! Your Raspberry Pi is now a dedicated USB audio gadget.
