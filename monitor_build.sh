#!/bin/bash
# Monitor Docker build progress

echo "🔍 Monitoring Docker Build Progress"
echo "===================================="
echo ""

# Check if build process is running
if pgrep -f "build_and_deploy.sh" > /dev/null; then
    echo "✅ Build process is running"
    echo ""
    
    # Show last 20 lines of build output
    if [ -f build_arm64_output.log ]; then
        echo "📝 Latest build output:"
        echo "----------------------"
        tail -20 build_arm64_output.log
    else
        echo "⏳ Waiting for build log to be created..."
    fi
else
    echo "❌ Build process is not running"
    echo ""
    
    # Check if build completed
    if [ -f build_arm64_output.log ]; then
        echo "📋 Checking build result..."
        if grep -q "🎉 Build and deployment complete!" build_arm64_output.log; then
            echo "✅ BUILD SUCCESSFUL!"
            echo ""
            echo "Checking deployment status..."
            bash check_deployment_status.sh
        elif grep -q "❌" build_arm64_output.log; then
            echo "❌ BUILD FAILED"
            echo ""
            echo "Last 30 lines of output:"
            tail -30 build_arm64_output.log
        else
            echo "⚠️  Build status unclear"
        fi
    fi
fi

echo ""
echo "💡 Run this script again to check progress"
echo "💡 Or view full log: tail -f build_arm64_output.log"
