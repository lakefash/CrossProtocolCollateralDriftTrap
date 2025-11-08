# CrossProtocolCollateralDriftTrap
# README — CrossProtocolCollateralDriftTrap

## Overview

CrossProtocolCollateralDriftTrap monitors the same token across two lending protocols. It compares each protocol’s collateral to debt ratio. If the ratios diverge beyond a fixed threshold, the trap signals drift. This helps detect pricing mismatch or collateral accounting imbalance.

This repository contains the trap ⁠ CrossProtocolCollateralDriftTrap.sol ⁠, the response contract ⁠ CrossProtocolCollateralDriftResponse.sol ⁠, and the ⁠ drosera.toml ⁠ configuration.

---

## Files in this repo

•⁠  ⁠⁠ src/CrossProtocolCollateralDriftTrap.sol ⁠ — main trap contract implementing ⁠ ITrap ⁠
•⁠  ⁠⁠ src/CrossProtocolCollateralDriftResponse.sol ⁠ — response contract for storage and reporting
•⁠  ⁠⁠ drosera.toml ⁠ — Drosera relay configuration
•⁠  ⁠⁠ http://README.md ⁠ — documentation

---

## Behaviour and data flow

1.⁠ ⁠Operator calls ⁠ setProtocols(address protocolA, address protocolB) ⁠.
2.⁠ ⁠The trap reads collateral, debt, and price data from both protocols through ⁠ collect() ⁠.
3.⁠ ⁠⁠ collect() ⁠ returns encoded ⁠ CollateralData ⁠.
4.⁠ ⁠Drosera collects samples and passes them to ⁠ shouldRespond(bytes[] samples) ⁠.
5.⁠ ⁠⁠ shouldRespond ⁠ checks the ratio difference.
6.⁠ ⁠If the difference is greater than ⁠ COLLATERAL_DRIFT_THRESHOLD_BP ⁠, the trap returns ⁠ (true, encodedPayload) ⁠.
7.⁠ ⁠The relay calls the response contract ⁠ respond(string,bytes) ⁠ using the encoded data.

---

## Deploying

1.⁠ ⁠Run ⁠ forge build ⁠.
2.⁠ ⁠Deploy ⁠ CrossProtocolCollateralDriftResponse.sol ⁠. Save the deployed address.
3.⁠ ⁠Deploy ⁠ CrossProtocolCollateralDriftTrap.sol ⁠.
4.⁠ ⁠Call ⁠ setProtocols(&lt;PROTOCOL_A&gt;, &lt;PROTOCOL_B&gt;) ⁠.
5.⁠ ⁠Update ⁠ drosera.toml ⁠ with:
   - response contract address
   - operator whitelist
   - block sample size and cooldown settings

---

## Quick ⁠ cast ⁠ examples

Check live collateral ratios:
cast call &lt;TRAP_ADDRESS&gt; "collect()" --rpc-url
Decode the result:

cast abi-decode "(address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)"

Check drift:

cast call &lt;TRAP_ADDRESS&gt; "shouldRespond(bytes[])" '[,]' --rpc-url

Submit report manually:

cast send &lt;RESPONSE_ADDRESS&gt; "respond(string,bytes)" "Cross-Protocol Collateral Drift Detected" &lt;ENCODED_DATA&gt; --private-key  --rpc-url

---

## Foundry test example
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/CrossProtocolCollateralDriftTrap.sol";
import "../src/CrossProtocolCollateralDriftResponse.sol";
contract CrossProtocolCollateralDriftTrapTest is Test {
CrossProtocolCollateralDriftTrap trap;
CrossProtocolCollateralDriftResponse response;

function setUp() public {
    trap = new CrossProtocolCollateralDriftTrap();
    response = new CrossProtocolCollateralDriftResponse();
    trap.setProtocols(address(0xA1), address(0xB1));
}

function testCollect() public {
    bytes memory data = trap.collect();
    assertTrue(data.length &gt; 0);
}

function testShouldRespond() public {
    CrossProtocolCollateralDriftTrap.CollateralData memory mock = CrossProtocolCollateralDriftTrap.CollateralData(
        address(0xToken),
        100e18,
        50e18,
        200e18,
        100e18,
        1e18,
        1e18,
        20000,
        15000,
        block.timestamp
    );

    bytes memory encoded = abi.encode(mock);
    bytes;
    samples[0] = encoded;

    (bool trigger, bytes memory payload) = trap.shouldRespond(samples);
    assertTrue(trigger);

    response.respond("Drift Alert", payload);
}

}

---

## drosera.toml example
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"
[traps]
[traps.crossprotocolcollateraldrift]
path = "out/CrossProtocolCollateralDriftTrap.sol/CrossProtocolCollateralDriftTrap.json"
response_contract = "REPLACE_WITH_RESPONSE_ADDRESS"
response_function = "respond(string,bytes)"
cooldown_period_blocks = 30
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["REPLACE_WITH_OPERATOR_ADDRESS"]

