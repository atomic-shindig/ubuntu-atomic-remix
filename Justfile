default:
    #!/usr/bin/env bash
    set -xeuo pipefail
    just build-sysupdate

build-sysupdate:
    mkosi -B --debug --profile=sysupdate,desktop

build-iso:
    mkosi -B --debug --profile=iso

clean:
    mkosi clean
    sudo rm -r mkosi.tools/ mkosi.cache/
