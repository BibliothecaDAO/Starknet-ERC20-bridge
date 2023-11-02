<a href="https://twitter.com/lootrealms">
<img src="https://img.shields.io/twitter/follow/lootrealms?style=social"/>
</a>
<a href="https://twitter.com/BibliothecaDAO">
<img src="https://img.shields.io/twitter/follow/BibliothecaDAO?style=social"/>
</a>

[![discord](https://img.shields.io/badge/join-bibliothecadao-black?logo=discord&logoColor=white)](https://discord.gg/realmsworld)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

# Starknet Lords ERC20 bridge

LORDS token bridge between Ethereum and Starknet.

## Important addresses

* L1 token: `0x686f2404e77Ab0d9070a46cdfb0B7feCDD2318b0` [Etherscan](https://etherscan.io/token/0x686f2404e77Ab0d9070a46cdfb0B7feCDD2318b0)
* L1 bridge: `0x023A2aAc5d0fa69E3243994672822BA43E34E5C9` [Etherscan](https://etherscan.io/address/0x023a2aac5d0fa69e3243994672822ba43e34e5c9)
* L2 token: `0x124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49` [Starkscan](https://starkscan.co/contract/0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49) [Voyager](https://voyager.online/contract/0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49)
* L2 bridge: `0x7c76a71952ce3acd1f953fd2a3fda8564408b821ff367041c89f44526076633` [Starkscan](https://starkscan.co/contract/0x07c76a71952ce3acd1f953fd2a3fda8564408b821ff367041c89f44526076633) [Voyager](https://voyager.online/contract/0x07c76a71952ce3acd1f953fd2a3fda8564408b821ff367041c89f44526076633)

## Architecture

### Overview

The bridge is built in a minimal fashion, without any external dependencies, immutable, non-upgradable. There is no support for message cancellation. It is built using Cairo v1.1.

For the high level overview of how Starknet L1 <> L2 messaging works, consult the [official documentation](https://docs.starknet.io/documentation/architecture_and_concepts/L1-L2_Communication/messaging-mechanism/).

### L1 -> L2 bridging

When you want to bridge your $LORDS from Ethereum to Starknet, you need to call the `deposit` function of the L1 bridge with the amount of tokens to be bridged and the Starknet address to which the $LORDS will be added to. You'll also have to pay a small fee (at the time of writing set to 1 wei, but this is bound to change in the future) for the Starknet OS to process the message. The bridge calls `transferFrom` so you'll also have to `approve` it beforehand.

Once the Starknet sequencer processes the message, your L2 address will see the increased $LORDS balance. The L1 bridge acts as an escrow for the tokens, locking them in until (if ever) they are withdrawn from L2.

<pre>

                             ┌────────────────┐
                             │   L1 $LORDS    │
                             │     token      │
                             │    contract    │
                             └────────────────┘
                                      ▲
                                      │
                                      │
                                transferFrom
                                      │
  ┌─────────────┐             ┌───────┴───────┐
  │  Ethereum   │             │               │
  │   $LORDS    │────deposit─▶│  bridge.sol   │────┐
  │    owner    │             │               │    │
  └─────────────┘             └───────────────┘    │
                                                   │
                                            sendMessageToL2
                                                   │
                                                   │
                              ┌─────────────────┐  │
                              │                 │  │
                           ┌──│  StarkNet Core  │◀─┘
                           │  │                 │
                           │  └─────────────────┘
                           │
                           │
                    handle_deposit
                           │
                           │   ┌────────────────┐
                           │   │                │
                           └──▶│  bridge.cairo  │
                               │                │
                               └────────────────┘
                                        │
                                       mint
                                        │
                                        ▼
                               ┌────────────────┐           ┌───────────┐
                               │                │           │ Starknet  │
                               │  token.cairo   ├──────────▶│  $LORDS   │
                               │                │           │   owner   │
                               └────────────────┘           └───────────┘</pre>

### L2 -> L1 bridging

When moving $LORDS back from Starknet to Ethereum, call the `initiate_withdrawal` function on the L2 bridge with the L1 address and the amount of tokens to bridge back over to L1. After the sequencer processes the transaction and settles back to L1, you will be able to reclaim your $LORDS by calling `withdraw` on the L1 bridge contract. Note that you have to call `withdraw` with the same values as supplied to `initiate_withdraw` on L2, otherwise the L1 transaction will fail.


<pre>
                                                   ┌────────────────┐
                                                   │                │
                                                   │  token.cairo   │
                                                   │                │
                                                   └────────────────┘
                                                            ▲
                                                            │
                                                           burn
                                                            │
                                                            │
          ┌───────────┐                            ┌────────────────┐
          │ Starknet  │                            │                │
          │  $LORDS   │────initiate_withdrawal────▶│  bridge.cairo  │───┐
          │   owner   │                            │                │   │
          └───────────┘                            └────────────────┘   │
                                                                        │
                                                                        │
                                                                        │
                                                               send_message_to_l1
                                                                        │
                                                                        │
                                                   ┌─────────────────┐  │
                                                   │                 │  │
                                            ┌─────▶│  Starknet Core  │◀─┘
                                            │      │                 │
                                            │      └─────────────────┘
                                            │
                                  consumeMessageFromL2
                                            │
                                            │
           ┌─────────┐              ┌───────────────┐
           │Ethereum │              │               │
           │   EOA   │──withdraw───▶│  bridge.sol   │────────┐
           │         │              │               │        │
           └─────────┘              └───────────────┘        │
                                                         transfer
                                                             │
                                                             ▼
                                                    ┌────────────────┐
                                                    │   L1 $LORDS    │
                                                    │     token      │
                                                    │    contract    │
                                                    └────────────────┘              </pre>
