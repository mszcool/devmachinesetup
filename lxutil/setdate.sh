#
# Hack for a little issue with WSL 2 after resume from sleep/hibernate
# Time need to be re-synced with the HW clock so that i.e. apt update etc. continues to work
#
sudo hwclock -s
echo "Time updated with success!";