#!/bin/bash

# ==============================================================================
#
#  Raspberry Pi USB Audio + Network Gadget Setup Script (using libcomposite)
#
#  This script configures the Raspberry Pi to act as a composite USB device
#  with two functions:
#    1. UAC2 Audio Device
#    2. ECM Ethernet Device (for SSH access and Internet Sharing over USB)
#
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e
# Print each command to stdout before executing it.
set -x

# --- Configuration ---
PI_AUDIO_DEVICE_IDENTIFIER="USB Audio Device"
GADGET_NAME="g1"
GADGET_DIR="/sys/kernel/config/usb_gadget/${GADGET_NAME}"
GADGET_AUDIO_DEVICE_NAME="UAC2"
STATIC_IP="10.0.0.1/24"
# The IP address of the host computer on the USB network.
# This is needed for internet connection sharing.
HOST_IP="10.0.0.2"
RECORDING_DIR="/home/gilbertomartinez/recordings"

# --- Argument Parsing ---
ENABLE_ETHERNET=false
ENABLE_AUTO_RECORDING=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-ethernet)
      ENABLE_ETHERNET=true
      ;;
    --auto-record)
      ENABLE_AUTO_RECORDING=true
      ;;
    -h|--help)
      echo "Usage: sudo $0 [--with-ethernet] [--auto-record]"
      echo "  --with-ethernet   Enable the USB Ethernet (ECM) gadget function."
      echo "  --auto-record   Enable continuous audio recording in 1-minute segments."
      exit 0
      ;;
    *)
      if [ -n "$1" ]; then
        echo "Unknown parameter passed: $1" >&2
        exit 1
      fi
      ;;
  esac
  shift
done


# --- Script Body ---

echo "--- Starting USB Audio + Network Gadget Setup (libcomposite) ---"

# 1. Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use 'sudo'."
   exit 1
fi

# 2. Unload all known conflicting gadget modules
echo "Unloading any existing gadget modules..."
if [ -d "${GADGET_DIR}" ]; then
    echo "" > "${GADGET_DIR}/UDC" || true
fi
sleep 1
rmmod g_ether || true
rmmod usb_f_rndis || true
rmmod u_ether || true
rmmod usb_f_ecm || true
rmmod g_audio || true
rmmod uac2 || true
rmmod usb_f_uac2 || true
rmmod libcomposite || true
sleep 1

# 3. Load libcomposite
echo "Loading libcomposite module..."
modprobe libcomposite

# 4. Create the USB Gadget configuration
echo "Creating composite gadget '${GADGET_NAME}'..."
mkdir -p "${GADGET_DIR}"
cd "${GADGET_DIR}"

# Configure gadget identity
echo "0x1d6b" > idVendor  # Linux Foundation
echo "0x0104" > idProduct # Multifunction Composite Gadget
echo "0x0100" > bcdDevice # v1.0.0
echo "0x0200" > bcdUSB    # USB 2.0

# Add English language strings
mkdir -p strings/0x409
echo "fedcba9876543210" > strings/0x409/serialnumber
echo "Raspberry Pi" > strings/0x409/manufacturer
echo "Audio+Network Gadget" > strings/0x409/product

# --- Configure Functions ---

# Create UAC2 (Audio) function
echo "Creating UAC2 (Audio) function..."
mkdir -p functions/uac2.usb0
echo "48000" > functions/uac2.usb0/c_srate # Capture rate
echo "4" > functions/uac2.usb0/c_ssize     # Capture sample size (32-bit)
echo "48000" > functions/uac2.usb0/p_srate # Playback rate
echo "4" > functions/uac2.usb0/p_ssize     # Playback sample size (32-bit)

if [ "$ENABLE_ETHERNET" = true ]; then
    # Create ECM (Ethernet) function
    echo "Creating ECM (Ethernet) function..."
    mkdir -p functions/ecm.usb0
fi

# --- Create and bind configuration ---
echo "Creating configuration..."
mkdir -p configs/c.1
echo 250 > configs/c.1/MaxPower

# Add a description for the configuration
mkdir -p configs/c.1/strings/0x409
if [ "$ENABLE_ETHERNET" = true ]; then
    echo "Config 1: Audio + ECM" > configs/c.1/strings/0x409/configuration
else
    echo "Config 1: Audio" > configs/c.1/strings/0x409/configuration
fi

# Link the functions to the configuration
echo "Linking functions to configuration..."
ln -s functions/uac2.usb0 configs/c.1/
if [ "$ENABLE_ETHERNET" = true ]; then
    ln -s functions/ecm.usb0 configs/c.1/
fi

# 5. Activate the gadget
echo "Activating the gadget..."
# Find the first available UDC (USB Device Controller)
UDC=$(ls /sys/class/udc | head -n 1)
if [ -z "$UDC" ]; then
    echo "ERROR: No UDC found!"
    exit 1
fi
echo "Binding to UDC: $UDC"
echo "$UDC" > UDC

if [ "$ENABLE_ETHERNET" = true ]; then
    # 6. Configure the network interface
    echo "Configuring the usb0 network interface..."
    # The ECM function creates the 'usb0' interface
    # Wait for it to appear
    for i in {1..10}; do
        if ip link show usb0 &> /dev/null; then
            break
        fi
        echo "Waiting for usb0 interface... ($i/10)"
        sleep 1
    done

    if ! ip link show usb0 &> /dev/null; then
        echo "ERROR: usb0 network interface did not appear."
        exit 1
    fi

    ip addr add ${STATIC_IP} dev usb0
    ip link set usb0 up

    # 7. Configure Internet Connection Sharing (ICS)
    # The following steps configure the Pi to use the host computer as a gateway
    # to the internet. For this to work, the host computer must be configured
    # to share its internet connection (see instructions at the end).

    # Set the default route to point to the host computer
    echo "Setting default route to ${HOST_IP}..."
    ip route add default via ${HOST_IP} dev usb0 || echo "Default route already exists. Ignoring."

    # Configure DNS. Note: this change might be overwritten by other network managers.
    echo "Configuring DNS..."
    if ! grep -q "8.8.8.8" /etc/resolv.conf; then
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    fi
fi


