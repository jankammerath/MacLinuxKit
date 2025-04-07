# MacLinuxKit

This is a proof of concept application to run a [LinuxKit](https://github.com/linuxkit/linuxkit) VM in a SwiftUI application and launch docker containers in it. It's using the same approach the Docker Desktop for Mac uses to run LinuxKit VMs. The idea is to have Docker and container capabilities in a native SwiftUI app without the dependency on Docker Desktop.

![LinuxKit VM running in a SwiftUI app](Doc/linuxkit.jpg)

Kindly note that his is extremely early, experimental and being worked on.

## Resources

The LinuxKit image is not included in this repository. You can find an example at my [snippetd](https://github.com/jankammerath/snippetd) project which allows spawning containers and executing arbitrary code within them. The `linuxkit-initrd.img` and the `linuxkit-kernel` _(uncompressed!)_ need to be in the `MacLinuxKit/Resources` folder.
