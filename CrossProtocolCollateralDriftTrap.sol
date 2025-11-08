// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

interface ILendingProtocol {
    function totalCollateral(address token) external view returns (uint256);
    function totalDebt(address token) external view returns (uint256);
    function getPrice(address token) external view returns (uint256);
}

contract CrossProtocolCollateralDriftTrap is ITrap {
    uint256 public constant COLLATERAL_DRIFT_THRESHOLD_BP = 500; // 5% divergence

    address public owner;
    address public protocolA;
    address public protocolB;

    string constant MESSAGE = "Cross-Protocol Collateral Drift Detected";

    struct CollateralData {
        address token;
        uint256 collateralA;
        uint256 debtA;
        uint256 collateralB;
        uint256 debtB;
        uint256 priceA;
        uint256 priceB;
        uint256 ratioA_BP;
        uint256 ratioB_BP;
        uint256 timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Set the protocol addresses dynamically
    function setProtocols(address _protocolA, address _protocolB) external onlyOwner {
        protocolA = _protocolA;
        protocolB = _protocolB;
    }

    /// @notice Collects current collateral/debt ratios safely
    function collect() external view override returns (bytes memory) {
        address token = address(this); // Drosera binds the token dynamically

        uint256 collateralA;
        uint256 debtA;
        uint256 priceA;
        uint256 collateralB;
        uint256 debtB;
        uint256 priceB;

        if (protocolA != address(0)) {
            try ILendingProtocol(protocolA).totalCollateral(token) returns (uint256 cA) { collateralA = cA; } catch {}
            try ILendingProtocol(protocolA).totalDebt(token) returns (uint256 dA) { debtA = dA; } catch {}
            try ILendingProtocol(protocolA).getPrice(token) returns (uint256 pA) { priceA = pA; } catch {}
        }

        if (protocolB != address(0)) {
            try ILendingProtocol(protocolB).totalCollateral(token) returns (uint256 cB) { collateralB = cB; } catch {}
            try ILendingProtocol(protocolB).totalDebt(token) returns (uint256 dB) { debtB = dB; } catch {}
            try ILendingProtocol(protocolB).getPrice(token) returns (uint256 pB) { priceB = pB; } catch {}
        }

        uint256 ratioA_BP = debtA > 0 ? (collateralA * priceA * 10_000) / debtA : 0;
        uint256 ratioB_BP = debtB > 0 ? (collateralB * priceB * 10_000) / debtB : 0;

        CollateralData memory data = CollateralData({
            token: token,
            collateralA: collateralA,
            debtA: debtA,
            collateralB: collateralB,
            debtB: debtB,
            priceA: priceA,
            priceB: priceB,
            ratioA_BP: ratioA_BP,
            ratioB_BP: ratioB_BP,
            timestamp: block.timestamp
        });

        return abi.encode(data);
    }

    /// @notice Pure function to check for anomalous cross-protocol drift
    function shouldRespond(bytes[] calldata samples)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (samples.length == 0) return (false, bytes(""));
        CollateralData memory latest = abi.decode(samples[0], (CollateralData));

        uint256 drift = latest.ratioA_BP > latest.ratioB_BP
            ? latest.ratioA_BP - latest.ratioB_BP
            : latest.ratioB_BP - latest.ratioA_BP;

        if (drift >= COLLATERAL_DRIFT_THRESHOLD_BP) {
            return (true, abi.encode(MESSAGE, abi.encode(latest)));
        }
        return (false, bytes(""));
    }
}