# 8. Find the ALSA device names
echo "Searching for UAC2 gadget audio device..."
USB_AUDIO_CARD=$(arecord -l | grep "$GADGET_AUDIO_DEVICE_NAME" | sed -n 's/card \([0-9]\+\):.*/\1/p' | head -n 1)
if [ -z "$USB_AUDIO_CARD" ]; then
    echo "ERROR: Could not find USB Audio Gadget ($GADGET_AUDIO_DEVICE_NAME) device."
    echo "--- Available capture devices: ---"
    arecord -l
    echo "------------------------------------"
    exit 1
fi

echo "Searching for Pi audio output device ('$PI_AUDIO_DEVICE_IDENTIFIER')..."
PI_AUDIO_CARD=$(aplay -l | grep "$PI_AUDIO_DEVICE_IDENTIFIER" | sed -n 's/card \([0-9]\+\):.*/\1/p' | head -n 1)
if [ -z "$PI_AUDIO_CARD" ]; then
    echo "ERROR: Could not find the Raspberry Pi audio output device ('$PI_AUDIO_DEVICE_IDENTIFIER')."
    echo "--- Available playback devices: ---"
    aplay -l
    echo "-------------------------------------"
    exit 1
fi

echo "Found USB Audio device card: $USB_AUDIO_CARD"
echo "Found Pi audio output device card: $PI_AUDIO_CARD"

# 9. Stop any previous audio processes
echo "Stopping any existing audio processes..."
killall alsaloop || true
killall arecord || true
sleep 1

# 10. Start audio forwarding
echo "Starting audio forwarding..."
sudo -u gilbertomartinez alsaloop -C multicapture -P plughw:"$PI_AUDIO_CARD",0 -f S32_LE -r 48000 -c 2 --daemon

if [ "$ENABLE_AUTO_RECORDING" = true ]; then
    # 11. Start recording in 1-minute segments
    echo "Starting audio recording in 1-minute segments..."
    mkdir -p "${RECORDING_DIR}"
    # The script is run as root, so we need to make sure the user can write to it.
    chown gilbertomartinez:gilbertomartinez "${RECORDING_DIR}" || echo "Could not chown ${RECORDING_DIR}. Recordings may be owned by root."

    # Run recording in a background loop
    (
      cd "${RECORDING_DIR}"
      while true; do
        FILENAME="$(date +%Y-%m-%d_%H-%M-%S).wav"
        echo "Recording to $FILENAME for 60 seconds..."
        arecord -D plughw:"$USB_AUDIO_CARD",0 -f S32_LE -r 48000 -c 2 -d 60 "$FILENAME"
      done
    ) &
fi

echo ""
echo "============================================================================="
if [ "$ENABLE_ETHERNET" = true ]; then
    echo " Composite Audio + Network Gadget Activated"
    echo " - Audio forwarding started."
    echo " - Network interface 'usb0' is up at ${STATIC_IP}."
    echo " - You can now SSH into the Pi at 'ssh pi@10.0.0.1'."
    echo ""
    echo "--- Internet Sharing Setup (Host Computer) ---"
    echo "To provide internet to the Pi, you must configure your host computer."
    echo "Find the name of the USB network interface on your host."
    echo ""
    echo "On Linux:"
    echo "  # 1. Find interface names (e.g., enp0s20f0u2 for USB, wlan0 for Wi-Fi)."
    echo "  ip link"
    echo ""
    echo "  # 2. Set IP address for the USB network interface."
    echo "  sudo ip addr add ${HOST_IP}/24 dev <usb_interface_name>"
    echo "  sudo ip link set <usb_interface_name> up"
    echo ""
    echo "  # 3. Enable IP forwarding."
    echo "  sudo sysctl -w net.ipv4.ip_forward=1"
    echo ""
    echo "  # 4. Set up NAT (replace <internet_iface> with your main one, e.g., wlan0)."
    echo "  sudo iptables -t nat -A POSTROUTING -o <internet_iface> -j MASQUERADE"
    echo "  sudo iptables -A FORWARD -i <usb_interface_name> -o <internet_iface> -j ACCEPT"
    echo "  sudo iptables -A FORWARD -i <internet_iface> -o <usb_interface_name> -m state --state RELATED,ESTABLISHED -j ACCEPT"
    echo ""
    echo "On macOS:"
    echo "  # 1. Find interface names."
    echo "  #    - Your main internet interface (e.g., 'en0' for Wi-Fi)."
    echo "  #    - The Pi's USB interface (e.g., 'en5', check Network Settings for 'RNDIS/Ethernet Gadget')."
    echo "  ifconfig"
    echo ""
    echo "  # 2. Set the IP address for the USB network interface."
    echo "  sudo ifconfig <pi_usb_interface_name> inet ${HOST_IP} netmask 255.255.255.0"
    echo ""
    echo "  # 3. Enable IP forwarding."
    echo "  sudo sysctl -w net.inet.ip.forwarding=1"
    echo ""
    echo "  # 4. Enable NAT using pf (replace <main_internet_iface> with your main one)."
    echo "  echo \"nat on <main_internet_iface> from ${STATIC_IP%.*}.0/24 to any -> (<main_internet_iface>)\" | sudo pfctl -f -"
    echo "  sudo pfctl -e"
else
    echo " Composite Audio Gadget Activated"
    echo " - Audio forwarding started."
fi
echo ""
echo "============================================================================="

exit 0
