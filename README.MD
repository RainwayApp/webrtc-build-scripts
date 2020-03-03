# webrtc-build-scripts

## Summary

WebRTC is a bitch to build. This repo current contains a script to build automate the building/patching required for it to work with Spitfire. 

Building is also slow and will use up all the CPU and network bandwidth on every device in your home, so have fun doing nothing while you contemplate why we're here to suffer. 

## Build details

Run build.ps1 from the root of checked out repository and the build will take care of the process. The steps include:

1. Download and setup of Google Depot Tools in the case they are not available in the system; you would probably want to have them installed upfront
2. Check out of webrtc repo at head of branch defined at the top of build.ps1 file (e.g. "m79")
3. Toolchain update for build steps below
4. Patching of webrtc and its Windows build configuration for .NET friendly build (dynamic CRT, use of standard `std`, C++/CLI friendliness)
5. Ninja build of 32/64 Debug/Release configurations of webrtc
6. Extraction of .H and .LIB files for use with in external projects (namely [Spitfire](https://github.com/RainwayApp/spitfire))
