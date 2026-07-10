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
            0x00000000000000000000000000000000000000f1)
                echo "0xf1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1"
                ;;
            *)
                echo "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
                ;;
        esac
        ;;
    call)
        case "$2" in
            "action()(address)") echo "$1" ;;
            "pause()(address)") echo "0x0000000000000000000000000000000000000012" ;;
            "autoLine()(address)")
                if [[ "${1,,}" == "0x0000000000000000000000000000000000000011" ]]; then
                    echo "0x0000000000000000000000000000000000000022"
                else
                    echo "0x0000000000000000000000000000000000000034"
                fi
                ;;
            "vat()(address)") echo "0x0000000000000000000000000000000000000023" ;;
            "ilk()(bytes32)") echo "0x4554482d41000000000000000000000000000000000000000000000000000000" ;;
            "lineMom()(address)") echo "0x0000000000000000000000000000000000000021" ;;
            "ilkRegistry()(address)") echo "0x0000000000000000000000000000000000000032" ;;
            "osm()(address)") echo "0x0000000000000000000000000000000000000042" ;;
            "osmMom()(address)") echo "0x0000000000000000000000000000000000000041" ;;
            "label()(string)") echo '"Incident batch"' ;;
            "leaves()(address[])") echo '[0x0000000000000000000000000000000000000011, 0x0000000000000000000000000000000000000022]' ;;
            "configHash()(bytes32)") echo "0x66fbf5b80224f0df35fa2a524c580bc83ea780a0e2e0dda40366cf190f725300" ;;
            "previewDeterministicAddress(address[],string)(address)") echo "0x00000000000000000000000000000000000000b1" ;;
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
    calldata)
        echo "0xdeadbeef"
        ;;
    tx)
        case "$1" in
            0x2222222222222222222222222222222222222222222222222222222222222222)
                input=0x60001234
                if [[ "${BROKEN_TX_INPUT:-0}" == "1" ]]; then input=0x600099; fi
                echo "{\"to\":null,\"input\":\"$input\"}"
                ;;
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                echo '{"to":null,"input":"0x6000"}'
                ;;
            *)
                input=0xdeadbeef
                if [[ "${BROKEN_FACTORY_CALL:-0}" == "1" ]]; then input=0xfeedface; fi
                echo "{\"to\":\"0x00000000000000000000000000000000000000f1\",\"input\":\"$input\"}"
                ;;
        esac
        ;;
    receipt)
        if [[ "$1" == "0x2222222222222222222222222222222222222222222222222222222222222222" ]]; then
            contract=0x0000000000000000000000000000000000000011
            if [[ "${BROKEN_RECEIPT_ADDRESS:-0}" == "1" ]]; then contract=0x0000000000000000000000000000000000000099; fi
            echo "{\"status\":\"0x1\",\"transactionHash\":\"0x2222222222222222222222222222222222222222222222222222222222222222\",\"blockNumber\":\"0x1\",\"contractAddress\":\"$contract\",\"logs\":[]}"
        elif [[ "$1" == "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ]]; then
            echo '{"status":"0x1","transactionHash":"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","blockNumber":"0x1","contractAddress":"0x00000000000000000000000000000000000000f1","logs":[]}'
        else
            emitter=0x00000000000000000000000000000000000000f1
            if [[ "${BROKEN_EVENT:-0}" == "1" ]]; then emitter=0x00000000000000000000000000000000000000f2; fi
            echo "{\"status\":\"0x1\",\"transactionHash\":\"0x9999999999999999999999999999999999999999999999999999999999999999\",\"blockNumber\":\"0x4\",\"contractAddress\":null,\"logs\":[{\"address\":\"$emitter\",\"topics\":[\"0xb20dab77fc2616d68d46577b9b7f8ac73dfd05bfdc661bcd0db909ee488f1e30\",\"0x00000000000000000000000000000000000000000000000000000000000000b1\",\"0x66fbf5b80224f0df35fa2a524c580bc83ea780a0e2e0dda40366cf190f725300\"],\"data\":\"0x0000000000000000000000000000000000000000000000000000000000000001\"}]}"
        fi
        ;;
    to-dec)
        case "$1" in
            0x1) echo "1" ;;
            0x5) echo "5" ;;
            *) echo "4" ;;
        esac
        ;;
    create2)
        echo "0x00000000000000000000000000000000000000b1"
        ;;
    *)
        echo "mock-cast: unsupported command: $command" >&2
        exit 2
        ;;
esac
