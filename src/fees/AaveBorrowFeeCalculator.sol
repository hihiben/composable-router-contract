// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FeeBase} from './FeeBase.sol';
import {IAaveV3Provider} from '../interfaces/aaveV3/IAaveV3Provider.sol';
import {IFeeCalculator} from '../interfaces/IFeeCalculator.sol';

contract AaveBorrowFeeCalculator is IFeeCalculator, FeeBase {
    address private constant _AAVE_V3_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    bytes32 private constant _V2_BORROW_META_DATA = bytes32(bytes('aave-v2:borrow'));
    bytes32 private constant _V3_BORROW_META_DATA = bytes32(bytes('aave-v3:borrow'));

    constructor(address router, uint256 feeRate) FeeBase(router, feeRate) {}

    function getFees(
        address callee,
        bytes calldata data
    ) external view returns (address[] memory, uint256[] memory, bytes32) {
        // Aave borrow signature:'borrow(address,uint256,uint256,uint16,address)', selector:0xa415bcad
        (address token, uint256 amount, , , ) = abi.decode(data[4:], (address, uint256, uint256, uint16, address));
        address[] memory tokens = new address[](1);
        tokens[0] = token;

        uint256[] memory fees = new uint256[](1);
        fees[0] = calculateFee(amount);

        bytes32 metadata = callee == IAaveV3Provider(_AAVE_V3_PROVIDER).getPool()
            ? _V3_BORROW_META_DATA
            : _V2_BORROW_META_DATA;
        return (tokens, fees, metadata);
    }

    function getDataWithFee(bytes calldata data) external view returns (bytes memory) {
        (address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) = abi.decode(
            data[4:],
            (address, uint256, uint256, uint16, address)
        );
        amount = calculateAmountWithFee(amount);
        return abi.encodePacked(data[:4], abi.encode(asset, amount, interestRateMode, referralCode, onBehalfOf));
    }
}
