// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossProtocolCollateralDriftResponse {
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

    struct Report {
        CollateralData data;
        string message;
        uint256 id;
        address reporter;
    }

    event CollateralDriftAlert(address indexed reporter, uint256 ratioA_BP, uint256 ratioB_BP, uint256 timestamp);
    event ReportLogged(uint256 indexed id, address indexed reporter, bytes encodedData, string message);

    uint256 public nextId = 1;
    Report[] public reports;
    mapping(address => uint256[]) public userReports;

    function respond(string memory message, bytes calldata encodedData) external {
        CollateralData memory data = abi.decode(encodedData, (CollateralData));

        emit CollateralDriftAlert(msg.sender, data.ratioA_BP, data.ratioB_BP, data.timestamp);

        Report memory r = Report({
            data: data,
            message: message,
            id: nextId++,
            reporter: msg.sender
        });

        reports.push(r);
        userReports[msg.sender].push(r.id);

        emit ReportLogged(r.id, msg.sender, encodedData, message);
    }

    function getReportsCount() external view returns (uint256) {
        return reports.length;
    }

    function getReport(uint256 id) external view returns (Report memory) {
        require(id < reports.length, "Invalid ID");
        return reports[id];
    }
}
