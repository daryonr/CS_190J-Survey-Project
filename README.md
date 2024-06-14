## Block Poll

**Abstract**

This project showcases a blockchain-based survey system that prioritizes user anonymity and incentivizes participation through a novel rewards structure. The system facilitates the decentralized creation, participation, and management of surveys, leveraging blockchain technology's inherent security and transparency. Developed using Solidity and the Foundry toolchain, it ensures that survey data remains immutable, verifiable, and securely stored. Our goal is to integrate the advantages of blockchain technology with innovative survey functionalities to create a robust and user-friendly platform.

## Overview

Our blockchain survey system is designed with several key features and functionalities:

- **User Registration**: Users can register custom account names linked to their blockchain addresses, required for creating surveys. Participants can engage in surveys without registration, maintaining anonymity.
- **Survey Creation**: Registered users can create surveys with a problem description and multiple numerical options. Each survey includes an expiry block timestamp and a maximum number of responses.
- **Survey Participation**: Surveys are identified by unique IDs for easy access and participation. Users can view active surveys by their IDs and submit one response per survey. Responses are recorded on the blockchain, ensuring data integrity and anonymity.
- **Survey Closure and Rewards**: Surveys can be closed manually or automatically upon expiry or reaching the maximum number of responses. Participants receive ETH rewards, managed by smart contracts, to incentivize participation.

In summary, this blockchain survey system offers a secure, transparent, and user-friendly platform for conducting surveys. By integrating blockchain technology with features like public/private results and participation bonuses, the system provides a dynamic and engaging user experience. The use of Solidity and Foundry ensures the integrity and security of survey data, making this a reliable tool for collecting and managing survey responses. 

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/BlockPoll.s.sol:BlockPollScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
