if [ "$MODIFIER" = "cmd" ]; then
    open /System/Library/PreferencePanes/Bluetooth.prefPane
    exit
fi

# Check if blueutil is available
if ! command -v blueutil &> /dev/null; then
    echo "blueutil not found. Installing via Homebrew..."
    brew install blueutil
fi

# Get current Bluetooth status
status=$(blueutil --power)

if [ "$status" = "1" ]; then
    blueutil --power 0
else
    blueutil --power 1
fi


