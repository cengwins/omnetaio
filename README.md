# OMNeT++ All-In-One Docker Image

This repository provides a standardized, pre-compiled Docker environment for OMNeT++, INET Framework, and Simu5G. It is designed to facilitate reproducible academic research and streamline the setup process for network simulations.

## Quick Start

To pull the pre-compiled image from our registry:

```bash
docker pull ghcr.io/cengwins/omnetaio:latest
```

To run an interactive session:

```bash
docker run -it ghcr.io/cengwins/omnetaio:latest /bin/bash
```

-----

## Image Contents

This image is a "Full-Source" build. To comply with the redistributive requirements of the original authors, we include the complete source code, build artifacts, and license files.

| Component | License | Location in Image |
| :--- | :--- | :--- |
| **OMNeT++** | Academic Public License | `/opt/omnetpp` |
| **INET Framework** | GNU LGPL | `/opt/inet` |
| **Simu5G** | GNU LGPL | `/opt/simu5g` |
| **License Files** | ---- | `/usr/share/licenses` |

The original `LICENSE` and `README` files are included in `usr/share/licenses` as provided by the upstream projects. They are also available in their respective source directories.

-----

## Licensing & Compliance

### 1\. The Dockerfile & Repository Code

The source code contained in this repository (the `Dockerfile` and any custom configuration scripts) is licensed under the **MIT License**. You are free to modify and reuse these scripts for any purpose.

### 2\. The Resulting Docker Image

The Docker image published to the registry is a collective work. Because it contains and is reliant upon OMNeT++, the **entire image bundle is distributed under the [OMNeT++ Academic Public License](https://github.com/omnetpp/omnetpp/blob/omnetpp-6.x/doc/License)**.

### 3\. LGPL Compliance (INET and Simu5G)

The INET Framework and Simu5G are included under the **GNU Lesser General Public License (LGPL)**.

  * We provide the complete machine-readable source code for INET and Simu5G within the image at `/opt/inet` and `/opt/simu5g` respectively.
  * Users may modify the INET and Simu5G source code within their own layers; however, those modifications must also be shared under the LGPL if redistributed.

-----

## Usage in Derived Projects

You can use this image as a base for your own research simulations:

```dockerfile
# Use our pre-compiled builder
FROM ghcr.io/cengwins/omnetaio:latest AS omnetaio

# Copy the pre-built OMNeT++, INET, and Simu5G installations into your new image
COPY --from=omnetaio /opt/omnetpp /opt/omnetpp
COPY --from=omnetaio /opt/inet /opt/inet
COPY --from=omnetaio /opt/simu5g /opt/simu5g
COPY --from=omnetaio /usr/share/licenses /usr/share/licenses
```

-----

**Disclaimer:** *This image is provided "as is" without warranty of any kind. WINS Lab is not affiliated with the OMNeT++ or INET core development teams.*
