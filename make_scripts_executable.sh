#!/bin/bash

# Make all ngrok session scripts executable

chmod +x setup_ngrok_session.sh
chmod +x stop_ngrok_session.sh
chmod +x check_ngrok_session.sh
chmod +x test_automation_setup.sh

echo "✅ All scripts are now executable"
echo ""
echo "Available commands:"
echo "  ./test_automation_setup.sh  - Test prerequisites"
echo "  ./setup_ngrok_session.sh    - Start everything"
echo "  ./stop_ngrok_session.sh     - Stop everything"
echo "  ./check_ngrok_session.sh    - Check status"
