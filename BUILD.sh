#!/bin/bash

echo "🔨 Building Agent Monitor..."
cd "$(dirname "$0")/app"

xcodebuild -project AgentMonitor.xcodeproj -scheme AgentMonitor -configuration Release clean build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📦 App location: build/Debug/AgentMonitor.app"
    echo ""
    echo "🚀 To launch: open build/Debug/AgentMonitor.app"
    echo ""
else
    echo ""
    echo "❌ Build failed. Check errors above."
    exit 1
fi
