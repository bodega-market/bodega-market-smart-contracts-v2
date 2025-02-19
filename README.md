# Bodega Market Contracts (Beta)

## Overview

Bodega enables users to create and participate in prediction markets with ease, offering flexibility in payment tokens, a fee-sharing mechanism, and scalable infrastructure for global adoption.

## Features

1. **Create Your Own Market**  
   Users can deploy custom prediction markets for any topic they choose. Whether it's sports, politics, or events, Bodega provides the tools to tailor your market to your specific needs.

2. **Flexible Payment Options**  
   Bodega supports payments with **any type of token** on Cardano. Market creators can define their preferred token for participation, enhancing accessibility and broadening the user base.

3. **Fee Based on Volume**  
   - Fees are determined by the transaction volume within the market.  
   - These fees are shared between the **market creator** and the **protocol**, creating incentives for both participants and developers to drive activity.

## How It Works

### Market Creation  

Deploy a new market using the contract interface. Define the candidates, payment token, and resolution method.

### Participation

Users can join markets by contributing their tokens based on their predictions.

### Fee Sharing

- A portion of the transaction fees is allocated to the market creator.  
- The remaining fees go to the protocol to sustain and grow the Bodega ecosystem.

### Market Resolution  

Once the market conditions are met or the event concludes, the protocol handles payout distribution based on the outcomes.

## Protocol Design

### Minting and Validation Scripts

#### 1. Protocol Management

- **MP - Batcher License**: Mints a batcher license token, verified by spending the protocol manager UTXO.
- **MP - Protocol AT**: Mints protocol settings and manager authentication tokens.
- **V - Protocol Manager**: Validates the spending of the manager UTXO to authorize protocol and project-related actions.
- **V - Protocol Settings**: Ensures the integrity of protocol configurations by validating the spending of the settings UTXO.
- **V - Protocol Treasury**: Controls treasury spending, which accumulates funds from protocol and project fees.

#### 2. Project Lifecycle

- **MP - Project AT**: Mints project metadata and project prediction tokens when a new project is created.
- **V - Project Info**: Validates the spending of the project info UTXO, ensuring all project details are correctly stored in the datum.
- **V - Project Prediction**: Handles validation for applying buy/reward positions, withdrawing fees, or processing refunds by consuming the project prediction UTXO.
- **V - project positions**: Handles validation for buying/reward positions,
- **MP - Project Share**: Mints or burns tokens that represent the amount of payment tokens used to buy or sell positions.

#### 3. Security and Reference Scripts

- **V - Reference Script Lock**: Ensures proper validation when spending reference script UTXOs that store all required reference scripts.
- **MP - Reference Script Lock**: Mints tokens to associate with the corresponding reference scripts.

## Flows

### 1. Initialize Protocol

- Define the protocol configuration.
- Mint **protocol settings** and **protocol manager authentication tokens**, then send them to their respective script addresses.
- Mint **reference script tokens** and send them along with the corresponding scripts to the reference script address.

### 2. Create Project

- Define project details.
- Mint **project authentication tokens** and send them to the **project info UTXO** with the pledge.
- Send the tokens to the **project predictions script address** along with the relevant information in the datum.
- Transfer the **open fee** to the **treasury address**.

### 3. Buy Position

- A user sends a specified amount of **payment tokens** to the **position script address**, along with the **buy information** stored in the datum.

### 4. Batch Buy Position

- The **batcher** collects all buy positions stored in the **position script address**.
- These positions are then applied to the **project prediction**.
- Users receive **share tokens** corresponding to the amount they have purchased.

### 5. Reward Position

- A user sends a specified amount of **payment tokens** to the **position script address**, along with **reward information** stored in the datum.

### 6. Batch Reward Position

- The **batcher** collects all reward positions stored in the **position script address**.
- These positions are then applied to the **project prediction**.
- Users receive **rewards** based on the **share tokens** they hold.

### 7. Withdraw Admin Fee

- The **batcher** collects fees from **prediction UTXOs** and sends them to the **treasury**.
- The **reward percentage** is then distributed between the **project creator** and the **protocol** by `share_ratio` defined in the project info datum.

### 8. Close Project

- The **project info UTXO** and **project prediction UTXO** are collected.
- The **pledge** is returned to the **project creator**.
