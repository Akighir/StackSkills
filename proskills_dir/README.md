# StackSkills: Decentralized Skills Marketplace

StackSkills is a decentralized skills marketplace built on the Stacks blockchain. It allows professionals to list their services, clients to book these services, and facilitates secure transactions between parties.

## Features

- Service listing creation and management
- Secure service booking and payment processing
- Decentralized storage of service credentials
- User marketplace statistics tracking
- Platform fee management

## Smart Contract Overview

The StackSkills smart contract is written in Clarity and provides the following main functions:

1. `create-service-listing`: Allows professionals to list their services
2. `book-service`: Enables clients to book and pay for services
3. `get-service-credentials`: Retrieves service access details for booked services
4. `update-service-price`: Allows service providers to update their prices
5. `deactivate-service`: Enables providers to remove their service listings
6. `update-platform-fee`: Admin function to adjust the platform fee

## Data Structures

The contract uses the following main data structures:

- `service-listings`: Stores details of listed services
- `user-marketplace-stats`: Tracks user statistics and ratings
- `completed-bookings`: Records completed service bookings
- `service-credentials`: Stores encrypted access details for services

## Getting Started

To interact with the StackSkills marketplace, you'll need a Stacks wallet and some STX tokens. Here's how to get started:

1. Deploy the smart contract to the Stacks blockchain
2. Use a Stacks wallet (e.g., Hiro Wallet) to interact with the contract
3. List your services or browse available services
4. Book services and complete transactions

## Development

To work on this project, you'll need:

- [Clarinet](https://github.com/hirosystems/clarinet): A Clarity runtime packaged as a command line tool
- [Stacks Blockchain API](https://github.com/blockstack/stacks-blockchain-api): To interact with the Stacks blockchain

## Contributing

We welcome contributions to StackSkills! Please feel free to submit issues, create pull requests, or reach out with suggestions.
