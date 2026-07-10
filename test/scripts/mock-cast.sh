#!/usr/bin/env bash
set -euo pipefail

command=$1
shift

case "$command" in
    chain-id)
        echo "1"
        ;;
    codehash)
        case "${1,,}" in
            0x0000000000000000000000000000000000000011)
                echo "0x1111111111111111111111111111111111111111111111111111111111111111"
                ;;
            0x0000000000000000000000000000000000000022)
                echo "0x2222222222222222222222222222222222222222222222222222222222222222"
                ;;
            0x00000000000000000000000000000000000000b1)
                echo "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                ;;
            *)
                echo "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
                ;;
        esac
        ;;
    call)
        case "$2" in
            "lineMom()(address)") echo "0x0000000000000000000000000000000000000021" ;;
            "label()(string)") echo '"Incident batch"' ;;
            "leaves()(address[])") echo '[0x0000000000000000000000000000000000000011, 0x0000000000000000000000000000000000000022]' ;;
            "configHash()(bytes32)") echo "0x66fbf5b80224f0df35fa2a524c580bc83ea780a0e2e0dda40366cf190f725300" ;;
            *) echo "mock-cast: unsupported call: $2" >&2; exit 2 ;;
        esac
        ;;
    abi-encode)
        echo "0xabcdef"
        ;;
    keccak)
        if [[ "$1" == "BatchDeployed(address,bytes32,uint8)" ]]; then
            echo "0xb20dab77fc2616d68d46577b9b7f8ac73dfd05bfdc661bcd0db909ee488f1e30"
        else
            echo "0x66fbf5b80224f0df35fa2a524c580bc83ea780a0e2e0dda40366cf190f725300"
        fi
        ;;
    receipt)
        if [[ "$1" == "0x2222222222222222222222222222222222222222222222222222222222222222" ]]; then
            echo '{"status":"0x1","transactionHash":"0x2222222222222222222222222222222222222222222222222222222222222222","blockNumber":"0x1","logs":[]}'
        else
            echo '{"status":"0x1","transactionHash":"0x9999999999999999999999999999999999999999999999999999999999999999","blockNumber":"0x4","logs":[{"address":"0x00000000000000000000000000000000000000f1","topics":["0xb20dab77fc2616d68d46577b9b7f8ac73dfd05bfdc661bcd0db909ee488f1e30","0x00000000000000000000000000000000000000000000000000000000000000b1","0x66fbf5b80224f0df35fa2a524c580bc83ea780a0e2e0dda40366cf190f725300"],"data":"0x0000000000000000000000000000000000000000000000000000000000000001"}]}'
        fi
        ;;
    to-dec)
        if [[ "$1" == "0x1" ]]; then echo "1"; else echo "4"; fi
        ;;
    create2)
        echo "0x00000000000000000000000000000000000000b1"
        ;;
    *)
        echo "mock-cast: unsupported command: $command" >&2
        exit 2
        ;;
esac
